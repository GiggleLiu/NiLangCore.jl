struct CompileInfo
    invcheckon::Ref{Bool}
end
CompileInfo() = CompileInfo(Ref(true))

function compile_body(m::Module, body::AbstractVector, info)
    out = []
    for ex in body
        ex_ = compile_ex(m, ex, info)
        ex_ !== nothing && push!(out, ex_)
    end
    return out
end

deleteindex!(d::AbstractDict, index) = delete!(d, index)

@inline function map_func(x::Symbol)
    if x == :+=
        PlusEq, false
    elseif x == :.+=
        PlusEq, true
    elseif x == :-=
        MinusEq, false
    elseif x == :.-=
        MinusEq, true
    elseif x == :*=
        MulEq, false
    elseif x == :.*=
        MulEq, true
    elseif x == :/=
        DivEq, false
    elseif x == :./=
        DivEq, true
    elseif x == :⊻=
        XorEq, false
    elseif x == :.⊻=
        XorEq, true
    else
        error("`$x` can not be mapped to a reversible function.")
    end
end

# e.g. map `x += sin(z)` => `PlusEq(sin)(x, z)`.
function to_standard_format(ex::Expr)
    head::Symbol = ex.head
    F, isbcast = map_func(ex.head)
    a, b = ex.args
    if !isbcast
        @smatch b begin
            :($f($(args...); $(kwargs...))) => :($F($f)($a, $(args...); $(kwargs...)))
            :($f($(args...))) => :($F($f)($a, $(args...)))
            :($x || $y) => :($F($logical_or)($a, $x, $y))
            :($x && $y) => :($F($logical_and)($a, $x, $y))
            _ => :($F(identity)($a, $b))
        end
    else
        @smatch b begin
            :($f.($(args...); $(kwargs...))) => :($F($f).($a, $(args...); $(kwargs...)))
            :($f.($(args...))) => :($F($f).($a, $(args...)))
            :($f($(args...); $(kwargs...))) => :($F($(removedot(f))).($a, $(args...); $(kwargs...)))
            :($f($(args...))) => :($F($(removedot(f))).($a, $(args...)))
            _ => :($F(identity).($a, $b))
        end
    end
end
logical_or(a, b) = a || b
logical_and(a, b) = a && b

"""
    compile_ex(m::Module, ex, info)

Compile a NiLang statement to a regular julia statement.
"""
function compile_ex(m::Module, ex, info)
    @smatch ex begin
        :($a += $b) || :($a .+= $b) ||
        :($a -= $b) || :($a .-= $b) ||
        :($a *= $b) || :($a .*= $b) ||
        :($a /= $b) || :($a ./= $b) ||
        :($a ⊻= $b) || :($a .⊻= $b) => compile_ex(m, to_standard_format(ex), info)
        :(($t1=>$t2)($x)) => assign_ex(x, :(convert($t2, $x)), info.invcheckon[])
        :(($t1=>$t2).($x)) => assign_ex(x, :(convert.($t2, $x)), info.invcheckon[])

        # multi args expanded in preprocessing
        # general
        :($x ↔ $y) => begin
            e1 = isemptyvar(x)
            e2 = isemptyvar(y)
            if e1 && e2
                nothing
            elseif e1 && !e2
                _push_value(x, _pop_value(y), info.invcheckon[])
            elseif !e1 && e2
                _push_value(y, _pop_value(x), info.invcheckon[])
            else
                tmp = gensym("temp")
                Expr(:block, :($tmp = $y), assign_ex(y, x, info.invcheckon[]), assign_ex(x, tmp, info.invcheckon[]))
            end
        end

        # stack
        :($s[end] → $x) => begin
            if info.invcheckon[]
                y = gensym("result")
                Expr(:block, :($y=$loaddata($x, $pop!($s))), _invcheck(y, x), assign_ex(x, y, info.invcheckon[]))
            else
                assign_ex(x, :($loaddata($x, $pop!($s))), false)  # assign back can help remove roundoff error
            end
        end
        :($s[end+1] ← $x) => :($push!($s, $_copy($x)))
        # dict
        :($x[$index] ← $tp) => begin
            assign_expr = :($x[$index] = $tp)
            if info.invcheckon[]
                Expr(:block, :(@assert !haskey($x, $index)), assign_expr)
            else
                assign_expr
            end
        end
        :($x[$index] → $tp) => begin
            delete_expr = :($(deleteindex!)($x, $index))
            if info.invcheckon[]
                Expr(:block, _invcheck(:($x[$index]), tp), delete_expr)
            else
                delete_expr
            end
        end
        # multi arg
        :(($(args...),) ← @unsafe_destruct $line $x) => begin
            Expr(:block, line, :(($(args...),) = $type2tuple($x)))
        end
        :(($(args...),) → @unsafe_destruct $line $x) => begin
            Expr(:block, line, Expr(:(=), x, Expr(:new, :(typeof($x)), args...)))
        end
        # general
        :($x ← $tp) => :($x = $tp)
        :($x → $tp) => begin
            if info.invcheckon[]
                _invcheck(x, tp)
            end
        end

        :($f($(args...))) => begin
            assignback_ex(ex, info.invcheckon[])
        end
        :($f.($(allargs...))) => begin
            args, kwargs = seperate_kwargs(allargs)
            symres = gensym("results")
            ex = :($symres = $unzipped_broadcast($kwargs, $f, $(args...)))
            Expr(:block, ex, assign_vars(args, symres, info.invcheckon[]).args...)
        end
        Expr(:if, _...) => compile_if(m, copy(ex), info)
        :(while ($pre, $post); $(body...); end) => begin
            whilestatement(pre, post, compile_body(m, body, info), info)
        end
        :(for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(m, body, info), info, nothing)
        end
        :(@simd $line for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(m, body, info), info, Symbol("@simd")=>line)
        end
        :(@threads $line for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(m, body, info), info, Symbol("@threads")=>line)
        end
        :(@avx $line for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(m, body, info), info, Symbol("@avx")=>line)
        end
        :(begin $(body...) end) => begin
            Expr(:block, compile_body(m, body, info)...)
        end
        :(@safe $line $subex) => subex
        :(@inbounds $line $subex) => Expr(:macrocall, Symbol("@inbounds"), line, compile_ex(m, subex, info))
        :(@invcheckoff $line $subex) => begin
            state = info.invcheckon[]
            info.invcheckon[] = false
            ex = compile_ex(m, subex, info)
            info.invcheckon[] = state
            ex
        end
        :(@cuda $line $(args...)) => begin
            fcall = @smatch args[end] begin
                :($f($(args...))) => Expr(:call,
                    Expr(:->,
                        :(args...),
                        Expr(:block,
                            :($f(args...)),
                            nothing
                        )
                    ),
                    args...
                )
                _ => error("expect a function after @cuda, got $(args[end])")
            end
            Expr(:macrocall, Symbol("@cuda"), line, args[1:end-1]..., fcall)
        end
        :(@launchkernel $line $device $thread $ndrange $f($(args...))) => begin
            res = gensym("results")
            Expr(:block,
                :($res = $f($device, $thread)($(args...); ndrange=$ndrange)),
                :(wait($res))
            )
        end
        :(nothing) => ex
        ::Nothing => ex
        ::LineNumberNode => ex
        _ => error("statement not supported: `$ex`")
    end
end

function compile_if(m::Module, ex, info)
    pres = []
    posts = []
    ex = analyse_if(m, ex, info, pres, posts)
    Expr(:block, pres..., ex, posts...)
end

function analyse_if(m::Module, ex, info, pres, posts)
    var = gensym("branch")
    if ex.head == :if
        pre, post = ex.args[1].args
        ex.args[1] = var
    elseif ex.head == :elseif
        pre, post = ex.args[1].args[2].args
        ex.args[1].args[2] = var
    end
    push!(pres, :($var = $pre))
    if info.invcheckon[]
        push!(posts, _invcheck(var, post))
    end
    ex.args[2] = Expr(:block, compile_body(m, ex.args[2].args, info)...)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            ex.args[3] = analyse_if(m, ex.args[3], info, pres, posts)
        elseif ex.args[3].head == :block
            ex.args[3] = Expr(:block, compile_body(m, ex.args[3].args, info)...)
        end
    end
    ex
end

function whilestatement(precond, postcond, body, info)
    ex = Expr(:block,
        Expr(:while,
            precond,
            Expr(:block, body...),
        ),
    )
    if info.invcheckon[]
        pushfirst!(ex.args, _invcheck(postcond, false))
        push!(ex.args[end].args[end].args,
            _invcheck(postcond, true)
        )
    end
    ex
end

function forstatement(i, range, body, info, mcr)
    assigns, checkers = compile_range(range)
    exf = Expr(:for, :($i=$range), Expr(:block, body...))
    if !(mcr isa Nothing)
        exf = Expr(:macrocall, mcr.first, mcr.second, exf)
    end
    if info.invcheckon[]
        Expr(:block, assigns..., exf, checkers...)
    else
        exf
    end
end

_pop_value(x) = @smatch x begin
    ::Symbol => x
    :($x::$T) => :($(_pop_value(x))::$T)
    :($s[end]) => :($pop!($s))
    :($s[$ind]) => :($pop!($s, $ind))  # dict (notice pop over vector elements is not allowed.)
    _ => error("can not pop variable $x")
end

_push_value(x, val, invcheck) = @smatch x begin
    :($s[end+1]) => :($push!($s, $val))
    _ => assign_ex(x, val, invcheck)
end

_copy(x) = copy(x)
_copy(x::Tuple) = copy.(x)

export @code_julia

"""
    @code_julia ex

Get the interpreted expression of `ex`.

```julia
julia> @code_julia x += exp(3.0)
quote
    var"##results#267" = ((PlusEq)(exp))(x, 3.0)
    x = var"##results#267"[1]
    try
        (NiLangCore.deanc)(3.0, var"##results#267"[2])
    catch e
        @warn "deallocate fail: `3.0 → var\"##results#267\"[2]`"
        throw(e)
    end
end

julia> @code_julia @invcheckoff x += exp(3.0)
quote
    var"##results#257" = ((PlusEq)(exp))(x, 3.0)
    x = var"##results#257"[1]
end
```
"""
macro code_julia(ex)
    QuoteNode(compile_ex(__module__, ex, CompileInfo()))
end

compile_ex(m::Module, ex) = compile_ex(m, ex, CompileInfo())

export @i

"""
    @i function fname(args..., kwargs...) ... end
    @i struct sname ... end

Define a reversible function/type.

```jldoctest; setup=:(using NiLangCore)
julia> @i function test(out!, x)
           out! += identity(x)
       end

julia> test(0.2, 0.8)
(1.0, 0.8)
```
See `test/compiler.jl` for more examples.
"""
macro i(ex)
    ex = gen_ifunc(__module__, ex)
    ex.args[1] = :(Base.@__doc__ $(ex.args[1]))
    esc(ex)
end

# generate the reversed function
function gen_ifunc(m::Module, ex)
    mc, fname, args, ts, body = precom(m, ex)
    fname = _replace_opmx(fname)

    # implementations
    ftype = get_ftype(fname)

    head = :($fname($(args...)) where {$(ts...)})
    dfname = dual_fname(fname)
    dftype = get_ftype(dfname)
    fdef1 = Expr(:function, head, Expr(:block, compile_body(m, body, CompileInfo())..., functionfoot(args)))
    dualhead = :($dfname($(args...)) where {$(ts...)})
    fdef2 = Expr(:function, dualhead, Expr(:block, compile_body(m, dual_body(m, body), CompileInfo())..., functionfoot(args)))
    if mc !== nothing
        fdef1 = Expr(:macrocall, mc[1], mc[2], fdef1)
        fdef2 = Expr(:macrocall, mc[1], mc[2], fdef2)
    end
    #ex = :(Base.@__doc__ $fdef1; if $ftype != $dftype; $fdef2; end)
    ex = Expr(:block, fdef1,
        Expr(:if, :($ftype != $dftype), fdef2),
        )
end

export nilang_ir
"""
    nilang_ir(ex; reversed::Bool=false)

Get the NiLang reversible IR from the function expression `ex`,
return the reversed function if `reversed` is `true`.

This IR is not directly executable on Julia, please use
`macroexpand(Main, :(@i function .... end))` to get the julia expression of a reversible function.

```jldoctest; setup=:(using NiLangCore)
julia> ex = :(@inline function f(x!::T, y) where T
                @routine begin
                    anc ← zero(T)
                    anc += identity(x!)
                end
                x! += y * anc
                ~@routine
           end);

julia> NiLangCore.nilang_ir(Main, ex) |> NiLangCore.rmlines
:(@inline function f(x!::T, y) where T
          begin
              anc ← zero(T)
              anc += identity(x!)
          end
          x! += y * anc
          begin
              anc -= identity(x!)
              anc → zero(T)
          end
      end)

julia> NiLangCore.nilang_ir(Main, ex; reversed=true) |> NiLangCore.rmlines
:(@inline function (~f)(x!::T, y) where T
          begin
              anc ← zero(T)
              anc += identity(x!)
          end
          x! -= y * anc
          begin
              anc -= identity(x!)
              anc → zero(T)
          end
      end)
```
"""
function nilang_ir(m::Module, ex; reversed::Bool=false)
    mc, fname, args, ts, body = precom(m, ex)
    fname = _replace_opmx(fname)

    # implementations
    if reversed
        dfname = :(~$fname) # use fake head for readability
        head = :($dfname($(args...)) where {$(ts...)})
        body = dual_body(m, body)
    else
        head = :($fname($(args...)) where {$(ts...)})
    end
    fdef = Expr(:function, head, Expr(:block, body...))
    if mc !== nothing
        fdef = Expr(:macrocall, mc[1], mc[2], fdef)
    end
    fdef
end

# seperate and return `args` and `kwargs`
@inline function seperate_kwargs(args)
    if length(args) > 0 && args[1] isa Expr && args[1].head == :parameters
        args = args[2:end], args[1]
    else
        args, Expr(:parameters)
    end
end

# add a `return` statement to the end of the function body.
function functionfoot(args)
    args = get_argname.(seperate_kwargs(args)[1])
    if length(args) == 1
        if args[1] isa Expr && args[1].head == :(...)
            args[1].args[1]
        else
            args[1]
        end
    else
        :(($(args...),))
    end
end

# to provide the eye candy for defining `x += f(args...)` like functions
_replace_opmx(ex) = @smatch ex begin
    :(:+=($f)) => :($(gensym())::PlusEq{typeof($f)})
    :(:-=($f)) => :($(gensym())::MinusEq{typeof($f)})
    :(:*=($f)) => :($(gensym())::MulEq{typeof($f)})
    :(:/=($f)) => :($(gensym())::DivEq{typeof($f)})
    :(:⊻=($f)) => :($(gensym())::XorEq{typeof($f)})
    _ => ex
end

export @instr

"""
    @instr ex

Execute a reversible instruction.
"""
macro instr(ex)
    ex = precom_ex(__module__, ex, NiLangCore.PreInfo())
    #variable_analysis_ex(ex, SymbolTable())
    esc(Expr(:block, NiLangCore.compile_ex(__module__, ex, CompileInfo()), nothing))
end

# the range of for statement
compile_range(range) = @smatch range begin
    :($start:$step:$stop) => begin
        start_, step_, stop_ = gensym("start"), gensym("step"), gensym("stop")
        Any[:($start_ = $start),
        :($step_ = $step),
        :($stop_ = $stop)],
        Any[_invcheck(start_, start),
        _invcheck(step_, step),
        _invcheck(stop_, stop)]
    end
    :($start:$stop) => begin
        start_, stop_ = gensym("start"), gensym("stop")
        Any[:($start_ = $start),
        :($stop_ = $stop)],
        Any[_invcheck(start_, start),
        _invcheck(stop_, stop)]
    end
    :($list) => begin
        list_ = gensym("iterable")
        Any[:($list_ = deepcopy($list))],
        Any[_invcheck(list_, list)]
    end
end

"""
    get_ftype(fname)

Return the function type, e.g.

* `obj::ABC` => `ABC`
* `f` => `typeof(f)`
"""
function get_ftype(fname)
    @smatch fname begin
        :($x::$tp) => tp
        _ => :($NiLangCore._typeof($fname))
    end
end

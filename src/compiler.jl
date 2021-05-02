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
            :($f($(args...); $(kwargs...))) => :($F($(debcast(f))).($a, $(args...); $(kwargs...)))
            :($f($(args...))) => :($F($(debcast(f))).($a, $(args...)))
            _ => :($F(identity).($a, $b))
        end
    end
end

# TODO: add `-x` to expression.
"""translate to normal julia code."""
function compile_ex(m::Module, ex, info)
    @smatch ex begin
        :($a += $b) || :($a .+= $b) ||
        :($a -= $b) || :($a .-= $b) ||
        :($a *= $b) || :($a .*= $b) ||
        :($a /= $b) || :($a ./= $b) ||
        :($a ⊻= $b) || :($a .⊻= $b) => compile_ex(m, to_standard_format(ex), info)
        :(($(args...),) ← @unsafe_destruct $line $x) => begin
            Expr(:block, line, :(($(args...),) = $type2tuple($x)))
        end
        :(($(args...),) → @unsafe_destruct $line $x) => begin
            Expr(:block, line, Expr(:(=), x, Expr(:new, :(typeof($x)), args...)))
        end
        :($x ← new{$(_...)}($(args...))) ||
        :($x ← new($(args...))) => begin
            :($x = $(ex.args[3]))
        end
        :($x → new{$(_...)}($(args...))) ||
        :($x → new($(args...))) => begin
            :($(Expr(:tuple, args...)) = $type2tuple($x))
        end
        :($x[$index] ← $tp) => begin
            assign_expr = :($x[$index] = $tp)
            if info.invcheckon[]
                Expr(:block, :(@assert !haskey($x, $index)), assign_expr)
            else
                assign_expr
            end
        end
        :($x ← $tp) => :($x = $tp)
        :($x[$index] → $tp) => begin
            delete_expr = :($(deleteindex!)($x, $index))
            if info.invcheckon[]
                Expr(:block, :($deanc($x[$index], $tp)), delete_expr)
            else
                delete_expr
            end
        end
        :($x → $tp) => begin
            if info.invcheckon[]
                :($deanc($x, $tp))
            end
        end
        :(($t1=>$t2)($x)) => assign_ex(x, :(convert($t2, $x)); invcheck=info.invcheckon[])
        :(($t1=>$t2).($x)) => assign_ex(x, :(convert.($t2, $x)); invcheck=info.invcheckon[])
        :($f($(args...))) => begin
            check_shared_rw(args)
            Expr(:macrocall, Symbol("@assignback"), LineNumberNode(0, "none"), ex, info.invcheckon[])
        end
        :($f.($(args...))) => begin
            check_shared_rw(args)
            Expr(:macrocall, Symbol("@assignback"), LineNumberNode(0, "none"), :($ibcast((@skip! $f), $(args...))), info.invcheckon[])
        end
        Expr(:if, _...) => compile_if(m, copy(ex), info)
        :(while ($pre, $post); $(body...); end) => begin
            whilestatement(pre, post, compile_body(m, body, info), info)
        end
        # TODO: allow ommit step.
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
            res = gensym()
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

struct TupleExpanded{FT} <: Function
    f::FT
end
(tf::TupleExpanded)(x) = tf.f(x...)

compile_dotpipline(x, f) = @smatch x begin
    :(($(xx...),)) => begin
        xx, :($f.($(xx...)))
    end
    :($xx .|> $ff) => begin
        vars, newx = compile_dotpipline(xx, ff)
        vars, :($TupleExpanded($f).($(newx)))
    end
    _ => error("reversible pipline broadcasting should start with a tuple, e.g. (x, y) .|> f1 .|> f2..., got $x")
end

function compile_if(m::Module, ex, info)
    pres = []
    posts = []
    ex = analyse_if(m, ex, info, pres, posts)
    Expr(:block, pres..., ex, posts...)
end

function analyse_if(m::Module, ex, info, pres, posts)
    var = gensym()
    if ex.head == :if
        pre, post = ex.args[1].args
        ex.args[1] = var
    elseif ex.head == :elseif
        pre, post = ex.args[1].args[2].args
        ex.args[1].args[2] = var
    end
    push!(pres, :($var = $pre))
    if info.invcheckon[]
        push!(posts, Expr(:macrocall, Symbol("@invcheck"), nothing, var, post))
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
        pushfirst!(ex.args, :(@invcheck !($postcond)))
        push!(ex.args[end].args[end].args,
            :(@invcheck $postcond)
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

export @code_julia

"""
    @code_julia ex

Get the interpreted expression of `ex`.

```jldoctest; setup=:(using NiLangCore)
julia> @code_julia x += exp(3.0)
:(@assignback ((PlusEq)(exp))(x, 3.0) true)
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

julia> @i struct CVar{T}
           g::T
           x::T
           function CVar{T}(x::T, g::T) where T
               new{T}(x, g)
           end
           function CVar(x::T, g::T) where T
               new{T}(x, g)
           end
           # warning: infered type `T` should be used in `← new` statement only.
           @i function CVar(xx::T) where T
               gg ← zero(xx)
               gg += identity(1)
               xx ← new{T}(gg, xx)
           end
       end

julia> CVar(0.2)
CVar{Float64}(1.0, 0.2)

julia> (~CVar)(CVar(0.2))
0.2
```
See `test/compiler.jl` and `test/invtype.jl` for more examples.
"""
macro i(ex)
    if ex isa Expr && ex.head == :struct
        ex = _gen_istruct(__module__, ex)
    else
        ex = _gen_ifunc(__module__, ex)
    end
    ex.args[1] = :(Base.@__doc__ $(ex.args[1]))
    esc(ex)
end

function _gen_istruct(m::Module, ex)
    invlist = []
    for (i, st) in enumerate(ex.args[3].args)
        @smatch st begin
            :(@i $line $funcdef) => begin
                fdefs = _gen_ifunc(m, funcdef).args
                ex.args[3].args[i] = fdefs[1]
                append!(invlist, fdefs[2:end])
            end
            _ => st
        end
    end
    Expr(:block, ex, invlist...)
end

function _gen_ifunc(m::Module, ex)
    mc, fname, args, ts, body = precom(m, ex)
    fname = _replace_opmx(fname)

    # implementations
    ftype = get_ftype(fname)

    head = :($fname($(args...)) where {$(ts...)})
    dfname = dual_fname(fname)
    dftype = get_ftype(dfname)
    fdef1 = Expr(:function, head, Expr(:block, compile_body(m, body, CompileInfo())..., invfuncfoot(args)))
    dualhead = :($dfname($(args...)) where {$(ts...)})
    fdef2 = Expr(:function, dualhead, Expr(:block, compile_body(m, dual_body(m, body), CompileInfo())..., invfuncfoot(args)))
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
               anc ← zero(T)
               @routine anc += identity(x!)
               x! += y * anc
               ~@routine
           end);

julia> NiLangCore.nilang_ir(Main, ex) |> NiLangCore.rmlines
:(@inline function f(x!::T, y) where T
          anc ← zero(T)
          anc += identity(x!)
          x! += y * anc
          anc -= identity(x!)
          anc → zero(T)
      end)

julia> NiLangCore.nilang_ir(Main, ex; reversed=true) |> NiLangCore.rmlines
:(@inline function (~f)(x!::T, y) where T
          anc ← zero(T)
          anc += identity(x!)
          x! -= y * anc
          anc -= identity(x!)
          anc → zero(T)
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

function notkey(args)
    if length(args) > 0 && args[1] isa Expr && args[1].head == :parameters
        args = args[2:end]
    else
        args
    end
end

function invfuncfoot(args)
    args = get_argname.(notkey(args))
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

_replace_opmx(ex) = @smatch ex begin
    :(:+=($f)) => :($(gensym())::PlusEq{typeof($f)})
    :(:-=($f)) => :($(gensym())::MinusEq{typeof($f)})
    :(:*=($f)) => :($(gensym())::MulEq{typeof($f)})
    :(:/=($f)) => :($(gensym())::DivEq{typeof($f)})
    :(:⊻=($f)) => :($(gensym())::XorEq{typeof($f)})
    _ => ex
end

function interpret_func(m::Module, ex)
    @smatch ex begin
        :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            ftype = get_ftype(fname)
            esc(:(
            function $fname($(args...))
                $(compile_body(m, body)...)
                ($(args...),)
            end;
            ))
        end
        _=>error("$ex is not a function def")
    end
end

function _hasmethod1(f::TF, argt) where TF
    any(m->Tuple{TF, argt} == m.sig, methods(f).ms)
end

export @instr

"""
    @instr ex

Execute a reversible instruction.
"""
macro instr(ex)
    esc(Expr(:block, NiLangCore.compile_ex(__module__, precom_ex(__module__, ex, NiLangCore.PreInfo(Symbol[])), CompileInfo()), nothing))
end

compile_range(range) = @smatch range begin
    :($start:$step:$stop) => begin
        start_, step_, stop_ = gensym(), gensym(), gensym()
        Any[:($start_ = $start),
        :($step_ = $step),
        :($stop_ = $stop)],
        Any[:(@invcheck $start_  $start),
        :(@invcheck $step_  $step),
        :(@invcheck $stop_  $stop)]
    end
    :($start:$stop) => begin
        start_, stop_ = gensym(), gensym()
        Any[:($start_ = $start),
        :($stop_ = $stop)],
        Any[:(@invcheck $start_  $start),
        :(@invcheck $stop_  $stop)]
    end
    :($list) => begin
        list_ = gensym()
        Any[:($list_ = deepcopy($list))],
        Any[:(@invcheck $list_  $list)]
    end
end

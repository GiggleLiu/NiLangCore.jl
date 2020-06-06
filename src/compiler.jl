struct CompileInfo
    invcheckon::Ref{Bool}
end
CompileInfo() = CompileInfo(Ref(true))

#using .NGG: rmlines
function compile_body(body::AbstractVector, info)
    out = []
    for ex in body
        ex_ = compile_ex(ex, info)
        ex_ !== nothing && push!(out, ex_)
    end
    return out
end

function _instr(opm, (@nospecialize f), out, args, info, ldot, rdot)
    if length(args) > 0 && args[1] isa Expr && args[1].head == :parameters
        _args = Any[args[1], out, args[2:end]...]
    else
        _args = Any[out, args...]
    end
    if ldot && !rdot
        f = debcast(f)
    end
    if ldot
        :(@assignback $ibcast((@skip! $opm($f)), $(_args...))) |> rmlines
    else
        :(@assignback $opm($f)($(_args...)) $(info.invcheckon[])) |> rmlines
    end
end

# TODO: add `-x` to expression.
"""translate to normal julia code."""
function compile_ex(ex, info)
    @smatch ex begin
        :($a += $f($(args...))) => _instr(PlusEq, f, a, args, info, false, false)
        :($a .+= $f($(args...))) => _instr(PlusEq, f, a, args, info, true, false)
        :($a .+= $f.($(args...))) => _instr(PlusEq, f, a, args, info, true, true)
        :($a -= $f($(args...))) => _instr(MinusEq, f, a, args, info, false, false)
        :($a .-= $f($(args...))) => _instr(MinusEq, f, a, args, info, true, false)
        :($a .-= $f.($(args...))) => _instr(MinusEq, f, a, args, info, true, true)
        :($a *= $f($(args...))) => _instr(MulEq, f, a, args, info, false, false)
        :($a .*= $f($(args...))) => _instr(MulEq, f, a, args, info, true, false)
        :($a .*= $f.($(args...))) => _instr(MulEq, f, a, args, info, true, true)
        :($a /= $f($(args...))) => _instr(DivEq, f, a, args, info, false, false)
        :($a ./= $f($(args...))) => _instr(DivEq, f, a, args, info, true, false)
        :($a ./= $f.($(args...))) => _instr(DivEq, f, a, args, info, true, true)
        :($a ⊻= $f($(args...))) => _instr(XorEq, f, a, args, info, false, false)
        :($a ⊻= $x || $y) => _instr(XorEq, logical_or, a, Any[x, y], info, false, false)
        :($a ⊻= $x && $y) => _instr(XorEq, logical_and, a, Any[x, y], info, false, false)
        :($a .⊻= $f($(args...))) => _instr(XorEq, f, a, args, info, true, false)
        :($a .⊻= $f.($(args...))) => _instr(XorEq, f, a, args, info, true, true)
        :($x ← new{$(_...)}($(args...))) ||
        :($x ← new($(args...))) => begin
            :($x = $(ex.args[3]))
        end
        :($x → new{$(_...)}($(args...))) ||
        :($x → new($(args...))) => begin
            :($(Expr(:tuple, args...)) = $type2tuple($x))
        end
        :($x ← $tp) => :($x = $tp)
        :($x → $tp) => begin
            if info.invcheckon[]
                :($deanc($x, $tp))
            end
        end
        :(($t1=>$t2)($x)) => assign_ex(x, :(convert($t2, $x)); invcheck=info.invcheckon[])
        :(($x |> $f)) => begin
            vars, fcall = compile_pipline(x, f)
            symres = gensym()
            Expr(:block, :($symres = $fcall),
                 assign_vars(vars, symres; invcheck=info.invcheckon[]))
        end
        :(($xs .|> $f)) => begin
            vars, fcall = compile_dotpipline(xs, f)
            symres = gensym()
            Expr(:block, :($symres = $fcall),
                 bcast_assign_vars(vars, symres; invcheck=info.invcheckon[]))
        end
        :(($t1=>$t2).($x)) => assign_ex(x, :(convert.($t2, $x)); invcheck=info.invcheckon[])
        :($f($(args...))) => :(@assignback $f($(args...)) $(info.invcheckon[])) |> rmlines
        :($f.($(args...))) => :(@assignback $ibcast((@skip! $f), $(args...))) |> rmlines
        Expr(:if, _...) => compile_if(copy(ex), info)
        :(while ($pre, $post); $(body...); end) => begin
            whilestatement(pre, post, compile_body(body, info), info)
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(body, info), info, nothing)
        end
        :(@simd $line for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(body, info), info, Symbol("@simd")=>line)
        end
        :(@threads $line for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(body, info), info, Symbol("@threads")=>line)
        end
        :(@avx $line for $i=$range; $(body...); end) => begin
            forstatement(i, range, compile_body(body, info), info, Symbol("@avx")=>line)
        end
        :(begin $(body...) end) => begin
            Expr(:block, compile_body(body, info)...)
        end
        :(@safe $line $subex) => subex
        :(@inbounds $line $subex) => Expr(:macrocall, Symbol("@inbounds"), line, compile_ex(subex, info))
        :(@invcheckoff $line $subex) => begin
            state = info.invcheckon[]
            info.invcheckon[] = false
            ex = compile_ex(subex, info)
            info.invcheckon[] = state
            ex
        end
        :(@cuda $line $(args...)) => begin
            fcall = @smatch args[end] begin
                :($f($(args...))) => Expr(:call,
                    Expr(:->,
                        Expr(:tuple, args...),
                        Expr(:block,
                            :($f($(args...))),
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
        ::LineNumberNode => ex
        _ => error("statement is not supported for invertible lang! got $ex")
    end
end

compile_pipline(x, f) = @smatch x begin
    :(($(xx...),)) => begin
        xx, :($f($(xx...)))
    end
    :($xx |> $ff) => begin
        vars, newx = compile_pipline(xx, ff)
        vars, :($f(NiLangCore.wrap_tuple($(newx))...))
    end
    _ => error("reversible pipline should start with a tuple, e.g. (x, y) |> f1 |> f2..., got $x")
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

function compile_if(ex, info)
    pres = []
    posts = []
    ex = analyse_if(ex, info, pres, posts)
    Expr(:block, pres..., ex, posts...)
end

function analyse_if(ex, info, pres, posts)
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
    ex.args[2] = Expr(:block, compile_body(ex.args[2].args, info)...)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            ex.args[3] = analyse_if(ex.args[3], info, pres, posts)
        elseif ex.args[3].head == :block
            ex.args[3] = Expr(:block, compile_body(ex.args[3].args, info)...)
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
julia> using MacroTools

julia> prettify(@code_julia x += exp(3.0))
:(@assignback (PlusEq(exp))(x, 3.0))
```
"""
macro code_julia(ex)
    QuoteNode(compile_ex(ex, CompileInfo()))
end

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
        ex = _gen_istruct(ex)
    else
        ex = _gen_ifunc(ex)
    end
    ex.args[1] = :(Base.@__doc__ $(ex.args[1]))
    esc(ex)
end

function _gen_istruct(ex)
    invlist = []
    for (i, st) in enumerate(ex.args[3].args)
        @smatch st begin
            :(@i $line $funcdef) => begin
                fdefs = _gen_ifunc(funcdef).args
                ex.args[3].args[i] = fdefs[1]
                append!(invlist, fdefs[2:end])
            end
            _ => st
        end
    end
    Expr(:block, ex, invlist...)
end

function _gen_ifunc(ex)
    mc, fname, args, ts, body = precom(ex)
    fname = _replace_opmx(fname)
    register_reversible!(fname)

    # implementations
    ftype = get_ftype(fname)

    head = :($fname($(args...)) where {$(ts...)})
    dfname = dual_fname(fname)
    dftype = get_ftype(dfname)
    fdef1 = Expr(:function, head, Expr(:block, compile_body(body, CompileInfo())..., invfuncfoot(args)))
    dualhead = :($dfname($(args...)) where {$(ts...)})
    fdef2 = Expr(:function, dualhead, Expr(:block, compile_body(dual_body(body), CompileInfo())..., invfuncfoot(args)))
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

```jldoctest; setup=:(using NiLangCore, MacroTools)
julia> ex = :(@inline function f(x!::T, y) where T
               anc ← zero(T)
               @routine anc += identity(x!)
               x! += y * anc
               ~@routine
           end);

julia> nilang_ir(ex) |> MacroTools.prettify
:(@inline function f(x!::T, y) where T
          anc ← zero(T)
          anc += identity(x!)
          x! += y * anc
          anc -= identity(x!)
          anc → zero(T)
      end)

julia> nilang_ir(ex; reversed=true) |> MacroTools.prettify
:(@inline function (~f)(x!::T, y) where T
          anc ← zero(T)
          anc += identity(x!)
          x! -= y * anc
          anc -= identity(x!)
          anc → zero(T)
      end)
```
"""
function nilang_ir(ex; reversed::Bool=false)
    mc, fname, args, ts, body = precom(ex)
    fname = _replace_opmx(fname)

    # implementations
    if reversed
        dfname = :(~$fname) # use fake head for readability
        head = :($dfname($(args...)) where {$(ts...)})
        body = dual_body(body)
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
    # TODO: DEPRECATE
    :(⊕($f)) => :($(gensym())::PlusEq{typeof($f)})
    :(⊖($f)) => :($(gensym())::MinusEq{typeof($f)})
    :(⊻($f)) => :($(gensym())::XorEq{typeof($f)})
    _ => ex
end

function interpret_func(ex)
    @smatch ex begin
        :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            ftype = get_ftype(fname)
            esc(:(
            function $fname($(args...))
                $(compile_body(body)...)
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
    esc(NiLangCore.compile_ex(precom_ex(ex, NiLangCore.PreInfo()), CompileInfo()))
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

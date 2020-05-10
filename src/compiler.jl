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
    @switch ex begin
        @case :($a += $f($(args...)))
            return _instr(PlusEq, f, a, args, info, false, false)
        @case :($a .+= $f($(args...)))
            return _instr(PlusEq, f, a, args, info, true, false)
        @case :($a .+= $f.($(args...)))
            return _instr(PlusEq, f, a, args, info, true, true)
        @case :($a -= $f($(args...)))
            return _instr(MinusEq, f, a, args, info, false, false)
        @case :($a .-= $f($(args...)))
            return _instr(MinusEq, f, a, args, info, true, false)
        @case :($a .-= $f.($(args...)))
            return _instr(MinusEq, f, a, args, info, true, true)
        @case :($a ⊻= $f($(args...)))
            return _instr(XorEq, f, a, args, info, false, false)
        @case :($a ⊻= $x || $y)
            return _instr(XorEq, logical_or, a, Any[x, y], info, false, false)
        @case :($a ⊻= $x && $y)
            return _instr(XorEq, logical_and, a, Any[x, y], info, false, false)
        @case :($a .⊻= $f($(args...)))
            return _instr(XorEq, f, a, args, info, true, false)
        @case :($a .⊻= $f.($(args...)))
            return _instr(XorEq, f, a, args, info, true, true)
        @case :($x ← new{$(_...)}($(args...))) ||
        :($x ← new($(args...)))
            return :($x = $(ex.args[3]))
        @case :($x → new{$(_...)}($(args...))) ||
        :($x → new($(args...)))
            return :($(Expr(:tuple, args...)) = $type2tuple($x))
        @case :($x ← $tp)
            return :($x = $tp)
        @case :($x → $tp)
            if info.invcheckon[]
                return :($deanc($x, $tp))
            else
                return nothing
            end
        @case :(($t1=>$t2)($x))
            return assign_ex(x, :(convert($t2, $x)); invcheck=info.invcheckon[])
        @case :(($x |> $f))
            vars, fcall = compile_pipline(x, f)
            symres = gensym()
            return Expr(:block, :($symres = $fcall),
                 assign_vars(vars, symres; invcheck=info.invcheckon[]))
        @case :(($xs .|> $f))
            vars, fcall = compile_dotpipline(xs, f)
            symres = gensym()
            return Expr(:block, :($symres = $fcall),
                 bcast_assign_vars(vars, symres; invcheck=info.invcheckon[]))
        @case :(($t1=>$t2).($x))
            return assign_ex(x, :(convert.($t2, $x)); invcheck=info.invcheckon[])
        @case :($f($(args...)))
            return :(@assignback $f($(args...)) $(info.invcheckon[])) |> rmlines
        @case :($f.($(args...)))
            return :(@assignback $ibcast((@skip! $f), $(args...))) |> rmlines
        @case Expr(:if, _...)
            return compile_if(copy(ex), info)
        @case :(while ($pre, $post); $(body...); end)
            return whilestatement(pre, post, compile_body(body, info), info)
        @case :(for $i=$range; $(body...); end)
            return forstatement(i, range, compile_body(body, info), info, nothing)
        @case :(@simd $line for $i=$range; $(body...); end)
            return forstatement(i, range, compile_body(body, info), info, Symbol("@simd")=>line)
        @case :(@threads $line for $i=$range; $(body...); end)
            return forstatement(i, range, compile_body(body, info), info, Symbol("@threads")=>line)
        @case :(@avx $line for $i=$range; $(body...); end)
            return forstatement(i, range, compile_body(body, info), info, Symbol("@avx")=>line)
        @case :(begin $(body...) end)
            return Expr(:block, compile_body(body, info)...)
        @case :(@safe $line $subex)
            return subex
        @case :(@inbounds $line $subex)
            return Expr(:macrocall, Symbol("@inbounds"), line, compile_ex(subex, info))
        @case :(@invcheckoff $line $subex)
            state = info.invcheckon[]
            info.invcheckon[] = false
            ex = compile_ex(subex, info)
            info.invcheckon[] = state
            return ex
        @case :(@cuda $line $(args...))
            fcall = @when :($f($(args...))) = args[end] begin
                Expr(:call,
                    Expr(:->,
                        Expr(:tuple, args...),
                        Expr(:block,
                            :($f($(args...))),
                            nothing
                        )
                    ),
                    args...
                )
            @otherwise
                error("expect a function after @cuda, got $(args[end])")
            end
            return Expr(:macrocall, Symbol("@cuda"), line, args[1:end-1]..., fcall)
        @case :(@launchkernel $line $device $thread $ndrange $f($(args...)))
            res = gensym()
            return Expr(:block,
                    :($res = $f($device, $thread)($(args...); ndrange=$ndrange)),
                    :(wait($res))
                )
        @case ::LineNumberNode
            return ex
        @case _
            return error("statement is not supported for invertible lang! got $ex")
    end
end

compile_pipline(x, f) = @switch x begin
    @case :(($(xx...),))
        return xx, :($f($(xx...)))
    @case :($xx |> $ff)
        vars, newx = compile_pipline(xx, ff)
        return vars, :($f(NiLangCore.wrap_tuple($(newx))...))
    @case _
        error("reversible pipline should start with a tuple, e.g. (x, y) |> f1 |> f2..., got $x")
end

struct TupleExpanded{FT} <: Function
    f::FT
end
(tf::TupleExpanded)(x) = tf.f(x...)

compile_dotpipline(x, f) = @switch x begin
    @case :(($(xx...),))
        return xx, :($f.($(xx...)))
    @case :($xx .|> $ff)
        vars, newx = compile_dotpipline(xx, ff)
        return vars, :($TupleExpanded($f).($(newx)))
    @case _
        error("reversible pipline broadcasting should start with a tuple, e.g. (x, y) .|> f1 .|> f2..., got $x")
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
        @when :(@i $line $funcdef) = st begin
            fdefs = _gen_ifunc(funcdef).args
            ex.args[3].args[i] = fdefs[1]
            append!(invlist, fdefs[2:end])
        end
    end
    Expr(:block, ex, invlist...)
end

function _gen_ifunc(ex)
    mc, fname, args, ts, body = precom(ex)
    fname = _replace_opmx(fname)

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
        _funcdef(:isreversible, ftype) |> rmlines
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

_replace_opmx(ex) = @switch ex begin
    @case :(⊕($f))
        return :($(gensym())::PlusEq{typeof($f)})
    @case :(⊖($f))
        return :($(gensym())::MinusEq{typeof($f)})
    @case :(⊻($f))
        return :($(gensym())::XorEq{typeof($f)})
    @case _
        return ex
end

function interpret_func(ex)
    @switch ex begin
        @case :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...))
            ftype = get_ftype(fname)
            return esc(:(
            function $fname($(args...))
                $(compile_body(body)...)
                ($(args...),)
            end;
            $(_funcdef(:isreversible, ftype))
            ))
        @case _
            error("$ex is not a function def")
    end
end

function _hasmethod1(f::TF, argt) where TF
    any(m->Tuple{TF, argt} == m.sig, methods(f).ms)
end

function _funcdef(f, ftype)
    :(if !$(_hasmethod1)(NiLangCore.$f, $ftype)
        NiLangCore.$f(::$ftype) = true
    end
     )
end

export @instr

"""
    @instr ex

Execute a reversible instruction.
"""
macro instr(ex)
    esc(NiLangCore.compile_ex(precom_ex(ex, NiLangCore.PreInfo()), CompileInfo()))
end

compile_range(range) = @switch range begin
    @case :($start:$step:$stop)
        start_, step_, stop_ = gensym(), gensym(), gensym()
        return Any[:($start_ = $start),
        :($step_ = $step),
        :($stop_ = $stop)],
        Any[:(@invcheck $start_  $start),
        :(@invcheck $step_  $step),
        :(@invcheck $stop_  $stop)]
    @case :($start:$stop)
        start_, stop_ = gensym(), gensym()
        return Any[:($start_ = $start),
        :($stop_ = $stop)],
        Any[:(@invcheck $start_  $start),
        :(@invcheck $stop_  $stop)]
    @case :($list)
        list_ = gensym()
        return Any[:($list_ = deepcopy($list))],
        Any[:(@invcheck $list_  $list)]
end

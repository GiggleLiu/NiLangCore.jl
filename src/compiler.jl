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

# TODO: add `-x` to expression.
"""translate to normal julia code."""
function compile_ex(ex, info)
    @match ex begin
        :($a += $f($(args...))) => :(@assignback PlusEq($f)($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a .+= $f($(args...))) => :(@assignback PlusEq($(debcast(f))).($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a .+= $f.($(args...))) => :(@assignback PlusEq($f).($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a -= $f($(args...))) => :(@assignback MinusEq($f)($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a .-= $f($(args...))) => :(@assignback MinusEq($(debcast(f))).($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a .-= $f.($(args...))) => :(@assignback MinusEq($f).($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a ⊻= $f($(args...))) => :(@assignback XorEq($f)($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a ⊻= $x || $y) => :(@assignback XorEq(NiLangCore.logical_or)($a, $x, $y) $(info.invcheckon[])) |> rmlines
        :($a ⊻= $x && $y) => :(@assignback XorEq(NiLangCore.logical_and)($a, $x, $y) $(info.invcheckon[])) |> rmlines
        :($a .⊻= $f($(args...))) => :(@assignback XorEq($(debcast(f))).($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($a .⊻= $f.($(args...))) => :(@assignback XorEq($f).($a, $(args...)) $(info.invcheckon[])) |> rmlines
        :($x ← new{$(_...)}($(args...))) ||
        :($x ← new($(args...))) => begin
            :($x = $(ex.args[3]))
        end
        :($x → new{$(_...)}($(args...))) ||
        :($x → new($(args...))) => begin
            :($(Expr(:tuple, args...)) = NiLangCore.type2tuple($x))
        end
        :($x ← $tp) => :($x = $tp)
        :($x → $tp) => begin
            if info.invcheckon[]
                #Expr(:block, :(NiLangCore.deanc($x, $tp)), :($x = nothing)) # assign to nothing to prevent using
                :(NiLangCore.deanc($x, $tp))
            else
                nothing
            end
        end
        :(($t1=>$t2)($x)) => assign_ex(x, :(convert($t2, $x)); invcheck=info.invcheckon[])
        :(($t1=>$t2).($x)) => assign_ex(x, :(convert.($t2, $x)); invcheck=info.invcheckon[])
        :($f($(args...))) => :(@assignback $f($(args...)) $(info.invcheckon[])) |> rmlines
        :($f.($(args...))) => :(@assignback $f.($(args...)) $(info.invcheckon[])) |> rmlines

        # TODO: allow no postcond, or no else
        :(if ($pre, $post); $(truebranch...); else; $(falsebranch...); end) => begin
            ifstatement(pre, post, compile_body(truebranch, info), compile_body(falsebranch, info), info)
        end
        :(while ($pre, $post); $(body...); end) => begin
            whilestatement(pre, post, compile_body(body, info), info)
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            forstatement(i, start, step, stop, compile_body(body, info), info)
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
            fcall = @match args[end] begin
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

function ifstatement(precond, postcond, truebranch, falsebranch, info)
    var = gensym()
    ex = Expr(:block,
        :($var = $precond),
        Expr(:if, var,
            Expr(:block, truebranch...),
            Expr(:block, falsebranch...),
            )
    )
    if info.invcheckon[]
        push!(ex.args,
            :(@invcheck $postcond $var)
        )
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

function forstatement(i, start, step, stop, body, info)
    start_, step_, stop_ = gensym(), gensym(), gensym()
    ex = Expr(:block,
        :($start_ = $start),
        :($step_ = $step),
        :($stop_ = $stop),
        Expr(:for, :($i=$start_:$step_:$stop_),
            Expr(:block, body...)
            )
    )
    if info.invcheckon[]
        append!(ex.args,
            [:(@invcheck $start_  $start),
            :(@invcheck $step_  $step),
            :(@invcheck $stop_  $stop)]
        )
    end
    ex
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
    QuoteNode(NiLangCore.compile_ex(ex, CompileInfo()))
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
        @match st begin
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

    # implementations
    ftype = get_ftype(fname)

    head = :($fname($(args...)) where {$(ts...)})
    dfname = NiLangCore.dual_fname(fname)
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

_replace_opmx(ex) = @match ex begin
    :(⊕($f)) => :($(gensym())::PlusEq{typeof($f)})
    :(⊖($f)) => :($(gensym())::MinusEq{typeof($f)})
    :(⊻($f)) => :($(gensym())::XorEq{typeof($f)})
    _ => ex
end

function interpret_func(ex)
    @match ex begin
        :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            ftype = get_ftype(fname)
            esc(:(
            function $fname($(args...))
                $(compile_body(body)...)
                ($(args...),)
            end;
            $(_funcdef(:isreversible, ftype))
            ))
        end
        _=>error("$ex is not a function def")
    end
end

function _hasmethod1(f::TF, argt) where TF
    any(m->Tuple{TF, argt} == m.sig, methods(f).ms)
end

function _funcdef(f, ftype)
    :(if !NiLangCore._hasmethod1(NiLangCore.$f, $ftype)
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

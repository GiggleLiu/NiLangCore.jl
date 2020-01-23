#using .NGG: rmlines
function interpret_body(body::AbstractVector)
    out = []
    for ex in body
        push!(out, interpret_ex(ex))
    end
    return out
end

# TODO: add `-x` to expression.
"""translate to normal julia code."""
function interpret_ex(ex)
    @match ex begin
        :($f($(args...))) => :(@assignback $f($(args...)))
        :($f.($(args...))) => :(@assignback $f.($(args...)))
        :($a += $f($(args...))) => :(@assignback PlusEq($f)($a, $(args...)))
        :($a .+= $f($(args...))) => :(@assignback PlusEq($(debcast(f))).($a, $(args...)))
        :($a .+= $f.($(args...))) => :(@assignback PlusEq($f).($a, $(args...)))
        :($a -= $f($(args...))) => :(@assignback MinusEq($f)($a, $(args...)))
        :($a .-= $f($(args...))) => :(@assignback MinusEq($(debcast(f))).($a, $(args...)))
        :($a .-= $f.($(args...))) => :(@assignback MinusEq($f).($a, $(args...)))
        :($a ⊻= $f($(args...))) => :(@assignback XorEq($f)($a, $(args...)))
        :($a .⊻= $f($(args...))) => :(@assignback XorEq($(debcast(f))).($a, $(args...)))
        :($a .⊻= $f.($(args...))) => :(@assignback XorEq($f).($a, $(args...)))

        # TODO: allow no postcond, or no else
        :(if ($pre, $post); $(truebranch...); else; $(falsebranch...); end) => begin
            ifstatement(pre, post, interpret_body(truebranch), interpret_body(falsebranch))
        end
        :(while ($pre, $post); $(body...); end) => begin
            whilestatement(pre, post, interpret_body(body))
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            forstatement(i, start, step, stop, interpret_body(body))
        end
        :(begin $(body...) end) => begin
            :(begin $(interpret_body(body)...) end)
        end
        :(@maybe $line $subex) => :(@maybe $(interpret_ex(subex)))
        :(@safe $line $subex) => subex
        :(@anc $line $x = $tp) => :(@anc $x = $tp)
        :(@deanc $line $x = $tp) => :(@deanc $x = $tp)
        :(return $(args...)) => LineNumberNode(0)
        ::LineNumberNode => ex
        _ => error("statement is not supported for invertible lang! got $ex")
    end
end

function ifstatement(precond, postcond, truebranch, falsebranch)
    var = gensym()
    :(
        $var = $precond;
        if $var
            $(truebranch...)
        else
            $(falsebranch...)
        end;
        @invcheck $postcond $var
    )
end

function whilestatement(precond, postcond, body)
    :(
        @invcheck !($postcond);
        while $precond
            $(body...)
            @invcheck $postcond
        end;
    )
end

function forstatement(i, start, step, stop, body)
    start_, step_, stop_ = gensym(), gensym(), gensym()
    ex = :(
        $start_ = $start[];
        $step_ = $step[];
        $stop_ = $stop[];
        for $i=$start_:$step_:$stop_
            $(body...);
        end;
        @invcheck $start_  $start[];
        @invcheck $step_  $step[];
        @invcheck $stop_  $stop[]
        )
end

export @code_interpret

"""
    @code_interpret ex

Get the interpreted expression of `ex`.

```jldoctest; setup=:(using NiLangCore)
julia> using MacroTools

julia> prettify(@code_interpret x += exp(3.0))
:(@assignback x += exp(3.0))
```
"""
macro code_interpret(ex)
    QuoteNode(NiLangCore.interpret_ex(ex))
end

export @i

"""
    @i function fname(args..., kwargs...) ... end

Define a reversible function. See `test/interpreter.jl` for examples.
"""
macro i(ex)
    mc, fname, args, ts, body = precom(ex)
    _gen_ifunc(mc, fname, args, ts, body)
end

function _gen_ifunc(mc, fname, args, ts, body)
    fname = _replace_opmx(fname)

    # implementations
    ftype = get_ftype(fname)

    head = :($fname($(args...)) where {$(ts...)})
    dfname = NiLangCore.dual_fname(fname)
    dftype = get_ftype(dfname)
    fdef1 = Expr(:function, head, quote $(interpret_body(body)...); $(invfuncfoot(args)) end)
    if mc !== nothing
        # TODO: support macro before function
    end
    ex = fdef1
    dualhead = :($dfname($(args...)) where {$(ts...)})
    fdef2 = Expr(:function, dualhead, quote $(interpret_body(dual_body(body))...); $(invfuncfoot(args)) end)
    ex = :($ex; if $ftype != $dftype; $fdef2; end)
    esc(:($ex;
    $(_funcdef(:isreversible, ftype))
    ))
end

function notkey(args)
    if length(args) > 0 && args[1] isa Expr && args[1].head == :parameters
        args = args[2:end]
    else
        args
    end
end

function invfuncfoot(args)
    :(return ($(get_argname.(notkey(args))...),))
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
                $(interpret_body(body)...)
                return ($(args...),)
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
    esc(NiLangCore.interpret_ex(precom_ex(ex, NiLangCore.PreInfo())))
end

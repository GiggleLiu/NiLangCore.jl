#using .NGG: rmlines
function interpret_body(body::AbstractVector, info)
    out = []
    for ex in body
        push!(out, interpret_ex(ex, info))
    end
    return out
end

# TODO: add `-x` to expression.
"""translate to normal julia code."""
function interpret_ex(ex, info)
    @match ex begin
        :($f($(args...))) => :(@instr $f($(args...)))
        :($f.($(args...))) => :(@instr $f.($(args...)))
        :($a += $f($(args...))) => :(@instr $a += $f($(args...)))
        :($a .+= $f($(args...))) => :(@instr $a .+= $f($(args...)))
        :($a .+= $f.($(args...))) => :(@instr $a .+= $f.($(args...)))
        :($a -= $f($(args...))) => :(@instr $a -= $f($(args...)))
        :($a .-= $f($(args...))) => :(@instr $a .-= $f($(args...)))
        :($a .-= $f.($(args...))) => :(@instr $a .-= $f.($(args...)))
        :($a ⊻= $f($(args...))) => :(@instr $a ⊻= $f($(args...)))
        :($a .⊻= $f($(args...))) => :(@instr $a .⊻= $f($(args...)))
        :($a .⊻= $f.($(args...))) => :(@instr $a .⊻= $f.($(args...)))
        # TODO: allow no postcond, or no else
        :(if ($pre, $post); $(truebranch...); else; $(falsebranch...); end) => begin
            ifstatement(pre, post, interpret_body(truebranch, info), interpret_body(falsebranch, info))
        end
        :(while ($pre, $post); $(body...); end) => begin
            whilestatement(pre, post, interpret_body(body, ()))
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            forstatement(i, start, step, stop, interpret_body(body, ()))
        end
        :(begin $(body...) end) => begin
            :(begin $(interpret_body(body, info)...) end)
        end
        :(@maybe $line $subex) => :(@maybe $(interpret_ex(subex, info)))
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
        @invcheck $postcond == $var
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
        @invcheck $start_ == $start[];
        @invcheck $step_ == $step[];
        @invcheck $stop_ == $stop[]
        )
end

export @i
export interpret_func

macro i(ex)
    fname, args, ts, body = precom(ex)
    _gen_ifunc(ex, fname, args, ts, body)
end

function _gen_ifunc(ex, fname, args, ts, body)
    info = ()
    fname = _replace_opmx(fname)
    ifname = :(~$fname)
    iex = dual_func(fname, args, ts, body)

    # implementations
    ftype = get_ftype(fname)
    iftype = get_ftype(NiLangCore.dual_fname(fname))

    head = :($fname($(args...)) where {$(ts...)})
    dualhead = :($(NiLangCore.dual_fname(fname))($(args...)) where {$(ts...)})
    fdef1 = Expr(:function, head, quote $(interpret_body(body, info)...); $(invfuncfoot(args)) end)
    fdef2 = Expr(:function, dualhead, quote $(interpret_body(dual_body(body), info)...); $(invfuncfoot(args)) end)
    esc(:(
    $fdef1;
    $fdef2;
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
            info = ()
            ftype = get_ftype(fname)
            esc(:(
            function $fname($(args...))
                $(interpret_body(body, info)...)
                return ($(args...),)
            end;
            $(_funcdef(:isreversible, ftype))
            ))
        end
        _=>error("$ex is not a function def")
    end
end

function _funcdef(f, ftype)
    :(NiLangCore.$f(::$ftype) = true)
end

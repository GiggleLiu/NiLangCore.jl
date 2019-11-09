function getdef end
function compile_body(body::AbstractVector, info)
    out = []
    for ex in body
        push!(out, compile_ex(ex, info))
    end
    return out
end

# TODO: add `-x` to expression.
"""translate to normal julia code."""
function compile_ex(ex, info)
    @match ex begin
        :($out ⊕ $f($(args...))) => :(infer($f, $out, $(args...)))
        :($out ⊖ $f($(args...))) => :(inv_infer($f, $out, $(args...)))
        :($out .⊕ $f.($(args...))) => :(infer.($f, $out, $(args...)))
        :($out .⊖ $f.($(args...))) => :(inv_infer.($f, $out, $(args...)))
        :($out .⊕ $f($(args...))) => :(infer.($(debcast(f)), $out, $(args...)))
        :($out .⊖ $f($(args...))) => :(inv_infer.($(debcast(f)), $out, $(args...)))
        :($f($(args...))) => ex
        :($f.($(args...))) => ex
        # TODO: allow no postcond, or no else
        :(if ($pre, $post); $(truebranch...); else; $(falsebranch...); end) => begin
            ifstatement(pre, post, compile_body(truebranch, info), compile_body(falsebranch, info))
        end
        :(while ($pre, $post); $(body...); end) => begin
            whilestatement(pre, post, compile_body(body, ()))
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            forstatement(i, start, step, stop, compile_body(body, ()))
        end
        :(@maybe $line $subex) => :(@maybe $(compile_ex(subex, info)))
        :(@anc $line $x::$tp) => ex
        ::LineNumberNode => ex
        _ => error("`$ex` statement is not supported for invertible lang! got $ex")
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
        $start_ = $(start)[];
        $step_ = $(step)[];
        $stop_ = $(stop)[];
        for $i=$start_:$step_:$stop_
            $(body...);
        end;
        @invcheck $start_ == $(start)[];
        @invcheck $step_ == $(step)[];
        @invcheck $stop_ == $(stop)[]
        )
end

export @i
export compile_func, getdef

macro i(ex)
    ex = precom(ex)
    :($(compile_func(ex));
    $(compile_func(dual_func(ex))))
end

function compile_func(ex)
    @match ex begin
        :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            info = ()
            ftype = get_ftype(fname)
            @show ftype
            @show :(function $(esc(fname))($(args...))
                $(compile_body(body, info)...)
            end;
            $(esc(:(NiLangCore.getdef)))(::$(esc(ftype))) = $(QuoteNode(ex));
            $(esc(:(NiLangCore.isreversible)))(::$(esc(ftype))) = true)
        end
        _=>error("$ex is not a function def")
    end
end

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
        :($f($(args...))) => begin
            if f in [:⊕, :⊖]
                @match args[2] begin
                    :($subf($(subargs...))) => :($f($subf, $(args[1]), $(subargs...)))
                    _ => error("a function call should be followed after ⊕ and ⊖.")
                end
            elseif f in [:(.⊕), :(.⊖)]
                @match args[2] begin
                    :($subf.($(subargs...))) => :($(debcast(f)).($subf, $(args[1]), $(subargs...)))
                    :($subf($(subargs...))) => :($(debcast(f)).($(debcast(subf)), $(args[1]), $(subargs...)))
                    _ => error("a broadcasted function call should be followed after .⊕ and .⊖.")
                end
            else
                :($(esc(f))($(args...)))
            end
        end
        :($f.($(args...))) => :($(esc(f)).($(args...)))
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
        :(@anc $line $x::$tp) => :(@anc $x::$tp)
        :(@deanc $line $x::$tp) => :(@deanc $x::$tp)
        ::LineNumberNode => ex
        _ => error("`$(ex.args)` statement is not supported for invertible lang! got $ex")
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
export compile_func

macro i(ex)
    ex = precom(ex)
    @match ex begin
        :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            info = ()
            ifname = Symbol(~, fname)
            iex = dual_func(ex)
            NiLangCore.INVFUNC[fname] = ifname
            NiLangCore.INVFUNC[ifname] = fname
            NiLangCore.FUNCDEF[fname] = ex
            NiLangCore.FUNCDEF[ifname] = iex

            # implementations
            ftype = get_ftype(fname)
            iftype = get_ftype(NiLangCore.dual_fname(fname))
            :(function $(esc(fname))($(args...))
                $(compile_body(body, info)...)
            end;
            function $(esc(NiLangCore.dual_fname(fname)))($(args...))
                $(compile_body(dual_body(body), info)...)
            end;
            $(esc(:(NiLangCore.isreversible)))(::$(esc(ftype))) = true)
        end
        _=>error("$ex is not a function def")
    end
end

function compile_func(ex)
    @match ex begin
        :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            info = ()
            ftype = get_ftype(fname)
            :(function $(esc(fname))($(args...))
                $(compile_body(body, info)...)
            end;
            $(esc(:(NiLangCore.isreversible)))(::$(esc(ftype))) = true)
        end
        _=>error("$ex is not a function def")
    end
end

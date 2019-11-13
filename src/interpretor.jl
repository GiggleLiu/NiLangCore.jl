using .NGG: rmlines
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
        :($f($(args...))) => :($f($(args...)))
        :($f.($(args...))) => :($f.($(args...)))
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
        :(@maybe $line $subex) => :(@maybe $(interpret_ex(subex, info)))
        :(@anc $line $x::$tp) => :(@anc $x::$tp)
        :(@deanc $line $x::$tp) => :(@deanc $x::$tp)
        :(@gradalloc $line $(args...)) => :(@gradalloc $(args...))
        :(@graddealloc $line $(args...)) => :(@graddealloc $(args...))
        :(return $(args...)) => LineNumberNode(0)
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
    ex = precom(ex)
    @match ex begin
        :(function $fname($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            info = ()
            ifname = :(~$fname)
            iex = dual_func(ex)
            NiLangCore.regdual(fname=>ex, ifname=>iex)

            # implementations
            ftype = get_ftype(fname)
            iftype = get_ftype(NiLangCore.dual_fname(fname))
            @show esc(:(
            function $fname($(args...))
                $(interpret_body(body, info)...)
                return ($(args...),)
            end;
            function $(NiLangCore.dual_fname(fname))($(args...))
                $(interpret_body(dual_body(body), info)...)
                return ($(args...),)
            end;
            NiLangCore.isreversible(::$ftype) = true
            )) |> rmlines
        end
        _=>error("$ex is not a function def")
    end
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
            NiLangCore.isreversible(::$ftype) = true
            )) |> rmlines
        end
        _=>error("$ex is not a function def")
    end
end

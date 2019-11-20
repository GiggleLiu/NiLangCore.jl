function dual_func(ex)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            :(function $(:(~$fname))($(args...));
                    $(dual_body(body)...);
                end)
        end
        _ => error("must input a function, got $ex")
    end
end

function dual_fname(op)
    @match op begin
        :($x::MinusEq{$tp}) => :($x::PlusEq{$tp})
        :($x::PlusEq{$tp}) => :($x::MinusEq{$tp})
        :($x::XorEq{$tp}) => :($x::XorEq{$tp})
        :($x::$tp) => :($x::Inv{$tp})
        #_ => :(_::Inv{typeof($op)})
        _ => :(_::typeof(~$op))
    end
end

function _infer_dual(sym::Symbol)
    if sym == :+=
        :-=
    elseif sym == :-=
        :+=
    elseif sym == :.+=
        :.-=
    elseif sym == :.-=
        :.+=
    elseif sym == :⊻=
        :⊻=
    elseif sym == :.⊻=
        :.⊻=
    end
end

function dual_ex(ex)
    @match ex begin
        :($f($(args...))) => begin
            if startwithdot(f)
                :($(dotgetdual(f)).($(args...)))
            else
                :($(getdual(f))($(args...)))
            end
        end
        :($f.($(args...))) => :($(getdual(f)).($(args...)))
        :($a += $f($(args...))) => :($a -= $f($(args...)))
        :($a .+= $f($(args...))) => :($a .-= $f($(args...)))
        :($a .+= $f.($(args...))) => :($a .-= $f.($(args...)))
        :($a -= $f($(args...))) => :($a += $f($(args...)))
        :($a .-= $f($(args...))) => :($a .+= $f($(args...)))
        :($a .-= $f.($(args...))) => :($a .+= $f.($(args...)))
        :($a ⊻= $f($(args...))) => :($a ⊻= $f($(args...)))
        :($a .⊻= $f($(args...))) => :($a .⊻= $f($(args...)))
        :($a .⊻= $f.($(args...))) => :($a .⊻= $f.($(args...)))
        :(if ($pre, $post); $(tbr...); else; $(fbr...); end) => begin
            :(if ($post, $pre); $(dual_body(tbr)...); else; $(dual_body(fbr)...); end)
        end
        :(while ($pre, $post); $(body...); end) => begin
            :(while ($post, $pre); $(dual_body(body)...); end)
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            :(for $i=$stop:(-$step):$start; $(dual_body(body)...); end)
        end
        :(@maybe $line $subex) => :(@maybe $(dual_ex(subex)))
        :(@anc $line $x::$tp) => :(@deanc $x::$tp)
        :(@deanc $line $x::$tp) => :(@anc $x::$tp)
        _ => ex
    end
end

dualname(f) = @match f begin
    :(⊕($f)) => :(⊖($f))
    :(⊖($f)) => :(⊕($f))
    :(~$fname) => fname
    _ => :(~$f)
end

getdual(f) = @match f begin
    :(⊕($f)) => :(⊖($f))
    :(⊖($f)) => :(⊕($f))
    _ => :(~$f)
end
dotgetdual(f::Symbol) = getdual(removedot(f))

function dual_body(body)
    out = map(st->(dual_ex(st)), Iterators.reverse(body))
end

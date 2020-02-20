# get the expression of the inverse function
function dual_func(fname, args, ts, body)
    :(function $(:(~$fname))($(args...)) where {$(ts...)};
            $(dual_body(body)...);
        end)
end

# get the function name of the inverse function
function dual_fname(op)
    @match op begin
        :($x::MinusEq{$tp}) => :($x::PlusEq{$tp})
        :($x::PlusEq{$tp}) => :($x::MinusEq{$tp})
        :($x::MinusEq) => :($x::PlusEq)
        :($x::PlusEq) => :($x::MinusEq)
        :($x::XorEq{$tp}) => :($x::XorEq{$tp})
        :($x::$tp) => :($x::Inv{<:$tp})
        #_ => :(_::Inv{typeof($op)})
        _ => :($(gensym())::NiLangCore._typeof(~$op))
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

"""
    dual_ex(ex)

Get the dual expression of `ex`.
"""
function dual_ex(ex)
    @match ex begin
        :($x → $val) => :($x ← $val)
        :($x ← $val) => :($x → $val)
        :(($t1=>$t2)($x)) => :(($t2=>$t1)($x))
        :(($t1=>$t2).($x)) => :(($t2=>$t1).($x))
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

        :($a += $b) => :($a -= $b)
        :($a .+= $b) => :($a .-= $b)
        :($a -= $b) => :($a += $b)
        :($a .-= $b) => :($a .+= $b)
        :($a ⊻= $b) => :($a ⊻= $b)
        :($a .⊻= $b) => :($a .⊻= $b)

        :(if ($pre, $post); $(tbr...); else; $(fbr...); end) => begin
            Expr(:if, :(($post, $pre)), Expr(:block, dual_body(tbr)...), Expr(:block, dual_body(fbr)...))
        end
        :(while ($pre, $post); $(body...); end) => begin
            Expr(:while, :(($post, $pre)), Expr(:block, dual_body(body)...))
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            Expr(:for, :($i=$stop:(-$step):$start), Expr(:block, dual_body(body)...))
        end
        :(@safe $line $subex) => :(@safe $subex)
        :(@inbounds $line $subex) => :(@inbounds $(dual_ex(subex)))
        :(begin $(body...) end) => Expr(:block, dual_body(body)...)
        ::LineNumberNode => ex
        ::Nothing => ex
        :() => ex
        _ => error("can not invert target expression $ex")
    end
end

export @code_reverse

"""
    @code_reverse ex

Get the reversed expression of `ex`.

```jldoctest; setup=:(using NiLangCore)
julia> @code_reverse x += exp(3.0)
:(x -= exp(3.0))
```
"""
macro code_reverse(ex)
    QuoteNode(NiLangCore.dual_ex(ex))
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

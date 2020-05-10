# get the expression of the inverse function
function dual_func(fname, args, ts, body)
    :(function $(:(~$fname))($(args...)) where {$(ts...)};
            $(dual_body(body)...);
        end)
end

# get the function name of the inverse function
function dual_fname(op)
    @switch op begin
        @case :($x::MinusEq{$tp})
            return :($x::PlusEq{$tp})
        @case :($x::PlusEq{$tp})
            return :($x::MinusEq{$tp})
        @case :($x::MinusEq)
            return :($x::PlusEq)
        @case :($x::PlusEq)
            return :($x::MinusEq)
        @case :($x::XorEq{$tp})
            return :($x::XorEq{$tp})
        @case :($x::$tp)
            return :($x::Inv{<:$tp})
        @case :(~$x)
            return x
        @case _
            return :($(gensym())::$_typeof(~$op))
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
    @switch ex begin
        @case :($x → $val)
            return :($x ← $val)
        @case :($x ← $val)
            return :($x → $val)
        @case :(($t1=>$t2)($x))
            return :(($t2=>$t1)($x))
        @case :(($t1=>$t2).($x))
            return :(($t2=>$t1).($x))
        @case :($a |> $b)
            pipline = get_pipline!(ex, Any[])
            return rev_pipline!(pipline[1], pipline[2:end], dot=false)
        @case :($a .|> $b)
            pipline = get_dotpipline!(ex, Any[])
            return rev_pipline!(pipline[1], pipline[2:end]; dot=true)
        @case :($f($(args...)))
            if startwithdot(f)
                return :($(dotgetdual(f)).($(args...)))
            else
                return :($(getdual(f))($(args...)))
            end
        @case :($f.($(args...)))
            return :($(getdual(f)).($(args...)))
        @case :($a += $f($(args...)))
            return :($a -= $f($(args...)))
        @case :($a .+= $f($(args...)))
            return :($a .-= $f($(args...)))
        @case :($a .+= $f.($(args...)))
            return :($a .-= $f.($(args...)))
        @case :($a -= $f($(args...)))
            return :($a += $f($(args...)))
        @case :($a .-= $f($(args...)))
            return :($a .+= $f($(args...)))
        @case :($a .-= $f.($(args...)))
            return :($a .+= $f.($(args...)))
        @case :($a ⊻= $f($(args...)))
            return :($a ⊻= $f($(args...)))
        @case :($a .⊻= $f($(args...)))
            return :($a .⊻= $f($(args...)))
        @case :($a .⊻= $f.($(args...)))
            return :($a .⊻= $f.($(args...)))
        @case :($a += $b)
            return :($a -= $b)
        @case :($a .+= $b)
            return :($a .-= $b)
        @case :($a -= $b)
            return :($a += $b)
        @case :($a .-= $b)
            return :($a .+= $b)
        @case :($a ⊻= $b)
            return :($a ⊻= $b)
        @case :($a .⊻= $b)
            return :($a .⊻= $b)
        @case Expr(:if, _...)
            return dual_if(copy(ex))
        @case :(while ($pre, $post); $(body...); end)
            return Expr(:while, :(($post, $pre)), Expr(:block, dual_body(body)...))
        @case :(for $i=$start:$step:$stop; $(body...); end)
            return Expr(:for, :($i=$stop:(-$step):$start), Expr(:block, dual_body(body)...))
        @case :(for $i=$start:$stop; $(body...); end)
            j = gensym()
            return Expr(:for, :($j=$start:$stop), Expr(:block, :($i ← $stop-$j+$start), dual_body(body)..., :($i → $stop-$j+$start)))
        @case :(for $i=$itr; $(body...); end)
            return Expr(:for, :($i=Base.Iterators.reverse($itr)), Expr(:block, dual_body(body)...))
        @case :(@safe $line $subex)
            return Expr(:macrocall, Symbol("@safe"), line, subex)
        @case :(@cuda $line $(args...))
            return Expr(:macrocall, Symbol("@cuda"), line, args[1:end-1]..., dual_ex(args[end]))
        @case :(@launchkernel $line $(args...))
            return Expr(:macrocall, Symbol("@launchkernel"), line, args[1:end-1]..., dual_ex(args[end]))
        @case :(@inbounds $line $subex)
            return Expr(:macrocall, Symbol("@inbounds"), line, dual_ex(subex))
        @case :(@simd $line $subex)
            return Expr(:macrocall, Symbol("@simd"), line, dual_ex(subex))
        @case :(@threads $line $subex)
            return Expr(:macrocall, Symbol("@threads"), line, dual_ex(subex))
        @case :(@avx $line $subex)
            return Expr(:macrocall, Symbol("@avx"), line, dual_ex(subex))
        @case :(@invcheckoff $line $subex)
            return Expr(:macrocall, Symbol("@invcheckoff"), line, dual_ex(subex))
        @case :(begin $(body...) end)
            return Expr(:block, dual_body(body)...)
        @case ::LineNumberNode
            return ex
        @case ::Nothing
            return ex
        @case :()
            return ex
        @case _
            return error("can not invert target expression $ex")
    end
end

get_pipline!(ex, out!) = @when :($a |> $f) = ex begin
        get_pipline!(a, out!)
        push!(out!, f)
        return out!
    @otherwise
        return push!(out!, ex)
end

get_dotpipline!(ex, out!) = @when :($a .|> $f) = a begin
        get_dotpipline!(a, out!)
        push!(out, f)
        return out!
    @otherwise
        return push!(out!, ex)
end

function rev_pipline!(var, fs; dot)
    if isempty(fs)
        return var
    end
    token = dot ? :(.|>) : :(|>)
    nvar = :($token($var, $(getdual(pop!(fs)))))
    rev_pipline!(nvar, fs; dot=dot)
end

function dual_if(ex)
    _dual_cond(cond) = @match cond begin
        :(($pre, $post)) => :(($post, $pre))
    end
    if ex.head == :if
        ex.args[1] = _dual_cond(ex.args[1])
    elseif ex.head == :elseif
        ex.args[1].args[2] = _dual_cond(ex.args[1].args[2])
    end
    ex.args[2] = Expr(:block, dual_body(ex.args[2].args)...)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            ex.args[3] = dual_if(ex.args[3])
        elseif ex.args[3].head == :block
            ex.args[3] = Expr(:block, dual_body(ex.args[3].args)...)
        end
    end
    ex
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
    QuoteNode(dual_ex(ex))
end

dualname(f) = @switch f begin
    @case :(⊕($f))
        return :(⊖($f))
    @case :(⊖($f))
        return :(⊕($f))
    @case :(~$fname)
        return fname
    @case _
        return :(~$f)
end

getdual(f) = @switch f begin
    @case :(⊕($f))
        return :(⊖($f))
    @case :(⊖($f))
        return :(⊕($f))
    @case :(~$f)
        return f
    @case _
        return :(~$f)
end
dotgetdual(f::Symbol) = getdual(removedot(f))

function dual_body(body)
    out = map(st->(dual_ex(st)), Iterators.reverse(body))
end

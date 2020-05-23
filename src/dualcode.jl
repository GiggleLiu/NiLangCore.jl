# get the expression of the inverse function
function dual_func(fname, args, ts, body)
    :(function $(:(~$fname))($(args...)) where {$(ts...)};
            $(dual_body(body)...);
        end)
end

# get the function name of the inverse function
function dual_fname(op)
    @smatch op begin
        :($x::MinusEq{$tp}) => :($x::PlusEq{$tp})
        :($x::PlusEq{$tp}) => :($x::MinusEq{$tp})
        :($x::MinusEq) => :($x::PlusEq)
        :($x::PlusEq) => :($x::MinusEq)
        :($x::DivEq{$tp}) => :($x::MulEq{$tp})
        :($x::MulEq{$tp}) => :($x::DivEq{$tp})
        :($x::DivEq) => :($x::MulEq)
        :($x::MulEq) => :($x::DivEq)
        :($x::XorEq{$tp}) => :($x::XorEq{$tp})
        :($x::$tp) => :($x::Inv{<:$tp})
        :(~$x) => x
        #_ => :(_::Inv{typeof($op)})
        _ => :($(gensym())::$_typeof(~$op))
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
    elseif sym == :*=
        :/=
    elseif sym == :/=
        :*=
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
    @smatch ex begin
        :($x → $val) => :($x ← $val)
        :($x ← $val) => :($x → $val)
        :(($t1=>$t2)($x)) => :(($t2=>$t1)($x))
        :(($t1=>$t2).($x)) => :(($t2=>$t1).($x))
        :($a |> $b) => begin
            pipline = get_pipline!(ex, Any[])
            rev_pipline!(pipline[1], pipline[2:end], dot=false)
        end
        :($a .|> $b) => begin
            pipline = get_dotpipline!(ex, Any[])
            rev_pipline!(pipline[1], pipline[2:end]; dot=true)
        end
        :($f($(args...))) => begin
            if startwithdot(f)
                :($(dotgetdual(f)).($(args...)))
            else
                :($(getdual(f))($(args...)))
            end
        end
        :($f.($(args...))) => :($(getdual(f)).($(args...)))
        :($a += $b) => :($a -= $b)
        :($a .+= $b) => :($a .-= $b)
        :($a -= $b) => :($a += $b)
        :($a .-= $b) => :($a .+= $b)
        :($a *= $b) => :($a /= $b)
        :($a .*= $b) => :($a ./= $b)
        :($a /= $b) => :($a *= $b)
        :($a ./= $b) => :($a .*= $b)
        :($a ⊻= $b) => :($a ⊻= $b)
        :($a .⊻= $b) => :($a .⊻= $b)
        Expr(:if, _...) => dual_if(copy(ex))
        :(while ($pre, $post); $(body...); end) => begin
            Expr(:while, :(($post, $pre)), Expr(:block, dual_body(body)...))
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            Expr(:for, :($i=$stop:(-$step):$start), Expr(:block, dual_body(body)...))
        end
        :(for $i=$start:$stop; $(body...); end) => begin
            j = gensym()
            Expr(:for, :($j=$start:$stop), Expr(:block, :($i ← $stop-$j+$start), dual_body(body)..., :($i → $stop-$j+$start)))
        end
        :(for $i=$itr; $(body...); end) => begin
            Expr(:for, :($i=Base.Iterators.reverse($itr)), Expr(:block, dual_body(body)...))
        end
        :(@safe $line $subex) => Expr(:macrocall, Symbol("@safe"), line, subex)
        :(@cuda $line $(args...)) => Expr(:macrocall, Symbol("@cuda"), line, args[1:end-1]..., dual_ex(args[end]))
        :(@launchkernel $line $(args...)) => Expr(:macrocall, Symbol("@launchkernel"), line, args[1:end-1]..., dual_ex(args[end]))
        :(@inbounds $line $subex) => Expr(:macrocall, Symbol("@inbounds"), line, dual_ex(subex))
        :(@simd $line $subex) => Expr(:macrocall, Symbol("@simd"), line, dual_ex(subex))
        :(@threads $line $subex) => Expr(:macrocall, Symbol("@threads"), line, dual_ex(subex))
        :(@avx $line $subex) => Expr(:macrocall, Symbol("@avx"), line, dual_ex(subex))
        :(@invcheckoff $line $subex) => Expr(:macrocall, Symbol("@invcheckoff"), line, dual_ex(subex))
        :(begin $(body...) end) => Expr(:block, dual_body(body)...)
        ::LineNumberNode => ex
        ::Nothing => ex
        :() => ex
        _ => error("can not invert target expression $ex")
    end
end

get_pipline!(ex, out!) = @smatch ex begin
    :($a |> $f) => begin
        get_pipline!(a, out!)
        push!(out!, f)
        out!
    end
    _ => push!(out!, ex)
end

get_dotpipline!(ex, out!) = @smatch a begin
    :($a .|> $f) => begin
        get_dotpipline!(a, out!)
        push!(out, f)
        out!
    end
    _ => push!(out!, ex)
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
    _dual_cond(cond) = @smatch cond begin
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

dualname(f) = @smatch f begin
    :(⊕($f)) => :(⊖($f))
    :(⊖($f)) => :(⊕($f))
    :(~$fname) => fname
    _ => :(~$f)
end

getdual(f) = @smatch f begin
    :(⊕($f)) => :(⊖($f))
    :(⊖($f)) => :(⊕($f))
    :(~$f) => f
    _ => :(~$f)
end
dotgetdual(f::Symbol) = getdual(removedot(f))

function dual_body(body)
    out = map(st->(dual_ex(st)), Iterators.reverse(body))
end

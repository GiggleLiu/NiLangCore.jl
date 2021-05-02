# get the expression of the inverse function
function dual_func(m::Module, fname, args, ts, body)
    :(function $(:(~$fname))($(args...)) where {$(ts...)};
            $(dual_body(m, body)...);
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
        :($x::$tp) => :($x::$invtype($tp))
        :(~$x) => x
        #_ => :(_::Inv{typeof($op)})
        _ => :($(gensym())::$_typeof(~$op))
    end
end

"""
    dual_ex(m::Module, ex)

Get the dual expression of `ex`.
"""
function dual_ex(m::Module, ex)
    @smatch ex begin
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
        Expr(:if, _...) => dual_if(m, copy(ex))
        :(while ($pre, $post); $(body...); end) => begin
            Expr(:while, :(($post, $pre)), Expr(:block, dual_body(m, body)...))
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            Expr(:for, :($i=$stop:(-$step):$start), Expr(:block, dual_body(m, body)...))
        end
        :(for $i=$start:$stop; $(body...); end) => begin
            j = gensym()
            Expr(:for, :($j=$start:$stop), Expr(:block, :($i ← $stop-$j+$start), dual_body(m, body)..., :($i → $stop-$j+$start)))
        end
        :(for $i=$itr; $(body...); end) => begin
            Expr(:for, :($i=Base.Iterators.reverse($itr)), Expr(:block, dual_body(m, body)...))
        end
        :(@safe $line $subex) => Expr(:macrocall, Symbol("@safe"), line, subex)
        :(@cuda $line $(args...)) => Expr(:macrocall, Symbol("@cuda"), line, args[1:end-1]..., dual_ex(m, args[end]))
        :(@launchkernel $line $(args...)) => Expr(:macrocall, Symbol("@launchkernel"), line, args[1:end-1]..., dual_ex(m, args[end]))
        :(@inbounds $line $subex) => Expr(:macrocall, Symbol("@inbounds"), line, dual_ex(m, subex))
        :(@simd $line $subex) => Expr(:macrocall, Symbol("@simd"), line, dual_ex(m, subex))
        :(@threads $line $subex) => Expr(:macrocall, Symbol("@threads"), line, dual_ex(m, subex))
        :(@avx $line $subex) => Expr(:macrocall, Symbol("@avx"), line, dual_ex(m, subex))
        :(@invcheckoff $line $subex) => Expr(:macrocall, Symbol("@invcheckoff"), line, dual_ex(m, subex))
        :(begin $(body...) end) => Expr(:block, dual_body(m, body)...)
        :(nothing) => ex
        ::LineNumberNode => ex
        ::Nothing => ex
        :() => ex
        _ => error("can not invert target expression $ex")
    end
end

function dual_if(m::Module, ex)
    _dual_cond(cond) = @smatch cond begin
        :(($pre, $post)) => :(($post, $pre))
    end
    if ex.head == :if
        ex.args[1] = _dual_cond(ex.args[1])
    elseif ex.head == :elseif
        ex.args[1].args[2] = _dual_cond(ex.args[1].args[2])
    end
    ex.args[2] = Expr(:block, dual_body(m, ex.args[2].args)...)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            ex.args[3] = dual_if(m, ex.args[3])
        elseif ex.args[3].head == :block
            ex.args[3] = Expr(:block, dual_body(m, ex.args[3].args)...)
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
    QuoteNode(dual_ex(__module__, ex))
end

getdual(f) = @smatch f begin
    :(~$f) => f
    _ => :(~$f)
end
dotgetdual(f::Symbol) = getdual(removedot(f))

function dual_body(m::Module, body)
    out = []
    # fix function LineNumberNode
    if length(body) > 1 && body[1] isa LineNumberNode && body[2] isa LineNumberNode
        push!(out, body[1])
        start = 2
    else
        start = 1
    end
    ptr = length(body)
    # reverse the statements
    len = 0
    while ptr >= start
        if  ptr-len==0 || body[ptr-len] isa LineNumberNode
            ptr-len != 0 && push!(out, body[ptr-len])
            for j=ptr:-1:ptr-len+1
                push!(out, dual_ex(m, body[j]))
            end
            ptr -= len+1
            len = 0
        else
            len += 1
        end
    end
    return out
end

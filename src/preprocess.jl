export precom
using DataStructures: OrderedDict

struct PreInfo
    ancs::OrderedDict{Symbol, Any}
    routines::Vector{Any}
end
PreInfo() = PreInfo(OrderedDict{Symbol,Symbol}(), [])

function precom(ex)
    mc, fname, args, ts, body = match_function(ex)
    info = PreInfo()
    mc, fname, args, ts, flushancs(precom_body(body, info), info)
end

function precom_body(body::AbstractVector, info)
    [precom_ex(ex, info) for ex in body]
end

function flushancs(out, info)
    for i in 1:length(info.ancs)
        (x, tp) = pop!(info.ancs)
        push!(out, :($x → $tp))
    end
    return out
end

function precom_opm(f, out, arg2)
    if f in [:(+=), :(-=)]
        @when :($subf($(subargs...))) = arg2 begin
            return Expr(f, out, arg2)
        @otherwise
            error("unknown expression after assign $(QuoteNode(arg2))")
        end
    elseif f in [:(.+=), :(.-=)]
        @switch arg2 begin
        @case :($subf.($(subargs...)))
            return Expr(f, out, arg2)
        @case :($subf($(subargs...)))
            return Expr(f, out, arg2)
        @case _
            error("unknown expression after assign $(QuoteNode(arg2))")
        end
    end
end

function precom_ox(f, out, arg2)
    if f == :(⊻=)
        @switch arg2 begin
            @case :($subf($(subargs...))) ||
            :($a || $b) ||
            :($a && $b)
                return Expr(f, out, arg2)
            @case _
                error("unknown expression after assign $(QuoteNode(arg2))")
        end
    elseif f == :(.⊻=)
        @switch arg2 begin
        @case :($subf.($(subargs...)))
            return Expr(f, out, arg2)
        @case :($subf($(subargs...)))
            return Expr(f, out, arg2)
        @case _
            error("unknown expression after assign $(QuoteNode(arg2))")
        end
    end
end

function precom_ex(ex, info)
    @switch ex begin
        @case :($x ← new{$(_...)}($(args...))) ||
        :($x ← new($(args...)))
            for arg in args
                # no need to deallocate `arg`.
                if arg != x
                    delete!(info.ancs, arg)
                end
            end
            if !(x in args)
                info.ancs[x] = ex.args[3]
            end
            return ex
        @case :($x → new{$(_...)}($(args...))) ||
        :($x → new($(args...)))
            for (i, arg) in enumerate(args)
                # no need to deallocate `arg`.
                if arg != x
                    info.ancs[arg] = :(getfield($x, $i))
                end
            end
            if !(x in args)
                delete!(info.ancs, x)
            end
            return ex
        @case :($x ← $val)
            info.ancs[x] = val
            return ex
        @case :($x → $val)
            delete!(info.ancs, x)
            return ex
        @case :($a += $b)
            return precom_opm(:+=, a, b)
        @case :($a -= $b)
            return precom_opm(:-=, a, b)
        @case :($a ⊻= $b)
            return precom_ox(:⊻=, a, b)
        @case :($a .+= $b)
            return precom_opm(:.+=, a, b)
        @case :($a .-= $b)
            return precom_opm(:.-=, a, b)
        @case :($a .⊻= $b)
            return precom_ox(:.⊻=, a, b)
        @case :($a ⊕ $b)
            return :($a += identity($b))
        @case :($a .⊕ $b)
            return :($a .+= identity.($b))
        @case :($a ⊖ $b)
            return :($a -= identity($b))
        @case :($a .⊖ $b)
            return :($a .-= identity.($b))
        @case :($a ⊙ $b)
            return :($a ⊻= identity($b))
        @case :($a .⊙ $b)
            return :($a .⊻= identity.($b))
        @case Expr(:if, _...)
            return precom_if(copy(ex))
        @case :(while ($pre, $post); $(body...); end)
            post = post == :~ ? pre : post
            info = PreInfo()
            return Expr(:while, :(($pre, $post)), Expr(:block, flushancs(precom_body(body, info), info)...))
        @case :(begin $(body...) end)
            return Expr(:block, precom_body(body, info)...)
        @case :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end)
            info = PreInfo()
            return Expr(:for, :($i=$(range)), Expr(:block, flushancs(precom_body(body, info), info)...))
        @case :(@anc $line $x = $val)
            @warn "`@anc x = expr` is deprecated, please use `x ← expr` for loading an ancilla."
            return precom_ex(:($x ← $val), info)
        @case :(@deanc $line $x = $val)
            @warn "`@deanc x = expr` is deprecated, please use `x → expr` for deallocating an ancilla."
            return precom_ex(:($x → $val), info)
        @case :(@safe $line $subex)
            return ex
        @case :(@cuda $line $(args...))
            return ex
        @case :(@launchkernel $line $(args...))
            return ex
        @case :(@inbounds $line $subex)
            return Expr(:macrocall, Symbol("@inbounds"), line, precom_ex(subex, info))
        @case :(@simd $line $subex)
            return Expr(:macrocall, Symbol("@simd"), line, precom_ex(subex, info))
        @case :(@threads $line $subex)
            return Expr(:macrocall, Symbol("@threads"), line, precom_ex(subex, info))
        @case :(@avx $line $subex)
            return Expr(:macrocall, Symbol("@avx"), line, precom_ex(subex, info))
        @case :(@invcheckoff $line $subex)
            return Expr(:macrocall, Symbol("@invcheckoff"), line, precom_ex(subex, info))
        @case :(@routine $line $name $expr)
            @warn "`@routine name begin ... end` is deprecated, please use `@routine begin ... end`"
            return precom_ex(:(@routine $expr), info)
        @case :(~(@routine $line $name))
            @warn "`~@routine name` is deprecated, please use `~@routine`"
            return precom_ex(:(~(@routine)), info)
        @case :(@routine $line $expr)
            precode = precom_ex(expr, info)
            push!(info.routines, precode)
            return precode
        @case :(~(@routine $line))
            return precom_ex(dual_ex(pop!(info.routines)), info)
        @case :(~$expr)
            return dual_ex(precom_ex(expr, info))
        @case :($f($(args...)))
            return :($f($(args...)))
        @case :($f.($(args...)))
            return :($f.($(args...)))
        @case ::LineNumberNode
            return ex
        @case ::Nothing
            return ex
        @case _
            return error("unsupported statement: $ex")
    end
end

function precom_if(ex)
    _expand_cond(cond) = @switch cond begin
        @case :(($pre, ~))
            return :(($pre, $pre))
        @case :(($pre, $post))
            return :(($pre, $post))
        @case _
            error("must provide post condition, use `~` to specify a dummy one.")
    end
    if ex.head == :if
        ex.args[1] = _expand_cond(ex.args[1])
    elseif ex.head == :elseif
        ex.args[1].args[2] = _expand_cond(ex.args[1].args[2])
    end
    info = PreInfo()
    ex.args[2] = Expr(:block, flushancs(precom_body(ex.args[2].args, info), info)...)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            ex.args[3] = precom_if(ex.args[3])
        elseif ex.args[3].head == :block
            info = PreInfo()
            ex.args[3] = Expr(:block, flushancs(precom_body(ex.args[3].args, info), info)...)
        else
            error("unknown statement following `if` $ex.")
        end
    end
    ex
end

export @code_preprocess

"""
    @code_preprocess ex

Preprocess `ex` and return the symmetric reversible IR.

```jldoctest; setup=:(using NiLangCore)
julia> using MacroTools

julia> prettify(@code_preprocess if (x < 3, ~) x += exp(3.0) end)
:(if (x < 3, x < 3)
      x += exp(3.0)
  else
  end)
```
"""
macro code_preprocess(ex)
    QuoteNode(precom_ex(ex, PreInfo()))
end

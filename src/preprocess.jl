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
        @match arg2 begin
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => error("unknown expression after assign $(QuoteNode(arg2))")
        end
    elseif f in [:(.+=), :(.-=)]
        @match arg2 begin
            :($subf.($(subargs...))) => Expr(f, out, arg2)
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => error("unknown expression after assign $(QuoteNode(arg2))")
        end
    end
end

function precom_ox(f, out, arg2)
    if f == :(⊻=)
        @match arg2 begin
            :($subf($(subargs...))) ||
            :($a || $b) ||
            :($a && $b) => Expr(f, out, arg2)
            _ => error("unknown expression after assign $(QuoteNode(arg2))")
        end
    elseif f == :(.⊻=)
        @match arg2 begin
            :($subf.($(subargs...))) => Expr(f, out, arg2)
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => error("unknown expression after assign $(QuoteNode(arg2))")
        end
    end
end

function precom_ex(ex, info)
    @match ex begin
        :($x ← new{$(_...)}($(args...))) ||
        :($x ← new($(args...))) => begin
            for arg in args
                # no need to deallocate `arg`.
                if arg != x
                    delete!(info.ancs, arg)
                end
            end
            if !(x in args)
                info.ancs[x] = ex.args[3]
            end
            ex
        end
        :($x → new{$(_...)}($(args...))) ||
        :($x → new($(args...))) => begin
            for (i, arg) in enumerate(args)
                # no need to deallocate `arg`.
                if arg != x
                    info.ancs[arg] = :(getfield($x, $i))
                end
            end
            if !(x in args)
                delete!(info.ancs, x)
            end
            ex
        end
        :($x ← $val) => begin
            info.ancs[x] = val
            ex
        end
        :($x → $val) => begin
            delete!(info.ancs, x)
            ex
        end
        # Yao IR
        :($locs => $b) => ex
        :(@ctrl $line $clocs $locs => $b) => ex
        :($res = @measure $line $(args...)) => error("measure is not reversible!")
        :($a += $b) => precom_opm(:+=, a, b)
        :($a -= $b) => precom_opm(:-=, a, b)
        :($a ⊻= $b) => precom_ox(:⊻=, a, b)
        :($a .+= $b) => precom_opm(:.+=, a, b)
        :($a .-= $b) => precom_opm(:.-=, a, b)
        :($a .⊻= $b) => precom_ox(:.⊻=, a, b)
        :($a ⊕ $b) => :($a += identity($b))
        :($a .⊕ $b) => :($a .+= identity.($b))
        :($a ⊖ $b) => :($a -= identity($b))
        :($a .⊖ $b) => :($a .-= identity.($b))
        :($a ⊙ $b) => :($a ⊻= identity($b))
        :($a .⊙ $b) => :($a .⊻= identity.($b))
        Expr(:if, _...) => precom_if(copy(ex))
        :(while ($pre, $post); $(body...); end) => begin
            post = post == :~ ? pre : post
            info = PreInfo()
            Expr(:while, :(($pre, $post)), Expr(:block, flushancs(precom_body(body, info), info)...))
        end
        :(begin $(body...) end) => begin
            Expr(:block, precom_body(body, info)...)
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end) => begin
            info = PreInfo()
            Expr(:for, :($i=$(precom_range(range))), Expr(:block, flushancs(precom_body(body, info), info)...))
        end
        :(@anc $line $x = $val) => begin
            @warn "`@anc x = expr` is deprecated, please use `x ← expr` for loading an ancilla."
            precom_ex(:($x ← $val), info)
        end
        :(@deanc $line $x = $val) => begin
            @warn "`@deanc x = expr` is deprecated, please use `x → expr` for deallocating an ancilla."
            precom_ex(:($x → $val), info)
        end
        :(@safe $line $subex) => ex
        :(@cuda $line $(args...)) => ex
        :(@launchkernel $line $(args...)) => ex
        :(@inbounds $line $subex) => Expr(:macrocall, Symbol("@inbounds"), line, precom_ex(subex, info))
        :(@simd $line $subex) => Expr(:macrocall, Symbol("@simd"), line, precom_ex(subex, info))
        :(@threads $line $subex) => Expr(:macrocall, Symbol("@threads"), line, precom_ex(subex, info))
        :(@avx $line $subex) => Expr(:macrocall, Symbol("@avx"), line, precom_ex(subex, info))
        :(@invcheckoff $line $subex) => Expr(:macrocall, Symbol("@invcheckoff"), line, precom_ex(subex, info))
        :(@routine $line $name $expr) => begin
            @warn "`@routine name begin ... end` is deprecated, please use `@routine begin ... end`"
            precom_ex(:(@routine $expr), info)
        end
        :(~(@routine $line $name)) => begin
            @warn "`~@routine name` is deprecated, please use `~@routine`"
            precom_ex(:(~(@routine)), info)
        end
        :(@routine $line $expr) => begin
            precode = precom_ex(expr, info)
            push!(info.routines, precode)
            precode
        end
        :(~(@routine $line)) => begin
            precom_ex(dual_ex(pop!(info.routines)), info)
        end
        :(~$expr) => dual_ex(precom_ex(expr, info))
        :($f($(args...))) => :($f($(args...)))
        :($f.($(args...))) => :($f.($(args...)))
        ::LineNumberNode => ex
        ::Nothing => ex
        _ => error("unsupported statement: $ex")
    end
end

precom_range(range) = @match range begin
    _ => range
end

function precom_if(ex)
    _expand_cond(cond) = @match cond begin
        :(($pre, ~)) => :(($pre, $pre))
        :(($pre, $post)) => :(($pre, $post))
        _ => error("must provide post condition, use `~` to specify a dummy one.")
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

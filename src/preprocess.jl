export precom

struct PreInfo
    ancs::Dict{Symbol, Any}
    routines::Vector{Any}
end
PreInfo() = PreInfo(Dict{Symbol,Symbol}(), [])

function precom(ex)
    mc, fname, args, ts, body = match_function(ex)
    info = PreInfo()
    mc, fname, args, ts, flushancs(precom_body(body, info), info)
end

function precom_body(body::AbstractVector, info)
    [precom_ex(ex, info) for ex in body]
end

function flushancs(out, info)
    for (x, tp) in info.ancs
        push!(out, :($x → $tp))
    end
    return out
end

function precom_opm(f, out, arg2)
    if f in [:(+=), :(-=)]
        @match arg2 begin
            :($subf($(subargs...))) => Expr(f, out, arg2)
            #_ => Expr(f, out, :(identity($arg2)))
            _ => error("unknown expression after assign $(QuoteNode(arg2))")
        end
    elseif f in [:(.+=), :(.-=)]
        @match arg2 begin
            :($subf.($(subargs...))) => Expr(f, out, arg2)
            :($subf($(subargs...))) => Expr(f, out, arg2)
            #_ => Expr(f, out, :(identity.($arg2)))
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
        :($a += $b) => precom_opm(:+=, a, b)
        :($a -= $b) => precom_opm(:-=, a, b)
        :($a .+= $b) => precom_opm(:.+=, a, b)
        :($a .-= $b) => precom_opm(:.-=, a, b)
        :($a ⊕ $b) => :($a += identity($b))
        :($a .⊕ $b) => :($a .+= identity.($b))
        :($a ⊖ $b) => :($a -= identity($b))
        :($a .⊖ $b) => :($a .-= identity.($b))
        :($a ⊙ $b) => :($a ⊻= identity($b))
        :($a .⊙ $b) => :($a .⊻= identity.($b))
        # TODO: allow no postcond, or no else
        :(if ($pre, $post); $(truebranch...); else; $(falsebranch...); end) => begin
            post = post == :~ ? pre : post
            Expr(:if, :(($pre, $post)), Expr(:block, precom_body(truebranch, info)...), Expr(:block, precom_body(falsebranch, info)...))
        end
        :(if ($pre, $post); $(truebranch...); end) => begin
            post = post == :~ ? pre : post
            precom_ex(Expr(:if, :(($pre, $post)), Expr(:block, truebranch...), Expr(:block)), info)
        end
        :(while ($pre, $post); $(body...); end) => begin
            post = post == :~ ? pre : post
            Expr(:while, :(($pre, $post)), Expr(:block, precom_body(body, PreInfo())...))
        end
        :(begin $(body...) end) => begin
            Expr(:block, precom_body(body, info)...)
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end) => begin
            Expr(:for, :($i=$(precom_range(range))), Expr(:block, precom_body(body, PreInfo())...))
        end
        :(@anc $line $x = $val) => begin
            @warn "`@anc x = expr` is deprecated, please use `x ← expr` for loading an ancilla."
            precom_ex(:($x ← $val), info)
        end
        :(@deanc $line $x = $val) => begin
            @warn "`@deanc x = expr` is deprecated, please use `x → expr` for deallocating an ancilla."
            precom_ex(:($x → $val), info)
        end
        :(@safe $line $subex) => :(@safe $subex)
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
    :($start:$step:$stop) => range
    :($start:$stop) => :($start:1:$stop)
    _ => error("not supported for loop style $range.")
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
    QuoteNode(NiLangCore.precom_ex(ex, NiLangCore.PreInfo()))
end

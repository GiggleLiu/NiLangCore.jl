export precom

struct PreInfo
    ancs::Dict{Symbol, Any}
    routines::Dict{Symbol, Any}
end
PreInfo() = PreInfo(Dict{Symbol,Symbol}(), Dict{Symbol,Any}())

function precom(ex)
    if ex.head == :macrocall
        mc = ex.args[1]
        ex = ex.args[3]
    else
        mc = nothing
    end
    fname, args, ts, body = match_function(ex)
    info = PreInfo()
    mc, fname, args, ts, flushancs(precom_body(body, info), info)
end

function precom_body(body::AbstractVector, info)
    [precom_ex(ex, info) for ex in body]
end

function flushancs(out, info)
    for (x, tp) in info.ancs
        push!(out, :(@deanc $x = $tp))
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
            Expr(:while, :(($pre, $post)), Expr(:block, precom_body(body, PreInfo(Dict{Symbol,Symbol}(), info.routines))...))
        end
        :(begin $(body...) end) => begin
            Expr(:block, precom_body(body, info)...)
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end) => begin
            Expr(:for, :($i=$(precom_range(range))), Expr(:block, precom_body(body, PreInfo(Dict{Symbol,Symbol}(), info.routines))...))
        end
        :(@anc $line $x = $val) => begin
            info.ancs[x] = val
            ex
        end
        :(@deanc $line $x = $val) => begin
            delete!(info.ancs, x)
            ex
        end
        :(@maybe $line $subex) => :(@maybe $(precom_ex(subex, info)))
        :(@safe $line $subex) => :(@safe $subex)
        :(@routine $line $name $expr) => begin
            precode = precom_ex(expr, info)
            info.routines[name] = precode
            precode
        end
        :(@routine $line $name) => info.routines[name]
        :(~(@routine $line $name)) => dual_ex(info.routines[name])
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

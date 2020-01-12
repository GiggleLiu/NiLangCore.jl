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
            :(if($pre, $post); $(precom_body(truebranch, info)...); else; $(precom_body(falsebranch, info)...); end)
        end
        :(if ($pre, $post); $(truebranch...); end) => begin
            post = post == :~ ? pre : post
            precom_ex(:(if ($pre, $post); $(truebranch...); else; end), info)
        end
        :(while ($pre, $post); $(body...); end) => begin
            post = post == :~ ? pre : post
            :(while ($pre, $post); $(precom_body(body, PreInfo(Dict{Symbol,Symbol}(), info.routines))...); end)
        end
        :(begin $(body...) end) => begin
            :(begin $(precom_body(body, info)...) end)
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end) => begin
            :(for $i=$(precom_range(range)); $(precom_body(body, PreInfo(Dict{Symbol,Symbol}(), info.routines))...); end)
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

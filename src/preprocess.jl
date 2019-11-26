export precom

struct PreInfo
    ancs::Dict{Symbol, Symbol}
    routines::Dict{Symbol, Any}
end
PreInfo() = PreInfo(Dict{Symbol,Symbol}(), Dict{Symbol,Any}())

function precom(ex)
    fname, args, ts, body = match_function(ex)
    info = PreInfo()
    fname, args, ts, flushancs(precom_body(body, info), info)
end

function precom_body(body::AbstractVector, info)
    [precom_ex(ex, info) for ex in body]
end

function flushancs(out, info)
    for (x, tp) in info.ancs
        push!(out, :(@deanc $x::$tp))
    end
    return out
end

function precom_opm(f, out, arg2)
    if f in [:(+=), :(-=)]
        @match arg2 begin
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => Expr(f, out, :(identity($arg2)))
        end
    elseif f in [:(.+=), :(.-=)]
        @match arg2 begin
            :($subf.($(subargs...))) => Expr(f, out, arg2)
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => Expr(f, out, :(identity.($arg2)))
        end
    end
end

function precom_ex(ex, info)
    @match ex begin
        :($a += $b) => precom_opm(:+=, a, b)
        :($a -= $b) => precom_opm(:-=, a, b)
        :($a .+= $b) => precom_opm(:.+=, a, b)
        :($a .-= $b) => precom_opm(:.-=, a, b)
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
        :(@anc $line $x::$tp) => begin
            info.ancs[x] = tp
            ex
        end
        :(@deanc $line $x::$tp) => begin
            delete!(info.ancs, x)
            ex
        end
        :(@maybe $line $subex) => :(@maybe $(precom_ex(subex, info)))
        :(@safe $line $subex) => :(@safe $subex)
        :(@routine $line $name begin $(body...) end) => begin
            precode = precom_body(body, info)
            info.routines[name] = precode
            :(begin $(precode...) end)
        end
        :(@routine $line $name) => :(begin $(info.routines[name]...) end)
        :(~(@routine $line $name)) => :(begin $(dual_body(info.routines[name])...) end)
        :(~($(body...))) => :(begin $(dual_body(precom_body(body, info))...) end)
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
    _ => error("not supported for loop style $ex.")
end

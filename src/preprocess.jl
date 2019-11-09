export precom

function precom(ex)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            ancs = Dict{Symbol,Symbol}()
            :(function $fname($(args...));
                $(flushancs(preprocess(body, ancs), ancs)...);
            end)
        end
        _ => error("must input a function, got $ex")
    end
end

function preprocess(body::AbstractVector, ancs)
    [prerender(ex, ancs) for ex in body]
end

function flushancs(out, ancs)
    for (x, tp) in ancs
        push!(out, :(@deanc $x::$tp))
    end
    return out
end

function prerender(ex, ancs)
    @match ex begin
        # TODO: allow no postcond, or no else
        :(if ($pre, $post); $(truebranch...); else; $(falsebranch...); end) => begin
            :(if($pre, $post); $(preprocess(truebranch, ancs)...); else; $(preprocess(falsebranch, ancs)...); end)
        end
        :(while ($pre, $post); $(body...); end) => begin
            :(while ($pre, $post); $(preprocess(body, Dict{Symbol, Symbol}())...); end)
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            :(for i=$start:$step:$stop; $(preprocess(body, Dict{Symbol, Symbol}())...); end)
        end
        :(@anc $line $x::$tp) => begin
            ancs[x] = tp
            ex
        end
        :(@deanc $line $x::$tp) => begin
            delete!(ancs, x)
            ex
        end
        _ => ex
    end
end

@info precom(:(
    function f(x)
        @anc i::Float64
        if (i[] > 3, i[]>3)
            @anc z::Int
        else
            @anc y::Int
            @deanc y::Int
        end
    end
))

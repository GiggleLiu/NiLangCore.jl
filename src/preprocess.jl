export precom

function precom(ex)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            ancs = Dict{Symbol,Symbol}()
            :(function $fname($(args...));
                $(flushancs(precom_body(body, ancs), ancs)...);
            end)
        end
        _ => error("must input a function, got $ex")
    end
end

function precom_body(body::AbstractVector, ancs)
    [precom_ex(ex, ancs) for ex in body]
end

function flushancs(out, ancs)
    for (x, tp) in ancs
        push!(out, :(@deanc $x::$tp))
    end
    return out
end

function precom_ex(ex, ancs)
    @match ex begin
        :($f($(args...))) => begin
            if f in [:⊕, :⊖]
                @match args[2] begin
                    :($subf($(subargs...))) => :($f($subf)($(args[1]), $(subargs...)))
                    _ => ex
                end
            elseif f in [:(.⊕), :(.⊖)]
                @match args[2] begin
                    :($subf.($(subargs...))) => :($(debcast(f))($subf).($(args[1]), $(subargs...)))
                    :($subf($(subargs...))) => :($(debcast(f))($(debcast(subf))).($(args[1]), $(subargs...)))
                    _ => ex
                end
            else
                ex
            end
        end
        # TODO: allow no postcond, or no else
        :(if ($pre, $post); $(truebranch...); else; $(falsebranch...); end) => begin
            :(if($pre, $post); $(precom_body(truebranch, ancs)...); else; $(precom_body(falsebranch, ancs)...); end)
        end
        :(while ($pre, $post); $(body...); end) => begin
            :(while ($pre, $post); $(precom_body(body, Dict{Symbol, Symbol}())...); end)
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            :(for i=$start:$step:$stop; $(precom_body(body, Dict{Symbol, Symbol}())...); end)
        end
        :(@anc $line $x::$tp) => begin
            ancs[x] = tp
            ex
        end
        :(@deanc $line $x::$tp) => begin
            delete!(ancs, x)
            ex
        end
        :(@maybe $line $subex) => :(@maybe $(precom_ex(subex, ancs)))
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

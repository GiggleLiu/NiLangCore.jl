export precom

function precom(ex)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            _precom(fname, args, body, nothing)
        end
        _ => begin
            if ex.head == :function
                @match ex.args[1] begin
                    :($fname($(args...)) where {$(ts...)}) =>
                        _precom(fname, args, ex.args[2].args, ts)
                    _ => error("not a valid input, got $ex")
                end
            else
                error("must input a function, got $ex")
            end
        end
    end
end

function _precom(fname, args, body, ts)
    ancs = Dict{Symbol,Symbol}()
    if ts === nothing
        :(function $fname($(args...));
            $(flushancs(precom_body(body, ancs), ancs)...);
        end)
    else
        :(function $fname($(args...)) where {$(ts...)};
            $(flushancs(precom_body(body, ancs), ancs)...);
        end)
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
            if f in [:+=, :-=]
                @match args[2] begin
                    :($subf($(subargs...))) => :($f($subf)($(args[1]), $(subargs...)))
                    _ => ex
                end
            elseif f in [:(.+=), :(.-=)]
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
            post = post == :~ ? pre : post
            :(if($pre, $post); $(precom_body(truebranch, ancs)...); else; $(precom_body(falsebranch, ancs)...); end)
        end
        :(if ($pre, $post); $(truebranch...); end) => begin
            precom_ex(:(if ($pre, $post); $(truebranch...); else; end), ancs)
        end
        :(while ($pre, $post); $(body...); end) => begin
            post = post == :~ ? pre : post
            :(while ($pre, $post); $(precom_body(body, Dict{Symbol, Symbol}())...); end)
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end) => begin
            rg = @match range begin
                :($start:$step:$stop) => range
                :($start:$stop) => :($start:1:$stop)
                _ => error("not supported for loop style $ex.")
            end
            :(for $i=$rg; $(precom_body(body, Dict{Symbol, Symbol}())...); end)
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

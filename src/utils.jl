# Compile utilities
startwithdot(sym::Symbol) = string(sym)[1] == '.'
startwithdot(sym::Expr) = false
endwithpang(sym::Symbol) = string(sym)[end] == '!'
endwithpang(sym::Expr) = false
removedot(sym::Symbol) = startwithdot(sym) ? Symbol(string(sym)[2:end]) : sym
function debcast(f)
    string(f)[1] == '.' || error("$f is not a broadcasting.")
    Symbol(string(f)[2:end])
end

get_ftype(fname::Symbol) = :(typeof($fname))
function get_ftype(fname::Expr)
    fname.head == :(::) && return fname.args[2]
end

get_argname(arg::Symbol) = arg
function get_argname(fname::Expr)
    @match fname begin
        :($x::$t) => x
        :($x::$t=$y) => x
        :($x=$y) => x
        :($x...) => :($x...)
        :($x::$t...) => :($x...)
        _ => error("can not get the function name of expression $fname.")
    end
end

function match_function(ex)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => (fname, args, [], body)
        Expr(:function, :($fname($(args...)) where {$(ts...)}), xbody) => (fname, args, ts, xbody.args)
        _ => error("must input a function, got $ex")
    end
end

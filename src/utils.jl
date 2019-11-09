# Compile utilities
startwithdot(sym::Symbol) = string(sym)[1] == '.'
removedot(sym::Symbol) = startwithdot(sym) ? Symbol(string(sym)[2:end]) : sym
function debcast(f)
    string(f)[1] == '.' || error("$f is not a broadcasting.")
    Symbol(string(f)[2:end])
end

get_ftype(fname::Symbol) = :(typeof($fname))
function get_ftype(fname::Expr)
    res = @capture $x::$tp fname
    return res[:tp]
end

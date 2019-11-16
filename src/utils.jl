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
    fname.head == :(::) && return fname.args[1]
    return fname
end

const GLOBAL_ATOL = Ref(1e-8)

########### macro tools #############
startwithdot(sym::Symbol) = string(sym)[1] == '.'
startwithdot(sym::Expr) = false
startwithdot(sym) = false
function removedot(f)
    string(f)[1] == '.' || error("$f is not a broadcasting.")
    Symbol(string(f)[2:end])
end

"""
    get_argname(ex)

Return the argument name of a function argument expression, e.g. `x::Float64 = 4` gives `x`.
"""
function get_argname(fname)
    @smatch fname begin
        ::Symbol => fname
        :($x::$t) => x
        :($x::$t=$y) => x
        :($x=$y) => x
        :($x...) => :($x...)
        :($x::$t...) => :($x...)
        Expr(:parameters, args...) => fname
        _ => error("can not get the function name of expression $fname.")
    end
end

"""
    match_function(ex)

Analyze a function expression, returns a tuple of `(macros, function name, arguments, type parameters (in where {...}), statements in the body)`
"""
function match_function(ex)
    @smatch ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => (nothing, fname, args, [], body)
        Expr(:function, :($fname($(args...)) where {$(ts...)}), xbody) => (nothing, fname, args, ts, xbody.args)
        Expr(:macrocall, mcname, line, fdef) => ([mcname, line], match_function(fdef)[2:end]...)
        _ => error("must input a function, got $ex")
    end
end

"""
    rmlines(ex::Expr)

Remove line number nodes for pretty printing.
"""
rmlines(ex::Expr) = begin
    hd = ex.head
    if hd == :macrocall
        Expr(:macrocall, ex.args[1], nothing, rmlines.(ex.args[3:end])...)
    else
        tl = Any[rmlines(ex) for ex in ex.args if !(ex isa LineNumberNode)]
        Expr(hd, tl...)
    end
end
rmlines(@nospecialize(a)) = a

########### ordered dict ###############
struct MyOrderedDict{TK,TV}
    keys::Vector{TK}
    vals::Vector{TV}
end

function MyOrderedDict{K,V}() where {K,V}
    MyOrderedDict(K[], V[])
end

function Base.setindex!(d::MyOrderedDict, val, key)
    ind = findfirst(x->x===key, d.keys)
    if ind isa Nothing
        push!(d.keys, key)
        push!(d.vals, val)
    else
        @inbounds d.vals[ind] = val
    end
    return d
end

function Base.getindex(d::MyOrderedDict, key)
    ind = findfirst(x->x===key, d.keys)
    if ind isa Nothing
        throw(KeyError(ind))
    else
        return d.vals[ind]
    end
end

function Base.delete!(d::MyOrderedDict, key)
    ind = findfirst(x->x==key, d.keys)
    if ind isa Nothing
        throw(KeyError(ind))
    else
        deleteat!(d.vals, ind)
        deleteat!(d.keys, ind)
    end
end

Base.length(d::MyOrderedDict) = length(d.keys)

function Base.pop!(d::MyOrderedDict)
    k = pop!(d.keys)
    v = pop!(d.vals)
    k, v
end

Base.isempty(d::MyOrderedDict) = length(d.keys) == 0

########### broadcasting ###############

"""
    unzipped_broadcast(f, args...)

unzipped broadcast for arrays and tuples, e.g. `SWAP.([1,2,3], [4,5,6])` will do inplace element-wise swap, and return `[4,5,6], [1,2,3]`.
"""
unzipped_broadcast(f) = error("must provide at least one argument in broadcasting!")
function unzipped_broadcast(f, arg::AbstractArray; kwargs...)
    arg .= f.(arg)
end
function unzipped_broadcast(f, arg::Tuple; kwargs...)
    f.(arg)
end
@generated function unzipped_broadcast(f, args::Vararg{<:AbstractArray,N}; kwargs...) where N
    argi = [:(args[$k][i]) for k=1:N]
    quote
        for i = 1:same_length(args)
            ($(argi...),) = f($(argi...); kwargs...)
        end
        return args
    end
end
@generated function unzipped_broadcast(f, args::Vararg{<:Tuple,N}; kwargs...) where N
    quote
        same_length(args)
        res = map(f, args...)
        ($([:($getindex.(res, $i)) for i=1:N]...),)
    end
end

function same_length(args)
    length(args) == 0 && error("can not broadcast over an empty set of arguments.")
    l = length(args[1])
    for j=2:length(args)
        @assert l == length(args[j]) "length of arguments should be the same `$(length(args[j])) != $l`"
    end
    return l
end

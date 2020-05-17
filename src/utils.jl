const GLOBAL_ATOL = Ref(1e-8)
# Compile utilities
startwithdot(sym::Symbol) = string(sym)[1] == '.'
startwithdot(sym::Expr) = false
startwithdot(sym) = false
endwithpang(sym::Symbol) = string(sym)[end] == '!'
endwithpang(sym::Expr) = false
removedot(sym::Symbol) = startwithdot(sym) ? Symbol(string(sym)[2:end]) : sym
function debcast(f)
    string(f)[1] == '.' || error("$f is not a broadcasting.")
    Symbol(string(f)[2:end])
end

function get_ftype(fname)
    @smatch fname begin
        :($x::$tp) => tp
        _ => :(NiLangCore._typeof($fname))
    end
end

get_argname(arg::Symbol) = arg
function get_argname(fname::Expr)
    @smatch fname begin
        :($x::$t) => x
        :($x::$t=$y) => x
        :($x=$y) => x
        :($x...) => :($x...)
        :($x::$t...) => :($x...)
        Expr(:parameters, args...) => fname
        _ => error("can not get the function name of expression $fname.")
    end
end

function match_function(ex)
    @smatch ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => (nothing, fname, args, [], body)
        Expr(:function, :($fname($(args...)) where {$(ts...)}), xbody) => (nothing, fname, args, ts, xbody.args)
        Expr(:macrocall, mcname, line, fdef) => ([mcname, line], match_function(fdef)[2:end]...)
        _ => error("must input a function, got $ex")
    end
end


gentup(struct_T) = NamedTuple{( fieldnames(struct_T)...,), Tuple{(fieldtype(struct_T,i) for i=1:fieldcount(struct_T))...}}

"""convert an object to a named tuple."""
@generated function struct2namedtuple(x)
   nt = Expr(:quote, gentup(x))
   tup = Expr(:tuple)
   for i=1:fieldcount(x)
       push!(tup.args, :(getfield(x, $i)) )
   end
   return :($nt($tup))
end

export almost_same

"""
    almost_same(a, b; atol=GLOBAL_ATOL[], kwargs...) -> Bool

Return true if `a` and `b` are almost same w.r.t. `atol`.
"""
function almost_same(a::T, b::T; atol=GLOBAL_ATOL[], kwargs...) where T <: Number
    isapprox(a, b; atol=atol, kwargs...)
end

function almost_same(a::TA, b::TB; kwargs...) where {TA, TB}
    false
end

@generated function almost_same(a::T, b::T; kwargs...) where T
    nf = fieldcount(a)
    quote
        res = true
        @nexprs $nf i-> res = res && almost_same(getfield(a, i), getfield(b, i); kwargs...)
        res
    end
end

almost_same(x::T, y::T; kwargs...) where T<:AbstractArray = all(almost_same.(x, y; kwargs...))


rmlines(ex::Expr) = begin
    hd = ex.head
    if hd == :macrocall
        Expr(:macrocall, ex.args[1], nothing, rmlines.(ex.args[3:end])...)
    else
        tl = map(rmlines, filter(!islinenumbernode, ex.args))
        Expr(hd, tl...)
    end
end
rmlines(@nospecialize(a)) = a
islinenumbernode(@nospecialize(x)) = x isa LineNumberNode

_typeof(x) = typeof(x)
_typeof(x::Type{T}) where T = Type{T}

@inline function ibcast(f, x)
    f, f.(x)
end

@inline function ibcast(f, x, y)
    res = f.(x, y)
    f, getindex.(res, 1), getindex.(res, 2)
end

@inline function ibcast(f, x, y, z)
    res = f.(x, y, z)
    f, getindex.(res, 1), getindex.(res, 2), getindex.(res, 3)
end

@inline function ibcast(f, x, y, z, a)
    res = f.(x, y, z, a)
    f, getindex.(res, 1), getindex.(res, 2), getindex.(res, 3), getindex.(res, 4)
end

@inline function ibcast(f, x, y, z, a, b)
    res = f.(x, y, z, a, b)
    f, getindex.(res, 1), getindex.(res, 2), getindex.(res, 3), getindex.(res, 4), getindex.(res, 5)
end

@inline function ibcast(f, x::AbstractArray)
    for i=1:length(x)
        @inbounds x[i] = f(x[i])
    end
    f, x
end

@inline function ibcast(f, x::AbstractArray, y)
    @assert length(x) == length(y)
    for i=1:length(x)
        (x[i], y[i]) = f(x[i], y[i])
    end
    f, x, y
end

@inline function ibcast(f, x::AbstractArray, y, z)
    @assert length(x) == length(y) == length(z)
    for i=1:length(x)
        (x[i], y[i], z[i]) = f(x[i], y[i], z[i])
    end
    f, x, y, z
end

@inline function ibcast(f, x::AbstractArray, y, z, a)
    @assert length(x) == length(y) == length(z) == length(a)
    for i=1:length(x)
        (x[i], y[i], z[i], a[i]) = f(x[i], y[i], z[i], a[i])
    end
    f, x, y, z, a
end

@inline function ibcast(f, x::AbstractArray, y, z, a, b)
    @assert length(x) == length(y) == length(z) == length(a) == length(b)
    for i=1:length(x)
        (x[i], y[i], z[i], a[i], b[i]) = f(x[i], y[i], z[i], a[i], b[i])
    end
    f, x, y, z, a, b
end

ibcast(f, args...) = ArgumentError("Sorry, number of arguments in broadcasting only supported to 5, got $(length(args)).")

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
    ind = findfirst(x->x===key, d.keys)
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

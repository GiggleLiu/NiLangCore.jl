export check_inv, world_similar, almost_same

@nospecialize
"""
    check_inv(f, args; atol::Real=1e-8, verbose::Bool=false, kwargs...)

Return true if `f(args..., kwargs...)` is reversible.
"""
function check_inv(f, args; atol::Real=1e-8, verbose::Bool=false, kwargs...)
    args0 = deepcopy(args)
    args_ = f(args...; kwargs...)
    args = length(args) == 1 ? (args_,) : args_
    args_ = (~f)(args...; kwargs...)
    args = length(args) == 1 ? (args_,) : args_
    world_similar(args0, args, atol=atol, verbose=verbose)
end

function world_similar(a, b; atol::Real=1e-8, verbose::Bool=false)
    for (xa, xb) in zip(a, b)
        if !almost_same(xa, xb; atol=atol)
            verbose && println("$xa does not match $xb")
            return false
        end
    end
    return true
end
@specialize

"""
    almost_same(a, b; atol=GLOBAL_ATOL[], kwargs...) -> Bool

Return true if `a` and `b` are almost same w.r.t. `atol`.
"""
function almost_same(a::T, b::T; atol=GLOBAL_ATOL[], kwargs...) where T <: AbstractFloat
    a === b || abs(b - a) < atol
end

function almost_same(a::TA, b::TB; kwargs...) where {TA, TB}
    false
end

function almost_same(a::T, b::T; kwargs...) where {T<:Dict}
    length(a) != length(b) && return false
    for (k, v) in a
        haskey(b, k) && almost_same(v, b[k]; kwargs...) || return false
    end
    return true
end

@generated function almost_same(a::T, b::T; kwargs...) where T
    nf = fieldcount(a)
    if isprimitivetype(T)
        :(a === b)
    else
        quote
            res = true
            @nexprs $nf i-> res = res && almost_same(getfield(a, i), getfield(b, i); kwargs...)
            res
        end
    end
end

almost_same(x::T, y::T; kwargs...) where T<:AbstractArray = all(almost_same.(x, y; kwargs...))

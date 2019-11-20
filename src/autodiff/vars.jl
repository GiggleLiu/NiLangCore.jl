######## GVar, a bundle that records gradient
export GVar, grad

# mutable to support `x.g = ...` expression.
struct GVar{T,GT<:Reg{T}} <: Bundle{T}
    x::T
    g::GT
end
GVar{T1,T2}(x) where {T1,T2} = GVar(T1(x), zero(T2))
GVar{T1,T2}(x::GVar{T1,T2}) where {T1,T2} = x # to avoid ambiguity error
Base.copy(b::GVar) = GVar(b.x, copy(b.g))
Base.zero(x::GVar) = GVar(Base.zero(x.x), Base.zero(x.g))
grad(gv::GVar) = val(gv.g)
grad(gv) = nothing

# constructors and deconstructors
## identity mapping
GVar(x::Integer) = x
(_::Type{Inv{GVar}})(x::Integer) = x

## variable mapping
GVar(x) = GVar(x, zero(x))
GVar(x::GVar) = GVar(x, zero(x))
(_::Type{Inv{GVar}})(x::GVar) = (@invcheck grad(x) ≈ zero(x); val(x))
Base.isapprox(x::Bundle, y::Number; kwargs...) = isapprox(val(x), y; kwargs...)
Base.isapprox(x::Bundle, y::Bundle; kwargs...) = isapprox(val(x), val(y); kwargs...)
Base.isapprox(x::Number, y::Bundle; kwargs...) = isapprox(x, val(y); kwargs...)

GVar(x::AbstractArray) = GVar.(x)
(f::Type{Inv{GVar}})(x::AbstractArray) = f.(x)

GVar(x::Tuple) = GVar.(x)
(_::Type{Inv{GVar}})(x::Tuple) = (~GVar).(x)

Base.show(io::IO, gv::GVar) = print(io, "GVar($(gv.x), $(gv.g))")
Base.show(io::IO, ::MIME"plain/text", gv::GVar) = Base.show(io, gv)
# interfaces
chfield(x::GVar{T1,T2}, ::typeof(grad), g) where {T1,T2} = chfield(x, Val(:g), g)

export Loss
struct Loss{T}<:Bundle{T} x::T end
Loss(x::Loss{T}) where T = x # to avoid ambiguity error
Loss{T}(x::Loss{T}) where T = x
(_::Type{Inv{Loss}})(x) = x.x
Base.eps(::Type{<:Loss{T}}) where T = Base.eps(T)
Base.show(io::IO, gv::Loss) = print(io, "Loss($(gv.x))")
Base.show(io::IO, ::MIME"plain/text", gv::Loss) = Base.show(io, gv)

######## Conditional apply
export conditioned_apply, @maybe

"""excute if and only if arguments are not nothing"""
macro maybe(ex)
    @match ex begin
        :($fname($(args...))) ||
        :(begin $fname($(args...)) end) => begin
            args = Expr(:tuple, esc.(args)...)
            esc(:(conditioned_apply($fname, $args, $args)))
        end
        _ => error("got $ex")
    end
end

@generated function conditioned_apply(f, args, cargs)
    if any(x->x<:Nothing, cargs.parameters)
        return :(nothing)
    else
        return quote
            f(args...)
        end
    end
end

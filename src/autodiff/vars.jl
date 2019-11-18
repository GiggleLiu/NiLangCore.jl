######## GVar, a variable that records gradient
export GVar, grad, val
# mutable to support `x.g = ...` expression.
struct GVar{T,GT<:Reg{T}} <: AbstractVar{T}
    x::T
    g::GT
end
GVar{T1,T2}(x) where {T1,T2} = GVar(T1(x), zero(T2))
Base.getindex(gv::GVar) = gv.x
Base.copy(b::GVar) = GVar(b.x, copy(b.g))
Base.zero(x::GVar) = GVar(Base.zero(x.x), Base.zero(x.g))
val(gv) = gv
val(gv::GVar) = gv.x
grad(gv::GVar) = gv.g
grad(gv) = nothing

# constructors and deconstructors
## identity mapping
GVar(x::Integer) = x
(_::Type{Inv{GVar}})(x::Integer) = x

## identity mapping
GVar(x) = GVar(x, zero(x))
GVar(x::GVar) = GVar(x, zero(x))
(_::Type{Inv{GVar}})(x::GVar) = (@invcheck x.g ≈ zero(x); x.x)

GVar(x::Tuple) = GVar.(x)
(_::Type{Inv{GVar}})(x::Tuple) = (~GVar).(x)

using Base.Cartesian
export @gradalloc, @graddealloc
macro gradalloc(args::Symbol...)
    ex = :()
    for s in args
        ex = :($ex; $(esc(s)) = GVar($(esc(s))))
    end
    ex
end

macro graddealloc(args::Symbol...)
    ex = :()
    for s in args
        ex = :($ex; $(esc(s)) = (~GVar)($(esc(s))))
    end
    ex
end
Base.show(io::IO, gv::GVar) = print(io, "GVar($(gv.x), $(gv.g))")
Base.show(io::IO, ::MIME"plain/text", gv::GVar) = Base.show(io, gv)

chvar(x::GVar{T1,T2}, ::Val{:g}, g) where {T1,T2} = GVar{T1,T2}(x.x, g)
chvar(x::GVar{T1,T2}, ::Val{:x}, v) where {T1,T2} = GVar{T1,T2}(T1(v), x.g)
chvar(x::GVar{T1,T2}, ::typeof(grad), g) where {T1,T2} = GVar{T1,T2}(x.x, g)
chvar(x::GVar{T1,T2}, ::typeof(val), v) where {T1,T2} = GVar{T1,T2}(T1(v), x.g)

#function Base.promote_rule(::Type{GVar{T,T2}}, ::Type{T}) where {T,T2}
#    GVar{T, T2}
#end
#Base.convert(::Type{GVar{T,T2}}, x::T) where {T, T2} = GVar(x, zero(T2))

export Loss
struct Loss{FT}<:AbstractFloat x::FT end
Loss{T}(x::Loss{T}) where T = x
Base.getindex(l::Loss) = l.x
(_::Type{Inv{Loss}})(x) = x.x
Base.promote_type(::Type{Loss{T1}}, ::Type{T2}) where {T1,T2} = Loss{promote_type(T1, T2)}
Base.promote_type(::Type{T1}, ::Type{Loss{T2}}) where {T1,T2} = promote_type(T1, T2)
Base.convert(::Type{T}, ls::Loss) where T<:Real = convert(T, ls.x)
Base.convert(::Type{Loss{T1}}, x::T2) where {T1, T2<:Number} = Loss(T1(x))
Base.convert(::Type{Loss{T1}}, x::Loss) where {T1} = Loss(T1(x.x))
Base.:-(x::Loss) = Loss(-x.x)
for OP in [:+, :-, :*, :/]
    @eval Base.$OP(x::Loss, y::Number) = Loss($OP(x.x, y[]))
    @eval Base.$OP(x::GVar, y::Number) = GVar($OP(x.x, y[]))
end
Base.eps(::Type{<:Loss{T}}) where T = Base.eps(T)
Base.show(io::IO, gv::Loss) = print(io, "Loss($(gv.x))")
Base.show(io::IO, ::MIME"plain/text", gv::Loss) = Base.show(io, gv)

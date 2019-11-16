######## GVar, a variable that records gradient
export GVar, grad, val
# mutable to support `x.g = ...` expression.
struct GVar{T,GT<:Reg{T}} <: AbstractVar{T}
    x::T
    g::GT
end
GVar{T1,T2}(x) where {T1,T2} = GVar(T1(x), zero(T2))
convert(::Type{T}, gv::GVar) where T = T(gv.x)
Base.copy(b::GVar) = GVar(b.x, copy(b.g))
val(gv) = gv
val(gv::GVar) = gv.x
grad(gv::GVar) = gv.g
grad(gv) = nothing

# constructors and deconstructors
GVar(x::Integer) = x
GVar(x) = GVar(x, zero(x))
GVar(x::GVar) = GVar(x, zero(x))
GVar(x::Tuple) = GVar.(x)
Base.zero(x::GVar) = GVar(Base.zero(x.x), Base.zero(x.g))

Base.:~(::Type{GVar}) = Inv{GVar}
(_::Type{Inv{GVar}})(x) = (@invcheck x.g ≈ zero(x); x.x)
(_::Type{Inv{GVar}})(x::Tuple) = x

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

chvar(x::GVar, ::Val{:g}, g) = GVar(x.x, g)
chvar(x::GVar, ::Val{:x}, v) = GVar(v, x.g)
chvar(x::GVar, ::typeof(grad), g) = GVar(x.x, g)
chvar(x::GVar, ::typeof(val), v) = GVar(v, x.g)

#function Base.promote_rule(::Type{GVar{T,T2}}, ::Type{T}) where {T,T2}
#    GVar{T, T2}
#end
#convert(::Type{GVar{T,T2}}, x::T) where {T, T2} = GVar(x, zero(T2))

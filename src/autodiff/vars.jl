######## GVar, a variable that records gradient
export GVar, grad, val
# mutable to support `x.g = ...` expression.
mutable struct GVar{T,GT<:Reg{T}} <: AbstractVar{T}
    x::T
    g::GT
end
convert(::Type{T}, gv::GVar) where T = T(gv.x)
Base.copy(b::GVar) = GVar(b.x, copy(b.g))
val(gv) = gv
val(gv::GVar) = gv.x
grad(gv::GVar) = gv.g
grad(gv) = nothing

# constructors and deconstructors
GVar(x) = GVar(x, zero(x))
GVar(x::Tuple) = GVar.(x)

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

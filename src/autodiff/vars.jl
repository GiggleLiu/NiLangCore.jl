######## GVar, a variable that records gradient
export GVar, grad, val
struct GVar{T,GT<:AbstractVar{T}} <: AbstractVar{T}
    x::Var{T}
    g::GT
end
Base.getindex(gv::GVar) = Base.getindex(gv.x)
Base.setindex!(r::GVar, val) = Base.setindex!(r.x, val)
Base.copy(b::GVar) = GVar(copy(b.x), copy(b.g))
val(gv) = gv
val(gv::GVar) = gv.x
grad(gv::GVar) = gv.g
grad(gv) = nothing

GVar(x) = x
GVar(x::Var) = GVar(x, Var(zero(x.x)))
GVar(x::GVar) = GVar(x.x, GVar(x.g))
GVar(x::Tuple) = GVar.(x)

Base.:~(::Type{GVar}) = Inv{GVar}
# TODO: should throw InvertibilityError for nonzero g!
(_::Type{Inv{GVar}})(x) = x
(_::Type{Inv{GVar}})(x::GVar{T,<:Var}) where T = x.x
(_::Type{Inv{GVar}})(x::GVar{T,<:GVar}) where T = GVar(x.x, (~GVar)(x.g))

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

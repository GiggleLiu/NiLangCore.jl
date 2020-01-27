######## GVar, a bundle that records gradient
"""
    GVar{T,GT} <: Bundle{T}
    GVar(x)

Attach a gradient field to `x`.
"""
struct GVar{T,GT} <: Bundle{T}
    x::T
    g::GT
end
Base.copy(b::GVar) = GVar(b.x, copy(b.g))
Base.zero(x::GVar) = GVar(Base.zero(x.x), Base.zero(x.g))
Base.zero(::Type{<:GVar{T}}) where T = GVar(zero(T))

# define kernel and field views
"""
    grad(var)

Get the gradient field of `var`.
"""
function grad end
@fieldview grad(gv::GVar) = gv.g

grad(gv::T) where T = zero(T)
grad(gv::AbstractArray{T}) where T = grad.(gv)
chfield(x::T, ::typeof(grad), g::T) where T = (@invcheck iszero(g) || g≈0; x)
chfield(x::GVar, ::typeof(grad), g::GVar) where T = GVar(x.x, g)

# NOTE: superwarning: check value only to make ancilla gradient descardable.
NiLangCore.deanc(x::GVar, val::GVar) = NiLangCore.deanc(value(x), value(val))
function NiLangCore.deanc(x::AbstractArray{<:GVar}, val::AbstractArray{<:GVar})
    for (xi, vali) in zip(x, val)
        NiLangCore.deanc(value(xi), value(vali))
    end
end

#NiLangCore.almost_same(a::GVar, b::GVar) = NiLangCore.almost_same(value(a), value(b))

# constructors and deconstructors
GVar(x::Integer) = x
(_::Type{Inv{GVar}})(x::Integer) = x
Base.:-(x::GVar) = GVar(-x.x, -x.g)

## variable mapping
GVar(x) = GVar(x, zero(x))
(_::Type{Inv{GVar}})(x::GVar) = (@invcheck iszero(grad(x)); x.x)
function (_::Type{Inv{GVar}})(x::GVar{<:GVar,<:GVar})
    Partial{:x}(x)
end

GVar(x::AbstractArray) = GVar.(x)
(f::Type{Inv{GVar}})(x::AbstractArray) = f.(x)

GVar(x::Tuple) = GVar.(x)
(_::Type{Inv{GVar}})(x::Tuple) = (~GVar).(x)

Base.show(io::IO, gv::GVar) = print(io, "GVar($(gv.x), $(gv.g))")
Base.show(io::IO, ::MIME"plain/text", gv::GVar) = Base.show(io, gv)
# interfaces

"""
    Loss{T}<:Bundle{T}
    Loss(x)

Wrapper used to mark the loss variable.
"""
struct Loss{T}<:Bundle{T} x::T end
Loss(x::Loss{T}) where T = x # to avoid ambiguity error
Loss{T}(x::Loss{T}) where T = x
(_::Type{Inv{Loss}})(x) = x.x
grad(x::Loss) = grad(x.x)
Base.eps(::Type{<:Loss{T}}) where T = Base.eps(T)
Base.show(io::IO, gv::Loss) = print(io, "Loss($(gv.x))")
Base.show(io::IO, ::MIME"plain/text", gv::Loss) = Base.show(io, gv)
Base.:-(x::Loss) = Loss(-x.x)

"""
    NoGrad{T}<:Bundle{T}
    NoGrad(x)

A `NoGrad(x)` is equivalent to `GVar^{-1}(x)`, which cancels the `GVar` wrapper.
"""
struct NoGrad{T}<:Bundle{T} x::T end
NoGrad(x::NoGrad{T}) where T = x # to avoid ambiguity error
NoGrad{T}(x::NoGrad{T}) where T = x
Base.eps(::Type{<:NoGrad{T}}) where T = Base.eps(T)
Base.show(io::IO, gv::NoGrad) = print(io, "NoGrad($(gv.x))")
Base.show(io::IO, ::MIME"plain/text", gv::NoGrad) = Base.show(io, gv)
Base.:-(x::NoGrad) = NoGrad(-x.x)
GVar(x::NoGrad) = x.x
(_::Type{Inv{GVar}})(x) = NoGrad(x)

for TP in [:GVar, :Loss, :NoGrad]
    @eval value(gv::$TP) = gv.x
    @eval chfield(x::$TP, ::typeof(value), xval) = chfield(x, Val(:x), xval)
end
chfield(x::GVar, ::typeof(value), xval::GVar) = GVar(xval, x.g)

"""
    @nograd f(args...)

Mark `f(args...)` as having no gradients.
"""
macro nograd(ex)
    @match ex begin
        :($f($(args...))) => begin
            newargs = []
            for arg in args
                push!(newargs, @match arg begin
                    :($x::GVar) => :($x.x)
                    :($x::GVar{$tp}) => :($x.x)
                    _ => arg
                end
                )
            end
            esc(quote
                @i function $f($(args...))
                    $f($(newargs...))
                end
            end)
        end
        _ => error("expect `f(args...)`, got $ex")
    end
end

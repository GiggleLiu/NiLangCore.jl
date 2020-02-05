######## GVar, a bundle that records gradient
"""
    GVar{T,GT} <: IWrapper{T}
    GVar(x)

Attach a gradient field to `x`.
"""
struct GVar{T,GT} <: IWrapper{T}
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
@fieldview grad(gv::GVar) = gv.g
@fieldview value(gv::GVar) = gv.x
chfield(x::GVar, ::typeof(value), xval::GVar) = GVar(xval, x.g)  # TODO: fix the problem causing this patch, the field type can not change?!

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
(_::Type{Inv{GVar}})(x::GVar) = (@invcheck grad(x) zero(grad(x)); x.x)
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
    Loss{T} <: IWrapper{T}
    Loss(x)

Wrapper used to mark the loss variable.
"""
@pure_wrapper Loss
grad(x::Loss) = grad(x.x)

"""
    NoGrad{T} <: IWrapper{T}
    NoGrad(x)

A `NoGrad(x)` is equivalent to `GVar^{-1}(x)`, which cancels the `GVar` wrapper.
"""
@pure_wrapper NoGrad
GVar(x::NoGrad) = x.x
(_::Type{Inv{GVar}})(x) = NoGrad(x)

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

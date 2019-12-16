struct TaylorVar{N,T,TT<:NTuple{N,Any}} <: Bundle{T}
    x::T
    tape::TT
end

TaylorVar{T1,T2}(x) where {T1,T2} = TaylorVar(T1(x), zero(T2))
TaylorVar{T1,T2}(x::TaylorVar{T1,T2}) where {T1,T2} = x # to avoid ambiguity error
Base.copy(b::TaylorVar) = TaylorVar(b.x, copy(b.tape))
Base.zero(x::TaylorVar) = TaylorVar(Base.zero(x.x), Base.zero(x.tape))
series(gv::TaylorVar) = value(gv.tape)
series(gv::T) where T = zero(T)

# constructors and deconstructors
## identity mapping
TaylorVar(x::Integer) = x
(_::Type{Inv{TaylorVar}})(x::Integer) = x
Base.:-(x::TaylorVar) = TaylorVar(-x.x, -x.tape)

## variable mapping
TaylorVar(x) = TaylorVar(x, zero(x))
TaylorVar(x::TaylorVar) = TaylorVar(x, zero(x))
(_::Type{Inv{TaylorVar}})(x::TaylorVar) = (@invcheck series(x) zero(x); x.x)
Base.isapprox(x::Bundle, y::Number; kwargs...) = isapprox(value(x), y; kwargs...)
Base.isapprox(x::Bundle, y::Bundle; kwargs...) = isapprox(value(x), value(y); kwargs...)
Base.isapprox(x::Number, y::Bundle; kwargs...) = isapprox(x, value(y); kwargs...)

TaylorVar(x::AbstractArray) = TaylorVar.(x)
(f::Type{Inv{TaylorVar}})(x::AbstractArray) = f.(x)

TaylorVar(x::Tuple) = TaylorVar.(x)
(_::Type{Inv{TaylorVar}})(x::Tuple) = (~TaylorVar).(x)

Base.show(io::IO, gv::TaylorVar) = print(io, "TaylorVar($(gv.x), $(gv.tape))")
Base.show(io::IO, ::MIME"plain/text", gv::TaylorVar) = Base.show(io, gv)
# interfaces
chfield(x::TaylorVar{T1,T2}, ::typeof(series), g) where {T1,T2} = chfield(x, Val(:g), g)
chfield(x::T, ::typeof(series), g::T) where T = x

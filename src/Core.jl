# Properties
export isreversible, isreflexive, isprimitive
"""
    isreversible(f)

Return `true` if a function is reversible.
"""
isreversible(f) = false

"""
    isreflexive(f)

Return `true` if a function is self-inverse.
"""
isreflexive(f) = false

"""
    isprimitive(f)

Return `true` if `f` is an `instruction` that can not be decomposed anymore.
"""
isprimitive(f) = false

# inv check
export invcheckon, InvertibilityError, @invcheck
const _invcheckon = Ref(true)

"""
    invcheckon(val::Bool)
    invcheckon() -> Bool

If `val` is provided, set the invertibility check status to `val`.
This is a global switch, turning off may increase the performance.

If `val` is not provided, query the invertibility check status.
"""
invcheckon(val::Bool) = _invcheckon[] = val
invcheckon() = _invcheckon[]

"""
    InvertibilityError <: Exception
    InvertibilityError(ex)

The error thrown when a irreversible statement appears in a reversible context.
"""
struct InvertibilityError <: Exception
    ex
end

"""
    @invcheck ex
    @invcheck x val

Pass the check it if `ex` is true or `x ≈ val`.
"""
macro invcheck(ex)
    esc(:(if invcheckon();
        $ex || throw(InvertibilityError($(QuoteNode(ex))));
    end))
end

macro invcheck(x, val)
    esc(:(if invcheckon() && !(NiLangCore.almost_same($x, $val))
        throw(InvertibilityError("$($(QuoteNode(x))) (=$($x)) ≂̸ $($(QuoteNode(val))) (=$($val))"))
    end))
end

# TODEP
# Inv Type
"""
    RevType

The base type for reversible types.
"""
abstract type RevType end
function invkernel end

"""
    chfield(x, field, val)

Change a `field` of an object `x`.

The `field` can be a `Val` type

```jldoctest; setup=:(using NiLangCore)
julia> chfield(1+2im, Val(:im), 5)
1 + 5im
```

or a function

```jldoctest; setup=:(using NiLangCore)
julia> using NiLangCore.ADCore: GVar

julia> x = GVar(1.0)
GVar(1.0, 0.0)

julia> chfield(x, grad, 0.5)
GVar(1.0, 0.5)
```
"""
function chfield end

chfield(x, ::Type{T}, v) where {T<:RevType} = (~T)(v)
isreversible(::Type{<:RevType}) = true
isreversible(::RevType) = true

# TODEP
# Bundle is a wrapper of data type, its invkernel is its value.
# instructions on Bundle will not change the original behavior of wrapped data type.
abstract type Bundle{t} <: RevType end
invkernel(b::Bundle) = value(b)

Base.isapprox(x::Bundle, y; kwargs...) = isapprox(value(x), y; kwargs...)
Base.isapprox(x::Bundle, y::Bundle; kwargs...) = isapprox(value(x), value(y); kwargs...)
Base.isapprox(x, y::Bundle; kwargs...) = isapprox(x, value(y); kwargs...)


######## Inv
export Inv
"""
    Inv{FT} <: Function
    Inv(f)

The inverse of a function.
"""
struct Inv{FT} <: Function
    _f::FT
end
Inv(f::Inv) = f._f
isreversible(::Inv) = true
Base.:~(f::Function) = Inv(f)
Base.:~(::Type{Inv{T}}) where T = T  # for type, it is a destructor
Base.:~(::Type{T}) where T = Inv{T}  # for type, it is a destructor
Base.show(io::IO, b::Inv) = print(io, "~$(b._f)")
Base.display(bf::Inv) where f = print(bf)
Base.getproperty(iv::Inv, prop::Symbol) = prop == :_f ? getfield(iv, :_f) : getproperty(iv._f, prop)

######### Infer
export PlusEq, MinusEq, XorEq
"""
    PlusEq{FT} <: Function
    PlusEq(f)
    ⊕(f)

Called when executing `out += f(args...)` instruction. The following two statements are same

```jldoctest; setup=:(using NiLangCore)
julia> x, y, z = 0.0, 2.0, 3.0
(0.0, 2.0, 3.0)

julia> x, y, z = PlusEq(*)(x, y, z)
(6.0, 2.0, 3.0)

julia> x, y, z = 0.0, 2.0, 3.0
(0.0, 2.0, 3.0)

julia> @instr x += y*z

julia> x, y, z
(6.0, 2.0, 3.0)
```
"""
struct PlusEq{FT} <: Function
    f::FT
end

"""
    MinusEq{FT} <: Function
    MinusEq(f)
    ⊖(f)

Called when executing `out -= f(args...)` instruction. See `PlusEq` for detail.
"""
struct MinusEq{FT} <: Function
    f::FT
end

"""
    XorEq{FT} <: Function
    XorEq(f)
    ⊙(f)

Called when executing `out ⊻= f(args...)` instruction. See `PlusEq` for detail.
"""
struct XorEq{FT} <: Function
    f::FT
end
isreflexive(::XorEq) = true

const OPMX{FT} = Union{PlusEq{FT}, MinusEq{FT}, XorEq{FT}}

"""
accumulate result into x.
"""
#(inf::PlusEq)(out!, args...) = (chfield(out!, value, value(out!) + inf.f(value.(args)...)), args...)
#(inf::MinusEq)(out!, args...) = (chfield(out!, value, value(out!) - inf.f(value.(args)...)), args...)
#(inf::XorEq)(out!, args...) = (chfield(out!, value, value(out!) ⊻ inf.f(value.(args)...)), args...)

for (TP, OP) in [(:PlusEq, :+), (:MinusEq, :-), (:XorEq, :⊻)]
    @eval (inf::$TP)(out!::Number, args::Number...; kwargs...) = $OP(out!, inf.f(args...; kwargs...)), args...
end

Base.:~(op::PlusEq) = MinusEq(op.f)
Base.:~(om::MinusEq) = PlusEq(om.f)
Base.:~(om::XorEq) = om
_str(::PlusEq) = '⊕'
_str(::MinusEq) = '⊖'
_str(::XorEq) = '⊙'
Base.display(o::OPMX) = print(_str(o), "(", o.f, ")")
Base.show(io::IO, o::OPMX) = print(io, _str(o), o.f)
isreversible(::OPMX) = true

export ⊕, ⊖, ⊙
⊕(f) = PlusEq(f)
⊖(f) = MinusEq(f)
⊙(f) = XorEq(f)

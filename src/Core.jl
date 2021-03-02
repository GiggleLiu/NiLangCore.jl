# Properties
export isreversible, isreflexive, isprimitive
export protectf
"""
    isreversible(f, ARGT)

Return `true` if a function is reversible.
"""
isreversible(f, ::Type{ARGT}) where ARGT = hasmethod(~f, ARGT)

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
export InvertibilityError, @invcheck

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
    esc(:($ex || throw(InvertibilityError($(QuoteNode(ex))))))
end

macro invcheck(x, val)
    esc(rmlines(:(
    if !($x === $val || $almost_same($x, $val))
        throw(InvertibilityError("$($(QuoteNode(x))) (=$($x)) ≂̸ $($(QuoteNode(val))) (=$($val))"))
    end)))
end

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
julia> using NiLangCore

julia> struct GVar{T, GT}
           x::T
           g::GT
       end

julia> @fieldview xx(x::GVar) = x.x

julia> chfield(GVar(1.0, 0.0), xx, 2.0)
GVar{Float64, Float64}(2.0, 0.0)
```
"""
function chfield end

######## Inv
export Inv, invtype
"""
    Inv{FT} <: Function
    Inv(f)

The inverse of a function.
"""
struct Inv{FT} <: Function
    f::FT
end
Inv(f::Inv) = f.f
Base.:~(f::Function) = Inv(f)
Base.:~(::Type{Inv{T}}) where T = T  # for type, it is a destructor
Base.:~(::Type{T}) where T = Inv{T}  # for type, it is a destructor
Base.show(io::IO, b::Inv) = print(io, "~$(b.f)")
Base.display(bf::Inv) where f = print(bf)
protectf(x) = x
protectf(x::Inv) = x.f

invtype(::Type{T}) where T = Inv{<:T}

######### Infer
export PlusEq, MinusEq, XorEq, MulEq, DivEq
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
    MulEq{FT} <: Function
    MulEq(f)

Called when executing `out *= f(args...)` instruction. See `PlusEq` for detail.
"""
struct MulEq{FT} <: Function
    f::FT
end

"""
    DivEq{FT} <: Function
    DivEq(f)

Called when executing `out /= f(args...)` instruction. See `PlusEq` for detail.
"""
struct DivEq{FT} <: Function
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

const OPMX{FT} = Union{PlusEq{FT}, MinusEq{FT}, XorEq{FT}, MulEq{FT}, DivEq{FT}}

logical_or(a, b) = a || b
logical_and(a, b) = a && b

_add(x, y) = x + y
_sub(x, y) = x - y
_xor(x, y) = x ⊻ y
_add(x::Tuple, y::Tuple) = x .+ y
_sub(x::Tuple, y::Tuple) = x .- y
_xor(x::Tuple, y::Tuple) = x .⊻ y
for (TP, OP) in [(:PlusEq, _add), (:MinusEq, _sub), (:XorEq, _xor)]
    @eval (inf::$TP)(out!, args...; kwargs...) = $OP(out!, inf.f(args...; kwargs...)), args...
end

Base.:~(op::PlusEq) = MinusEq(op.f)
Base.:~(om::MinusEq) = PlusEq(om.f)
Base.:~(op::MulEq) = DivEq(op.f)
Base.:~(om::DivEq) = MulEq(om.f)
Base.:~(om::XorEq) = om
_str(::PlusEq) = "+="
_str(::MinusEq) = "-="
_str(::MulEq) = "*="
_str(::DivEq) = "/="
_str(::XorEq) = "⊻="
Base.display(o::OPMX) = print(_str(o), "(", o.f, ")")
Base.show_function(io::IO, o::OPMX, compact::Bool) = print(io, "$(_str(o))($(o.f))")
Base.show_function(io::IO, ::MIME"plain/text", o::OPMX, compact::Bool) = Base.show(io, o)

# TODO deprecate
export ⊕, ⊖, ⊙
⊕(f) = PlusEq(f)
⊖(f) = MinusEq(f)
⊙(f) = XorEq(f)

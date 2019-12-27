# Properties
export isreversible, isreflexive, isprimitive
isreversible(f) = false
isreflexive(f) = false
isprimitive(f) = false

# inv check
export invcheckon, InvertibilityError, @invcheck
const _invcheckon = Ref(true)
invcheckon(val::Bool) = _invcheckon[] = val
invcheckon() = _invcheckon[]

struct InvertibilityError <: Exception
    ex
end


# Inv Type
abstract type RevType end
function invkernel end
function chfield end

chfield(x, ::Type{T}, v) where {T<:RevType} = (~T)(v)
isreversible(::Type{<:RevType}) = true
isreversible(::RevType) = true

# Bundle is a wrapper of data type, its invkernel is its value.
# instructions on Bundle will not change the original behavior of wrapped data type.
abstract type Bundle{t} <: RevType end
invkernel(b::Bundle) = value(b)

Base.isapprox(x::Bundle, y; kwargs...) = isapprox(value(x), y; kwargs...)
Base.isapprox(x::Bundle, y::Bundle; kwargs...) = isapprox(value(x), value(y); kwargs...)
Base.isapprox(x, y::Bundle; kwargs...) = isapprox(x, value(y); kwargs...)


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

######## Inv
export Inv
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
struct PlusEq{FT} <: Function
    f::FT
end
struct MinusEq{FT} <: Function
    f::FT
end
struct XorEq{FT} <: Function
    f::FT
end
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
Base.display(o::OPMX) = print(_str(o), o.f)
Base.show(io::IO, o::OPMX) = print(io, _str(o), o.f)
isreversible(::OPMX) = true

export ⊕, ⊖, ⊙
⊕(f) = PlusEq(f)
⊖(f) = MinusEq(f)
⊙(f) = XorEq(f)

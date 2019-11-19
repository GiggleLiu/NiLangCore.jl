# Properties
export isreversible, isreflexive, isprimitive
isreversible(f) = false
isreflexive(f) = false
isprimitive(f) = false

# inv check
export invcheckon, InvertibilityError, @invcheck
const _invcheckon = Ref(true)
invcheckon(val::Bool) = _invcheckon(val)
invcheckon() = _invcheckon[]

struct InvertibilityError <: Exception
    ex
end

macro invcheck(ex)
    esc(:(if invcheckon();
        $ex || throw(InvertibilityError($(QuoteNode(ex))));
    end))
end

######## Inv
export Inv
struct Inv{FT} <: Function
    f::FT
end
Inv(f::Inv) = f.f
isreversible(::Inv) = true
Base.:~(f::Function) = Inv(f)
Base.:~(::Type{T}) where T = Inv{T}  # for type, it is a destructor
Base.show(io::IO, b::Inv) = print(io, "~$(b.f)")
Base.display(bf::Inv) where f = print(bf)

######### Infer
export ⊕, ⊖
export OPlus, OMinus
struct OPlus{FT} <: Function
    f::FT
end
struct OMinus{FT} <: Function
    f::FT
end
const OPM{FT} = Union{OPlus{FT}, OMinus{FT}}

"""
accumulate result into x.
"""
(inf::OPlus)(out!, args...) = (out! += inf.f(getindex.(args)...), args...)
(inf::OMinus)(out!, args...) = (out! -= inf.f(getindex.(args)...), args...)
# TODO: support "<="
⊕(f) = OPlus(f)
⊖(f) = OMinus(f)


Base.:~(op::OPlus) = OMinus(op.f)
Base.:~(om::OMinus) = OPlus(om.f)
_char(::OPlus) = '⊕'
_char(::OMinus) = '⊖'
Base.display(o::OPM) = print(_char(o), o.f)
Base.show(io::IO, o::OPM) = print(io, _char(o), o.f)
isreversible(::OPM) = true

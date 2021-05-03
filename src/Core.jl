############# function properties #############
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

############# ancillas ################
export InvertibilityError, @invcheck

"""
    deanc(a, b)

Deallocate varialbe `a` with value `b`. It will throw an error if

* `a` and `b` are objects with different types,
* `a` is not equal to `b` (for floating point numbers, an error within `NiLangCore.GLOBAL_ATOL[]` is allowed),
"""
function deanc end

function deanc(a::T, b::T) where T <: AbstractFloat
    if a !== b && abs(b - a) > GLOBAL_ATOL[]
        throw(InvertibilityError("deallocate fail (floating point numbers): $a ≂̸ $b"))
    end
end
deanc(x::T, val::T) where T<:Tuple = deanc.(x, val)
deanc(x::T, val::T) where T<:AbstractArray = x === val || deanc.(x, val)
deanc(a::T, b::T) where T<:AbstractString = a === b || throw(InvertibilityError("deallocate fail (string): $a ≂̸ $b"))
function deanc(x::T, val::T) where T<:Dict
    if x !== val
        if length(x) != length(val)
            throw(InvertibilityError("deallocate fail (dict): length of dict not the same, got $(length(x)) and $(length(val))!"))
        else
            for (k, v) in x
                if haskey(val, k)
                    deanc(x[k], val[k])
                else
                    throw(InvertibilityError("deallocate fail (dict): key $k of dict does not exist!"))
                end
            end
        end
    end
end
deanc(a, b) = throw(InvertibilityError("deallocate fail (type mismatch): `$(typeof(a))` and `$(typeof(b))`"))

@generated function deanc(a::T, b::T) where T
    nf = fieldcount(a)
    if isprimitivetype(T)
        :(a === b || throw(InvertibilityError("deallocate fail (primitive): $a ≂̸ $b")))
    else
        quote
            @nexprs $nf i-> deanc(getfield(a, i), getfield(b, i))
        end
    end
end

"""
    InvertibilityError <: Exception
    InvertibilityError(ex)

The error for irreversible statements.
"""
struct InvertibilityError <: Exception
    ex
end

"""
    @invcheck x val

The macro version `NiLangCore.deanc`, with more informative error.
"""
macro invcheck(x, val)
    esc(quote
        try
            $deanc($x, $val)
        catch e
            @warn "Error while checking `$($(QuoteNode(x)))` and `$($(QuoteNode(val)))`"
            throw(e)
        end
    end)
end
_invcheck(a, b) = Expr(:macrocall, Symbol("@invcheck"), nothing, a, b)

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

########### Inv  ##########
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
"""
    protectf(f)

Protect a function from being inverted, useful when using an callable object.
"""
protectf(x) = x
protectf(x::Inv) = x.f

invtype(::Type{T}) where T = Inv{<:T}

######### Infer
export PlusEq, MinusEq, XorEq, MulEq, DivEq
"""
    PlusEq{FT} <: Function
    PlusEq(f)

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

Called when executing `out ⊻= f(args...)` instruction. See `PlusEq` for detail.
"""
struct XorEq{FT} <: Function
    f::FT
end
isreflexive(::XorEq) = true

const OPMX{FT} = Union{PlusEq{FT}, MinusEq{FT}, XorEq{FT}, MulEq{FT}, DivEq{FT}}

for (TP, OP) in [(:PlusEq, :+), (:MinusEq, :-), (:XorEq, :⊻)]
    @eval (inf::$TP)(out!, args...; kwargs...) = $OP(out!, inf.f(args...; kwargs...)), args...
    @eval (inf::$TP)(out!::Tuple, args...; kwargs...) = $OP.(out!, inf.f(args...; kwargs...)), args...  # e.g. allow `(x, y) += sincos(a)`
end

Base.:~(op::PlusEq) = MinusEq(op.f)
Base.:~(om::MinusEq) = PlusEq(om.f)
Base.:~(op::MulEq) = DivEq(op.f)
Base.:~(om::DivEq) = MulEq(om.f)
Base.:~(om::XorEq) = om
for (T, S) in [(:PlusEq, "+="), (:MinusEq, "-="), (:MulEq, "*="), (:DivEq, "/="), (:XorEq, "⊻=")]
    @eval Base.display(o::$T) = print($S, "(", o.f, ")")
    @eval Base.display(o::Type{$T}) = print($S)
    @eval Base.show_function(io::IO, o::$T, compact::Bool) = print(io, "$($S)($(o.f))")
    @eval Base.show_function(io::IO, ::MIME"plain/text", o::$T, compact::Bool) = Base.show(io, o)
end

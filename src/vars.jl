export @pure_wrapper
export IWrapper, Partial
export chfield, value, unwrap

############# ancillas ################
"""
    @deanc x = expr

Deallocate ancilla `x` if `x == expr`,
else throw an `InvertibilityError`.
"""
macro deanc(ex)
    @when :($x = $val) = ex begin
        return Expr(:block, :(deanc($(esc(x)), $(esc(val)))), :($(esc(x)) = nothing))
    @otherwise
        return error("please use like `@deanc x = val`")
    end
end

deanc(x, val) = @invcheck x val

"""
    @anc x = expr

Create an ancilla `x` with initial value `expr`,
"""
macro anc(ex)
    @when :($x = $tp) = ex begin
        return esc(ex)
    @otherwise
        return error("please use like `@anc x = val`")
    end
end

# variables
# TODO: allow reversible mapping
export @fieldview
"""
    @fieldview fname(x::TYPE) = x.fieldname

Create a function fieldview that can be accessed by a reversible program

```jldoctest; setup=:(using NiLangCore)
julia> struct GVar{T, GT}
           x::T
           g::GT
       end

julia> @fieldview xx(x::GVar) = x.x

julia> chfield(GVar(1.0, 0.0), xx, 2.0)
GVar{Float64,Float64}(2.0, 0.0)
```
"""
macro fieldview(ex)
    @when :($f($obj::$tp) = begin $line; $obj.$prop end) = ex begin
        return esc(quote
            Base.@__doc__ $f($obj::$tp) = begin $line; $obj.$prop end
            NiLangCore.chfield($obj::$tp, ::typeof($f), xval) = chfield($obj, Val($(QuoteNode(prop))), xval)
        end)
    @otherwise
        return error("expect expression `f(obj::type) = obj.prop`, got $ex")
    end
end

"""
    value(x)

Get the `value` from a wrapper instance.
"""
value(x) = x
chfield(x::T, ::typeof(value), y::T) where T = y

chfield(a, b, c) = error("chfield($a, $b, $c) not defined!")
chfield(x, ::typeof(identity), xval) = xval
function chfield(tp::Tuple, i::Tuple{Int}, val)
    TupleTools.insertat(tp, i[1], (val,))
end
chfield(tp::Tuple, i::Int, val) = chfield(tp, (i,), val)

for VTYPE in [:AbstractArray, :Ref]
    @eval function chfield(a::$VTYPE, indices::Tuple, val)
        setindex!(a, val, indices...)
        a
    end
    @eval chfield(tp::$VTYPE, i::Int, val) = chfield(tp, (i,), val)
end
chfield(x::T, ::typeof(-), y::T) where T = -y
chfield(x::T, ::typeof(adjoint), y) where T = adjoint(y)

"""
    IWrapper{T} <: Real

IWrapper{T} is a wrapper of for data of type T.
It will forward `>, <, >=, <=, ≈` operations.
"""
abstract type IWrapper{T} <: Real end
chfield(x, ::Type{T}, v) where {T<:IWrapper} = (~T)(v)
Base.eps(::Type{<:IWrapper{T}}) where T = Base.eps(T)
@generated function almost_same(a::T, b::T; kwargs...) where T<:IWrapper
    nf = fieldcount(a)
    quote
        res = true
        @nexprs $nf i-> res = res && almost_same(getfield(a, i), getfield(b, i); kwargs...)
        res
    end
end

"""
    unwrap(x)

Unwrap a wrapper instance (recursively) to get the original value.
"""
unwrap(x::IWrapper) = unwrap(value(x))
unwrap(x) = x

for op in [:>, :<, :>=, :<=, :isless, :(==)]
    @eval Base.$op(a::IWrapper, b::IWrapper) = $op(unwrap(a), unwrap(b))
    @eval Base.$op(a::IWrapper, b::Real) = $op(unwrap(a), b)
    @eval Base.$op(a::IWrapper, b::AbstractFloat) = $op(unwrap(a), b)
    @eval Base.$op(a::Real, b::IWrapper) = $op(a, unwrap(b))
    @eval Base.$op(a::AbstractFloat, b::IWrapper) = $op(a, unwrap(b))
end

"""
    @pure_wrapper TYPE

Create a reversible wrapper type `TYPE{T} <: IWrapper{T}` that plays a role of simple wrapper.

```jldoctest; setup=:(using NiLangCore)
julia> @pure_wrapper A

julia> A(0.5)
A(0.5)

julia> (~A)(A(0.5))
0.5

julia> -A(0.5)
A(-0.5)

julia> A(0.5) < A(0.6)
true
```
"""
macro pure_wrapper(tp)
    TP = esc(tp)
    quote
        Base.@__doc__ struct $TP{T} <: IWrapper{T} x::T end
        $TP(x::$TP{T}) where T = x # to avoid ambiguity error
        $TP{T}(x::$TP{T}) where T = x
        (_::Type{Inv{$TP}})(x) = x.x
        NiLangCore.value(x::$TP) = x.x
        NiLangCore.chfield(x::$TP, ::typeof(value), xval) = chfield(x, Val(:x), xval)
        Base.zero(x::$TP) = $TP(zero(x.x))
        Base.show(io::IO, gv::$TP) = print(io, "$($TP)($(gv.x))")
        Base.show(io::IO, ::MIME"plain/text", gv::$TP) = Base.show(io, gv)
        Base.:-(x::$TP) = $TP(-x.x)
    end
end

"""
Partial{FIELD, T, T2} <: IWrapper{T2}

Take a field `FIELD` without dropping information.
This operation can be undone by calling `~Partial{FIELD}`.
"""
struct Partial{FIELD, T, T2} <: IWrapper{T2}
    x::T
    function Partial{FIELD,T,T2}(x::T) where {T,T2,FIELD}
        new{FIELD,T,T2}(x)
    end
    function Partial{FIELD,T,T2}(x::T) where {T<:Complex,T2,FIELD}
        new{FIELD,T,T2}(x)
    end
end
Partial{FIELD}(x::T) where {T,FIELD} = Partial{FIELD,T,typeof(getfield(x,FIELD))}(x)
Partial{FIELD}(x::T) where {T<:Complex,FIELD} = Partial{FIELD,T,typeof(getfield(x,FIELD))}(x)

@generated function (_::Type{Inv{Partial{FIELD}}})(x::Partial{FIELD}) where {FIELD}
    :(x.x)
end

function chfield(hd::Partial{FIELD}, ::typeof(value), val) where FIELD
    chfield(hd, Val(:x), chfield(hd.x, Val(FIELD), val))
end

@generated function value(hv::Partial{FIELD}) where FIELD
    :(hv.x.$FIELD)
end

function Base.zero(x::T) where T<:Partial
    zero(T)
end

function Base.zero(x::Type{<:Partial{FIELD,T}}) where {FIELD, T}
    Partial{FIELD}(Base.zero(T))
end
Base.show(io::IO, gv::Partial{FIELD}) where FIELD = print(io, "$(gv.x).$FIELD")
Base.show(io::IO, ::MIME"plain/text", gv::Partial) = Base.show(io, gv)

export tget

"""
    tget(x::Tuple, i)

Get the i-th entry of a tuple.
"""
tget(x::Tuple, inds...) = x[inds...]

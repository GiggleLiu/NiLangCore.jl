using Base.Cartesian

export @pure_wrapper
export IWrapper, Partial
export chfield, value, unwrap

############# ancillas ################
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
GVar{Float64, Float64}(2.0, 0.0)
```
"""
macro fieldview(ex)
    @smatch ex begin
        :($f($obj::$tp) = begin $line; $ex end) => begin
            xval = gensym()
            esc(Expr(:block,
                :(Base.@__doc__ $f($obj::$tp) = begin $line; $ex end),
                :($NiLangCore.chfield($obj::$tp, ::typeof($f), $xval) = $(Expr(:block, assign_ex(ex, xval;invcheck=false), obj)))
            ))
        end
        _ => error("expect expression `f(obj::type) = obj.prop`, got $ex")
    end
end

"""
    value(x)

Get the `value` from a wrapper instance.
"""
value(x) = x
chfield(a, b, c) = error("chfield($a, $b, $c) not defined!")
chfield(x::T, ::typeof(value), y::T) where T = y
chfield(x, ::typeof(identity), xval) = xval
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
        $TP{T}(x::$TP{T}) where T = x # to avoid ambiguity error
        (_::Type{Inv{$TP}})(x) = x.x
        $NiLangCore.value(x::$TP) = x.x
        $NiLangCore.chfield(x::$TP, ::typeof(value), xval) = chfield(x, Val(:x), xval)
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
    tget(i::Int)

Get the i-th entry of a tuple.
"""
tget(i::Int) = x::Tuple -> x[i]

export subarray

"""
    subarray(ranges...)

Get a subarray, same as `view` in Base.
"""
subarray(args...) = x -> view(x, args...)

@inline @generated function _zero(::Type{T}) where {T<:Tuple}
    Expr(:tuple, Any[:(_zero($field)) for field in T.types]...)
end
_zero(::Type{T}) where T<:Real = zero(T)
_zero(::Type{String}) = ""
_zero(::Type{Char}) = '\0'
_zero(::Type{T}) where {ET,N,T<:Array{ET,N}} = reshape(ET[], ntuple(x->0, N))
_zero(::Type{T}) where {A,B,T<:Dict{A,B}} = Dict{A,B}()

#_zero(x::T) where T = _zero(T) # not adding this line!

@inline @generated function _zero(x::T) where {ET,N,T<:Tuple{Vararg{ET,N}}}
    Expr(:tuple, Any[:(_zero(x[$i])) for i=1:N]...)
end
_zero(x::T) where T<:Real = zero(x)
_zero(::String) = ""
_zero(::Char) = '\0'
_zero(x::T) where T<:Array = zero(x)
function _zero(d::T) where {A,B,T<:Dict{A,B}}
    Dict{A,B}([x=>zero(y) for (x,y) in d])
end

@generated function chfield(x, ::Val{FIELD}, xval) where FIELD
    if x.mutable
        Expr(:block, :(x.$FIELD = xval), :x)
    else
        :(@with x.$FIELD = xval)
    end
end
@generated function chfield(x, f::Function, xval)
    :(@invcheck f(x) xval; x)
end

@generated function type2tuple(x::T) where T
    Expr(:tuple, [:(x.$v) for v in fieldnames(T)]...)
end
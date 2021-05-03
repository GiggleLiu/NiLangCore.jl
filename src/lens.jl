export _zero

# update a field of a struct.
@inline @generated function field_update(main :: T, field::Val{Field}, value) where {T, Field}
    fields = fieldnames(T)
    Expr(:new, T, Any[field !== Field ? :(main.$field) : :value for field in fields]...)
end

# the default constructor of a struct
@inline @generated function default_constructor(::Type{T}, fields::Vararg{Any,N}) where {T,N}
    Expr(:new, T, Any[:(fields[$i]) for i=1:N]...)
end

"""
    _zero(T)
    _zero(x::T)

Create a `zero` of type `T` by recursively applying `zero` to its fields.
"""
@inline @generated function _zero(::Type{T}) where {T}
    Expr(:new, T, Any[:(_zero($field)) for field in T.types]...)
end

@inline @generated function _zero(x::T) where {T}
    Expr(:new, T, Any[:(_zero(x.$field)) for field in fieldnames(T)]...)
end

function lens_compile(ex, cache, value)
    @smatch ex begin
        :($a.$b.$c = $d) => begin
            updated =
                Expr(:let,
                    Expr(:block, :($cache = $cache.$b), :($value = $d)),
                    :($field_update($cache, $(Val(c)), $value)))
            lens_compile(:($a.$b = $updated), cache, value)
        end
        :($a.$b = $c) => begin
            Expr(:let,
                Expr(:block, :($cache = $a), :($value=$c)),
                :($field_update($cache, $(Val(b)), $value)))
        end
        _ => error("Malformed update notation $ex, expect the form like 'a.b = c'.")
    end
end

function with(ex)
    cache = gensym("cache")
    value = gensym("value")
    lens_compile(ex, cache, value)
end

"""
e.g. `@with x.y = val` will return a new object similar to `x`, with the `y` field changed to `val`.
"""
macro with(ex)
    with(ex) |> esc
end

@inline @generated function _zero(::Type{T}) where {T<:Tuple}
    Expr(:tuple, Any[:(_zero($field)) for field in T.types]...)
end
_zero(::Type{T}) where T<:Real = zero(T)
_zero(::Type{String}) = ""
_zero(::Type{Char}) = '\0'
_zero(::Type{T}) where {ET,N,T<:Array{ET,N}} = reshape(ET[], ntuple(x->0, N))
_zero(::Type{T}) where {A,B,T<:Dict{A,B}} = Dict{A,B}()

#_zero(x::T) where T = _zero(T) # not adding this line!
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
    Expr(:block, _invcheck(:(f(x)), :xval), :x)
end

# convert field of an object to a tuple
@generated function type2tuple(x::T) where T
    Expr(:tuple, [:(x.$v) for v in fieldnames(T)]...)
end

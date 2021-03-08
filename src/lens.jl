export _zero

@inline @generated function field_update(main :: T, field::Val{Field}, value) where {T, Field}
    fields = fieldnames(T)
    Expr(:new, T, Any[field !== Field ? :(main.$field) : :value for field in fields]...)
end

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
        :($a.$(b::Symbol).$(c::Symbol) = $d) => begin
            updated =
                Expr(:let,
                    Expr(:block, :($cache = $cache.$b), :($value = $d)),
                    :($field_update($cache, $(Val(c)), $value)))
            lens_compile(:($a.$b = $updated), cache, value)
        end
        :($a.$(b::Symbol) = $c) => begin
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

macro with(ex)
    with(ex) |> esc
end
@generated function field_update(main :: T, field::Val{Field}, value) where {T, Field}
    fields = fieldnames(T)
    Expr(:new, T, [field !== Field ? :(main.$field) : :value for field in fields]...)
end

@inline @generated function default_constructor(::Type{T}, fields::Vararg{Any,N}) where {T,N}
    Expr(:new, T, [:(fields[$i]) for i=1:N]...)
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
export @anc, @deanc
export RevType, Bundle, Partial
export chfield, value

############# ancillas ################
"""
    @deanc x = expr

Deallocate ancilla `x` if `x == expr`,
else throw an `InvertibilityError`.
"""
macro deanc(ex)
    @match ex begin
        :($x = $val) => :(deanc($(esc(x)), $(esc(val))))
        _ => error("please use like `@deanc x = val`")
    end
end

deanc(x, val) = @invcheck x val

"""
    @deanc x = expr

Create an ancilla `x` with initial value `expr`,
"""
macro anc(ex)
    @match ex begin
        :($x = $tp) => esc(ex)
        _ => error("please use like `@anc x = val`")
    end
end

# variables
# TODO: allow reversible mapping
export @fieldview
"""
    @fieldview fname(x::TYPE) = x.fieldname

Create a function fieldview that can be accessed by a reversible program

```jldoctest; setup=:(using NiLangCore)
julia> using NiLangCore.ADCore

julia> @fieldview xx(x::GVar) = x.x

julia> chfield(GVar(1.0), xx, 2.0)
GVar(2.0, 0.0)
```
"""
macro fieldview(ex)
    @match ex begin
        :($f($obj::$tp) = begin $line; $obj.$prop end) => esc(quote
            $f($obj::$tp) = begin $line; $obj.$prop end
            NiLangCore.chfield($obj::$tp, ::typeof($f), xval) = chfield($obj, Val($(QuoteNode(prop))), xval)
        end)
        _ => error("expect expression `f(obj::type) = obj.prop`, got $ex")
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
NiLangCore.chfield(x::T, ::typeof(-), y::T) where T = -y
NiLangCore.chfield(x::T, ::typeof(adjoint), y::T) where T = adjoint(y)

"""
    Partial{FIELD, T} <: RevType

Take a field `FIELD` without dropping information.
This operation can be undone by calling `~Partial{FIELD}`.
"""
struct Partial{FIELD, T} <: RevType
    x::T
end
Partial{FIELD}(x::T) where {T,FIELD} = Partial{FIELD,T}(x)

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

export tget

"""
    tget(x::Tuple, i)

Get the i-th entry of a tuple.
"""
tget(x::Tuple, inds...) = x[inds...]

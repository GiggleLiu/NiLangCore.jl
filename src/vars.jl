export @anc, @deanc
export RevType, Bundle, Partial
export invkernel, chfield, value

const GLOBAL_INFO = Dict{Any,Any}()

############# ancillas ################
macro deanc(ex)
    @match ex begin
        :($x = $val) => :(deanc($(esc(x)), $(esc(val))))
        _ => error("please use like `@deanc x = val`")
    end
end

deanc(x, val) = @invcheck x val

macro anc(ex)
    @match ex begin
        :($x = $tp) => esc(ex)
        _ => error("please use like `@anc x = val`")
    end
end

# variables
export @fieldview
macro fieldview(ex)
    @match ex begin
        :($f($obj::$tp) = begin $line; $obj.$prop end) => esc(quote
            $f($obj::$tp) = begin $line; $obj.$prop end
            NiLangCore.chfield($obj::$tp, ::typeof($f), xval) = chfield($obj, Val($(QuoteNode(prop))), xval)
        end)
        _ => error("expect expression `f(obj::type) = obj.prop`, got $ex")
    end
end

# NOTE: the reason for not using x[], x[] is designed for mutable types!
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

# take a field view without drop information
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
tget(x::Tuple, inds...) = x[inds...]

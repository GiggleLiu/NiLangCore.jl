export @anc, @deanc
export RevType, Bundle
export invkernel, chfield, value

const GLOBAL_INFO = Dict{Any,Any}()

############# ancillas ################
macro deanc(ex)
    @match ex begin
        :($x = $val) => esc(:(@invcheck $x $val))
        _ => error("please use like `@deanc x = val`")
    end
end

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
NiLangCore.chfield(x::T, ::typeof(conj), y::T) where T = conj(y)

# Bundle is a wrapper of data type, its invkernel is its value.
# instructions on Bundle will not change the original behavior of wrapped data type.
abstract type Bundle{t} <: RevType end
invkernel(b::Bundle) = value(b)

Base.isapprox(x::Bundle, y; kwargs...) = isapprox(value(x), y; kwargs...)
Base.isapprox(x::Bundle, y::Bundle; kwargs...) = isapprox(value(x), value(y); kwargs...)
Base.isapprox(x, y::Bundle; kwargs...) = isapprox(x, value(y); kwargs...)

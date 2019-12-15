export @push, @pop
export @anc, @deanc

const A_STACK = []
const B_STACK = []
const GLOBAL_INFO = Dict{Any,Any}()

"""
push value to A STACK, with initialization.
"""
macro push(ex::Expr)
    @match ex begin
        :($x = $val) =>
        :(
        $(esc(x)) = $(Var(val));
        push!(A_STACK, $(esc(x)))
        )
    end
end

"""
push a value to A STACK from top of B STACK.
"""
macro push(ex::Symbol)
    :(
    $(esc(ex)) = pop!(B_STACK);
    push!(A_STACK, $(esc(ex)))
    )
end

"""
pop a value to B STACK from top of A STACK.
"""
macro pop(ex::Symbol)
    :(
    $(esc(ex)) = pop!(A_STACK);
    push!(B_STACK, $(esc(ex)))
    )
end

"""
pop value to B STACK, with post check.
"""
macro pop(ex::Expr)
    @match ex begin
        :($x = $val) =>
            :(
            push!(A_STACK, $(esc(x)));
            @invcheck NiLangCore.isappr($(esc(x)[]), $val)
            )
    end
end

############# ancillas ################
macro deanc(ex)
    @match ex begin
        :($x = $val) => :(@invcheck NiLangCore.isappr($(esc(x)), $(esc(val))))
        _ => error("please use like `@deanc x::T`")
    end
end

macro anc(ex)
    @match ex begin
        :($x = $tp) => esc(ex)
        _ => error("please use like `@anc x = val`")
    end
end

export Bundle, val, value
export chfield
export Dup
# variables
# Bundle is a wrapper of data type
# instructions on Bundle will not change the original behavior of wrapped data type.
# but, will extract information.
# Bundle type is always callable as a data converter.
abstract type Bundle{T} <: InvType end

# NOTE: the reason for not using x[], x[] is designed for mutable types!
val(x) = x
val(b::Bundle) = val(b.x)
value(x) = x
value(b::Bundle) = b.x
chfield(x::Bundle, ::typeof(val), xval) = chfield(x, Val(:x), chfield(x.x, val, xval))
chfield(x::Bundle, ::typeof(value), xval) = chfield(x, Val(:x), xval)
chfield(x, ::typeof(identity), xval) = xval
chfield(x, ::Type{T}, v) where {T<:Bundle} = (~T)(v)

function chfield(tp::Tuple, i::Tuple{Int}, val)
    TupleTools.insertat(tp, i[1], (val,))
end

chfield(a, b, c) = error("chfield($a, $b, $c) not defined!")

chfield(tp::Tuple, i::Int, val) = chfield(tp, (i,), val)

for VTYPE in [:AbstractArray, :Ref]
    @eval function chfield(a::$VTYPE, indices::Tuple, val)
        setindex!(a, val, indices...)
        a
    end
    @eval chfield(tp::$VTYPE, i::Int, val) = chfield(tp, (i,), val)
end

isreversible(::Type{<:Bundle}) = true

function chfield end
chfield(x::T, ::typeof(val), y::T) where T = y
chfield(x::T, ::typeof(value), y::T) where T = y
NiLangCore.chfield(x::T, ::typeof(-), y::T) where T = -y
NiLangCore.chfield(x::T, ::typeof(conj), y::T) where T = conj(y)

struct Dup{T} <: Bundle{T}
    x::T
    twin::T
end
function Dup(x::T) where T
   Dup{T}(x, copy(x))
end

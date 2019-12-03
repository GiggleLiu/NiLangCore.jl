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

function chfield end

export Bundle, Reg, val
export chfield, chval
export Dup
# variables
# Bundle is a wrapper of data type
# instructions on Bundle will not change the original behavior of wrapped data type.
# but, will extract information.
# Bundle type is always callable as a data converter.
abstract type Bundle{T} <: Number end
"""get the data in a bundle"""

# NOTE: the reason for not using x[], x[] is designed for mutable types!
val(x) = x
val(b::Bundle) = val(b.x)
@generated function chfield(x, ::Val{FIELD}, xval) where FIELD
    :(@with x.$FIELD = xval)
end
@generated function chfield(x, f::Function, xval)
    :($(checkconst(:(f(x)), :xval)); x)
end
chfield(x::Bundle, ::typeof(val), xval) = chfield(x, Val(:x), chfield(x.x, val, xval))
chfield(x, ::typeof(identity), xval) = xval
chfield(x, ::Type{T}, v) where {T<:Bundle} = (~T)(v)
isreversible(::Type{<:Bundle}) = true

function chfield end
chfield(x::T, ::typeof(val), y::T) where T = y
NiLangCore.chfield(x::T, ::typeof(-), y::T) where T = -y
NiLangCore.chfield(x::T, ::typeof(conj), y::T) where T = conj(y)
chval(a, x) = chfield(a, val, x)
const Reg{T} = Union{T, Bundle{T}} where T<:Number

struct Dup{T} <: Bundle{T}
    x::T
    twin::T
end
function Dup(x::T) where T
   Dup{T}(x, copy(x))
end
Dup(x::Dup) = Dup(x)
(_::Type{<:Inv{Dup}})(dp::Dup) = (@invcheck isappr(dp.twin, dp.x); dp.x)
isappr(x, y) = isapprox(x, y; atol=1e-8)
isappr(x::AbstractArray, y::AbstractArray) = all(isapprox.(x, y; atol=1e-8))

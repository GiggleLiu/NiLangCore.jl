export @newvar, @push, @pop, @newreg
export GRef, AbstractGArray, GRefArray, GArray, Reg
export safe_readvar
export getregs, getparams

const A_STACK = []
const B_STACK = []
const GLOBAL_INFO = Dict{Any,Any}()

# inv check
export invcheckon, InvertibilityError, @invcheck
const _invcheckon = Ref(true)
invcheckon(val::Bool) = _invcheckon(val)
invcheckon() = _invcheckon[]

struct InvertibilityError <: Exception
    ex
end

macro invcheck(ex)
    :(if invcheckon();
        $ex || throw(InvertibilityError($(QuoteNode(ex))));
    end)
end

macro newvar(sym)
    if sym.head == :(=)
        a, b = sym.args
        quote
            $(esc(a)) = GRef($(esc(b)))
            $(esc(a))
        end
    else
        :(error("not an array assignment."))
    end
end

macro R(ex)
    @capture $a[$(inds...)] ex
    :(GRefArray(a, inds))
end

"""
push value to A STACK, with initialization.
"""
macro push(ex::Expr)
    res = @capture ($x = $val) ex
    :(
    $(esc(res[:x])) = $(GRef(res[:val]));
    push!(A_STACK, $(esc(res[:x])))
    )
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
    res = @capture ($x = $val) ex
    :(
    push!(A_STACK, $(esc(res[:x])));
    @invcheck $(esc(res[:x])[]) ≈ $(res[:val])
    )
end

macro newreg(sym::Symbol...)
    ex = :()
    for s in sym
        ex = :($ex; $(esc(s)) = GRef(0))
    end
    ex
end

############# GRef ################
mutable struct GRef{T} <: Ref{T}
    x::T
    function GRef(x::T) where T
        new{T}(x)
    end
end
Base.getindex(r::GRef) = r.x
Base.setindex!(r::GRef, val) = r.x = val
function Base.copy(b::GRef)
    res = GRef(copy(b.x))
    return res
end

############# GRefArray ################
abstract type AbstractGArray{T,N} <: AbstractArray{T, N} end
Base.getindex(arr::AbstractGArray, range::AbstractRange) = GSubArray(arr, range)
Base.getindex(arr::AbstractGArray, arg) = GRefArray(arr, arg)
Base.getindex(arr::AbstractGArray, args...) = GRefArray(arr, args)
Base.setindex!(arr::AbstractGArray, val) = arr[] .= val
Base.length(arr::AbstractGArray) = length(arr[])
Base.size(arr::AbstractGArray, args...) = size(arr[], args...)

mutable struct GArray{T,N,AT} <: AbstractGArray{T,N}
    x::AT
    function GArray(x::AT) where {T,N,AT<:AbstractArray{T,N}}
        new{T,N,AT}(x)
    end
end
GRef(x::AbstractArray) = GArray(x)
Base.getindex(arr::GArray) = arr.x
function Base.copy(b::GArray)
    res = GArray(copy(b.x))
    return res
end
Base.isapprox(a::Union{GArray,GRef}, b::Union{GArray,GRef}; atol=1e-8) = isapprox(a.x, b.x; atol=atol)
function Base.show(io::IO, r::GArray)
    println(io, summary(r))
    print(io, r.x)
end

Base.show(io::IO, ::MIME"text/plain", r::GArray) = print(io, r)

export GType, GUnitRange, GSubArray
GType{T} = Union{T, GRef{T}}
struct GUnitRange{T, T1<:GType{T}, T2<:GType{T}} <: AbstractUnitRange{T}
    start::T1
    stop::T2
end
(::Colon)(i::GRef, j) = GUnitRange(i,j)
(::Colon)(i::GRef, j::GRef) = GUnitRange(i,j)
(::Colon)(i, j::GRef) = GUnitRange(i,j)
Base.first(x::GUnitRange) = x.start
Base.last(x::GUnitRange) = x.stop

mutable struct GSubArray{T,N,AT<:AbstractGArray{T,N}, IT<:AbstractRange} <: AbstractGArray{T,N}
    x::AT
    range::IT
    function GSubArray(arr::AT, range::IT) where {T,N,AT<:AbstractGArray{T,N},IT<:AbstractRange}
        new{T,N,AT,IT}(arr, range)
    end
end

function Base.show(io::IO, r::GSubArray)
    println(io, summary(r))
    print(io, r.x)
end

Base.show(io::IO, ::MIME"text/plain", r::GSubArray) = print(io, r)

GRef(x::GSubArray) = x
Base.getindex(b::GSubArray) = view(b.x.x, b.range.start[]:b.range.stop[])
Base.setindex!(b::GSubArray, val) = view(b.x.x, b.range.start[]:b.range.stop[]) .= val
Base.setindex!(arr::AbstractGArray, val, i) = @inbounds arr[][i[]] = val

struct GRefArray{T,Tp,A<:AbstractGArray{T}} <: Ref{T}
    x::A
    i::Tp
end

GRef(x::AbstractGArray, i) = GRefArray(x[], i)
Base.setindex!(b::GRefArray{T}, x) where T = (@inbounds b.x[][b.i[]] = x; b)
Base.setindex!(b::GRefArray{T,<:Tuple}, x) where T = (@inbounds b.x[][getindex.(b.i)...] = x; b)
Base.setindex!(b::GRefArray{T, <:CartesianIndex}, x) where T = (@inbounds b.x[][getindex.(b.i.I)...] = x; b)
Base.getindex(b::GRefArray) = b.x[][b.i[]]
Base.getindex(b::GRefArray{<:Any, <:Tuple}) = @inbounds b.x[][getindex.(b.i)...]
Base.getindex(b::GRefArray{<:Any, <:CartesianIndex}) = @inbounds b.x[][getindex.(b.i.I)...]
Base.copy(b::GRefArray) = GRefArray(copy(b.x), copy(b.i))

safe_readvar(var::Nothing) = nothing
safe_readvar(var::GRef) = var[]
safe_readvar(var::GArray) = var.x

function Base.summary(io::IO, x::GRef)
    print(io, "GRef(...$(string(objectid(x))[end-4:end]))")
end

function Base.summary(io::IO, x::GRefArray)
    print(io, "GRefArray($(size(x.x.x)...), ...$(string(objectid(x.i))[end-4:end]))")
end

function Base.summary(io::IO, x::Nothing)
    print(io, "nothing")
end

Base.iszero(x::GRef) = iszero(x[])
Base.getindex(x::String) = x

const Reg{T} = Union{Ref{T}}

macro deanc(ex)
    @match ex begin
        :($x::$tp) => :(@invcheck $(esc(esc(x))) ≈ GRef(zero($tp)))
        _ => error("please use like `@deanc x::T`")
    end
end

macro anc(ex)
    @match ex begin
        :($x::$tp) => :($(esc(x)) = GRef(zero($tp)))
        _ => error("please use like `@anc x::T`")
    end
end

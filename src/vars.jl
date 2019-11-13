export @newvar, @push, @pop, @newreg, @newfloats
export @anc, @deanc
export Var, AbstractVarArray, ArrayElem, VarArray, Reg
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

macro newvar(ex)
    @match ex begin
        :($a = $b) => :($(esc(a)) = Var($(esc(b))); $(esc(a)))
        _ => error("not an array assignment.")
    end
end

macro newfloats(args...)
    ex = :()
    for arg in args
        ex = :($ex; $(esc(arg)) = Var(0.0))
    end
    return ex
end

macro R(ex)
    @match ex begin
        :($a[$(inds...)]) => :(ArrayElem(a, inds))
        _ => error("expected a[...] like expression, got $ex")
    end
end

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
            @invcheck $(esc(x)[]) ≈ $val
            )
    end
end

macro newreg(sym::Symbol...)
    ex = :()
    for s in sym
        ex = :($ex; $(esc(s)) = Var(0))
    end
    ex
end

############# Var ################
mutable struct Var{T} <: AbstractVar{T}
    x::T
    Var(x::T) where T = new{T}(x)
end

Base.getindex(r::Var) = r.x
Base.setindex!(r::Var, val) = r.x = val
function Base.copy(b::Var)
    res = Var(copy(b.x))
    return res
end

############# ArrayElem ################
abstract type AbstractVarArray{T,N} <: AbstractArray{T, N} end
Base.getindex(arr::AbstractVarArray, range::AbstractRange) = GSubArray(arr, range)
Base.getindex(arr::AbstractVarArray, arg) = ArrayElem(arr, arg)
Base.getindex(arr::AbstractVarArray, args...) = ArrayElem(arr, args)
Base.setindex!(arr::AbstractVarArray, val) = arr[] .= val
Base.length(arr::AbstractVarArray) = length(arr[])
Base.size(arr::AbstractVarArray, args...) = size(arr[], args...)

mutable struct VarArray{T,N,AT} <: AbstractVarArray{T,N}
    x::AT
    function VarArray(x::AT) where {T,N,AT<:AbstractArray{T,N}}
        new{T,N,AT}(x)
    end
end
Var(x::AbstractArray) = VarArray(x)
Base.getindex(arr::VarArray) = arr.x
function Base.copy(b::VarArray)
    res = VarArray(copy(b.x))
    return res
end
Base.isapprox(a::VarArray, b::VarArray; atol=1e-8) = isapprox(a.x, b.x; atol=atol)
Base.isapprox(a::Reg, b::Reg; atol=1e-8) = isapprox(a.x, b.x; atol=atol)
function Base.show(io::IO, r::VarArray)
    println(io, summary(r))
    print(io, r.x)
end

Base.show(io::IO, ::MIME"text/plain", r::VarArray) = print(io, r)

export GType, GUnitRange, GSubArray
GType{T} = Union{T, Var{T}}
struct GUnitRange{T, T1<:GType{T}, T2<:GType{T}} <: AbstractUnitRange{T}
    start::T1
    stop::T2
end
(::Colon)(i::Var, j) = GUnitRange(i,j)
(::Colon)(i::Var, j::Var) = GUnitRange(i,j)
(::Colon)(i, j::Var) = GUnitRange(i,j)
Base.first(x::GUnitRange) = x.start
Base.last(x::GUnitRange) = x.stop

mutable struct GSubArray{T,N,AT<:AbstractVarArray{T,N}, IT<:AbstractRange} <: AbstractVarArray{T,N}
    x::AT
    range::IT
    function GSubArray(arr::AT, range::IT) where {T,N,AT<:AbstractVarArray{T,N},IT<:AbstractRange}
        new{T,N,AT,IT}(arr, range)
    end
end

function Base.show(io::IO, r::GSubArray)
    println(io, summary(r))
    print(io, r.x)
end

Base.show(io::IO, ::MIME"text/plain", r::GSubArray) = print(io, r)

Var(x::GSubArray) = x
Base.getindex(b::GSubArray) = view(b.x.x, b.range.start[]:b.range.stop[])
Base.setindex!(b::GSubArray, val) = view(b.x.x, b.range.start[]:b.range.stop[]) .= val
Base.setindex!(arr::AbstractVarArray, val, i) = @inbounds arr[][i[]] = val

struct ArrayElem{T,Tp,A<:AbstractVarArray{T}} <: AbstractVar{T}
    x::A
    i::Tp
end

Var(x::AbstractVarArray, i) = ArrayElem(x[], i)
Base.setindex!(b::ArrayElem{T}, x) where T = (@inbounds b.x[][b.i[]] = x; b)
Base.setindex!(b::ArrayElem{T,<:Tuple}, x) where T = (@inbounds b.x[][getindex.(b.i)...] = x; b)
Base.setindex!(b::ArrayElem{T, <:CartesianIndex}, x) where T = (@inbounds b.x[][getindex.(b.i.I)...] = x; b)
Base.getindex(b::ArrayElem) = b.x[][b.i[]]
Base.getindex(b::ArrayElem{<:Any, <:Tuple}) = @inbounds b.x[][getindex.(b.i)...]
Base.getindex(b::ArrayElem{<:Any, <:CartesianIndex}) = @inbounds b.x[][getindex.(b.i.I)...]
Base.copy(b::ArrayElem) = ArrayElem(copy(b.x), copy(b.i))

safe_readvar(var::Nothing) = nothing
safe_readvar(var::Var) = var[]
safe_readvar(var::VarArray) = var.x

function Base.summary(io::IO, x::Var)
    print(io, "Var(...$(string(objectid(x))[end-4:end]))")
end

function Base.summary(io::IO, x::ArrayElem)
    print(io, "ArrayElem($(size(x.x.x)...), ...$(string(objectid(x.i))[end-4:end]))")
end

function Base.summary(io::IO, x::Nothing)
    print(io, "nothing")
end

Base.iszero(x::Var) = iszero(x[])
Base.zero(x::Var) = Var(zero(x[]))
Base.zero(::Type{Var{T}}) where T = Var(zero(T))
Base.getindex(x::String) = x

macro deanc(ex)
    @match ex begin
        :($x::$tp) => :(@invcheck $(esc(esc(x))) ≈ Var(zero($tp)))
        _ => error("please use like `@deanc x::T`")
    end
end

macro anc(ex)
    @match ex begin
        :($x::$tp) => :($(esc(x)) = Var(zero($tp)))
        _ => error("please use like `@anc x::T`")
    end
end

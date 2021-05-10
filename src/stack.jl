export FastStack, GLOBAL_STACK, FLOAT64_STACK, FLOAT32_STACK, COMPLEXF64_STACK, COMPLEXF32_STACK, BOOL_STACK, INT64_STACK, INT32_STACK

const GLOBAL_STACK = []

struct FastStack{T}
    data::Vector{T}
    top::Base.RefValue{Int}
end

function FastStack{T}(n::Int) where T
    FastStack{T}(Vector{T}(undef, n), Ref(0))
end

function FastStack(n::Int) where T
    FastStack{Any}(Vector{Any}(undef, n), Ref(0))
end

Base.show(io::IO, x::FastStack{T}) where T = print(io, "FastStack{$T}($(x.top[])/$(length(x.data)))")
Base.show(io::IO, ::MIME"text/plain", x::FastStack{T}) where T = show(io, x)
Base.length(stack::FastStack) = stack.top[]
Base.empty!(stack::FastStack) = (stack.top[] = 0; stack)

@inline function Base.push!(stack::FastStack, val)
    stack.top[] += 1
    @boundscheck stack.top[] <= length(stack.data) || throw(BoundsError(stack, stack.top[]))
    stack.data[stack.top[]] = val
    return stack
end

@inline function Base.pop!(stack::FastStack)
    @boundscheck stack.top[] > 0 || throw(BoundsError(stack, stack.top[]))
    val = stack.data[stack.top[]]
    stack.top[] -= 1
    return val
end

# default stack size is 10^6 (~8M for Float64)
let
    empty_exprs = Expr[:($empty!($GLOBAL_STACK))]
    for DT in [:Float64, :Float32, :ComplexF64, :ComplexF32, :Int64, :Int32, :Bool]
        STACK = Symbol(uppercase(String(DT)), :_STACK)
        @eval const $STACK = FastStack{$DT}(1000000)
        # allow in-stack and out-stack different, to support loading data to GVar.
        push!(empty_exprs, Expr(:call, empty!, STACK))
    end
    @eval function empty_global_stacks!()
        $(empty_exprs...)
    end
end

"""
    loaddata(t, x)

load data `x`, matching type `t`.
"""
loaddata(::Type{T}, x::T) where T = x
loaddata(::Type{T1}, x::T) where {T1,T} = convert(T1,x)
loaddata(::T1, x::T) where {T1,T} = loaddata(T1, x)
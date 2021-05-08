export FastStack

const GLOBAL_STACK = []

struct FastStack{T}
    data::Vector{T}
    top::Base.RefValue{Int}
end

function FastStack{T}(n::Int) where T
    FastStack{T}(zeros(T, n), Ref(0))
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
    for DT in [:Float64, :Float32, :ComplexF64, :ComplexF32, :Int64, :Int32, :Bool, :UInt8]
        STACK = Symbol(:GLOBAL_STACK_, DT)
        @eval const $STACK = FastStack{$DT}(1000000)
        @eval select_stack(::$DT) = $STACK
        push!(empty_exprs, Expr(:call, empty!, STACK))
    end
    @eval function empty_global_stacks!()
        $(empty_exprs...)
    end
end

"""
    loaddata(T, x)

load data from stack, matching target type `T`.
"""
loaddata(::Type{T}, x::T) where T = x
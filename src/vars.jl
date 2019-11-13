export @newvar, @push, @pop, @newreg, @newfloats
export @anc, @deanc
export Var

const A_STACK = []
const B_STACK = []
const GLOBAL_INFO = Dict{Any,Any}()

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
Base.copy(b::Var) = Var(b.x)

macro deanc(ex)
    @match ex begin
        :($x::$tp) => :(@invcheck $(esc(x)) ≈ zero($tp))
        _ => error("please use like `@deanc x::T`")
    end
end

macro anc(ex)
    @match ex begin
        :($x::$tp) => :($(esc(x)) = zero($tp))
        _ => error("please use like `@anc x::T`")
    end
end

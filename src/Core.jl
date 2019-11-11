# Properties
export isreversible, isreflexive, isprimitive
isreversible(f) = false
isreflexive(f) = false
isprimitive(f) = false

######## Inv
export Inv
struct Inv{FT} <: Function
    f::FT
end
Inv(f::Inv) = f.f
isreversible(::Inv) = true
Base.:~(f::Function) = Inv(f)
Base.show(io::IO, b::Inv) = print(io, "~$(b.f)")
Base.display(bf::Inv) where f = print(bf)

######## Grad
export Grad
struct Grad{FT} <: Function
    f::FT
end
isreversible(::Grad) = true
Base.adjoint(f::Function) = Grad(f)
Base.show(io::IO, b::Grad) = print(io, "$(b.f)'")
Base.display(bf::Grad) where f = print(bf)

######## Conditional apply
export conditioned_apply, @maybe

"""excute if and only if arguments are not nothing"""
macro maybe(ex)
    @match ex begin
        :($fname($(args...))) => begin
            args = Expr(:tuple, esc.(args)...)
            :(conditioned_apply($fname, $args, $args))
        end
    end
end

@generated function conditioned_apply(f, args, cargs)
    if any(x->x<:Nothing, cargs.parameters)
        return :(nothing)
    else
        return quote
            f(args...)
        end
    end
end

######### Infer
export ⊕, ⊖

"""
accumulate result into x.
"""
⊕(f, out!::Reg, args...) = out![] += f(getindex.(args)...)
⊖(f, out!::Reg, args...) = out![] -= f(getindex.(args)...)

accum(x::Reg, val) = x[] -= val
acumm(x::AbstractArray, val) = x .+= val
decum(x::Reg, val) = x[] -= val
decum(x::AbstractArray, val) = x .-= val

Base.:~(::typeof(⊕)) = ⊖
Base.:~(::typeof(⊖)) = ⊕
Base.display(::typeof(⊕)) = print("⊕")
Base.show(io::IO, ::typeof(⊕)) = print(io, "⊕")
Base.display(::typeof(⊖)) = print("⊖")
Base.show(io::IO, ::typeof(⊖)) = print(io, "⊖")
isreversible(::typeof(⊕)) = true
isreversible(::typeof(⊖)) = true

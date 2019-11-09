export isreversible, isreflexive
export @dual, @selfdual, Inv
export ⊕, ⊖, infer
export conditioned_apply, @maybe

isreversible(f) = false
isreflexive(f) = false
struct Inv{FT} <: Function
    f::FT
end
Inv(f::Inv) = f.f
isreversible(::Inv) = true
(f::Inv)(args...) = f.f(args...)

Base.:~(f::Function) = Inv(f)
Base.show(io::IO, b::Inv) = print(io, "~$(b.f)")
Base.display(bf::Inv) where f = print(bf)

"""
accumulate result into x.
"""
infer(f, out!::Reg, args...) = out![] += f(getindex.(args)...)
inv_infer(f, out!::Reg, args...) = out![] -= f(getindex.(args)...)

accum(x::Reg, val) = x[] -= val
acumm(x::AbstractArray, val) = x .+= val
decum(x::Reg, val) = x[] -= val
decum(x::AbstractArray, val) = x .-= val

const ⊕ = infer
const ⊖ = inv_infer
Base.:~(::typeof(⊕)) = ⊖
Base.:~(::typeof(⊖)) = ⊕
Base.display(::typeof(⊕)) = print("⊕")
Base.show(io::IO, ::typeof(⊕)) = print(io, "⊕")
Base.display(::typeof(⊖)) = print("⊖")
Base.show(io::IO, ::typeof(⊖)) = print(io, "⊖")
isreversible(::typeof(infer)) = true

"""
define dual instructions

TODO: check address conflicts!
"""
macro dual(ex)
    @match ex begin
        :($fline; function $f($(args...)) $(body...) end; $invfline;
            function $invf($(invargs...)) $(invbody...)end) => begin
            if length(args) != length(invargs)
                return :(error("forward and reverse function arguments should be the same! got $args and $invargs"))
            end
            :(
            function $(esc(f))($(args...)) $(body...) end;
            function $(esc(invf))($(invargs...)) $(invbody...) end;
            $(esc(:(NiLangCore.isreversible)))(::typeof($(esc(f)))) = true;
            $(esc(:(NiLangCore.isreversible)))(::typeof($(esc(invf)))) = true;
            Base.:~(::typeof($(esc(f)))) = $(esc(invf));
            Base.:~(::typeof($(esc(invf)))) = $(esc(f))
            )
        end
    end
end

"""define a self-dual instruction"""
macro selfdual(ex)
    @match ex begin
        :($fline; function $f($(args...)) $(body...) end) =>
        :(
            function $(esc(f))($(args...)) $(body...) end;
            $(esc(:(NiLangCore.isreversible)))(::typeof($(esc(f)))) = true;
            $(esc(:(NiLangCore.isreflexive)))(::typeof($(esc(f)))) = true;
            Base.:~(::typeof($(esc(f)))) = $(esc(f))
        )
    end
end

"""excute if and only if arguments are not nothing"""
macro maybe(ex)
    res = @capture $fname($(args...)) ex
    args = Expr(:tuple, esc.(res[:args])...)
    quote
        conditioned_apply($(res[:fname]), $args, $args)
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

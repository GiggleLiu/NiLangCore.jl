export Grad
struct Grad{FT} <: Function
    f::FT
end
Base.adjoint(f::Function) = Grad(f)
Base.show(io::IO, b::Grad) = print(io, "$(b.f)'")
Base.display(bf::Grad) where f = print(bf)
Inv(f::Grad) = Grad(~f.f)
#Grad(f::Inv) = Inv(f.f')

# TODO: make `iloss` kwargs
@i function (g::Grad)(args...)
    g.f(args...)
    GVar.(args)
    for i=1:length(args)
        if (args[i] isa GVar{<:Loss}, ~)
            grad(args[i]) ⊕ 1.0
        end
    end
    (~g.f)(args...)
end

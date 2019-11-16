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
@i function (g::Grad)(iloss::Int, args...)
    g.f(args...)
    @safe println(args)
    GVar.(args)
    @safe println(args)
    grad(args[iloss]) ⊕ 1.0
    @safe println(~g.f, args...)
    (~g.f)(args...)
    @safe println(g.f, args...)
end

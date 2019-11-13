export Grad
struct Grad{FT} <: Function
    f::FT
end
isreversible(::Grad) = true
Base.adjoint(f::Function) = Grad(f)
Base.show(io::IO, b::Grad) = print(io, "$(b.f)'")
Base.display(bf::Grad) where f = print(bf)
Inv(f::Grad) = Grad(~f.f)
#Grad(f::Inv) = Inv(f.f')

@i function (g::Grad)(args, loss)
    println(g.f, args...)
    g.f(args...)
    @gradalloc args
    grad(loss) + 1
    (~g.f)(args...)
end

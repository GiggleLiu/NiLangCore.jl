using Zygote

f(x, y) = (x+exp(y), y)
invf(x, y) = (x-exp(y), y)

# ∂L/∂x2 = ∂L/∂x1*∂x1/∂x2 + ∂L/∂y1*∂y1/∂y2 = ∂L/∂x1*invf'(x2) + ∂L/∂y1*invf'(y2)
x1, y1 = 1.4, 4.4
x2, y2 = f(x,y)
function gf(x, y, gx, gy)
    x2, y2 = f(x, y)
    invJ1 = gradient((x2, y2)->invf(x2, y2)[1], x2, y2)
    invJ2 = gradient((x2, y2)->invf(x2, y2)[2], x2, y2)
    return (x2, y2, gx, gy)
end

gradient((x, y)->invf(x, y)[1], x, y)

mutable struct A{T}
    x::T
end

Base.:*(x1::A, x2::A) = A(x1.x*x2.x)
Base.:+(x1::A, x2::A) = A(x1.x+x2.x)
Base.zero(::A{T}) where T = A(T(0))

struct A2{T}
    x::T
end

Base.:*(x1::A2, x2::A2) = A2(x1.x*x2.x)
Base.:+(x1::A2, x2::A2) = A2(x1.x+x2.x)
Base.zero(::A2{T}) where T = A2(T(0))

struct BG{T}
    x::T
    g::B{T}
    BG(x::T) where T = new{T}(x)
end

struct BG{T}
    x::T
    g::BG{T}
    BG(x::T) where T = new{T}(x)
end

mutable struct AG{T}
    x::T
    g::AG{T}
    AG(x::T) where T = new{T}(x)
    AG(x::T, g::TG) where {T,TG} = new{T}(x, T(g))
end
Base.:*(x1::AG, x2::AG) = AG(x1.x*x2.x)
Base.:+(x1::AG, x2::AG) = AG(x1.x+x2.x)
Base.zero(::AG{T}) where T = AG(T(0))
init(ag::AG{T}) where T = (ag.g = AG(T(0)))

using BenchmarkTools
ma = fill(A(1.0), 100,100)
ma2 = fill(A2(1.0), 100,100)
function f(ma, mb)
    M, N, K = size(ma, 1), size(mb, 2), size(ma, 2)
    res = fill(zero(ma[1]), M, N)
    for i=1:M
        for j=1:N
            for k=1:K
                @inbounds res[i,j] += ma[i,k]*mb[k,j]
            end
        end
    end
    return res
end

@benchmark f(ma, ma)
@benchmark f(ma2, ma2)
ma = fill(AG(1.0), 100,100)
@benchmark ma*ma

a = A(0.4)
ag = AG(0.4)
using NiLangCore
@benchmark isdefined($ag, :g)
@benchmark $ag + $ag
ag.g = AG(0.0)
@benchmark $a + $a

struct SG{T}
    x::T
    g::Ref{T}
    SG(x::T) where T = new{T}(x)
end
Base.:*(x1::SG, x2::SG) = SG(x1.x*x2.x)
Base.:+(x1::SG, x2::SG) = SG(x1.x+x2.x)
Base.zero(::SG{T}) where T = SG(T(0))
init(ag::AG{T}) where T = (ag.g = AG(T(0)))

using BenchmarkTools
ma = fill(SG(1.0), 100,100)
@benchmark ma*ma

a = A(0.4)
ag = AG(0.4)
using NiLangCore
@benchmark isdefined($ag, :g)
@benchmark $ag + $ag
ag.g = AG(0.0)
@benchmark $a + $a

using NiLangCore, NiLangCore.ADCore
@i function test(x, one, N::Int)
    for i = 1:N
        x ⊕ one
    end
end

invcheckon(true)
@benchmark test'(Loss(0.0), 1.0, 1000000)

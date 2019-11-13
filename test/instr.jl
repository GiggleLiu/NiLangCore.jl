using NiLangCore
using NiLangCore: interpret_ex, dual_ex, precom_ex

using Test
import Base: +, -, xor

@dual begin
    function +(a!::Reg, b)
        # check address conflict, a, b should be different.
        a![] += b[]
    end

    function -(a!::Reg, b)
        a![] -= b[]
    end
end

@i function -(a!::GVar, b)
    -(val(a!), val(b))
    @maybe grad(b) + grad(a!)
end

@selfdual begin
    function xor(a!::Reg, b)
        a![] = xor(a![], b[])
    end
end
#@nograd xor

@i function (_::typeof(⊕(*)))(out!::GVar, x, y)
    out! ⊖ x * y
    @maybe grad(x) ⊕ grad(out!) * grad(y)
    @maybe grad(y) ⊕ grad(x) * grad(out!)
end

@testset "@dual" begin
    @test isreversible(+)
    @test isreversible(-)
    @test !isreflexive(+)
    @test ~(+) == -
    @newvar a=2.0
    @newvar b=1.0
    a + b
    @test a[] == 3.0
    a - b
    @test a[] == 2.0
    check_inv(+, (a, b))
    check_grad(+, (a, b), loss=a)
    @test isprimitive(+)
    @test isprimitive(-)
    @test nargs(+) == 2
    @test nargs(-) == 2
end

@testset "@selfdual" begin
    @test isreversible(xor)
    @test isreflexive(xor)
    @test isprimitive(xor)
    @test nargs(xor) == 2
    @test ~(xor) == xor
    @newvar a=2
    @newvar b=1
    a ⊻ b
    @test a[] == 3
    a ⊻ b
    @test a[] == 2
    @newvar aδ = 1.0
    @newvar bδ = 1.0
end

@testset "interpret_ex" begin
    info = ()
    @test interpret_ex(:(f(x, y)), info) == :(f(x, y))
    @test interpret_ex(precom_ex(:(out ⊕ (x + y)), info), info) == :(⊕(+)(out, x, y))
    @test interpret_ex(:(x .+ y), info) == :(x .+ y)
    @test interpret_ex(:(f.(x, y)), info) == :(f.(x, y))
    @test interpret_ex(precom_ex(:(out .⊕ (x .+ y)), info), info) == :(⊕(+).(out, x, y))
    @test interpret_ex(precom_ex(:(out .⊕ swap.(x, y)), info), info) == :(⊕(swap).(out, x, y))
end

@testset "dual_ex" begin
    @test dual_ex(:(⊕(+)(out, x, y))) == :(⊖(+)(out, x, y))
    @test dual_ex(:(x .+ y)) == :((x .- y))
    @test dual_ex(:((+).(x, y))) == :((-).(x, y))
    @test dual_ex(:(⊕(+).(out, x, y))) == :(⊖(+).(out, x, y))
    @test dual_ex(:(⊕(xor).(out, x, y))) == :(⊖(xor).(out, x, y))
end

@testset "⊕" begin
    x = Var(1.0)
    y = Var(1.0)
    ⊕(exp)(y, x)
    @test x[] ≈ 1
    @test y[] ≈ 1+exp(1.0)
    (~⊕(exp))(y, x)
    @test x[] ≈ 1
    @test y[] ≈ 1
end

@testset "maybe" begin
    x = 1
    y = 2
    @test conditioned_apply(+, (x, y), (x, y)) == 3
    @test (@maybe x + y) == 3
    x = nothing
    @test (@maybe x + y) == nothing

    a = Var(0.3)
    @test check_grad(+, (a, 1.0), loss=a)
end

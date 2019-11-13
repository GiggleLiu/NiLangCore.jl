using NiLangCore
using NiLangCore: interpret_ex, dual_ex, precom_ex

using Test
import Base: +, -
import NiLangCore: ⊕, ⊖

@dual begin
    function ⊕(a!, b)
        a! + b, b
    end
    function ⊖(a!, b)
        a! - b, b
    end
end

@i function ⊖(a!::GVar, b)
    val(a!) ⊖ val(b)
    @maybe grad(b) ⊕ grad(a!)
end

@selfdual begin
    function XOR(a!, b)
        xor(a!, b), b
    end
end
#@nograd XOR

@i function (_::OMinus{typeof(*)})(out!::GVar, x, y)
    out! ⊖ x * y
    @maybe grad(x) ⊕ grad(out!) * grad(y)
    @maybe grad(y) ⊕ grad(x) * grad(out!)
end

@testset "@dual" begin
    @test isreversible(⊕)
    @test isreversible(⊖)
    @test !isreflexive(⊕)
    @test ~(⊕) == ⊖
    a=2.0
    b=1.0
    @instr a ⊕ b
    @test a == 3.0
    @instr a ⊖ b
    @test a == 2.0
    check_inv(⊕, (a, b))
    check_grad(⊕, (a, b), loss=a)
    @test isprimitive(⊕)
    @test isprimitive(⊖)
    @test nargs(⊕) == 2
    @test nargs(⊖) == 2
end

@testset "@selfdual" begin
    @test isreversible(XOR)
    @test isreflexive(XOR)
    @test isprimitive(XOR)
    @test nargs(XOR) == 2
    @test ~(XOR) == XOR
    a=2
    b=1
    @instr XOR(a, b)
    @test a == 3
    @instr XOR(a, b)
    @test a == 2
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
    #@test dual_ex(:(x .⊕ y)) == :((x .(~(⊕)) y))
    @test dual_ex(:((+).(x, y))) == :((~(+)).(x, y))
    @test dual_ex(:(⊕(+).(out, x, y))) == :(⊖(+).(out, x, y))
    @test dual_ex(:(⊕(XOR).(out, x, y))) == :(⊖(XOR).(out, x, y))
end

@testset "⊕" begin
    x = 1.0
    y = 1.0
    @instr ⊕(exp)(y, x)
    @test x ≈ 1
    @test y ≈ 1+exp(1.0)
    @instr (~⊕(exp))(y, x)
    @test x[] ≈ 1
    @test y[] ≈ 1
end

@testset "maybe" begin
    x = 1
    y = 2
    @test conditioned_apply(⊕, (x, y), (x, y)) == 3
    @test (@maybe (x, y) = ⊕(x, y))[1] == 3
    x = nothing
    @test (@maybe (x, y) = x ⊕ y) == nothing

    a = Var(0.3)
    @test check_grad(+, (a, 1.0), loss=a)
end

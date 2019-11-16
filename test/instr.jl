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

@i function ⊖(a!::GVar, b::GVar)
    a!.x ⊖ b.x
    b.g ⊕ a!.g
end

@i function ⊖(a!, b::GVar)
    a! ⊖ b.x
end

@i function ⊖(a!::GVar, b)
    a!.x ⊖ b
end

@selfdual begin
    function XOR(a!, b)
        xor(a!, b), b
    end
end
#@nograd XOR

@i function (_::OMinus{typeof(*)})(out!::GVar, x::GVar, y::GVar)
    out!.x ⊖ x.x * y.x
    x.g ⊕ out!.g * y.g
    y.g ⊕ x.g * out!.g
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
    args = (1,2)
    @instr ⊕(args...)
    @test args == (3,2)
    @instr a ⊖ b
    @test a == 2.0
    @test check_inv(⊕, (a, b))
    @test check_grad(⊕, (Loss(a), b))
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

#=
@testset "interpret_ex" begin
    info = ()
    @test interpret_ex(:(f(x, y)), info) == :(@instr f(x, y))
    @test interpret_ex(precom_ex(:(out ⊕ (x + y)), info), info) == :(@instr ⊕(+)(out, x, y))
    @test interpret_ex(:(x .+ y), info) == :(@instr x .+ y)
    @test interpret_ex(:(f.(x, y)), info) == :(@instr f.(x, y))
    @test interpret_ex(precom_ex(:(out .⊕ (x .+ y)), info), info) == :(@instr ⊕(+).(out, x, y))
    @test interpret_ex(precom_ex(:(out .⊕ swap.(x, y)), info), info) == :(@instr ⊕(swap).(out, x, y))
end
=#

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
    @test x ≈ 1
    @test y ≈ 1
end

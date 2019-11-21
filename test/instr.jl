using NiLangCore
using NiLangCore: interpret_ex, dual_ex, precom_ex

using Test
import Base: +, -
import NiLangCore: ⊕, ⊖

function ⊕(a!, b)
    @assign val(a!) val(a!) + val(b)
    a!, b
end
function ⊖(a!, b)
    @assign val(a!) val(a!) - val(b)
    a!, b
end
const _add = ⊕
const _sub = ⊖
@dual _add _sub
@ignore ⊕(a!::Nothing, b)
@ignore ⊕(a!::Nothing, b::Nothing)
@ignore ⊕(a!, b::Nothing)

function XOR(a!::T, b) where T
    @assign a! xor(a!, b)
    T(a!), b
end
@selfdual XOR
#@nograd XOR

@testset "ignore" begin
    @test nothing ⊕ 3 == (nothing, 3)
    @test nothing ⊕ nothing == (nothing, nothing)
    @test 3 ⊕ nothing == (3, nothing)
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
    @test isprimitive(⊕)
    @test isprimitive(⊖)
end

@testset "@selfdual" begin
    @test isreversible(XOR)
    @test isreflexive(XOR)
    @test isprimitive(XOR)
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

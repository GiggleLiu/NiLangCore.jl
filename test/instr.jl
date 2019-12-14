using NiLangCore
using NiLangCore: interpret_ex, dual_ex, precom_ex

using Test
import Base: +, -
import NiLangCore: ⊕, ⊖

function add(a!, b)
    @assign val(a!) val(a!) + val(b)
    a!, b
end
function sub(a!, b)
    @assign val(a!) val(a!) - val(b)
    a!, b
end
@dual add sub

function XOR(a!::T, b) where T
    @assign a! xor(a!, b)
    T(a!), b
end
@selfdual XOR
#@nograd XOR

@testset "@dual" begin
    @test isreversible(add)
    @test isreversible(sub)
    @test !isreflexive(add)
    @test ~(add) == sub
    a=2.0
    b=1.0
    @instr add(a, b)
    @test a == 3.0
    args = (1,2)
    @instr add(args...)
    @test args == (3,2)
    @instr sub(a, b)
    @test a == 2.0
    @test check_inv(add, (a, b))
    @test isprimitive(add)
    @test isprimitive(sub)
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

@testset "+= and const" begin
    x = 0.5
    @instr x ⊕ π
    @test x == 0.5+π
    @instr x += log(π)
    @test x == 0.5 + π + log(π)
    @instr x ⊕ log(π)/2
    @test x == 0.5 + π + 3*log(π)/2
    @instr x ⊕ log(2*π)/2
    @test x == 0.5 + π + 3*log(π)/2 + log(2π)/2
end

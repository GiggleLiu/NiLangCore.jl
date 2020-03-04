using NiLangCore
using NiLangCore: compile_ex, dual_ex, precom_ex

using Test
import Base: +, -
import NiLangCore: ⊕, ⊖

function add(a!::Number, b::Number)
    a!+b, b
end

@i function add(a!, b)
    add(value(a!), value(b))
end

function sub(a!::Number, b::Number)
    a!-b, b
end

@i function sub(a!, b)
    sub(value(a!), value(b))
end

@dual add sub

function XOR(a!::Number, b::Number) where T
    xor(a!, b), b
end

@i function XOR(a!::T, b) where T
    XOR(value(a!), value(b))
end
@selfdual XOR
#@nograd XOR

@testset "boolean" begin
    x = false
    @instr x ⊻= identity(true)
    @test x
    @instr x ⊻= true || false
    @test !x
    @instr x ⊻= true && false
    @instr x ⊻= !false
    @test x
end

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
@testset "compile_ex" begin
    info = ()
    @test compile_ex(:(f(x, y)), info) == :(@instr f(x, y))
    @test compile_ex(precom_ex(:(out ⊕ (x + y)), info), info) == :(@instr ⊕(+)(out, x, y))
    @test compile_ex(:(x .+ y), info) == :(@instr x .+ y)
    @test compile_ex(:(f.(x, y)), info) == :(@instr f.(x, y))
    @test compile_ex(precom_ex(:(out .⊕ (x .+ y)), info), info) == :(@instr ⊕(+).(out, x, y))
    @test compile_ex(precom_ex(:(out .⊕ swap.(x, y)), info), info) == :(@instr ⊕(swap).(out, x, y))
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

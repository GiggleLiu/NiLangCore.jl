using NiLangCore
using NiLangCore: compile_ex, dual_ex, grad_ex

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

@adjoint function (+)'(a!::Reg, b, aδ, bδ!)
    -(a!, b)
    @maybe bδ! + aδ
end

@selfdual begin
    function xor(a!::Reg, b)
        a![] = xor(a![], b[])
    end
end
@nograd xor

@i function (F::typeof((⊕)'))(f::typeof(*), out!::Reg, x, y, outδ, xδ!, yδ!)
    out! ⊖ x * y
    @maybe xδ! ⊕ outδ * y
    @maybe yδ! ⊕ x * outδ
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
    (⊻)'(a, b, aδ, bδ)
    @test a[] == 3
    @test aδ[] == 1
    @test bδ[] == 1
end

@testset "compile_ex" begin
    info = ()
    @test compile_ex(:(f(x, y)), info) == :($(esc(:f))(x, y))
    @test compile_ex(:(out ⊕ (x + y)), info) == :(⊕(+, out, x, y))
    @test compile_ex(:(x .+ y), info) == :($(esc(:.+))(x, y))
    @test compile_ex(:(f.(x, y)), info) == :(f.(x, y))
    @test compile_ex(:(out .⊕ (x .+ y)), info) == :((⊕).(+, out, x, y))
    @test compile_ex(:(out .⊕ swap.(x, y)), info) == :((⊕).(swap, out, x, y))
end

@testset "dual_ex" begin
    @test dual_ex(:(out ⊕ (x + y))) == :(out ⊖ (x + y))
    @test dual_ex(:(x .+ y)) == :((x .- y))
    @test dual_ex(:((+).(x, y))) == :((-).(x, y))
    @test dual_ex(:(out .⊕ (x .+ y))) == :(out .⊖ (x .+ y))
    @test dual_ex(:(out .⊕ xor.(x, y))) == :(out .⊖ xor.(x, y))
end

@testset "grad_ex" begin
    info = Dict(:x=>:gx, :y=>:gy, :out=>:gout)
    @test grad_ex(:(out ⊕ (x + y)), info) == :(Grad{typeof(⊕)}(⊕)(+, out, x, y, gout, gx, gy))
    @test grad_ex(:(x .+ y), info) == :(Grad{typeof(+)}(+).(x, y, gx, gy))
    @test grad_ex(:(out .⊕ (x .+ y)), info) == :(Grad{typeof(⊕)}(⊕).(+, out, x, y, gout, gx, gy))
    @test grad_ex(:(out .⊕ swap.(x, y)), info) == :(Grad{typeof(⊕)}(⊕).(swap, out, x, y, gout, gx, gy))
end

@testset "⊕" begin
    x = Ref(1.0)
    y = Ref(1.0)
    ⊕(exp, y, x)
    @test x[] ≈ 1
    @test y[] ≈ 1+exp(1.0)
    (~⊕)(exp, y, x)
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
end

using NiLangCore
using NiLangCore: compile_ex, dual_ex

using Test

@dual begin
    function Base.:+(a!::Reg, b)
        # check address conflict, a, b should be different.
        a![] += b[]
    end

    function Base.:-(a!::Reg, b)
        a![] -= b[]
    end
end

@adjoint function (+)'(a!::Reg, b, aδ, bδ!)
    -(a!, b)
    @maybe bδ! + aδ
end

@selfdual begin
    function Base.xor(a!::Reg, b)
        a![] = xor(a![], b[])
    end
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
end

@testset "@selfdual" begin
    @test isreversible(xor)
    @test isreflexive(xor)
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
    @test compile_ex(:(f(x, y)), info) == :(f(x, y))
    @test compile_ex(:(out ⊕ (x + y)), info) == :(infer(+, out, x, y))
    @test compile_ex(:(x .+ y), info) == :(x .+ y)
    @test compile_ex(:(f.(x, y)), info) == :(f.(x, y))
    @test compile_ex(:(out .⊕ (x .+ y)), info) == :(infer.(+, out, x, y))
    @test compile_ex(:(out .⊕ swap.(x, y)), info) == :(infer.(swap, out, x, y))
end

@testset "dual_ex" begin
    @test dual_ex(:(f(x, y))) == :((~f)(x, y))
    @test dual_ex(:(out ⊕ (x + y))) == :(out ⊖ (x + y))
    @test dual_ex(:(x .+ y)) == :((~+).(x, y))
    @test dual_ex(:(f.(x, y))) == :((~f).(x, y))
    @test dual_ex(:(out .⊕ (x .+ y))) == :(out .⊖ (x .+ y))
    @test dual_ex(:(out .⊕ swap.(x, y))) == :(out .⊖ swap.(x, y))
end

@testset "grad_ex" begin
    info = Dict(:x=>:gx, :y=>:gy, :out=>:gout)
    #=
    info.stage = :BG
    @test dual_ex(:(f(x, y)), info) == :((f')(x, y, gx, gy))
    @test dual_ex(:(out ⊕ (x + y)), info) == :((⊕)'(+, out, x, y, gout, gx, gy))
    @test dual_ex(:(x .+ y), info) == :((+)'.(x, y, gx, gy))
    @test dual_ex(:(f.(x, y)), info) == :((f').(x, y, gx, gy))
    @test dual_ex(:(out .⊕ (x .+ y)), info) == :((⊕)'.(+, out, x, y, gout, gx, gy))
    @test dual_ex(:(out .⊕ swap.(x, y)), info) == :((⊕)'.(swap, out, x, y, gout, gx, gy))
    info.stage = :FG
    @test dual_ex(:(f(x, y)), info) == :((~f')(x, y, gx, gy))
    @test dual_ex(:(out ⊕ (x + y)), info) == :((~(⊕)')(+, out, x, y, gout, gx, gy))
    @test dual_ex(:(x .+ y), info) == :((~(+)').(x, y, gx, gy))
    @test dual_ex(:(f.(x, y)), info) == :((~f').(x, y, gx, gy))
    @test dual_ex(:(out .⊕ (x .+ y)), info) == :((~(⊕)').(+, out, x, y, gout, gx, gy))
    @test dual_ex(:(out .⊕ swap.(x, y)), info) == :((~(⊕)').(swap, out, x, y, gout, gx, gy))
    =#
end

@testset "infer" begin
    x = Ref(1.0)
    y = Ref(1.0)
    infer(exp, y, x)
    @test x[] ≈ 1
    @test y[] ≈ 1+exp(1.0)
    (~infer)(exp, y, x)
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

using NiLangCore
using NiLangCore: type2tuple
using Test

struct NiTypeTest{T} <: RevType
    x::T
    g::T
end
NiTypeTest(x) = NiTypeTest(x, zero(x))
@fieldview NiLangCore.value(invtype::NiTypeTest) = invtype.x
@fieldview gg(invtype::NiTypeTest) = invtype.g

@testset "inv type" begin
    it = NiTypeTest(0.5)
    @test value(it) == 0.5
    @test chfield(it, value, 0.3) == NiTypeTest(0.3)
    it = chfield(it, Val(:g), 0.2)
    @test almost_same(NiTypeTest(0.5+1e-15), NiTypeTest(0.5))
    @test !almost_same(NiTypeTest(1.0), NiTypeTest(1))
    it = NiTypeTest(0.5)
    @test chfield(it, gg, 0.3) == NiTypeTest(0.5, 0.3)
end

struct CVar{T}
    x::T
    g::T
end

struct DVar{GT,CT,T}
    x::T
    k::CT
    g::GT
end
DVar{GT}(x, g) where GT = DVar(x, g, zero(GT))

# currently variable types can not be infered
@iconstruct function CVar(gg ← zero(xx), xx)
end

@iconstruct function DVar{Float64}(xx, gg ← zero(xx)) where {T}
    gg += identity(xx)
    CVar(gg)
end

@testset "revtype" begin
    @test type2tuple(CVar(1.0)) == (0.0, 1.0)
    @test CVar(0.5) == CVar(0.0, 0.5)
    @test (~CVar)(CVar(0.5)) == 0.5
    @test_throws InvertibilityError (~CVar)(CVar(0.5, 0.4))
    @test (~DVar{Float64})(DVar{Float64}(0.5)) == 0.5
end

struct PVar{T}
    g::T
    x::T
end

struct SVar{T}
    x::T
    g::T
end

@icast PVar(g, x) => SVar(x, k) begin
    g → zero(x)
    k ← zero(x)
    k += identity(x)
end

@icast x::Float64 => SVar(x, gg) begin
    gg ← zero(x)
    gg += identity(x)
end

@testset "@icast" begin
    @test PVar((SVar(PVar(0.0, 0.5)))) == PVar(0.0, 0.5)
    @test Float64(SVar(0.5)) == 0.5
    @i function test(x)
        (Float64=>SVar)(x)
    end
    @test test(0.5) == SVar(0.5)
    @test (~test)(test(0.5)) == 0.5
end

@i struct B{T}
    x::T
    g::T
    function B(x::T, g::T) where T
        new{T}(x, g)
    end
    # TODO: fix the type inference!
    @i function B(x::T) where T
        g ← zero(x)
        g += identity(1)
        x ← new{T}(x, g)
    end
end

@testset "reversible type" begin
    @test B(0.5) == B(0.5, 1.0)
    @test (~B)(B(0.5)) === 0.5
end

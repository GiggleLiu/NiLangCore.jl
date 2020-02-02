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
@iconstruct function CVar(xx, gg<=zero(xx))
end

@iconstruct function DVar{Float64}(xx, gg<=zero(xx)) where {T}
    gg += identity(xx)
    CVar(gg)
end

@testset "revtype" begin
    @test type2tuple(CVar(1.0)) == (1.0, 0.0)
    @test CVar(0.5) == CVar(0.5, 0.0)
    @test (~CVar)(CVar(0.5)) == 0.5
    @test_throws InvertibilityError (~CVar)(CVar(0.5, 0.4))
    @test (~DVar{Float64})(DVar{Float64}(0.5)) == 0.5
end

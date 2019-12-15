using NiLangCore
using Test

struct NiTypeTest{T} <: RevType
    x::T
    g::T
end
NiTypeTest(x) = NiTypeTest(x, zero(x))
NiLangCore.invkernel(invtype::NiTypeTest) = invtype.x
@fieldview NiLangCore.value(invtype::NiTypeTest) = invtype.x
@fieldview gg(invtype::NiTypeTest) = invtype.g

@testset "inv type" begin
    it = NiTypeTest(0.5)
    @test value(it) == 0.5
    @test chfield(it, value, 0.3) == NiTypeTest(0.3)
    @test (~NiTypeTest)(it) == 0.5
    it = chfield(it, Val(:g), 0.2)
    @test_throws InvertibilityError (~NiTypeTest)(it)
    @test almost_same(NiTypeTest(0.5+1e-15), NiTypeTest(0.5))
    @test !almost_same(NiTypeTest(1.0), NiTypeTest(1))
    it = NiTypeTest(0.5)
    @test chfield(it, gg, 0.3) == NiTypeTest(0.5, 0.3)
end

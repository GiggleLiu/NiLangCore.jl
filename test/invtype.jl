using NiLangCore
using Test

struct NiTypeTest{T} <: RevType
    x::T
    g::T
end
NiTypeTest(x) = NiTypeTest(x, zero(x))
NiLangCore.invkernel(invtype::NiTypeTest) = invtype.x

@testset "inv type" begin
    it = NiTypeTest(0.5)
    @test (~NiTypeTest)(it) == 0.5
    it = chfield(it, Val(:g), 0.2)
    @test_throws InvertibilityError (~NiTypeTest)(it)
    @test almost_same(NiTypeTest(0.5+1e-15), NiTypeTest(0.5))
    @test !almost_same(NiTypeTest(1.0), NiTypeTest(1))
end

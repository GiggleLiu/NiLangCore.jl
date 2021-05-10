using NiLangCore
using NiLangCore: type2tuple
using Test

struct NiTypeTest{T} <: IWrapper{T}
    x::T
    g::T
end
NiTypeTest(x) = NiTypeTest(x, zero(x))
@fieldview value(invtype::NiTypeTest) = invtype.x
@fieldview gg(invtype::NiTypeTest) = invtype.g

@testset "inv type" begin
    it = NiTypeTest(0.5)
    @test eps(typeof(it)) === eps(Float64)
    @test value(it) == 0.5
    @test it ≈ NiTypeTest(0.5)
    @test it > 0.4
    @test it < NiTypeTest(0.6)
    @test it < 7
    @test 0.4 < it
    @test 7 > it
    @test chfield(it, value, 0.3) == NiTypeTest(0.3)
    it = chfield(it, Val(:g), 0.2)
    @test almost_same(NiTypeTest(0.5+1e-15), NiTypeTest(0.5))
    @test !almost_same(NiTypeTest(1.0), NiTypeTest(1))
    it = NiTypeTest(0.5)
    @test chfield(it, gg, 0.3) == NiTypeTest(0.5, 0.3)
end

@testset "mutable struct set field" begin
    mutable struct MS{T}
        x::T
        y::T
        z::T
    end

    ms = MS(0.5, 0.6, 0.7)
    @i function f(ms)
        ms.x += 1
        ms.y += 1
        ms.z -= ms.x ^ 2
    end
    ms2 = f(ms)
    @test (ms2.x, ms2.y, ms2.z) == (1.5, 1.6, -1.55)

    struct IMS{T}
        x::T
        y::T
        z::T
    end

    ms = IMS(0.5, 0.6, 0.7)
    ms2 = f(ms)
    @test (ms2.x, ms2.y, ms2.z) == (1.5, 1.6, -1.55)
end

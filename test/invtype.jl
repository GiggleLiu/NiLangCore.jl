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

@i struct BVar{T}
    x::T
    function BVar{T}(x::T) where T
        new{T}(g, x)
    end
    # currently variable types can not be infered
    @i function BVar(xx::T) where T
        xx ← new{T}(xx)
    end
end

@i struct CVar{T}
    g::T
    x::T
    function CVar{T}(x::T, g::T) where T
        new{T}(x, g)
    end
    function CVar(x::T, g::T) where T
        new{T}(x, g)
    end
    # currently variable types can not be infered
    # TODO: fix the type inference!
    @i function CVar(xx::T) where T
        gg ← zero(xx)
        gg += identity(1)
        xx ← new{T}(gg, xx)
    end
end

@i struct DVar{GT,CT,T}
    x::T
    k::CT
    l
    @i function DVar{Float64}(xx::T) where {T}
        gg ← zero(xx)
        gg += identity(xx)
        ll ← zero(gg)
        xx ← new{Float64, typeof(gg), T}(xx, gg, ll)
    end
end

@testset "revtype" begin
    @test type2tuple(CVar(1.0)) == (1.0, 1.0)
    @test CVar(0.5) == CVar(1.0, 0.5)
    @test (~BVar)(BVar(0.5)) == 0.5
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
    @test convert(PVar, convert(SVar, PVar(0.0, 0.5))) == PVar(0.0, 0.5)
    @test convert(Float64, convert(SVar,0.5)) == 0.5
    @i function test(x)
        (Float64=>SVar)(x)
    end
    @test test(0.5) == convert(SVar, 0.5)
    @test (~test)(test(0.5)) == 0.5
    @i function test(x)
        (Float64=>SVar).(x)
    end
    @test test([0.5, 0.6]) == [convert(SVar,0.5), convert(SVar,0.6)]
    @test (~test)(test([0.5, 0.6])) == [0.5, 0.6]
end

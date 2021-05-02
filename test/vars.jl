using Test, NiLangCore
using NiLangCore: type2tuple

@testset "dataview" begin
    x = 1.0
    @test_throws ErrorException chfield(x, "asdf", 3.0)
    @test chfield(x, identity, 2.0) === 2.0
    @test value(x) === 1.0
    @assign (x |> value) 0.2
    @test x == 0.2
    @assign -x 0.1
    @test x == -0.1
    x = 1+2.0im
    @assign x' 0.1+1im
    @test x == 0.1-1im
    x = (3, 4)
    @instr (x.:1) += 3
    @test x == (6, 4)
    x = 3
    y = (4,)
    @instr x += y.:1
    @test x == 7
    x = [3, 4]
    y = ([4, 4],)
    @instr x .+= y.:1
    @test x == [7.0, 8.0]
    x = true
    y = (true,)
    @instr x ⊻= y.:1
    @test x == false
    x = [true, false]
    y = ([true, true],)
    @instr x .⊻= (y |> tget(1))
    @test x == [false, true]

    x = ones(4)
    y = ones(2)
    @instr (x |> subarray(1:2)) += y
    @test x == [2,2,1,1]
    @instr (x |> subarray(1)) += (y |> subarray(1))
    @test x == [3,2,1,1]
end

@testset "anc, deanc" begin
    @i function f(y)
        x ← y
        x → 1.0
    end
    f(1.0)
    @test_throws InvertibilityError f(1.1)

    @i function f2(y)
        x ← y
        x → (1.0, 2.0)
    end
    f2((1.0, 2.0))
    @test_throws InvertibilityError f2((1.1, 2.0))

    @i function f3(y)
        x ← y
        x → [1.0, 2.0]
    end
    f3([1.0, 2.0])
    @test_throws InvertibilityError f3([1.1, 2.0])

    struct B
        a
        b
    end
    @i function f4(y)
        x ← y
        x → B(1.0, 2.0)
    end
    f4(B(1.0, 2.0))
    @test_throws InvertibilityError f4(B(1.0, 1.1))

    @i function f5(y)
        x ← y
        x → ""
    end
    f5("")
    @test_throws InvertibilityError f5("a")
end

@testset "inv and tuple output" begin
    a, b = false, false
    @instr ~(a ⊻= true)
    @test a == true
    @instr ~((a, b) ⊻= (true, true))
    @test a == false
    @test b == true
    y = 1.0
    x = 1.0
    @instr ~(~(y += 1.0))
    @test y == 2.0
    @instr ~(~((x, y) += (1.0, 1.0)))
    @test y == 3.0
    @test x == 2.0
    @instr ~((x, y) += (1.0, 1.0))
    @test y == 2.0
    @test x == 1.0
    @instr ~(y += 1.0)
    @test y == 1.0

    z = [1.0, 2.0]
    @instr ~(~(z .+= [1.0, 2.0]))
    @test z ≈ [2.0, 4.0]
end

@testset "chfield" begin
    x = [1,2,3]
    @test chfield(x, length, 3) == x
    @test_throws InvertibilityError chfield(x, length, 2)
end

@testset "invcheck" begin
    @test (@invcheck 0.3 0.3) isa Any
    @test_throws InvertibilityError (@invcheck 0.3 0.4)
    @test_throws InvertibilityError (@invcheck 3 3.0)
end

@testset "partial" begin
    x = Partial{:im}(3+2im)
    println(x)
    @test x === Partial{:im,Complex{Int64},Int64}(3+2im)
    @test value(x) == 2
    @test chfield(x, value, 4) == Partial{:im}(3+4im)
    @test zero(x) == Partial{:im}(0.0+0.0im)
    @test (~Partial{:im})(x) == 3+2im
end

@testset "pure wrapper" begin
    @pure_wrapper A
    a = A(0.5)
    @test a isa A
    @test zero(a) == A(0.0)
    @test (~A)(a) === 0.5
    @test -A(0.5) == A(-0.5)

    a2 = A{Float64}(a)
    @test a2 === a
    println(a2)
    @test chfield(a2, A, A(0.4)) === 0.4
end

@testset ">, <" begin
    @pure_wrapper A
    a = A(0.5)
    @test unwrap(A(a)) == 0.5
    @test A(a) < 0.6
    @test A(a) <= 0.6
    @test A(a) >= 0.4
    @test a ≈ 0.5
    @test a == 0.5
    @test a > 0.4
    @test isless(a, 0.6)
end

@testset "dict" begin
    @i function f1()
        d ← Dict(1=>1, 2=>2)
        d → Dict(2=>2)
    end
    @i function f2()
        d ← Dict(1=>1)
        d → Dict(2=>1)
    end
    @i function f3()
        d ← Dict(1=>1)
        d → Dict(1=>2)
    end
    @i function f4()
        d ← Dict(1=>1)
        d → Dict(1=>1)
    end
    @test_throws InvertibilityError f1()
    @test_throws InvertibilityError f2()
    @test_throws InvertibilityError f3()
    @test f4() == ()
end

@testset "fieldview" begin
    @fieldview first_real(x::Vector{ComplexF64}) = x[1].re
    x = [1.0im, 2+3im]
    @instr (x |> first_real) += 3
    @test x == [3+1.0im, 2+3.0im]
end

struct NiTypeTest{T} <: IWrapper{T}
    x::T
    g::T
end
NiTypeTest(x) = NiTypeTest(x, zero(x))
@fieldview NiLangCore.value(invtype::NiTypeTest) = invtype.x
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
        gg += 1
        xx ← new{T}(gg, xx)
    end
end

@i struct DVar{GT,CT,T}
    x::T
    k::CT
    l
    @i function DVar{Float64}(xx::T) where {T}
        gg ← zero(xx)
        gg += xx
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
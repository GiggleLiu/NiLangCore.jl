using Test, NiLangCore
using NiLangCore: type2tuple

@testset "dataview" begin
    x = 1.0
    @test_throws ErrorException chfield(x, "asdf", 3.0)
    @test chfield(x, identity, 2.0) === 2.0
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
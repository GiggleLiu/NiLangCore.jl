using Test, NiLangCore

@testset "dataview" begin
    x = 1.0
    @assign value(x) 0.2
    @test x == 0.2
    @assign -x 0.1
    @test x == -0.1
    x = 1+2.0im
    @assign x' 0.1+1im
    @test x == 0.1-1im
    x = (3, 4)
    @test tget(x, 1) == 3
end

@testset "anc, deanc" begin
    @i function f(y)
        x ← y
        x → 1.0
    end
    f(1.0)
    @test_throws InvertibilityError f(1.1)

    @i function f(y)
        x ← y
        x → (1.0, 2.0)
    end
    f((1.0, 2.0))
    @test_throws InvertibilityError f((1.1, 2.0))

    @i function f(y)
        x ← y
        x → [1.0, 2.0]
    end
    f([1.0, 2.0])
    @test_throws InvertibilityError f([1.1, 2.0])
end

@testset "inv and tuple output" begin
    a, b = false, false
    @instr ~(a ⊻= identity(true))
    @test a == true
    @instr ~((a, b) ⊻= identity((true, true)))
    @test a == false
    @test b == true
    y = 1.0
    x = 1.0
    @instr ~(~(y += identity(1.0)))
    @test y == 2.0
    @instr ~(~((x, y) += identity((1.0, 1.0))))
    @test y == 3.0
    @test x == 2.0
    @instr ~((x, y) += identity((1.0, 1.0)))
    @test y == 2.0
    @test x == 1.0
    @instr ~(y += identity(1.0))
    @test y == 1.0

    z = [1.0, 2.0]
    @instr ~(~(z .+= identity.([1.0, 2.0])))
    @test z ≈ [2.0, 4.0]
end

@testset "chfield" begin
    x = [1,2,3]
    @test chfield(x, length, 3) == x
    @test_throws InvertibilityError chfield(x, length, 2)

    @test chfield((1,2,3), 3, 'k') == (1,2,'k')
    @test chfield((1,2,3), (3,), 'k') == (1,2,'k')
    @test chfield([1,2,3], 2, 4) == [1,4,3]
    @test chfield([1,2,3], (2,), 4) == [1,4,3]
    @test chfield(Ref(3), (), 4).x == Ref(4).x
end

@testset "invcheck" begin
    @test (@invcheck 0.3 0.3) isa Any
    @test_throws InvertibilityError (@invcheck 0.3 0.4)
    @test_throws InvertibilityError (@invcheck 3 3.0)
    @test (@invcheck 3 == 3.0) isa Any
end

@testset "partial" begin
    x = Partial{:im}(3+2im)
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

using Test, NiLangCore

@testset "anc" begin
    NiLangCore.@anc x = 0.0
    @test x === 0.0
    NiLangCore.@deanc x = 0.0
    @test x isa Nothing
    x = 1.0
    @test_throws InvertibilityError (NiLangCore.@deanc x = 0.0)
    @assign value(x) 0.2
    @test x == 0.2
    @assign -x 0.1
    @test x == -0.1
    x = 1+2.0im
    @assign x' 0.1+1im
    @test x == 0.1-1im
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
    (~Partial{:im})(x) == 3+2im
end

@testset "pure wrapper" begin
    @pure_wrapper A
    a = A(0.5)
    @test a isa A
    @test (~A)(a) === 0.5
    @test -A(0.5) == A(-0.5)
    @test A(1+0.5im)' == A(1-0.5im)
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
    

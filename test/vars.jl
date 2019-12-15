using Test, NiLangCore

@testset "anc" begin
    @anc x = 0.0
    @test x === 0.0
    @test (@deanc x = 0.0)
    x += 1
    @test_throws InvertibilityError (@deanc x = 0.0)
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

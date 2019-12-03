using Test, NiLangCore

@testset "anc" begin
    @anc x = 0.0
    @test x === 0.0
    @test (@deanc x = 0.0)
    x += 1
    @test_throws InvertibilityError (@deanc x = 0.0)
    @assign val(x) 0.1
    @test x == 0.1
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
end

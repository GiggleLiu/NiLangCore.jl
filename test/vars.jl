using Test, NiLangCore

@testset "anc" begin
    @anc x::Float64
    @test x === 0.0
    @test (@deanc x::Float64)
    x += 1
    @test_throws InvertibilityError (@deanc x::Float64)
    @assign val(x) 0.1
    @test x == 0.1
    @assign -x 0.1
    @test x == -0.1
    x = 1+2.0im
    @assign x' 0.1+1im
    @test x == 0.1-1im
end

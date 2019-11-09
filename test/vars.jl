using Test
@testset "anc" begin
    @anc x::Float64
    @test x[] === 0.0
    @test (@deanc x::Float64)
    x[] += 1
    @test_throws InvertibilityError (@deanc x::Float64)
end

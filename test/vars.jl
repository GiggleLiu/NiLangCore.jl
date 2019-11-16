using Test
@testset "anc" begin
    @anc x::Float64
    @test x === 0.0
    @test (@deanc x::Float64)
    x += 1
    @test_throws InvertibilityError (@deanc x::Float64)
end

@testset "GVar" begin
    gv = GVar(1.0, GVar(0.0))
    @test gv.g.g === 0.0
    @assign gv.g.g 7.0
    @test gv.g.g === 7.0
    @assign grad(gv) 9.0
    @test grad(gv) === 9.0
    gv = GVar(1.0, GVar(0.0))
    @assign grad(grad(gv)) 0.0
    @test gv.g.g === 0.0
    args = (GVar(0.0, 1.0),)
    @assign grad(args[1]) 0.0
    @test args[1].g == 0.0
end

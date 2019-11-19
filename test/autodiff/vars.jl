using NiLangCore, NiLangCore.AD
using Test

@testset "gvar" begin
    g1 = GVar(0.0)
    @test (~GVar)(g1) === 0.0
    @assign grad(g1) 0.5
    @test g1 === GVar(0.0, 0.5)
    @test_throws InvertibilityError (~GVar)(g1)
end


@testset "assign" begin
    arg = (1,2,GVar(3.0))
    @assign arg[3].g 4.0
    @test arg[3].g == 4.0
    gv = GVar(1.0, GVar(0.0))
    @test gv.g.g === 0.0
    @assign gv.g.g 7.0
    @test gv.g.g === 7.0
    gv = GVar(1.0, GVar(0.0))
    @assign grad(grad(gv)) 0.0
    @test gv.g.g === 0.0
    args = (GVar(0.0, 1.0),)
    @assign grad(args[1]) 0.0
    @test args[1].g == 0.0
    arr = [1.0]
    @assign arr[] 0.0
    @test arr[] == 0.0
end

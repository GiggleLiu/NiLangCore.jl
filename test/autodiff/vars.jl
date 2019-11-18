using NiLangCore, Test

@testset "gvar" begin
    g1 = GVar(Var(0.0))
    grad(g1)[] = 0.5
    @test g1 isa GVar{Float64, Var{Float64}}
    @test grad(g1)[] == 0.5
    g2 = GVar(g1)
    grad(grad(g2))[] = 0.8
    @test g2 isa GVar{Float64, GVar{Float64,Var{Float64}}}
    g3 = GVar(g2)
    @test grad(g3)[] == 0.5
    @test grad(grad(g3))[] == 0.8
    @test g3 isa GVar{Float64, GVar{Float64,GVar{Float64,Var{Float64}}}}
    @test (~GVar)(g3) === g2
    @test (~GVar)(g2) === g1

    GVar(0.3) === 0.3
    (~GVar)(0.3) === 0.3
end


@testset "assign" begin
    arg = (1,2,GVar(3.0))
    @assign arg[3].g 4.0
    @test arg[3].g == 4.0
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

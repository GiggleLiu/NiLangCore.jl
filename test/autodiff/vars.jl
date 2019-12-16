using NiLangCore, NiLangCore.ADCore
using Test

@testset "gvar" begin
    g1 = GVar(0.0)
    @test (~GVar)(g1) === 0.0
    @assign grad(g1) 0.5
    @test g1 === GVar(0.0, 0.5)
    @test_throws InvertibilityError (~GVar)(g1)
    @test !almost_same(GVar(0.0), GVar(0.0, 1.0))
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

@testset "assign tuple" begin
    x = 0.3
    z = Loss(0.3)
    @instr GVar.((x,))
    @test x === GVar(0.3)
end

#=
gcond(f, args::Tuple, x...) = f, args, x...
gcond(f, args::Tuple, x::GVar...) = f, f(args...), x...
(_::Inv{typeof(gcond)})(f, args::Tuple, x::GVar...) = f, (~f)(args...), x...
(_::Inv{typeof(gcond)})(f, args::Tuple, x...) = f, args, x...

@testset "gcond" begin
    f, args, x, y = ⊕(identity), (7.0, 2.0), GVar(1.0, 1.0), GVar(2.0, 1.0)
    @test gcond(f, (a, b), x, y) == (⊕(identity), (9.0, 2.0), GVar(1.0, 1.0), GVar(2.0, 1.0))
    @test (~gcond)(gcond(f, (a, b), x, y)...) == (f, args, x, y)
    @test gcond(f, (a, b), x, b) == (f, args, x, b)
    @test (~gcond)(gcond(f, (a, b), x, b)...) == (f, args, x, b)
end
=#

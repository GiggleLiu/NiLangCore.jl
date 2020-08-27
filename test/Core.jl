using Test, NiLangCore

@testset "basic" begin
    @test ~(~sin) === sin
    @test ~(~typeof(sin)) === typeof(sin)
    @test isreflexive(XorEq(NiLangCore.logical_or))
    println(XorEq(*))
    println(PlusEq(+))
    println(MinusEq(-))
    println(MulEq(*))
    println(DivEq(/))
end

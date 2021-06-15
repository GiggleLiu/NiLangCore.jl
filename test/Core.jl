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

@static if VERSION > v"1.5.100"
@testset "composite function" begin
    @i function f1(x)
        x.:1 += x.:2
    end
    @i function f2(x)
        x.:2 += cos(x.:1)
    end
    @i function f3(x)
        x.:1 ↔ x.:2
    end
    x = (2.0, 3.0)
    y = (f3∘f2∘f1)(x)
    z = (~(f3∘f2∘f1))(y)
    @show x, z
    @test all(x .≈ z)
end
end

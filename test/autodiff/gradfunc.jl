using Test, NiLangCore

@i function ⊖(a!::GVar, b::GVar)
    val(a!) ⊖ val(b)
    grad(b) ⊕ grad(a!)
end

@i function (_::OMinus{typeof(*)})(out!::GVar, x::GVar, y::GVar)
    @safe println(out!)
    out!.x ⊖ x.x * y.x
    x.g ⊕ out!.g * y.g
    y.g ⊕ x.g * out!.g
end

@testset "i" begin
    @i function test1(a, b, out)
        a ⊕ b
        out ⊕ a * b
    end

    @i function tt(a, b)
        @anc out::Float64
        test1(a, b, out)
        (~test1)(a, b, out)
        a ⊕ b
    end

    # compute (a+b)*b -> out
    x = 3.0
    y = 4.0
    out = 0.0
    @test check_grad(test1, (x, y, Loss(out)))
    @test check_grad(tt, (Loss(x), y))
end


@testset "instructs" begin
    a = 0.2
    b = 0.5
    @test check_grad(⊕, (Loss(a), b))
end

@testset "broadcast" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a .⊕ b
    end
    @i function test2(a, b, out)
        a .⊕ b
        out .⊕ (a .* b)
    end

    x = Array([3, 1.0])
    y = [4, 2.0]
    out = Array([0.0, 1.0])
    # gradients
    check_grad(test2, (x, y, Loss(out)))
end

@testset "broadcast 2" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a ⊕ b
    end
    @i function test2(a, b, out)
        a + b
        out ⊕ (a * b)
    end

    x = [3, 1.0]
    y = [4, 2.0]
    out = [0.0, 1.0]
    # gradients
    a = 1.0
    b = 1.3
    c = 1.9
    @test check_grad(test2, (a,b,Loss(c))
    (x, y, out), _ = test2'.(x, y, Loss(out))
    @test grad.(out) == [0,2.0]
    @test grad.(x) == [1, 6.0]
    @test grad.(y) == [1, 14.0]
end

@testset "function call function" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a ⊕ b
    end

    @i function test2(a, b, out)
        test1(a, out)
        (~test1)(a, out)
        out ⊕ (a * b)
    end

    a = 1.0
    b = 1.3
    c = 1.9
    @test check_grad(test2, (a,b,Loss(c)))
end

@testset "second order gradient" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a + b
    end

    a = 1.1
    b = 1.7
    ga = 0.4
    gb = 0.3
    @test check_grad(test1', (Loss(a),b))
end

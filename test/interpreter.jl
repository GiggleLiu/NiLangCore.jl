using NiLangCore
using Test

@testset "i" begin
    @i function test1(a, b, out)
        a ⊕ b
        out ⊕ a * b
    end

    @i function tt(a, b)
        @anc out::Float64
        test1(a, b, out)
        (~test1)(a, b, out)
        a + b
    end

    # compute (a+b)*b -> out
    x = 3
    y = 4
    out = 0
    @instr test1(x, y, out)
    @test out==28
    @instr (~test1)(x, y, out)
    @test out==0
    @test isreversible(test1)
    @test isreversible(test1')
    (~test1)' == ~(test1')
    @test isreversible(~test1')
    check_inv(tt, (x, y))

    # gradient
    x = Var(3)
    y = Var(4)
    out = Var(0)
    @instr test1(x, y, out)
    xδ = Var(1)
    yδ = Var(2)
    outδ = Var(2)
    @instr test1'((x, y, out), out)
    @test grad(out) == 2
    @test grad(x) == 9
    @test grad(y) == 14+2+9
end

@testset "if statement 1" begin
    # compute (a+b)*b -> out
    @i function test1(a, b, out)
        a ⊕ b
        if (a > 8, a > 8)
            out ⊕ a*b
        else
        end
    end

    x = 3
    y = 4
    out = 0
    @instr test1(x, y, out)
    @test out==0
    @test x==7
    @instr (~test1)(x, y, out)
    @test out==0
    @test x==3
end

@testset "if statement error" begin
    x = 3
    y = 4
    out = 0

    # compute (a+b)*b -> out
    @i function test1(a, b, out)
        a ⊕ b
        if (out < 4,  out < 4)
            out ⊕ a*b
        else
        end
    end

    @test_throws InvertibilityError test1(x, y, out)
end

@testset "if statement 3" begin
    x = 3
    y = 4
    out = 0
    @i function test1(a::Reg, b, out::Reg)
        a ⊕ b
        if (a > 2, a > 2)
            out ⊕ a*b
        else
        end
    end

    x = 3
    y = 4
    out = 0
    @instr test1(x, y, out)
    @test out==28
    @instr (~test1)(x, y, out)
    @test out==0
end

@testset "for" begin
    @i function looper(x, y, k)
        for i=1:1:k
            x ⊕ y
        end
    end
    x = 0.0
    y = 1.0
    k = 3
    @instr looper(x, y, k)
    @test x == 3
    @instr (~looper)(x, y, k)
    @test x == 0.0

    shiba = 18
    @i function looper2(x, y, k)
        for i=1:1:k
            k ⊕ shiba
            x ⊕ y
        end
    end
    @test_throws InvertibilityError looper2(x, y, k)
end

@testset "while" begin
    @i function looper(x, y)
        while (x<100, x>0)
            x ⊕ y
        end
    end
    x = 0.0
    y = 9
    @instr looper(x, y)
    @test x == 108
    @instr (~looper)(x, y)
    @test x == 0.0

    @i function looper2(x, y)
        while (x<100, x>-10)
            x ⊕ y
        end
    end
    @test_throws InvertibilityError looper2(x, y)
end

@testset "ancilla" begin
    one, ten = 1, 10
    @i function looper(x, y)
        @anc z::Int
        x ⊕ y
        z ⊕ one
        z ⊖ one
    end
    x = 0.0
    y = 9
    @instr looper(x, y)
    @test x[] == 9
    @instr (~looper)(x, y)
    @test x[] == 0.0

    @i function looper(x, y)
        @anc z::Int
        x ⊕ y
        z ⊕ one
        z ⊖ ten
    end
    x = 0.0
    y = 9
    @test_throws InvertibilityError looper(x, y)
end

@testset "broadcast" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a .⊕ b
    end
    x = Array([3, 1.0])
    y = Array([4, 2.0])
    @instr test1(x, y)
    @test x == [7, 3.0]
    @instr (~test1)(x, y)
    @test x == [3, 1.0]

    @i function test2(a, b, out)
        a .⊕ b
        out .⊕ (a .* b)
    end

    x = Array([3, 1.0])
    y = [4, 2.0]
    out = Array([0.0, 1.0])
    @instr test2(x, y, out)
    @test out==[28, 7]
    @instr (~test2)(x, y, out)
    @test out==[0, 1.0]

    # gradients
    xδ = Array([1,2.0])
    yδ = Array([0,2.0])
    outδ = Array([0,2.0])
    test2(x, y, out)
    test2'(x, y, out)
    @test outδ[] == [0,2.0]
    @test xδ[] == [1, 6.0]
    @test yδ[] == [1, 14.0]
end

@testset "broadcast 2" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a ⊕ b
    end
    x = VarArray([3, 1.0])
    y = VarArray([4, 2.0])
    @instr test1.(x, y)
    @test x[] == [7, 3.0]
    @instr (~test1).(x, y)
    @test x[] == [3, 1.0]

    @i function test2(a, b, out)
        a + b
        out ⊕ (a * b)
    end

    x = VarArray([3, 1.0])
    y = [4, 2.0]
    out = VarArray([0.0, 1.0])
    test2.(x, y, out)
    @test out[]==[28, 7]
    (~test2).(x, y, out)
    @test out[]==[0, 1.0]

    # gradients
    xδ = VarArray([1,2.0])
    yδ = VarArray([0,2.0])
    outδ = VarArray([0,2.0])
    test2.(x, y, out)
    (x, y, out), _ = test2'.((x, y, out), out)
    @test outδ[] == [0,2.0]
    @test xδ[] == [1, 6.0]
    @test yδ[] == [1, 14.0]
    @newvar a = 1.0
    @newvar b = 1.3
    @newvar c = 1.9
    @test check_grad(test2, (a,b,c), loss=c)
end

@testset "function call function" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a + b
    end

    @i function test2(a, b, out)
        test1(a, out)
        (~test1)(a, out)
        out ⊕ (a * b)
    end

    @newvar a = 1.0
    @newvar b = 1.3
    @newvar c = 1.9
    @test check_grad(test2, (a,b,c), loss=c)
end

@testset "second order gradient" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a + b
    end
    @initgrad (+)'
    @initgrad test1
    @initgrad test1'

    @newvar a = 1.1
    @newvar b = 1.7
    @newvar ga = 0.4
    @newvar gb = 0.3
    @test check_grad(test1', (a,b, ga, gb), loss=a)
end

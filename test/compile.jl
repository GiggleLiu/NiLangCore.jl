using NiLangCore
using Test

@i function test1(a::GRef, b, out::GRef)
    a + b
    out ⊕ a * b
end
@eval $(gradexpr(test1))

@testset "i" begin
    # compute (a+b)*b -> out
    x = GRef(3)
    y = GRef(4)
    out = GRef(0)
    test1(x, y, out)
    @test out[]==28
    (~test1)(x, y, out)
    @test out[]==0
    @test isreversible(test1)
    @test isreversible(test1')
    (~test1)' == ~(test1')
    @test isreversible(~test1')

    # gradient
    x = GRef(3)
    y = GRef(4)
    out = GRef(0)
    test1(x, y, out)
    xδ = GRef(1)
    yδ = GRef(2)
    outδ = GRef(2)
    test1'(x, y, out, xδ, yδ, outδ)
    @test outδ[] == 2
    @test xδ[] == 9
    @test yδ[] == 14+2+9
end

@testset "if statement 1" begin
    # compute (a+b)*b -> out
    @i function test1(a::GRef, b, out::GRef)
        a + b
        if (a[] > 8, a[] > 8)
            out ⊕ a[]*b[]
        else
        end
    end

    x = GRef(3)
    y = GRef(4)
    out = GRef(0)
    test1(x, y, out)
    @test out[]==0
    @test x[]==7
    (~test1)(x, y, out)
    @test out[]==0
    @test x[]==3
end

@testset "if statement error" begin
    x = Ref(3)
    y = Ref(4)
    out = Ref(0)

    # compute (a+b)*b -> out
    @i function test1(a::Ref, b, out::Ref)
        a + b
        if (out[] < 4,  out[] < 4)
            out ⊕ a[]*b[]
        else
        end
    end

    @test_throws InvertibilityError test1(x, y, out)
end

@testset "if statement 3" begin
    x = Ref(3)
    y = Ref(4)
    out = Ref(0)
    @i function test1(a::Ref, b, out::Ref)
        a + b
        if (a[] > 2, a[] > 2)
            out ⊕ a[]*b[]
        else
        end
    end

    x = Ref(3)
    y = Ref(4)
    out = Ref(0)
    test1(x, y, out)
    @test out[]==28
    (~test1)(x, y, out)
    @test out[]==0
end

@testset "for" begin
    @i function looper(x, y, k)
        for i=1:1:k[]
            x + y
        end
    end
    x = Ref(0.0)
    y = 1.0
    k = Ref(3)
    looper(x, y, k)
    @test x[] == 3
    (~looper)(x, y, k)
    @test x[] == 0.0

    @i function looper2(x, y, k)
        for i=1:1:k[]
            k + 18
            x + y
        end
    end
    @test_throws InvertibilityError looper2(x, y, k)
end

@testset "while" begin
    @i function looper(x, y)
        while (x[]<100, x[]>0)
            x + y
        end
    end
    x = Ref(0.0)
    y = 9
    looper(x, y)
    @test x[] == 108
    (~looper)(x, y)
    @test x[] == 0.0

    @i function looper2(x, y)
        while (x[]<100, x[]>-10)
            x + y
        end
    end
    @test_throws InvertibilityError looper2(x, y)
end

@testset "ancilla" begin
    @i function looper(x, y)
        @anc z::Int
        x + y
        z + 1
        z - 1
    end
    x = Ref(0.0)
    y = 9
    looper(x, y)
    @test x[] == 9
    (~looper)(x, y)
    @test x[] == 0.0

    @i function looper(x, y)
        @anc z::Int
        x + y
        z + 1
        z - 10
        println(z)
    end
    x = Ref(0.0)
    y = 9
    @test_throws InvertibilityError looper(x, y)
end

@testset "broadcast" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a .+ b
    end
    x = GArray([3, 1.0])
    y = GArray([4, 2.0])
    test1(x, y)
    @test x[] == [7, 3.0]
    (~test1)(x, y)
    @test x[] == [3, 1.0]

    @i function test2(a, b, out)
        a .+ b
        out .⊕ (a .* b)
    end

    x = GArray([3, 1.0])
    y = [4, 2.0]
    out = GArray([0.0, 1.0])
    test2(x, y, out)
    @test out[]==[28, 7]
    (~test2)(x, y, out)
    @test out[]==[0, 1.0]

    # gradients
    xδ = GArray([1,2.0])
    yδ = GArray([0,2.0])
    outδ = GArray([0,2.0])
    test2(x, y, out)
    test2'(x, y, out, xδ, yδ, outδ)
    @test outδ[] == [0,2.0]
    @test xδ[] == [1, 6.0]
    @test yδ[] == [1, 14.0]
end

@testset "broadcast 2" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a + b
    end
    x = GArray([3, 1.0])
    y = GArray([4, 2.0])
    test1.(x, y)
    @test x[] == [7, 3.0]
    (~test1).(x, y)
    @test x[] == [3, 1.0]

    @i function test2(a, b, out)
        a + b
        out ⊕ (a * b)
    end

    x = GArray([3, 1.0])
    y = [4, 2.0]
    out = GArray([0.0, 1.0])
    test2.(x, y, out)
    @test out[]==[28, 7]
    (~test2).(x, y, out)
    @test out[]==[0, 1.0]

    # gradients
    xδ = GArray([1,2.0])
    yδ = GArray([0,2.0])
    outδ = GArray([0,2.0])
    test2.(x, y, out)
    test2'.(x, y, out, xδ, yδ, outδ)
    @test outδ[] == [0,2.0]
    @test xδ[] == [1, 6.0]
    @test yδ[] == [1, 14.0]
    @test check_grad(test2, (x, y, out), loss=out[1])
end

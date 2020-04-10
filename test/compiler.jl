using NiLangCore
using Test

@testset "i" begin
    @i function test1(a::T, b, out) where T<:Number
        add(a, b)
        out += a * b
    end

    @i function tt(a, b)
        out ← 0.0
        test1(a, b, out)
        (~test1)(a, b, out)
        a ⊕ b
    end

    # compute (a+b)*b -> out
    x = 3.0
    y = 4.0
    out = 0.0
    @test isreversible(test1)
    @test check_inv(test1, (x, y, out))
    @test check_inv(tt, (x, y))
    @test check_inv(tt, (x, y))
end

@testset "if statement 1" begin
    # compute (a+b)*b -> out
    @i function test1(a, b, out)
        add(a, b)
        if (a > 8, a > 8)
            out += a*b
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
        add(a, b)
        if (out < 4,  out < 4)
            out += a*b
        else
        end
    end

    @test_throws InvertibilityError test1(x, y, out)
end

@testset "if statement 3" begin
    x = 3
    y = 4
    out = 0
    @i @inline function test1(a, b, out)
        add(a, b)
        if (a > 2, a > 2)
            out += a*b
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

    @i function looper2(x, y)
        while (x<100, x>0)
            z ← 0
            x ⊕ y
            z += identity(1)
        end
    end
    @test_throws InvertibilityError looper2(x, y)
end

@testset "ancilla" begin
    one, ten = 1, 10
    @i function looper(x, y)
        z ← 0
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
        z ← 0
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
    x = [3, 1.0]
    y = [4, 2.0]
    @instr test1(x, y)
    @test x == [7, 3.0]
    @instr (~test1)(x, y)
    @test x == [3, 1.0]

    @i function test2(a, b, out)
        a .⊕ b
        out .+= (a .* b)
    end

    x = Array([3, 1.0])
    y = [4, 2.0]
    out = Array([0.0, 1.0])
    @instr test2(x, y, out)
    @test out==[28, 7]
    @test check_inv(test2, (x, y, out))
end

@testset "broadcast 2" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a ⊕ b
    end
    x = [3, 1.0]
    y = [4, 2.0]
    @instr test1.(x, y)
    @test x == [7, 3.0]
    @instr (~test1).(x, y)
    @test x == [3, 1.0]

    @i function test2(a, b, out)
        add(a, b)
        out += (a * b)
    end

    x = [3, 1.0]
    y = [4, 2.0]
    out = [0.0, 1.0]
    @instr test2.(x, y, out)
    @test out==[28, 7]
    @instr (~test2).(x, y, out)
    @test out==[0, 1.0]
    args = (x, y, out)
    @instr test2.(args...)
    @test args[3]==[28, 7]
end

@testset "neg sign" begin
    @i function test(out, x, y)
        out += x * (-y)
    end
    @test check_inv(test, (0.1, 2.0, -2.5); verbose=true)
end

@testset "@ibounds" begin
    @i function test(x, y)
        for i=1:length(x)
            @inbounds x[i] += identity(y[i])
        end
    end
    @test test([1,2], [2,3]) == ([3,5], [2,3])
end

@testset "kwargs" begin
    @i function test(out, x; y)
        out += x * (-y)
    end
    @test check_inv(test, (0.1, 2.0); y=0.5, verbose=true)
end

@testset "routines" begin
    @i function test(out, x)
        @routine begin
            out += identity(x)
        end
        ~@routine
    end
    out, x = 0.0, 1.0
    @instr test(out, x)
    @test out == 0.0
end

@testset "inverse a prog" begin
    @i function test(out, x)
        ~(out += identity(x);
        out += identity(x))
        ~for i=1:3
            out += identity(x)
        end
    end
    out, x = 0.0, 1.0
    @test check_inv(test, (out, x))
    @instr test(out, x)
    @test out == -5.0
end

@testset "invcheck" begin
    @i function test(out, x)
        anc ← 0
        @invcheckoff for i=1:x[]
            x[] -= identity(1)
        end
        @invcheckoff while (anc<3, anc<3)
            anc += identity(1)
        end
        out += identity(anc)
        @invcheckoff anc → 0
    end
    res = test(0, Ref(7))
    @test res[1] == 3
    @test res[2][] == 0
end

@testset "nilang ir" begin
    ex = :(
        @inline function f(x!::T, y) where T
            anc ← zero(T)
            @routine anc += identity(x!)
            x! += y * anc
            ~@routine
        end
    )
    ex2 = :(
    @inline function f(x!::T, y) where T
          anc ← zero(T)
          anc += identity(x!)
          x! += y * anc
          anc -= identity(x!)
          anc → zero(T)
    end)

    ex3 = :(
    @inline function (~f)(x!::T, y) where T
          anc ← zero(T)
          anc += identity(x!)
          x! -= y * anc
          anc -= identity(x!)
          anc → zero(T)
    end)
    @test nilang_ir(ex) |> NiLangCore.rmlines == ex2 |> NiLangCore.rmlines
    @test nilang_ir(ex; reversed=true) |> NiLangCore.rmlines == ex3 |> NiLangCore.rmlines
end

@testset "protectf" begin
    struct C<:Function end
    # protected
    @i function (a::C)(x)
        @safe @show a
        if (protectf(a) isa Inv, ~)
            add(x, 1.0)
        else
            sub(x, 1.0)
        end
    end
    a = C()
    @test (~a)(a(1.0)) == 1.0
    # not protected
    @i function (a::C)(x)
        @safe @show a
        if (a isa Inv, ~)
            add(x, 1.0)
        else
            sub(x, 1.0)
        end
    end
    @test (~a)(a(1.0)) == -1.0
end

@testset "ifelse statement" begin
    @i function f(x, y)
        if (x > 0, ~)
            y += identity(1)
        elseif (x < 0, ~)
            y += identity(2)
        else
            y += identity(3)
        end
    end
    @test f(1, 0) == (1, 1)
    @test f(-2, 0) == (-2, 2)
    @test f(0, 0) == (0, 3)

    @i function f2(x, y)
        if (x > 0, x < 0)
            y += identity(1)
        elseif (x < 0, x < 0)
            y += identity(2)
        else
            y += identity(3)
        end
    end
    @test_throws InvertibilityError f2(-1, 0)
end

@testset "skip!" begin
    x = 0.4
    @instr (@skip! 3) += identity(x)
    @test x == 0.4
    y = 0.3
    @instr x += identity(@keep y)
    @test x == 0.7
    @test y == 0.3
end

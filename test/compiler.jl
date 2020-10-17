using NiLangCore
using Test
using Base.Threads

@testset "i" begin
    @i function test1(a::T, b, out) where T<:Number
        add(a, b)
        out += a * b
    end

    @i function tt(a, b)
        out ← 0.0
        test1(a, b, out)
        (~test1)(a, b, out)
        a += b
    end

    # compute (a+b)*b -> out
    x = 3.0
    y = 4.0
    out = 0.0
    @test isreversible(test1, Tuple{Number, Any, Any})
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

@testset "if statement 4" begin
    @i function test1(a, b, out)
        add(a, b)
        if a > 8.0
            out += a*b
        end
    end
    @test test1(1.0, 8.0, 0.0)[3] == 72.0

    @i function test2(a, b)
        add(a, b)
        if a > 8.0
            a -= b^2
        end
    end
    @test_throws InvertibilityError test2(1.0, 8.0)

    @test_throws LoadError macroexpand(Main, :(@i function test3(a, b)
        add(a, b)
        if a > 8.0
            a -= b*b
        end
    end))
end

@testset "for" begin
    @i function looper(x, y, k)
        for i=1:1:k
            x += y
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
            k += shiba
            x += y
        end
    end
    @test_throws InvertibilityError looper2(x, y, k)
end

@testset "while" begin
    @i function looper(x, y)
        while (x<100, x>0)
            x += y
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
            x += y
        end
    end
    @test_throws InvertibilityError looper2(x, y)

    @i function looper2(x, y)
        while (x<100, x>0)
            z ← 0
            x += y
            z += 1
        end
    end
    @test_throws InvertibilityError looper2(x, y)
end

@testset "ancilla" begin
    one, ten = 1, 10
    @i function looper(x, y)
        z ← 0
        x += y
        z += one
        z -= one
    end
    x = 0.0
    y = 9
    @instr looper(x, y)
    @test x[] == 9
    @instr (~looper)(x, y)
    @test x[] == 0.0

    @i function looper(x, y)
        z ← 0
        x += y
        z += one
        z -= ten
    end
    x = 0.0
    y = 9
    @test_throws InvertibilityError looper(x, y)
end

@testset "broadcast" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a .+= b
    end
    x = [3, 1.0]
    y = [4, 2.0]
    @instr test1(x, y)
    @test x == [7, 3.0]
    @instr (~test1)(x, y)
    @test x == [3, 1.0]

    @i function test2(a, b, out)
        a .+= identity.(b)
        out .+= (a .* b)
    end

    x = Array([3, 1.0])
    y = [4, 2.0]
    out = Array([0.0, 1.0])
    @instr test2(x, y, out)
    @test out==[28, 7]
    @test check_inv(test2, (x, y, out))
end

@testset "broadcast arr" begin
    @i function f5(x, y, z, a, b)
        x += y + z
        b += a + x
    end
    @i function f4(x, y, z, a)
        x += y + z
        a += y + x
    end
    @i function f3(x, y, z)
        y += x + z
    end
    @i function f2(x, y)
        y += x
    end
    @i function f1(x)
        l ← zero(x)
        l += x
        x -= 2 * l
        l += x
    end
    a = randn(10)
    b = randn(10)
    c = randn(10)
    d = randn(10)
    e = randn(10)
    aa = copy(a)
    @instr f1.(aa)
    @test aa ≈ -a
    aa = copy(a)
    bb = copy(b)
    @instr f2.(aa, bb)
    @test aa ≈ a
    @test bb ≈ b + a

    aa = copy(a)
    bb = copy(b)
    cc = copy(c)
    @instr f3.(aa, bb, cc)
    @test aa ≈ a
    @test bb ≈ b + a + c
    @test cc ≈ c

    aa = copy(a)
    bb = copy(b)
    cc = copy(c)
    dd = copy(d)
    @instr f4.(aa, bb, cc, dd)
    @test aa ≈ a + b + c
    @test bb ≈ b
    @test cc ≈ c
    @test dd ≈ a + 2b + c + d

    aa = copy(a)
    bb = copy(b)
    cc = copy(c)
    dd = copy(d)
    ee = copy(e)
    @instr f5.(aa, bb, cc, dd, ee)
    @test aa ≈ a + b + c
    @test bb ≈ b
    @test cc ≈ c
    @test dd ≈ d
    @test ee ≈ a + b + c + d + e

    x = randn(5)
    @test_throws AssertionError @instr x .+= c
end

@testset "broadcast tuple" begin
    @i function f5(x, y, z, a, b)
        x += y + z
        b += a + x
    end
    @i function f4(x, y, z, a)
        x += y + z
        a += y + x
    end
    @i function f3(x, y, z)
        y += x + z
    end
    @i function f2(x, y)
        y += x
    end
    @i function f1(x)
        l ← zero(x)
        l += x
        x -= 2 * l
        l += x
    end
    a = (1,2)
    b = (3,1)
    c = (6,7)
    d = (1,11)
    e = (4,1)
    aa = a
    @instr f1.(aa)
    @test aa == -1 .* a
    aa = a
    bb = b
    @instr f2.(aa, bb)
    @test aa == a
    @test bb == b .+ a

    aa = a
    bb = b
    cc = c
    @instr f3.(aa, bb, cc)
    @test aa == a
    @test bb == b .+ a .+ c
    @test cc == c

    aa = a
    bb = b
    cc = c
    dd = d
    @instr f4.(aa, bb, cc, dd)
    @test aa == a .+ b .+ c
    @test bb == b
    @test cc == c
    @test dd == a .+ 2 .* b .+ c .+ d

    aa = a
    bb = b
    cc = c
    dd = d
    ee = e
    @instr f5.(aa, bb, cc, dd, ee)
    @test aa == a .+ b .+ c
    @test bb == b
    @test cc == c
    @test dd == d
    @test ee == a .+ b .+ c .+ d .+ e

    x = (2,1,5)
    @test_throws DimensionMismatch @instr x .+= c
end

@testset "broadcast 2" begin
    # compute (a+b)*b -> out
    @i function test1(a, b)
        a += b
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
            @inbounds x[i] += y[i]
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
            out += x
        end
        ~@routine
    end
    out, x = 0.0, 1.0
    @instr test(out, x)
    @test out == 0.0
end

@testset "inverse a prog" begin
    @i function test(out, x)
        ~(out += x;
        out += x)
        ~for i=1:3
            out += x
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
            x[] -= 1
        end
        @invcheckoff while (anc<3, anc<3)
            anc += 1
        end
        out += anc
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
            @routine anc += x!
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
    @test nilang_ir(@__MODULE__, ex) |> NiLangCore.rmlines == ex2 |> NiLangCore.rmlines
    @test nilang_ir(@__MODULE__, ex; reversed=true) |> NiLangCore.rmlines == ex3 |> NiLangCore.rmlines
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
            y += 1
        elseif (x < 0, ~)
            y += 2
        else
            y += 3
        end
    end
    @test f(1, 0) == (1, 1)
    @test f(-2, 0) == (-2, 2)
    @test f(0, 0) == (0, 3)

    @i function f2(x, y)
        if (x > 0, x < 0)
            y += 1
        elseif (x < 0, x < 0)
            y += 2
        else
            y += 3
        end
    end
    @test_throws InvertibilityError f2(-1, 0)
end

@testset "skip!" begin
    x = 0.4
    @instr (@skip! 3) += x
    @test x == 0.4
    y = 0.3
    @instr x += @keep y
    @test x == 0.7
    @test y == 0.3
end

@testset "for x in range" begin
    @i function f(x, y)
        for item in y
            x += item
        end
    end
    @test check_inv(f, (0.0, [1,2,5]))
end

@testset "dual_pipline" begin
    @i function f(x, y)
        (x, y) |> ⊕(identity) |> ⊕(identity)
    end
    @test f(2,3) == (8, 3)
    @test (~f)(f(2,3)...) == (2, 3)
    x, y = 2, 3
    @instr (x, y) |> f
    @test (x, y) == (8,3)
    x, y = 2, 3
    @instr (x, y) |> f |> ~f
    @test (x, y) == (2,3)
    args = (2,3)
    @instr (args...,) |> f
    @test args == (8,3)
    x, y = [2,3,1], [3,5,1]
    @instr (x, y) .|> f
    @test (x, y) == ([8, 13, 3],[3, 5, 1])
    b = [1,3,5]
    NEG(x) = -x
    @selfdual NEG
    @show NEG.(b)
    @instr (b,) .|> NEG
    @test b == [-1, -3, -5]
    x, y = [2,3,1], [3,5,1]
    @instr (x, y) .|> f .|> ~f
    @test (x, y) == ([2, 3, 1],[3, 5, 1])
    x, y = 1, 2
    SWAP(x,y) = (y, x)
    @selfdual SWAP
    @instr (x, y) |> ⊕(identity) |> SWAP
    @instr ~((x, y) |> ⊕(identity) |> SWAP)
    @test (x, y) == (1, 2)
end

@testset "@simd and @threads" begin
    @i function f(x)
        @threads for i=1:length(x)
            x[i] += 1
        end
    end
    x = [1,2,3]
    @test f(x) == [2,3,4]
    @i function f(x)
        @simd for i=1:length(x)
            x[i] += 1
        end
    end
    x = [1,2,3]
    @test f(x) == [2,3,4]
end

@testset "xor over ||" begin
    x = false
    @instr x ⊻= true || false
    @test x
    @instr x ⊻= true && false
    @test x
end

macro zeros(T, x, y)
    esc(:($x ← zero($T); $y ← zero($T)))
end

@testset "macro" begin
    @i function f(x)
        @zeros Float64 a b
        x += a * b
    end
    @test f(3.0) == 3.0
end

@testset "allow nothing pass" begin
    @i function f(x)
        nothing
    end
    @test f(2) == 2
end

@testset "ancilla check" begin
    ex1 = :(@i function f(x)
        x ← 0
    end)
    @test_throws LoadError macroexpand(Main, ex1)

    ex2 = :(@i function f(x)
        y ← 0
        y ← 0
    end)
    @test_throws LoadError macroexpand(Main, ex2)

    ex3 = :(@i function f(x)
        y ← 0
    end)
    @test macroexpand(Main, ex3) isa Expr

    ex4 = :(@i function f(x; y=5)
        y ← 0
    end)
    @test_throws LoadError macroexpand(Main, ex4)

    ex5 = :(@i function f(x)
        y → 0
    end)
    @test_throws LoadError macroexpand(Main, ex5)

    ex6 = :(@i function f(x::Int)
        y ← 0
    end)
    @test macroexpand(Main, ex6) isa Expr

    ex7 = :(@i function f(x::Int)
        if x>3
            y ← 0
        elseif x<-3
            y ← 0
        else
            y ← 0
        end
    end)
    @test macroexpand(Main, ex7) isa Expr

    ex8 = :(@i function f(x; y=5)
        z ← 0
    end)
    @test macroexpand(Main, ex8) isa Expr

    ex9 = :(@i function f(x; y)
        z ← 0
    end)
    @test macroexpand(Main, ex9) isa Expr

    ex10 = :(@i function f(x; y)
        begin
            z ← 0
        end
        ~begin
            z ← 0
        end
    end)
    @test macroexpand(Main, ex10) isa Expr
end

@testset "inv type" begin
    struct AddX{T}
        x::T
    end
    struct SubX{T}
        x::T
    end
    @dualtype AddX SubX
    @i function (f::AddX)(x::Real) end
    @test hasmethod(AddX(3), Tuple{Real})
    @test hasmethod(SubX(3), Tuple{Real})
end

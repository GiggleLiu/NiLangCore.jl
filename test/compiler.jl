using NiLangCore
using Test
using Base.Threads

@testset "to_standard_format" begin
    for (OP, FUNC) in [(:+=, PlusEq), (:-=, MinusEq), (:*=, MulEq), (:/=, DivEq), (:⊻=, XorEq)]
        @test NiLangCore.to_standard_format(Expr(OP, :x, :y)) == :($FUNC(identity)(x, y))
        @test NiLangCore.to_standard_format(Expr(OP, :x, :(sin(y; z=3)))) == :($FUNC(sin)(x, y; z=3))

        OPD = Symbol(:., OP)
        @test NiLangCore.to_standard_format(Expr(OPD, :x, :y)) == :($FUNC(identity).(x, y))
        @test NiLangCore.to_standard_format(Expr(OPD, :x, :(sin.(y)))) == :($FUNC(sin).(x, y))
        @test NiLangCore.to_standard_format(Expr(OPD, :x, :(y .* z))) == :($FUNC(*).(x, y, z))
    end
    @test NiLangCore.to_standard_format(Expr(:⊻=, :x, :(y && z))) == :($XorEq($(NiLangCore.logical_and))(x, y, z))
    @test NiLangCore.to_standard_format(Expr(:⊻=, :x, :(y || z))) == :($XorEq($(NiLangCore.logical_or))(x, y, z))
end

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
        out → 0.0
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

   @test_throws LoadError macroexpand(@__MODULE__, :(@i function looper3(x, y)
        while (x<100, x>0)
            z ← 0
            x += y
            z += 1
        end
    end))
end

@testset "ancilla" begin
    one, ten = 1, 10
    @i function looper(x, y)
        z ← 0
        x += y
        z += one
        z -= one
        z → 0
    end
    x = 0.0
    y = 9
    @instr looper(x, y)
    @test x[] == 9
    @instr (~looper)(x, y)
    @test x[] == 0.0

    @i function looper2(x, y)
        z ← 0
        x += y
        z += one
        z -= ten
        z → 0
    end
    x = 0.0
    y = 9
    @test_throws InvertibilityError looper2(x, y)
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
        l → zero(x)
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
        l → zero(x)
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
    @test_throws AssertionError @instr x .+= c
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
            anc → zero(T)
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
    @instr x += @const y
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

@testset "@simd and @threads" begin
    @i function f(x)
        @threads for i=1:length(x)
            x[i] += 1
        end
    end
    x = [1,2,3]
    @test f(x) == [2,3,4]
    @i function f2(x)
        @simd for i=1:length(x)
            x[i] += 1
        end
    end
    x = [1,2,3]
    @test f2(x) == [2,3,4]
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
        ~@zeros Float64 a b
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
        y → 0
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
        y → 0
    end)
    @test macroexpand(Main, ex6) isa Expr

    ex7 = :(@i function f(x::Int)
        if x>3
            y ← 0
            y → 0
        elseif x<-3
            y ← 0
            y → 0
        else
            y ← 0
            y → 0
        end
    end)
    @test macroexpand(Main, ex7) isa Expr

    ex8 = :(@i function f(x; y=5)
        z ← 0
        z → 0
    end)
    @test macroexpand(Main, ex8) isa Expr

    ex9 = :(@i function f(x; y)
        z ← 0
        z → 0
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

@testset "dict access" begin
    d = Dict(3=>4)
    @instr d[3] → 4
    @instr d[4] ← 3
    @test d == Dict(4=>3)
    @test_throws InvertibilityError @instr d[4] → 5
    @test (@instr @invcheckoff d[8] → 5; true)
    @test_throws InvertibilityError @instr d[4] ← 5
    @test (@instr @invcheckoff d[4] ← 5; true)
end

@testset "@routine,~@routine" begin
    @test_throws LoadError macroexpand(Main, :(@i function f(x)
        @routine begin
        end
    end))
    @test_throws LoadError macroexpand(Main, :(@i function f(x)
        ~@routine
    end))
    @test macroexpand(Main, :(@i function f(x)
        @routine begin end
        ~@routine
    end)) !== nothing
end

@testset "@from post while pre" begin
    @i function f()
       x ← 5
       z ← 0
       @from z==0 while x > 0
           x -= 1
           z += 1
       end
       z → 5
       x → 0
    end

    @test f() == ()
    @test (~f)() == ()
end


@testset "argument with function call" begin
    @test_throws LoadError @macroexpand @i function f(x, y)
        x += sin(exp(y))
    end
    @i function f(x, y)
        x += sin(exp(0.4)) + y
    end
end

@testset "allocation multiple vars" begin
    info = NiLangCore.PreInfo()
    @test NiLangCore.precom_ex(NiLangCore, :(x,y ← var), info) == :((x, y) ← var)
    @test NiLangCore.precom_ex(NiLangCore, :(x,y → var), info) == :((x, y) → var)
    @test NiLangCore.precom_ex(NiLangCore, :((x,y) ↔ (a, b)), info) == :((x,y) ↔ (a,b))
    @test (@code_reverse (x,y) ← var) == :((x, y) → var)
    @test (@code_reverse (x,y) → var) == :((x, y) ← var)
    @test (@code_julia (x,y) ← var) == :((x, y) = var)
    @test (@code_julia (x,y) → var) == :(try
        $(NiLangCore.deanc)((x, y), var)
    catch e
        $(:(println("deallocate fail `$($(QuoteNode(:((x, y))))) → $(:var)`")) |> NiLangCore.rmlines)
        throw(e)
    end)

    x = randn(2,4)
    @i function f(y, x)
        m, n ← size(x)
        (l, k) ← size(x)
        y += m*n
        y += l*k
        (l, k) → size(x)
        m, n → size(x)
    end
    twosize = f(0, x)[1]
    @test  twosize == 16
    @test (~f)(twosize, x)[1] == 0

    @i function g(x)
        (m, n) ← size(x)
        (m, n) → (7, 5)
    end

    @test_throws InvertibilityError g(x)
    @test_throws InvertibilityError (~g)(x)
end

@testset "argument without argname" begin
    @i function f(::Complex)
    end
    @test f(1+2im) == 1+2im
end

@testset "tuple input" begin
    @i function f(x::Tuple{<:Tuple, <:Real})
        f(x.:1)
        (x.:1).:1 += x.:2
    end
    @i function f(x::Tuple{<:Real, <:Real})
        x.:1 += x.:2
    end
    @i function g(data)
        f(((data.:1, data.:2), data.:3))
    end
    @test g((1,2,3)) == (6,2,3)
end

@testset "single argument" begin
    @i function f(x)
        neg(x)
    end
    @i function g(x::Vector)
        neg.(x)
    end
    @test f(3) == -3
    @test g([3, 2]) == [-3, -2]
    x = (3,)
    @instr f(x...)
    @test x == (-3,)
    x = ([3, 4],)
    @instr f.(x...)
    @test x == ([-3, -4],)
end

@testset "type constructor" begin
    @i function f(x, y, a, b)
        add(Complex{}(x, y), Complex{}(a, b))
    end
    @test f(1,2, 3, 4) == (4, 6, 3, 4)
    @test_throws LoadError macroexpand(NiLangCore, :(@i function f(x, y, a, b)
        add(Complex(x, y), Complex{}(a, b))
    end))
    @i function g(x::Inv, y::Inv)
        add(x.f, y.f)
    end
    @i function g(x, y)
        g(Inv{}(x), Inv{}(y))
    end
    @test g(2, 3) == (5, 3)
end

@testset "variable_analysis" begin
    # kwargs should not be assigned
    @test_throws LoadError macroexpand(@__MODULE__, :(@i function f1(x; y=4)
        y ← 5
        y → 5
    end))
    # deallocated variables should not be used
    @test_throws LoadError macroexpand(@__MODULE__, :(@i function f1(x; y=4)
        z ← 5
        z → 5
        x += 2 * z
    end))
    # deallocated variables should not be used in local scope
    @test_throws LoadError macroexpand(@__MODULE__, :(@i function f1(x; y=4)
        z ← 5
        z → 5
        for i=1:10
            x += 2 * z
        end
    end))
end

@testset "boolean" begin
    @i function f1(x, y, z)
        x ⊻= true
        y .⊻= z
    end
    @test f1(false, [true, false], [true, false]) == (true, [false, false], [true, false])

    @i function f2(x, y, z)
        z[2] ⊻= true && y[1]
        z[1] ⊻= z[2] || x
    end
    @test f2(false, [true, false], [true, false]) == (false, [true, false], [false, true])
end

@testset "swap ↔" begin
    @i function f1(x, y)
        j::∅ ↔ k::∅   # dummy swap
        a::∅ ↔ x
        a ↔ y
        a ↔ x::∅   # ↔ is symmetric
    end
    @test f1(2, 3) == (3, 2)
    @test check_inv(f1, (2, 3))

    # stack
    @i function f2(x, y)
        x[end+1] ↔ y
        y ← 2
    end
    @test f2([1,2,3], 4) == ([1,2,3,4], 2)
    @test check_inv(f2, ([1,2,3], 3))

    @i function f4(x, y)
        y ↔ x[end+1]
        y ← 2
    end
    @test f4([1,2,3], 4) == ([1,2,3,4], 2)
    @test check_inv(f4, ([1,2,3], 3))

    @i function f3(x, y::TY, s) where TY
        y → _zero(TY)
        x[end] ↔ (y::TY)::∅
        @safe @show x[2], s
        x[2] ↔ s
    end
    @test f3(Float32[1,2,3], 0.0, 4f0) == (Float32[1,4], 3.0, 2f0)
    @test check_inv(f3, (Float32[1,2,3], 0.0, 4f0))
end

@testset "feed tuple and types" begin
    @i function f3(a, d::Complex)
        a.:1 += d.re
        d.re ↔ d.im
    end
    @i function f4(a, b, c, d, e)
        f3((a, b, c), Complex{}(d, e))
    end
    @test f4(1,2,3,4,5) == (5,2,3,5,4)
    @test check_inv(f4, (1,2,3,4,5))
end

@testset "exchange tuple and fields" begin
    @i function f1(x, y, z)
        (x, y) ↔ @fields z
    end
    @test f1(1,2, 3+4im) == (3,4,1+2im)

    @i function f2(re, x)
        r, i ← @fields x
        re += r
        r, i → @fields x
    end
    @test f2(0.0, 3.0+2im) == (3.0, 3.0 + 2.0im)

    @i function f3(x, y, z)
        (@fields z) ↔ (x, y)
    end
    @test f3(1,2, 3+4im) == (3,4,1+2im)

    @test_throws LoadError macroexpand(@__MODULE__, :(@i function f3(x, y, z)
        (x, y) ↔ (z, j)
    end))
    @i function f4(x, y, z, j)
        (x, y) ↔ (z, j)
    end
    @test f4(1,2, 3, 4) == (3,4,1,2)
end


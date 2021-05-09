using NiLangCore, Test

@testset "stack" begin
    for (stack, x) in [
                (FLOAT64_STACK, 0.3), (FLOAT32_STACK, 0f4),
                (INT64_STACK, 3), (INT32_STACK, Int32(3)),
                (COMPLEXF64_STACK, 4.0+0.3im), (COMPLEXF32_STACK, 4f0+0f3im),
                (BOOL_STACK, true),
                ]
        println(stack)
        push!(stack, x)
        @test pop!(stack) === x
    end
end

@testset "stack operations" begin
    z = 1.0
    NiLangCore.empty_global_stacks!()
    @test_throws InvertibilityError (@instr POP!(z))
    y = 0.0
    @test_throws ArgumentError (@instr POP!(y))
    @test_throws ArgumentError (@instr COPYPOP!(y))
    @test_throws ArgumentError (@instr @invcheckoff POP!(y))
    @test_throws ArgumentError (@instr @invcheckoff COPYPOP!(y))
    x = 0.3
    NiLangCore.empty_global_stacks!()
    @instr PUSH!(x)
    @test x === 0.0
    @instr POP!(x)
    @test x === 0.3
    @instr @invcheckoff PUSH!(x)
    x = 0.4
    @test_throws InvertibilityError @instr POP!(x)
    y = 0.5
    @instr PUSH!(y)
    @instr @invcheckoff POP!(x)
    @test x == 0.5

    x =0.3
    st = Float64[]
    @instr PUSH!(st, x)
    @test x === 0.0
    @test length(st) == 1
    @instr POP!(st, x)
    @test length(st) == 0
    @test x === 0.3
    @instr PUSH!(st, x)
    @test length(st) == 1
    x = 0.4
    @test_throws InvertibilityError @instr POP!(x)
    @test length(st) == 1

    y = 0.5
    @instr PUSH!(st, y)
    @instr @invcheckoff POP!(st, x)
    @test x == 0.5

    VEC = [1,3,3]
    @instr PUSH!(VEC)
    @test VEC == Int[]

    @i function test(x)
        x2 ← zero(x)
        x2 += x^2
        PUSH!(x)
        x ↔ x2
    end
    @test test(3.0) == 9.0
    l = length(NiLangCore.GLOBAL_STACK)
    @test check_inv(test, (3.0,))
    @test length(NiLangCore.GLOBAL_STACK) == l

    @i function test2(x)
        x2 ← zero(x)
        x2 += x^2
        @invcheckoff PUSH!(x)
        x ↔ x2
    end
    @test test2(3.0) == 9.0
    l = length(NiLangCore.GLOBAL_STACK)
    @test check_inv(test2, (3.0,))
    @test length(NiLangCore.GLOBAL_STACK) == l

    x = 3.0
    @instr PUSH!(x)
    NiLangCore.empty_global_stacks!()
    l = length(NiLangCore.GLOBAL_STACK)
    @test l == 0
end

@testset "copied push/pop stack operations" begin
    NiLangCore.empty_global_stacks!()
    x =0.3
    @instr COPYPUSH!(x)
    @test x === 0.3
    @instr COPYPOP!(x)
    @test x === 0.3
    @instr COPYPUSH!(x)
    x = 0.4
    @test_throws InvertibilityError @instr COPYPOP!(x)
    y = 0.5
    @instr COPYPUSH!(y)
    @instr @invcheckoff COPYPOP!(x)
    @test x == 0.5

    st = []
    x = [0.3]
    @instr COPYPUSH!(st, x)
    @test st[1] !== [0.3]
    @test st[1] ≈ [0.3]

    x =0.3
    st = Float64[]
    @instr COPYPUSH!(st, x)
    @test x === 0.3
    @test length(st) == 1
    @instr COPYPOP!(st, x)
    @test length(st) == 0
    @test x === 0.3
    @instr @invcheckoff COPYPUSH!(st, x)
    @test length(st) == 1
    x = 0.4
    @test_throws InvertibilityError @instr COPYPOP!(st, x)
    @test length(st) == 0

    y = 0.5
    @instr COPYPUSH!(st, y)
    @instr @invcheckoff COPYPOP!(st, x)
    @test x == 0.5

    @i function test(x, x2)
        x2 += x^2
        COPYPUSH!(x)
        x ↔ x2
    end
    @test test(3.0, 0.0) == (9.0, 3.0)
    l = length(NiLangCore.GLOBAL_STACK)
    @test check_inv(test, (3.0, 0.0))
    @test length(NiLangCore.GLOBAL_STACK) == l
end

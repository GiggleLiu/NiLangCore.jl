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
    @test_throws ArgumentError (@instr GLOBAL_STACK[end] ↔ y::∅)
    y = 4.0
    @test_throws ArgumentError (@instr GLOBAL_STACK[end] → y)
    @test_throws BoundsError (@instr @invcheckoff GLOBAL_STACK[end] ↔ y)
    @test_throws ArgumentError (@instr @invcheckoff GLOBAL_STACK[end] → y)
    x = 0.3
    NiLangCore.empty_global_stacks!()
    @instr GLOBAL_STACK[end+1] ↔ x
    @instr GLOBAL_STACK[end] ↔ x::∅
    @test x === 0.3
    @instr @invcheckoff GLOBAL_STACK[end+1] ↔ x
    y = 0.5
    @instr GLOBAL_STACK[end+1] ↔ y
    @instr @invcheckoff GLOBAL_STACK[end] ↔ x::∅
    @test x == 0.5

    x =0.3
    st = Float64[]
    @instr st[end+1] ↔ x
    @test length(st) == 1
    @instr st[end] ↔ x::∅
    @test length(st) == 0
    @test x === 0.3
    @instr st[end+1] ↔ x
    @test length(st) == 1

    y = 0.5
    @instr st[end+1] ↔ y
    @instr @invcheckoff st[end] ↔ x::∅
    @test x == 0.5

    @i function test(x)
        x2 ← zero(x)
        x2 += x^2
        GLOBAL_STACK[end+1] ↔ x
        x::∅ ↔ x2
    end
    @test test(3.0) == 9.0
    l = length(NiLangCore.GLOBAL_STACK)
    @test check_inv(test, (3.0,))
    @test length(NiLangCore.GLOBAL_STACK) == l

    @i function test2(x)
        x2 ← zero(x)
        x2 += x^2
        @invcheckoff GLOBAL_STACK[end+1] ↔ x
        x::∅ ↔ x2
    end
    @test test2(3.0) == 9.0
    l = length(NiLangCore.GLOBAL_STACK)
    @test check_inv(test2, (3.0,))
    @test length(NiLangCore.GLOBAL_STACK) == l

    x = 3.0
    @instr GLOBAL_STACK[end+1] ↔ x
    NiLangCore.empty_global_stacks!()
    l = length(NiLangCore.GLOBAL_STACK)
    @test l == 0
end

@testset "copied push/pop stack operations" begin
    NiLangCore.empty_global_stacks!()
    x =0.3
    @instr GLOBAL_STACK[end+1] ← x
    @test x === 0.3
    @instr GLOBAL_STACK[end] → x
    @test x === 0.3
    @instr GLOBAL_STACK[end+1] ← x
    x = 0.4
    @test_throws InvertibilityError @instr GLOBAL_STACK[end] → x
    y = 0.5
    @instr GLOBAL_STACK[end+1] ← y
    @instr @invcheckoff GLOBAL_STACK[end] → x
    @test x == 0.5

    st = []
    x = [0.3]
    @instr st[end+1] ← x
    @test st[1] !== [0.3]
    @test st[1] ≈ [0.3]

    x =0.3
    st = Float64[]
    @instr ~(st[end] → x)
    @test x === 0.3
    @test length(st) == 1
    @instr ~(st[end+1] ← x)
    @test length(st) == 0
    @test x === 0.3
    @instr @invcheckoff st[end+1] ← x
    @test length(st) == 1
    x = 0.4
    @test_throws InvertibilityError @instr st[end] → x
    @test length(st) == 0

    y = 0.5
    @instr st[end+1] ← y
    @instr @invcheckoff st[end] → x
    @test x == 0.5

    @i function test(x, x2)
        x2 += x^2
        GLOBAL_STACK[end+1] ← x
        x ↔ x2
    end
    @test test(3.0, 0.0) == (9.0, 3.0)
    l = length(NiLangCore.GLOBAL_STACK)
    @test check_inv(test, (3.0, 0.0))
    @test length(NiLangCore.GLOBAL_STACK) == l
end

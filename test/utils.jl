using Test, NiLangCore
using NiLangCore: get_argname, get_ftype, match_function, MyOrderedDict

@testset "match function" begin
    ex = match_function(:(function f(x) x end))
    @test ex[1] == nothing
    @test ex[2] == :f
    @test ex[3] == [:x]
    @test ex[4] == []
    @test length(filter(x->!(x isa LineNumberNode), ex[5])) == 1
    ex = match_function(:(@inline function f(x; y) x end))
    @test ex[1][1] == Symbol("@inline")
    @test ex[1][2] isa LineNumberNode
    @test ex[2] == :f
    @test ex[3] == [Expr(:parameters, :y), :x]
    @test length(filter(x->!(x isa LineNumberNode), ex[5])) == 1
    @test ex[4] == []
    ex = match_function(:(function f(x::T) where T x end))
    @test ex[2] == :f
    @test ex[3] == [:(x::T)]
    @test length(filter(x->!(x isa LineNumberNode), ex[5])) == 1
    @test ex[4] == [:T]
    ex = match_function(:(f(x)=x))
    @test ex[2] == :f
    @test ex[3] == [:x]
    @test length(ex[5]) == 2
    @test ex[4] == []
end

@testset "argname and type" begin
    @test get_argname(:(y=3)) == :y
    @test get_argname(:(y::Int)) == :y
    @test get_argname(:(y::Int=3)) == :y
    @test get_argname(:(f(; k::Int=4)).args[2]) == :(f(; k::Int=4)).args[2]
end

@testset "my ordered dict" begin
    od = MyOrderedDict{Any, Any}()
    od[:a] = 2
    od[:b] = 4
    od[:c] = 7
    @test length(od) == 3
    @test od[:b] == 4
    od[:b] = 1
    @test od[:b] == 1
    delete!(od, :b)
    @test_throws KeyError od[:b]
    @test pop!(od) == (:c, 7)
    @test length(od) == 1
end

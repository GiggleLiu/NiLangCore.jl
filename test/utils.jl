using Test, NiLangCore
using NiLangCore: get_argname, get_ftype, match_function

@testset "match function" begin
    ex = match_function(:(function f(x) x end))
    @test ex[1] == nothing
    @test ex[2] == :f
    @test ex[3] == [:x]
    @test ex[4] == []
    @test length(ex[5]) == 2
    ex = match_function(:(@inline function f(x; y) x end))
    @test ex[1][1] == Symbol("@inline")
    @test ex[1][2] isa LineNumberNode
    @test ex[2] == :f
    @test ex[3] == [Expr(:parameters, :y), :x]
    @test length(ex[5]) == 2
    @test ex[4] == []
    ex = match_function(:(function f(x::T) where T x end))
    @test ex[2] == :f
    @test ex[3] == [:(x::T)]
    @test length(ex[5]) == 2
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

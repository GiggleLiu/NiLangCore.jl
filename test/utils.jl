using Test, NiLangCore
using NiLangCore: get_argname, get_ftype, match_function

@testset "match function" begin
    ex = match_function(:(function f(x) x end))
    @test ex[1] == :f
    @test ex[2] == [:x]
    @test ex[3] == []
    @test length(ex[4]) == 2
    ex = match_function(:(function f(x; y) x end))
    @test ex[1] == :f
    @test ex[2] == [Expr(:parameters, :y), :x]
    @test length(ex[4]) == 2
    @test ex[3] == []
    ex = match_function(:(function f(x::T) where T x end))
    @test ex[1] == :f
    @test ex[2] == [:(x::T)]
    @test length(ex[4]) == 2
    @test ex[3] == [:T]
    ex = match_function(:(f(x)=x))
    @test ex[1] == :f
    @test ex[2] == [:x]
    @test length(ex[4]) == 2
    @test ex[3] == []
end

@testset "argname and type" begin
    @test get_argname(:(y=3)) == :y
    @test get_argname(:(y::Int)) == :y
    @test get_argname(:(y::Int=3)) == :y
end

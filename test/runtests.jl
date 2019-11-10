using NiLangCore
using Test

@testset "instr.jl" begin
    include("instr.jl")
end

@testset "vars.jl" begin
    include("vars.jl")
end

@testset "compile.jl" begin
    include("compile.jl")
end

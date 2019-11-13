using NiLangCore
using Test

@testset "instr.jl" begin
    include("instr.jl")
end

@testset "vars.jl" begin
    include("vars.jl")
end

@testset "interpreter.jl" begin
    include("interpreter.jl")
end

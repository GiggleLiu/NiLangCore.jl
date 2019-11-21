using NiLangCore
using Test

@testset "utils.jl" begin
    include("utils.jl")
end

@testset "instr.jl" begin
    include("instr.jl")
end

@testset "vars.jl" begin
    include("vars.jl")
end

@testset "interpreter.jl" begin
    include("interpreter.jl")
end

@testset "autodiff.jl" begin
    include("autodiff/autodiff.jl")
end

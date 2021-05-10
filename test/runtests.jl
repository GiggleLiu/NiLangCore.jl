using NiLangCore
using Test

@testset "Core.jl" begin
    include("Core.jl")
end

@testset "stack.jl" begin
    include("stack.jl")
end

@testset "lens.jl" begin
    include("lens.jl")
end

@testset "utils.jl" begin
    include("utils.jl")
end

@testset "variable_analysis.jl" begin
    include("variable_analysis.jl")
end

@testset "instr.jl" begin
    include("instr.jl")
end

@testset "vars.jl" begin
    include("vars.jl")
end

@testset "compiler.jl" begin
    include("compiler.jl")
end

using NiLangCore
using Test

@testset "utils.jl" begin
    include("utils.jl")
end

@testset "instr.jl" begin
    include("instr.jl")
end

@testset "invtype.jl" begin
    include("invtype.jl")
end

@testset "vars.jl" begin
    include("vars.jl")
end

@testset "compiler.jl" begin
    include("compiler.jl")
end

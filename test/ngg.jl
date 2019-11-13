using NiLangCore.NGG
using Test

@testset "generate func" begin
    g = make_function(
               :g, #fname
               [
                   Argument(:a, nothing, Unset()),
                   Argument(:b, nothing, Unset())
               ],  # args
               Argument[], # kwargs
               :(a + b) #expression
           )
    @test g(1, 2) == 3
    @test get_ast(g) == :(a+b)
end

function get_ast(::RuntimeFn{Args, Kws, Ex, Name}) where {Args, Kws, Ex, Name}
    @show Ex
    from_type(Ex)
end

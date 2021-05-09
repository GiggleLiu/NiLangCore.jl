using NiLangCore, Test

@testset "update field" begin
    @test NiLangCore.field_update(1+2im, Val(:im), 4) == 1+4im
    struct TestUpdateField1{A, B}
        a::A
    end
    @test NiLangCore.field_update(TestUpdateField1{Int,Float64}(1), Val(:a), 4) == TestUpdateField1{Int,Float64}(4)
    struct TestUpdateField2{A}
        a::A
        function TestUpdateField2(a::T) where T
            new{T}(a)
        end
    end
    @test NiLangCore.field_update(TestUpdateField2(1), Val(:a), 4) == TestUpdateField2(4)

    @test NiLangCore.default_constructor(ComplexF64, 1.0, 2.0) == 1+2im
end

@testset "_zero" begin
    @test _zero(Tuple{Float64, Float32,String,Matrix{Float64},Char,Dict{Int,Int}}) == (0.0, 0f0, "", zeros(0,0), '\0', Dict{Int,Int}())
    @test _zero(ComplexF64) == 0.0 + 0.0im
    @test _zero((1,2.0,"adsf",randn(2,2),'d',Dict(2=>5))) == (0, 0.0,"",zeros(2,2),'\0',Dict(2=>0))
    @test _zero(1+2.0im) == 0.0 + 0.0im
    @test _zero(()) == ()
    @test _zero((1,2)) == (0, 0)
    @test _zero(Symbol) == Symbol("")
    @test _zero(:x) == Symbol("")
end

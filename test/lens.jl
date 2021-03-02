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
end
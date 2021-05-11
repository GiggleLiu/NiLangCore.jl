using Test, NiLangCore
using NiLangCore: SymbolTable, allocate!, deallocate!, operate!, swapvars!, variable_analysis_ex

@testset "variable analysis" begin
    st = SymbolTable()
    # allocate! : not exist
    allocate!(st, :x)
    allocate!(st, :y)
    @test st.existing == [:x, :y]
    # allocate! : existing
    @test_throws InvertibilityError allocate!(st, :x)
    @test st.existing == [:x, :y]
    # deallocate! : not exist
    @test_throws InvertibilityError deallocate!(st, :z)
    # deallocate! : existing
    deallocate!(st, :y)
    @test st.existing == [:x]
    @test st.deallocated == [:y]
    # deallocate! : deallocated
    @test_throws InvertibilityError deallocate!(st, :y)
    # operate! : deallocated
    @test_throws InvertibilityError operate!(st, :y)
    # allocate! : deallocated
    allocate!(st, :y)
    @test st.existing == [:x, :y]
    @test st.deallocated == []
    # operate! : not exist
    operate!(st, :j)
    @test st.unclassified == [:j]
    # operate! : existing
    operate!(st, :y)
    @test st.unclassified == [:j]
    # allocate! unclassified
    @test_throws InvertibilityError allocate!(st, :j)
    # operate! : unclassified
    operate!(st, :j)
    @test st.unclassified == [:j]
    # deallocate! : unclassified
    @test_throws InvertibilityError deallocate!(st, :j)

    # swap both existing
    swapvars!(st, :j, :x)
    @test st.unclassified == [:x]
    @test st.existing == [:j, :y]

    # swap existing - nonexisting
    swapvars!(st, :j, :k)
    @test st.unclassified == [:x, :j]
    @test st.existing == [:k, :y]

    # swap nonexisting - existing
    swapvars!(st, :o, :x)
    @test st.unclassified == [:o, :j, :x]
    @test st.existing == [:k, :y]

    # swap both not existing
    swapvars!(st, :m, :n)
    @test st.unclassified == [:o, :j, :x, :m, :n]

    # push and pop variables
end


@testset "variable analysis" begin
    st = SymbolTable([:x, :y], [], [])
    ex = :((x,y) ↔ (a, b))
    variable_analysis_ex(ex, st)
    @test st.existing == [:a, :b]
    @test st.unclassified == [:x, :y]
    st = SymbolTable([:x, :y], [], [])
    ex = :((x,y) ↔ b)
    variable_analysis_ex(ex, st)
    @test st.existing == [:b]
    @test st.unclassified == [:x, :y]
    ex = :(b ↔ (x,y))
    variable_analysis_ex(ex, st)
    @test st.existing == [:x, :y]
    @test st.unclassified == [:b]

    st = SymbolTable([:x, :y], [], [])
    ex = :(b ↔ x)
    variable_analysis_ex(ex, st)
    @test st.existing == [:b, :y]
    @test st.unclassified == [:x]

    st = SymbolTable([], [], [])
    ex = :(b ↔ (x, y))
    variable_analysis_ex(ex, st)
    @test st.existing == []
    @test st.unclassified == [:b, :x, :y]
end
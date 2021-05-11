function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    Base.precompile(Tuple{typeof(gen_ifunc),Module,Expr})   # time: 1.9265794
    Base.precompile(Tuple{typeof(render_arg),Expr})   # time: 0.045112614
    Base.precompile(Tuple{typeof(dual_ex),Module,Expr})   # time: 0.04482814
    Base.precompile(Tuple{typeof(memkernel),Expr})   # time: 0.042466346
    Base.precompile(Tuple{typeof(functionfoot),Vector{Any}})   # time: 0.028968
    Base.precompile(Tuple{PlusEq{typeof(cos)},Float64,Float64})   # time: 0.024845816
    Base.precompile(Tuple{typeof(assign_ex),Expr,Expr,Bool})   # time: 0.02307638
    Base.precompile(Tuple{typeof(pushvar!),Vector{Symbol},Expr})   # time: 0.008682777
    Base.precompile(Tuple{typeof(precom_opm),Symbol,Symbol,Expr})   # time: 0.024082141
    Base.precompile(Tuple{typeof(precom_opm),Symbol,Expr,Expr})   # time: 0.014433064
    Base.precompile(Tuple{PlusEq{typeof(sin)},Float64,Float64})   # time: 0.004275546
    Base.precompile(Tuple{typeof(get_argname),Expr})   # time: 0.00546523
    Base.precompile(Tuple{typeof(forstatement),Symbol,Expr,Vector{Any},CompileInfo,Nothing})   # time: 0.003776189
    Base.precompile(Tuple{typeof(julia_usevar!),SymbolTable,Expr})   # time: 0.049144164
    Base.precompile(Tuple{typeof(julia_usevar!),SymbolTable,Symbol})   # time: 0.003254819
    Base.precompile(Tuple{typeof(precom_ex),Module,LineNumberNode,PreInfo})   # time: 0.001450645
    Base.precompile(Tuple{typeof(precom_body),Module,SubArray{Any, 1, Vector{Any}, Tuple{UnitRange{Int64}}, true},PreInfo})   # time: 0.001423381
    Base.precompile(Tuple{typeof(precom_body),Module,Vector{Any},PreInfo})   # time: 0.001126582
    Base.precompile(Tuple{typeof(variable_analysis_ex),Expr,SymbolTable})   # time: 0.31368348
    Base.precompile(Tuple{typeof(precom_ex),Module,Expr,PreInfo})   # time: 0.20325074
    Base.precompile(Tuple{typeof(compile_ex),Module,Expr,CompileInfo})   # time: 0.19640462
    Base.precompile(Tuple{Core.kwftype(typeof(almost_same)),NamedTuple{(:atol,), Tuple{Float64}},typeof(almost_same),Vector{Int64},Vector{Int64}})   # time: 0.080980584
    Base.precompile(Tuple{typeof(unzipped_broadcast),PlusEq{typeof(*)},Tuple{Float64, Float64},Tuple{Float64, Float64},Tuple{Float64, Float64}})   # time: 0.07962415
    Base.precompile(Tuple{typeof(unzipped_broadcast),PlusEq{typeof(identity)},Vector{Float64},Vector{Float64}})   # time: 0.060837016
    Base.precompile(Tuple{typeof(almost_same),Vector{Float64},Vector{Float64}})   # time: 0.043818954
    Base.precompile(Tuple{typeof(functionfoot),Vector{Expr}})   # time: 0.03988443
    Base.precompile(Tuple{typeof(assign_ex),Expr,Symbol,Bool})   # time: 0.03273888
    Base.precompile(Tuple{typeof(assign_ex),Expr,Float64,Bool})   # time: 0.031806484
    Base.precompile(Tuple{typeof(Base.show_function),IOContext{IOBuffer},PlusEq{typeof(abs2)},Bool})   # time: 0.025549678
    Base.precompile(Tuple{typeof(precom_opm),Symbol,Symbol,Symbol})   # time: 0.023482375
    Base.precompile(Tuple{PlusEq{typeof(^)},ComplexF64,ComplexF64,Vararg{ComplexF64, N} where N})   # time: 0.018600011
    Base.precompile(Tuple{typeof(functionfoot),Vector{Symbol}})   # time: 0.018092046
    Base.precompile(Tuple{PlusEq{typeof(tan)},Float64,Float64})   # time: 0.015275044
    Base.precompile(Tuple{typeof(precom_if),Module,Expr,PreInfo})   # time: 0.010871046
    Base.precompile(Tuple{MinusEq{typeof(^)},Union{Float64, ComplexF64},Union{Float64, ComplexF64},Union{Float64, ComplexF64}})   # time: 0.010170748
    Base.precompile(Tuple{PlusEq{typeof(*)},Float64,Float64,Vararg{Float64, N} where N})   # time: 0.007921303
    Base.precompile(Tuple{PlusEq{typeof(+)},Float64,Float64,Vararg{Float64, N} where N})   # time: 0.00782437
    Base.precompile(Tuple{typeof(_isconst),Expr})   # time: 0.007764913
    Base.precompile(Tuple{typeof(swapvars!),SymbolTable,Expr,Expr})   # time: 0.007498742
    Base.precompile(Tuple{typeof(Base.show_function),IOContext{IOBuffer},PlusEq{typeof(angle)},Bool})   # time: 0.007020253
    Base.precompile(Tuple{typeof(precom_opm),Symbol,Expr,Int64})   # time: 0.006372358
    Base.precompile(Tuple{typeof(precom_opm),Symbol,Symbol,Int64})   # time: 0.006353995
    Base.precompile(Tuple{typeof(Base.show_function),IOContext{IOBuffer},PlusEq{typeof(abs)},Bool})   # time: 0.005321797
    Base.precompile(Tuple{typeof(unzipped_broadcast),PlusEq{typeof(*)},Vector{Float64},Vector{Float64},Vector{Float64}})   # time: 0.005210431
    Base.precompile(Tuple{typeof(isreversible),Function,Type{Tuple{Number, Any, Any}}})   # time: 0.003735743
    Base.precompile(Tuple{typeof(removedot),Symbol})   # time: 0.003666485
    Base.precompile(Tuple{PlusEq{typeof(*)},Float64,Int64,Vararg{Any, N} where N})   # time: 0.003475684
    Base.precompile(Tuple{MinusEq{typeof(*)},Float64,Int64,Vararg{Any, N} where N})   # time: 0.003429493
    Base.precompile(Tuple{PlusEq{typeof(*)},Float64,Float64,Vararg{Any, N} where N})   # time: 0.002768054
    Base.precompile(Tuple{MinusEq{typeof(*)},Float64,Float64,Vararg{Any, N} where N})   # time: 0.002728645
    Base.precompile(Tuple{typeof(assign_vars),SubArray{Any, 1, Vector{Any}, Tuple{UnitRange{Int64}}, true},Expr,Bool})   # time: 0.00237789
    Base.precompile(Tuple{typeof(unzipped_broadcast),MinusEq{typeof(*)},Vector{Float64},Vector{Float64},Vector{Float64}})   # time: 0.002377491
    Base.precompile(Tuple{typeof(almost_same),Tuple{Float64, Float64, Vector{Float64}, Vector{Float64}},Tuple{Float64, Float64, Vector{Float64}, Vector{Float64}}})   # time: 0.002303422
    Base.precompile(Tuple{typeof(unzipped_broadcast),MinusEq{typeof(identity)},Vector{Float64},Vector{Float64}})   # time: 0.00225225
    Base.precompile(Tuple{typeof(dual_swap),Expr,Expr})   # time: 0.002167955
    Base.precompile(Tuple{PlusEq{typeof(sin)},ComplexF64,ComplexF64})   # time: 0.002135965
    Base.precompile(Tuple{typeof(whilestatement),Expr,Expr,Vector{Any},CompileInfo})   # time: 0.001927632
    Base.precompile(Tuple{typeof(variable_analysis_ex),LineNumberNode,SymbolTable})   # time: 0.001729012
    Base.precompile(Tuple{typeof(compile_ex),Module,LineNumberNode,CompileInfo})   # time: 0.001608265
    Base.precompile(Tuple{typeof(assign_ex),Int64,Expr,Bool})   # time: 0.001299157
    Base.precompile(Tuple{typeof(_pop_value),Expr})   # time: 0.001298544
    Base.precompile(Tuple{typeof(assign_ex),Symbol,Symbol,Bool})   # time: 0.001287453
    Base.precompile(Tuple{typeof(assign_ex),Float64,Expr,Bool})   # time: 0.001275525
    Base.precompile(Tuple{MinusEq{typeof(/)},Float64,Float64,Vararg{Any, N} where N})   # time: 0.001080575
    Base.precompile(Tuple{typeof(_push_value),Expr,Expr,Bool})   # time: 0.00106306
    Base.precompile(Tuple{MinusEq{typeof(*)},Float64,Float64,Vararg{Float64, N} where N})   # time: 0.001049093
    Base.precompile(Tuple{PlusEq{typeof(/)},Float64,Float64,Vararg{Any, N} where N})   # time: 0.00102371
end

function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    isdefined(NiLangCore, Symbol("##assign_ex#32")) && precompile(Tuple{getfield(NiLangCore, Symbol("##assign_ex#32")), Bool, typeof(NiLangCore.assign_ex), Symbol, Expr})
    isdefined(NiLangCore, Symbol("##assign_ex#34")) && precompile(Tuple{getfield(NiLangCore, Symbol("##assign_ex#34")), Bool, typeof(NiLangCore.assign_ex), Expr, Expr})
    isdefined(NiLangCore, Symbol("##assign_vars#30")) && precompile(Tuple{getfield(NiLangCore, Symbol("##assign_vars#30")), Bool, typeof(NiLangCore.assign_vars), Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}, Symbol})
    isdefined(NiLangCore, Symbol("##s12#1")) && precompile(Tuple{getfield(NiLangCore, Symbol("##s12#1")), Int, Int, Int, Int, Int, Int})
    isdefined(NiLangCore, Symbol("##s70#25")) && precompile(Tuple{getfield(NiLangCore, Symbol("##s70#25")), Int, Int, Int, Int, Int})
    isdefined(NiLangCore, Symbol("#@assignback")) && precompile(Tuple{getfield(NiLangCore, Symbol("#@assignback")), LineNumberNode, Module, Int, Int})
    isdefined(NiLangCore, Symbol("#@i")) && precompile(Tuple{getfield(NiLangCore, Symbol("#@i")), LineNumberNode, Module, Int})
    isdefined(NiLangCore, Symbol("#@invcheck")) && precompile(Tuple{getfield(NiLangCore, Symbol("#@invcheck")), LineNumberNode, Module, Int, Int})
    isdefined(NiLangCore, Symbol("#@with")) && precompile(Tuple{getfield(NiLangCore, Symbol("#@with")), LineNumberNode, Module, Int})
    isdefined(NiLangCore, Symbol("#assign_ex##kw")) && precompile(Tuple{getfield(NiLangCore, Symbol("#assign_ex##kw")), NamedTuple{(:invcheck,), Tuple{Bool}}, typeof(NiLangCore.assign_ex), Expr, Expr})
    isdefined(NiLangCore, Symbol("#assign_vars##kw")) && precompile(Tuple{getfield(NiLangCore, Symbol("#assign_vars##kw")), NamedTuple{(:invcheck,), Tuple{Bool}}, typeof(NiLangCore.assign_vars), Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}, Symbol})
    precompile(Tuple{typeof(NiLangCore._gen_ifunc), Expr})
    precompile(Tuple{typeof(NiLangCore._instr), Type{Int}, Int, Expr, Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}, NiLangCore.CompileInfo, Bool, Bool})
    precompile(Tuple{typeof(NiLangCore._instr), Type{Int}, Int, Symbol, Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}, NiLangCore.CompileInfo, Bool, Bool})
    precompile(Tuple{typeof(NiLangCore._replace_opmx), Symbol})
    precompile(Tuple{typeof(NiLangCore._typeof), typeof(identity)})
    precompile(Tuple{typeof(NiLangCore.compile_body), Array{Any, 1}, NiLangCore.CompileInfo})
    precompile(Tuple{typeof(NiLangCore.compile_body), Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}, NiLangCore.CompileInfo})
    precompile(Tuple{typeof(NiLangCore.compile_ex), Expr, NiLangCore.CompileInfo})
    precompile(Tuple{typeof(NiLangCore.compile_ex), LineNumberNode, NiLangCore.CompileInfo})
    precompile(Tuple{typeof(NiLangCore.compile_range), Expr})
    precompile(Tuple{typeof(NiLangCore.dotgetdual), Symbol})
    precompile(Tuple{typeof(NiLangCore.dual_body), Array{Any, 1}})
    precompile(Tuple{typeof(NiLangCore.dual_ex), Expr})
    precompile(Tuple{typeof(NiLangCore.dual_fname), Symbol})
    precompile(Tuple{typeof(NiLangCore.dual_if), Expr})
    precompile(Tuple{typeof(NiLangCore.flushancs), Array{Any, 1}, NiLangCore.PreInfo})
    precompile(Tuple{typeof(NiLangCore.forstatement), Symbol, Expr, Array{Any, 1}, NiLangCore.CompileInfo, Nothing})
    precompile(Tuple{typeof(NiLangCore.get_argname), Expr})
    precompile(Tuple{typeof(NiLangCore.get_argname), Symbol})
    precompile(Tuple{typeof(NiLangCore.get_dotpipline!), Expr, Array{Any, 1}})
    precompile(Tuple{typeof(NiLangCore.get_ftype), Expr})
    precompile(Tuple{typeof(NiLangCore.get_ftype), Symbol})
    precompile(Tuple{typeof(NiLangCore.get_pipline!), Expr, Array{Any, 1}})
    precompile(Tuple{typeof(NiLangCore.getdual), Symbol})
    precompile(Tuple{typeof(NiLangCore.ibcast), Type{Int}, Tuple{Float64, Float64, Array{Float64, 1}, Array{Float64, 1}, Array{Float64, 1}}})
    precompile(Tuple{typeof(NiLangCore.invfuncfoot), Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}})
    precompile(Tuple{typeof(NiLangCore.lens_compile), Expr, Symbol, Symbol})
    precompile(Tuple{typeof(NiLangCore.match_function), Expr})
    precompile(Tuple{typeof(NiLangCore.notkey), Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}})
    precompile(Tuple{typeof(NiLangCore.precom), Expr})
    precompile(Tuple{typeof(NiLangCore.precom_body), Array{Any, 1}, NiLangCore.PreInfo})
    precompile(Tuple{typeof(NiLangCore.precom_body), Base.SubArray{Any, 1, Array{Any, 1}, Tuple{Base.UnitRange{Int64}}, true}, NiLangCore.PreInfo})
    precompile(Tuple{typeof(NiLangCore.precom_ex), Expr, NiLangCore.PreInfo})
    precompile(Tuple{typeof(NiLangCore.precom_if), Expr})
    precompile(Tuple{typeof(NiLangCore.precom_opm), Symbol, Expr, Expr})
    precompile(Tuple{typeof(NiLangCore.precom_opm), Symbol, Symbol, Expr})
    precompile(Tuple{typeof(NiLangCore.removedot), Symbol})
    precompile(Tuple{typeof(NiLangCore.rmlines), Expr})
    precompile(Tuple{typeof(NiLangCore.rmlines), Int})
    precompile(Tuple{typeof(NiLangCore.startwithdot), Symbol})
    precompile(Tuple{typeof(NiLangCore.with), Expr})
    precompile(Tuple{typeof(NiLangCore.wrap_tuple), Float64})
end

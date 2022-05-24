module NiLangCore
using MLStyle
using TupleTools

include("lens.jl")

include("utils.jl")
include("symboltable.jl")
include("stack.jl")
include("Core.jl")
include("vars.jl")

include("instr.jl")
include("dualcode.jl")
include("preprocess.jl")
include("variable_analysis.jl")
include("compiler.jl")
include("checks.jl")

if Base.VERSION >= v"1.4.2"
    include("precompile.jl")
    _precompile_()
end

end # module

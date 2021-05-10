module NiLangCore
using MatchCore
using TupleTools

#include("ngg/ngg.jl")
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

end # module

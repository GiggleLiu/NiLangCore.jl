module NiLangCore
using GeneralizedGenerated
using MLStyle

include("utils.jl")
include("vars.jl")
include("Core.jl")

include("instr.jl")
include("dualcode.jl")
include("preprocess.jl")
include("compile.jl")
include("gradcode.jl")
include("checks.jl")

end # module

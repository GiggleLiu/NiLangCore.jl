module NiLangCore
using GeneralizedGenerated
using MLStyle

include("utils.jl")
include("Core.jl")
include("vars.jl")

include("instr.jl")
include("dualcode.jl")
include("preprocess.jl")
include("interpretor.jl")
include("gradcode.jl")
include("checks.jl")

include("ngg/ngg.jl")

end # module

module NiLangCore
using MLStyle

#include("ngg/ngg.jl")

include("utils.jl")
include("Core.jl")
include("vars.jl")

include("instr.jl")
include("dualcode.jl")
include("preprocess.jl")
include("interpreter.jl")
#include("gradcode.jl")
include("autodiff/autodiff.jl")
include("checks.jl")

end # module

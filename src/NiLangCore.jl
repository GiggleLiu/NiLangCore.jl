module NiLangCore
using MLStyle
using TupleTools

export RevType, invkernel, chfield

#include("ngg/ngg.jl")
include("lens.jl")

include("utils.jl")
include("Core.jl")
include("invtype.jl")
include("vars.jl")

include("instr.jl")
include("dualcode.jl")
include("preprocess.jl")
include("interpreter.jl")
include("checks.jl")

include("autodiff/autodiff.jl")
export ADCore

end # module

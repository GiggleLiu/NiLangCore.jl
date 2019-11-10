module NiLangCore
using GeneralizedGenerated
using MLStyle

include("utils.jl")
include("capture.jl")
include("vars.jl")
include("Core.jl")

include("instr.jl")
include("invcode.jl")
include("preprocess.jl")
include("compile.jl")
include("gradcode.jl")
include("checks.jl")

end # module

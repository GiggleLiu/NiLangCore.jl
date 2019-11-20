module AD
using ..NiLangCore
using MLStyle
import ..NiLangCore: val, chfield

export GVar, grad, Loss

include("vars.jl")
include("gradfunc.jl")
include("checks.jl")

end

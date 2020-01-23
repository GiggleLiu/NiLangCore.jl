module ADCore
using ..NiLangCore
using MLStyle
import ..NiLangCore: chfield, value

export GVar, grad, Loss, NoGrad, @nograd

include("vars.jl")
include("gradfunc.jl")
include("checks.jl")

end

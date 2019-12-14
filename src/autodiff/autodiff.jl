module ADCore
using ..NiLangCore
using MLStyle
import ..NiLangCore: val, chfield, value

export GVar, grad, Loss, NoGrad, TaylorVar

include("vars.jl")
include("gradfunc.jl")
include("checks.jl")

end

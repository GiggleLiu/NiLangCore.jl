# NiLangCore

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://GiggleLiu.github.io/NiLangCore.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://GiggleLiu.github.io/NiLangCore.jl/dev)
[![Build Status](https://travis-ci.com/GiggleLiu/NiLangCore.jl.svg?branch=master)](https://travis-ci.com/GiggleLiu/NiLangCore.jl)
[![Codecov](https://codecov.io/gh/GiggleLiu/NiLangCore.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/GiggleLiu/NiLangCore.jl)

Core package for reversible language.

```julia
@i function f(x, y)
    x + y
end

# forward and backward excution
x = Var(1.0)
y = Var(1.0)
f(x, y)  # x= 2.0
(~f)(x, y)  # x= 1.0

# obtain gradients
gf = g(f)
@newfloats gx gy
gf(x, y, gx, gy)

# obtain second order gradients
ggf = g(gf)
@newfloats ggx ggy
gf(x, y, gx, gy, x2, y2, gx2, gy2)
```

# NiLangCore

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://GiggleLiu.github.io/NiLangCore.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://GiggleLiu.github.io/NiLangCore.jl/dev)
[![Build Status](https://travis-ci.com/GiggleLiu/NiLangCore.jl.svg?branch=master)](https://travis-ci.com/GiggleLiu/NiLangCore.jl)
[![Codecov](https://codecov.io/gh/GiggleLiu/NiLangCore.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/GiggleLiu/NiLangCore.jl)

Core package for reversible language.

## Examples
1. Define a pair of dual function
```julia
function ⊕(a!, b)
    @assign val(a!) val(a!) + val(b)
    a!, b
end
function ⊖(a!, b)
    @assign val(a!) val(a!) - val(b)
    a!, b
end
const _add = ⊕
const _sub = ⊖
@dual _add _sub
```

2. Define a function
```julia
@i test(a, b)
    a ⊖ b
end

# obtain the gradient
test'(0.5, 0.3)
```

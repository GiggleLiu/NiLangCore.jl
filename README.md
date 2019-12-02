# NiLangCore

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

## Duality
```
a += b <--> a -= b
a ⊻= b <--> a ⊻= b
@anc x = 0.0 <--> @deanc x =0.0
if (precond, postcond) ... else ... end <--> if (postcond, precond) ... else ... end
while (precond, postcond) ... end <--> while (postcond, precond) ... end
for i=start:step:stop ... end <--> for i=stop:-step:start ... end
@safe ... <--> @safe ...
```

Duality of types
```
Bundle{T}(::T) <--> (~Bundle{T})(::Bundle{T})
```

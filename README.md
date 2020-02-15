# NiLangCore

The core package for reversible eDSL NiLang.

[![Build Status](https://travis-ci.com/GiggleLiu/NiLangCore.jl.svg?branch=master)](https://travis-ci.com/GiggleLiu/NiLangCore.jl)
[![Codecov](https://codecov.io/gh/GiggleLiu/NiLangCore.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/GiggleLiu/NiLangCore.jl)

**Warning**
Requires Julia version >= 1.3.

## Examples
1. Define a pair of dual instructions
```julia
julia> using NiLangCore

julia> function ADD(a!::Number, b::Number)
           a! + b, b
       end
ADD (generic function with 3 methods)

julia> function SUB(a!::Number, b::Number)
           a! - b, b
       end
SUB (generic function with 3 methods)
```

2. Define a reversible function
```julia
julia> @i function test(a, b)
           SUB(a, b)
       end
```

## Reversible IR

```julia
julia> using NiLangCore

julia> @code_reverse x += f(y)
:(x -= f(y))

julia> @code_reverse x .+= f.(y)
:(x .-= f.(y))

julia> @code_reverse x ⊻= f(y)
:(x ⊻= f(y))

julia> @code_reverse @anc x = zero(T)
:(#= /home/leo/.julia/dev/NiLangCore/src/dualcode.jl:79 =# @deanc x = zero(T))

julia> @code_reverse begin y += f(x) end
quote
    #= /home/leo/.julia/dev/NiLangCore/src/dualcode.jl:82 =#
    y -= f(x)
    #= REPL[52]:1 =#
end

julia> julia> @code_reverse if (precond, postcond) y += f(x) else y += g(x) end
:(if (postcond, precond)
      #= /home/leo/.julia/dev/NiLangCore/src/dualcode.jl:69 =#
      y -= f(x)
      #= REPL[48]:1 =#
  else
      #= /home/leo/.julia/dev/NiLangCore/src/dualcode.jl:69 =#
      y -= g(x)
      #= REPL[48]:1 =#
  end)

julia> @code_reverse while (precond, postcond) y += f(x) end
:(while (postcond, precond)
      #= /home/leo/.julia/dev/NiLangCore/src/dualcode.jl:72 =#
      y -= f(x)
      #= REPL[49]:1 =#
  end)

julia> @code_reverse for i=start:step:stop y += f(x) end
:(for i = stop:-step:start
      #= /home/leo/.julia/dev/NiLangCore/src/dualcode.jl:76 =#
      y -= f(x)
      #= REPL[50]:1 =#
  end)

julia> @code_reverse @safe println(x)
:(#= /home/leo/.julia/dev/NiLangCore/src/dualcode.jl:81 =# @safe println(x))
```

Additional macro tools includes

* `@code_preprocess`, preprocess user input to a legal reversible IR.
* `@code_interpret`, interpret reversible IR to native Julia code.

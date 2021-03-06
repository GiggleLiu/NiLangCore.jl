# NiLangCore

The core package for reversible eDSL NiLang.

![CI](https://github.com/GiggleLiu/NiLangCore.jl/workflows/CI/badge.svg)
[![codecov](https://codecov.io/gh/GiggleLiu/NiLangCore.jl/branch/master/graph/badge.svg?token=ReCkoV9Pgp)](https://codecov.io/gh/GiggleLiu/NiLangCore.jl)

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

julia> @dual ADD SUB
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

julia> @code_reverse x ← zero(T)
:(x → zero(T))

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
:(@from !postcond while precond
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


## A note on symbols
The `←` (\leftarrow + TAB) operation copies B to A, its inverse is `→` (\rightarrow + TAB)
* push into a stack, `A[end+1] ← B` => `[A..., B], B`
* add a key-value pair into a dict, `A[i] ← B` => `{A..., i=>B}, B`
* allocate a new ancilla, `(A = ∅) ← B` => `(A = B), B`

The `↔` (\leftrightarrow + TAB) operation swaps B and A, it is self reversible
* swap two variables, `A ↔ B` => `B, A`
* transfer into a stack, `A[end+1] ↔ B` => `[A..., B], ∅`
* transfer a key-value pair into a dict, `A[i] ↔ B` => `haskey ? {(A\A[i])..., i=>B}, A[i] : {A..., i=>B}, ∅`
* transfer the value of two variables, `(A = ∅) ↔ B` => `(A = B), ∅`

One can use `var::∅` to annotate `var` as a fresh new variable (only new variables can be allocated), use `var[end+1]` to represent stack top for push and `var[end]` for stack top for pop.
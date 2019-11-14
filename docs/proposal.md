# NiLang

## Requirements
```julia
# variable with `!` are changed.
# ⊕ and ⊖ represents `+=` and `-=`
# variables can not be either assigned removed.
# input variables match output variables exactly.
@i function f(x!, y)
    x! ⊕ y
end

# 1. forward and backward excution
x = 1.0
y = 1.0
f(x, y)  # x == 2.0
(~f)(x, y)  # x == 1.0


# 2. obtain gradients
(x, y) = f'((x, y); loss=x)
gx = x.g
gy = y.g

# 2. obtain higher order gradients
(x, y) = f''((x, y); loss=x)
ggx = x.g.g
ggy = y.g.g

# Here, `x` is the loss, we want to obtain the gradients dx/dx and dx/dy.
# Gradients are stored in another tape (like an image tape of input variables).
```

## Schetch of current design
### Interpreter Rules

Inverse Rules: `Forward (Inverse) Rule <-> Inverse (Forward) Rule`
* `@anc x::Float64` <-> `@deanc x::Float64`  # introduce ancilla
* `@gradalloc args...` <-> `@graddealloc args...`  # allocate gradient space
* `x ⊕ y` <-> `x ⊖ y`
* `f(args...)` <-> `~f(args...)`
* `if (precon, postcon) ... else ... end` <-> `if (postcon, precon) ... else ... end`
* ...

Interpreter Rules: `Forward Rule -> Native Julia Code`
* `@safe ex` -> `ex`  # safe expression that does not harm invertibility
* `f(args...)` -> `args... = f(args...)`  # to avoid using mutable structures
* `if (precon, postcon) ... else ... end` -> `if precon ... else ... end; @invcheck postcon`
* ...

To excute an instruction/function, use `@instr f(args...)`, it is equivalent to `args... = f(args...)`.

### Gradients
Gradients are now Implemented in a multiple dispatch way!
`GVar` is a variable with gradient field, `@gradalloc x` is equivalent to `x = GVar(x)`.
```julia
@i function ⊖(a!::GVar, b)
    a!.x ⊖ b.x  # normal run
    @maybe b.g ⊕ a!.g  # operation to gradient space
end
```

The gradient function is implemented as
```julia
# NOTE:
# 1. f' == Grad(f)
# 2. `loss` is one of the inputs
@i function (g::Grad)(args...; loss)
    # foward pass, args are variables
    g.f(args...)
    # allocate gradient space, it will change the type of variables to `Grad`!
    @gradalloc x y
    loss.g ⊕ 1
    # NOTE:
    # (x_out, y_out, dL/gx_out, dL/gy_out) -> (x_out, y_out, dL/gx_in, dL/gx_in)
    # i.e. applying a jacobian to gradient space: `J_f * [gx, gy]`
    # 2. should compile `f'` automatically
    ~g.f(args...)
end
```

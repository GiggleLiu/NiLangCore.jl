# NiLang

## Requirements
```julia
# variable with `!` are changed.
@i function f(x!, y)
    x + y
end

# 1. forward and backward excution
x = GRef(1.0)
y = GRef(1.0)
f(x, y)  # x == 2.0
(~f)(x, y)  # x == 1.0

# 2. obtain gradients
@i function gf(x, y, gx, gy)
    f(x, y)
    # NOTE:
    # 1. f' implements the chain rule,
    # (x_out, y_out, dL/gx_out, dL/gy_out) -> (x_out, y_out, dL/gx_in, dL/gx_in)
    # i.e. applying a jacobian to gradient space: `J_f * [gx, gy]`
    # 2. should compile `f'` automatically
    f'(x, y, gx, gy)
end
# NOTE: `gx` is the loss
gx, gy = GRef(1.0), GRef(0.0)
gf(x, y, gx, gy)  # gx == gy == 1.0

# 3. higher order gradients
@i function ggf(x, y, gx, gy, ggx, ggy)
    gf(x, y, gx, gy)
    # NOTE:
    # 1. x, y are not changed, the gradient of identity mapping is not
    # of interest hence set to nothing and will not be computed at runtime.
    # see `@maybe` macro for reference.
    # 2. should compile `f''` automatically, since `gf'` calls `f''`.
    gf'(x, y, gx, gy, nothing, nothing, ggx, ggy)
end
# NOTE: `x_out` is the loss
gx, gy = GRef(1.0), GRef(0.0)
ggx, ggy = GRef(1.0), GRef(0.0)
ggf(x, y, gx, gy, ggx, ggy)  # obtain dL^2/dxdx, dL^2/dxdy
ggx, ggy = GRef(0.0), GRef(1.0)
ggf(x, y, gx, gy, ggx, ggy)  # obtain dL^2/dydx, dL^2/dydy

# 3. obtain second order gradients
@i function f2(out! x, y)
    out ⊕ x * y
end

@newfloats gx, gy, x2, y3, gx2, gy2
gx = GRef(0.0)
gy = GRef(0.0)
gx2 =  ggy
f2''(x, y, gx, gy, x2, y2, ggx, ggy)
```

## Schetch of current design
#### correctness
`check_inv(f, (args...))` and `check_inv(f, (args...))`

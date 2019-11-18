export check_inv
export ng, check_grad
export ngradient, gradient

isvar(x) = false
isvar(x::AbstractFloat) = true
isvar(x::AbstractArray{T}) where T<:AbstractFloat = true

function tset(vfunc::Function, tp::Tuple, iloss)
    map(i->i===iloss ? vfunc(tp[i]) : tp[i], 1:length(tp))
end
function tset(val, tp::Tuple, iloss)
    map(i->i===iloss ? val : tp[i], 1:length(tp))
end

function gradient(f, args, vars)
    gargs = f'(args...)
    return [x[] for x in grad.(gargs) if x!==nothing]
end

function world_similar(a, b; atol::Real=1e-8, verbose::Bool=false)
    for (xa, xb) in zip(a, b)
        if !isapprox(xa, xb; atol=atol)
            verbose && println("$xa does not match $xb")
            return false
        end
    end
    return true
end

function check_inv(f, args; atol::Real=1e-8, verbose::Bool=false)
    args0 = deepcopy(args)
    args = f(args...)
    args = (~f)(args...)
    world_similar(args0, args, atol=atol, verbose=verbose)
end

function ng(f, args, iloss, x::Reg; δ=1e-5)
    args = tset(x->x+δ/2, args, iloss)
    args = f(args...)
    pos = args[iloss]
    args = (~f)(args...)
    args = tset(x->x-δ, args, iloss)
    args = f(args...)
    neg = args[iloss]
    args = (~f)(args...)
    args = tset(x->x+δ/2, args, iloss)
    (pos-neg)/δ
end

function ng(f, args, iloss, x::AbstractArray; δ=1e-5)
    res = zero(x)
    for i = 1:length(x)
        res[i] = ng(f, args, iloss, x[i]; δ=δ)
    end
end

function ngradient(f, args, vars)
    iloss = findfirst(x->x<:Loss, typeof.(args))
    @show args, iloss
    map(x-> ng(f, args, iloss, x), vars)
end

function check_grad(f, args; atol::Real=1e-8, verbose::Bool=false)
    vars = ((x for x in args if isvar(x))...,)
    initial_vars = deepcopy(vars)
    ngs = ngradient(f, args, vars)
    gs = gradient(f, args, vars)
    verbose && @show ngs
    verbose && @show gs
    @show ngs
    @show gs
    if !all(isapprox.(ngs, gs, atol=atol))
        verbose && println("gradient not match.")
        return false
    end

    if !world_similar(initial_vars, vars, atol=atol, verbose=verbose)
        verbose && println("world changed during obtaining gradient.")
        return false
    end
    return true
end

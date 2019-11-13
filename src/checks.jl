export check_inv
export ng, check_grad
export ngradient, gradient

isvar(x) = false
isvar(x::Reg{T}) where T<:AbstractFloat = true
isvar(x::AbstractVarArray{T}) where T<:AbstractFloat = true

zerovar(::Reg{T}) where T = Var(zero(T))
zerovar(::T) where T = Var(zero(T))
zerovar(::ArrayElem{T}) where T = nothing
zerovar(x::AbstractVarArray) = zero(x)
zerovar(x::AbstractArray) = Var(zero(x))

function gradient(f, args, vars, loss)
    gargs = [isvar(x) ? zerovar(x) : nothing for x in args]
    f(args...)
    gargs[findfirst(x->x===(loss), args)][] = 1
    (f')(args..., gargs...)
    return [x[] for x in gargs if x!==nothing]
end

function world_similar(a, b; atol::Real=1e-8, verbose::Bool=false)
    for (xa, xb) in zip(a, b)
        if xa isa Var
            if !isapprox(xa[], xb[]; atol=atol)
                verbose && println("$xa does not match $xb")
                return false
            end
        else
            if !isapprox(xa, xb; atol=atol)
                verbose && println("$xa does not match $xb")
                return false
            end
        end
    end
    return true
end

function check_inv(f, args; atol::Real=1e-8, verbose::Bool=false)
    args0 = deepcopy(args)
    f(args...)
    (~f)(args...)
    world_similar(args0, args, atol=atol, verbose=verbose)
end

function ng(f, args, y, x::Reg; δ=1e-5)
    x[] += δ/2
    f(args...)
    pos = y[]
    (~f)(args...)
    x[] -= δ
    f(args...)
    neg = y[]
    (~f)(args...)
    x[] += δ/2
    (pos-neg)/δ
end

function ng(f, args, y, x::AbstractVarArray; δ=1e-5)
    res = zero(x[])
    for i = 1:length(x)
        res[i] = ng(f, args, y, x[i]; δ=δ)
    end
end

function ngradient(f, args, vars, loss)
    map(x-> ng(f, args, loss, x), vars)
end

function check_grad(f, args; loss, atol::Real=1e-8, verbose::Bool=false)
    vars = filter(isvar, [args...])
    initial_vars = deepcopy(vars)
    ngs = ngradient(f, args, vars, loss)
    gs = gradient(f, args, vars, loss)
    verbose && @show ngs
    verbose && @show gs
    if !isapprox(ngs, gs, atol=atol)
        verbose && println("gradient not match.")
        return false
    end

    if !world_similar(initial_vars, vars, atol=atol, verbose=verbose)
        verbose && println("world changed during obtaining gradient.")
        return false
    end
    return true
end

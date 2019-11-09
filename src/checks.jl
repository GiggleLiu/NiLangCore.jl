export check_inv
export ng, check_grad
export ngradient, gradient

isvar(x) = false
isvar(x::Ref{T}) where T<:AbstractFloat = true
isvar(x::AbstractGArray{T}) where T<:AbstractFloat = true

zerovar(::Ref{T}) where T = GRef(zero(T))
zerovar(::T) where T = GRef(zero(T))
zerovar(::GRefArray{T}) where T = nothing
zerovar(x::AbstractGArray) = zero(x)
zerovar(x::AbstractArray) = GRef(zero(x))

function gradient(f, args, vars, loss)
    gargs = [isvar(x) ? zerovar(x) : nothing for x in args]
    f(args...)
    gargs[findfirst(x->x===(loss), args)][] = 1
    (f')(args..., gargs...)
    return [x[] for x in gargs if x!==nothing]
end

function world_similar(a, b; atol::Real=1e-8, verbose::Bool=false)
    for (xa, xb) in zip(a, b)
        if xa isa GRef
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

function ng(f, args, y, x::Ref; δ=1e-5)
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

function ng(f, args, y, x::AbstractGArray; δ=1e-5)
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

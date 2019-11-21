export ng, check_grad
export ngradient, gradient

isvar(x) = false
isvar(x::AbstractFloat) = true
isvar(x::Bundle{<:AbstractFloat}) = true
isvar(x::AbstractArray{T}) where T<:AbstractFloat = true

function tset(vfunc::Function, tp::Tuple, iloss)
    map(i->i===iloss ? vfunc(tp[i]) : tp[i], 1:length(tp))
end
function tset(val, tp::Tuple, iloss)
    map(i->i===iloss ? val : tp[i], 1:length(tp))
end

function gradient(f, args; kwargs=())
    gargs = f'(args...; kwargs...)
    return [val.(grad.(x)) for x in gargs if x isa GVar || x isa AbstractArray{<:GVar}]
end

function ng(f, args, iarg, iloss; δ=1e-5, kwargs=())
    x = args[iarg]
    if x isa AbstractArray
        res = zero(x)
        for i = 1:length(x)
            args[iarg][i] += δ/2
            @instr f(args...; kwargs...)
            pos = val(args[iloss])
            @instr (~f)(args...; kwargs...)
            args[iarg][i] -= δ
            @instr f(args...; kwargs...)
            neg = val(args[iloss])
            @instr (~f)(args...; kwargs...)
            args[iarg][i] += δ/2
            res[i] = (pos - neg)/δ
        end
        return res
    else
        args = tset(x->(x ⊕ δ/2)[1], args, iarg)
        @instr f(args...; kwargs...)
        pos = val(args[iloss])
        @instr (~f)(args...; kwargs...)
        args = tset(x->(x ⊖ δ)[1], args, iarg)
        @instr f(args...; kwargs...)
        neg = val(args[iloss])
        @instr (~f)(args...; kwargs...)
        args = tset(x->(x ⊕ δ/2)[1], args, iarg)
        (pos - neg)/δ
    end
end

function ngradient(f, args; kwargs=())
    iloss = findfirst(x->x<:Loss, typeof.(args))
    if iloss === nothing
        throw(ArgumentError("input arguments does not contain Loss! $args"))
    end
    map(1:length(args)) do iarg
        if isvar(args[iarg])
            ng(f, args, iarg, iloss; kwargs=kwargs)
        else
            0
        end
    end
end

function check_grad(f, args; kwargs=(), atol::Real=1e-4, verbose::Bool=false)
    vars = ((iarg for iarg in 1:length(args) if isvar(args[iarg]))...,)
    initial_vars = deepcopy(vars)
    ngs = ngradient(f, args; kwargs=kwargs)
    gs = gradient(f, args; kwargs=kwargs)
    verbose && @show ngs
    verbose && @show gs
    if !all(isapprox.(ngs, gs, atol=atol))
        verbose && println("gradient not match: $ngs v.s. $gs")
        return false
    end

    if !world_similar(initial_vars, vars, atol=atol, verbose=verbose)
        verbose && println("world changed during obtaining gradient.")
        return false
    end
    return true
end

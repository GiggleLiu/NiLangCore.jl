export check_inv, world_similar

function world_similar(a, b; atol::Real=1e-8, verbose::Bool=false)
    for (xa, xb) in zip(a, b)
        if !isapprox(xa, xb; atol=atol)
            verbose && println("$xa does not match $xb")
            return false
        end
    end
    return true
end

function check_inv(f, args; kwargs=(), atol::Real=1e-8, verbose::Bool=false)
    args0 = deepcopy(args)
    args = f(args...; kwargs...)
    args = (~f)(args...; kwargs...)
    world_similar(args0, args, atol=atol, verbose=verbose)
end

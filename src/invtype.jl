using Base.Cartesian

export @iconstruct

@generated function chfield(x, ::Val{FIELD}, xval) where FIELD
    :(@with x.$FIELD = xval)
end
@generated function chfield(x, f::Function, xval)
    :(@invcheck f(x) xval; x)
end

"""
    @iconstruct function TYPE(args...) ... end

Create a reversible constructor.


```jldoctest; setup=:(using NiLangCore, Test)
julia> struct DVar{T}
           x::T
           g::T
       end

julia> @iconstruct function DVar(xx, gg=zero(xx))
           gg += identity(xx)
       end

julia> @test (~DVar)(DVar(0.5)) == 0.5
Test Passed
```
"""
macro iconstruct(ex)
    mc, fname, args, ts, body = precom(ex)
    esc(_gen_iconstructor(mc, fname, args, ts, body))
end

@generated function type2tuple(x::T) where T
    Expr(:tuple, [:(x.$v) for v in fieldnames(T)]...)
end

function _gen_iconstructor(mc, fname, args, ts, body)
    preargs, assigns, postargs = args_and_assigns(args)
    body = [assigns..., body...]

    head = :($fname($(preargs...)) where {$(ts...)})
    tail = :($fname($(postargs...)))
    fdef1 = Expr(:function, head, Expr(:block, interpret_body(body)..., :(return $tail)))

    dfname = :(_::Type{Inv{$fname}})
    obj = gensym()
    fieldvalues = gensym()
    invtrueargs = [preargs[1:end-1]..., obj]
    loads = []
    for (i,arg) in enumerate(postargs)
        push!(loads, :($arg = $fieldvalues[$i]))
    end
    loaddata = Expr(:block, loads...)
    dualhead = :($dfname($([invtrueargs[1:end-1]..., :($(invtrueargs[end])::$fname)]...)) where {$(ts...)})
    fdef2 = Expr(:function, dualhead, Expr(:block, :($fieldvalues = NiLangCore.type2tuple($obj)), loaddata, interpret_body(dual_body(body))..., :(return $(get_argname(preargs[end])))))

    # implementations
    ftype = get_ftype(fname)
    Expr(:block, fdef1, fdef2)
end

function args_and_assigns(args)
    preargs = []
    assigns = []
    postargs = []
    count = 0
    for arg in args
        @match arg begin
            :($a ← $b) => begin
                push!(assigns, arg)
                push!(postargs, get_argname(a))
            end
            Expr(:parameters, kwargs...) => begin
                push!(preargs, arg)
                push!(postargs, arg)
            end
            ::Symbol || :($x::$tp) => begin
                if count == 1
                    error("got more than one primitary argument!")
                end
                count += 1
                push!(preargs, arg)
                push!(postargs, get_argname(arg))
            end
            _ => error("got invalid input argument: $(arg), should be a normal argument or `x ← val`.")
        end
    end
    if count == 0
        error("no primitary argument found!")
    end
    preargs, assigns, postargs
end

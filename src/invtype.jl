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
    trueargs, assigns = args_and_assigns(args)
    body = [[:(@anc $a) for a in assigns]..., body...]

    head = :($fname($(trueargs...)) where {$(ts...)})
    tail = :($fname($(get_argname.([trueargs..., assigns...])...)))
    fdef1 = Expr(:function, head, Expr(:block, interpret_body(body)..., :(return $tail)))

    dfname = :(_::Type{Inv{$fname}})
    obj = gensym()
    fieldvalues = gensym()
    invtrueargs = [trueargs[1:end-1]..., obj]
    loads = Any[:($(get_argname(trueargs[end])) = $fieldvalues[1])]
    for (i,arg) in enumerate(assigns)
        @match arg begin
            :($a = $b) => push!(loads, :($a = $fieldvalues[$(i+1)]))
            _ => error("unkown assign $arg")
        end
    end
    loaddata = Expr(:block, loads...)
    dualhead = :($dfname($([invtrueargs[1:end-1]..., :($(invtrueargs[end])::$fname)]...)) where {$(ts...)})
    fdef2 = Expr(:function, dualhead, Expr(:block, :($fieldvalues = NiLangCore.type2tuple($obj)), loaddata, interpret_body(dual_body(body))..., :(return $(get_argname(trueargs[end])))))

    # implementations
    ftype = get_ftype(fname)
    Expr(:block, fdef1, fdef2)
end

function args_and_assigns(args)
    assigns = []
    if args[1] isa Expr && args[1].head == :parameters
        newargs = [args[1], args[2]]
    else
        newargs = [args[1]]
    end
    for arg in args[length(newargs)+1:end]
        @match arg begin
            Expr(:kw, a, b) => push!(assigns, :($a = $b))
            _ => error("got invalid input argument: $(arg), should be `x = val`.")
        end
    end
    newargs, assigns
end

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

julia> @iconstruct function DVar(xx, gg ← zero(xx))
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
    loaddata = _unpack_struct(obj, postargs)
    invtrueargs = [preargs[1:end-1]..., obj]
    dualhead = :($dfname($([invtrueargs[1:end-1]..., :($(invtrueargs[end])::$fname)]...)) where {$(ts...)})
    fdef2 = Expr(:function, dualhead, Expr(:block, loaddata, interpret_body(dual_body(body))..., :(return $(get_argname(preargs[end])))))

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

export @icast
"""
```jldoctest; setup=:(using NiLangCore, Test)
julia> struct PVar{T}
           g::T
           x::T
       end

julia> struct SVar{T}
           x::T
           g::T
       end

julia> @icast PVar(g, x) => SVar(x, k) begin
          g → zero(x)
          k ← zero(x)
          k += identity(x)
       end

julia> @test PVar((SVar(PVar(0.0, 0.5)))) == PVar(0.0, 0.5)
Test Passed

julia> @icast x::Base.Float64 => SVar(x, gg) begin
           gg ← zero(x)
           gg += identity(x)
       end

julia> @test Float64(SVar(0.5)) == 0.5
Test Passed
```
"""
macro icast(ex, body)
    if !(body isa Expr && body.head == :block)
        error("the second argument must be a `begin ... end` statement.")
    end
    @match ex begin
        :($a => $b) => begin
            t1, args1 = _match_typecast(a)
            t2, args2 = _match_typecast(b)
            ancs = Dict{Any,Any}()
            for arg in _asvector(args1)
                ancs[arg] = nothing
            end
            info = PreInfo(ancs, [])
            body = precom_body(body.args, info)
            for arg in _asvector(args2)
                delete!(info.ancs, arg)
            end
            isempty(info.ancs) || throw("variable information discarded/unknown variable: $(info.ancs)")
            x = gensym()
            fdef1 = Expr(:function, :($t1($x::$t2)), Expr(:block, _unpack_struct(x, args2), interpret_body(dual_body(body))..., a))
            fdef2 = Expr(:function, :($t2($x::$t1)), Expr(:block, _unpack_struct(x, args1), interpret_body(body)..., b))
            esc(Expr(:block, fdef1, fdef2, nothing))
        end
        _ => error("the first argument must be a pair like `x => y`.")
    end
end

_match_typecast(ex) = @match ex begin
    :($tp($(args...))) => (tp, args)
    :($x::$tp) => (tp, x)
    _ => error("type specification should be `T(args...)` or `x::T`.")
end

function _unpack_struct(obj, args)
    if args isa AbstractVector
        Expr(:(=), Expr(:tuple, args...), :(NiLangCore.type2tuple($obj)))
    else
        Expr(:(=), args, obj)
    end
end

_asvector(x::AbstractVector) = x
_asvector(x) = [x]

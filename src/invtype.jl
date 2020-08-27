using Base.Cartesian

export @iconstruct

@generated function chfield(x, ::Val{FIELD}, xval) where FIELD
    if x.mutable
        Expr(:block, :(x.$FIELD = xval), :x)
    else
        :(@with x.$FIELD = xval)
    end
end
@generated function chfield(x, f::Function, xval)
    :(@invcheck f(x) xval; x)
end

@generated function type2tuple(x::T) where T
    Expr(:tuple, [:(x.$v) for v in fieldnames(T)]...)
end

export @icast
"""
    @icast TDEF1 => TDEF2 begin ... end

Define type cast between `TDEF1` and `TDEF2`.
Type `TDEF1` or `TDEF2` can be `T(args...)` or `x::T` like.

```jldoctest; setup=:(using NiLangCore)
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

julia> x = PVar(0.0, 0.5)
PVar{Float64}(0.0, 0.5)

julia> @instr (PVar=>SVar)(x)
SVar{Float64}(0.5, 0.5)

julia> @instr (SVar=>PVar)(x)
PVar{Float64}(0.0, 0.5)

julia> @icast x::Base.Float64 => SVar(x, gg) begin
           gg ← zero(x)
           gg += identity(x)
       end

julia> x = 0.5
0.5

julia> @instr (Float64=>SVar)(x)
SVar{Float64}(0.5, 0.5)

julia> @instr (SVar=>Float64)(x)
0.5
```
"""
macro icast(ex, body)
    m = __module__
    if !(body isa Expr && body.head == :block)
        error("the second argument must be a `begin ... end` statement.")
    end
    @smatch ex begin
        :($a => $b) => begin
            t1, args1 = _match_typecast(a)
            t2, args2 = _match_typecast(b)
            ancs = MyOrderedDict{Symbol,Any}()
            vars = Symbol[]
            for arg in _asvector(args1)
                ancs[arg] = nothing
                pushvar!(vars, arg)
            end
            info = PreInfo(vars, ancs, [])
            body = precom_body(m, body.args, info)
            for arg in _asvector(args2)
                delete!(info.ancs, arg)
            end
            isempty(info.ancs) || throw("variable information discarded/unknown variable: $(info.ancs)")
            x = gensym()
            fdef1 = Expr(:function, :(Base.convert(::Type{$t1}, $x::$t2)), Expr(:block, _unpack_struct(x, args2), compile_body(m, dual_body(m, body), CompileInfo())..., a))
            fdef2 = Expr(:function, :(Base.convert(::Type{$t2}, $x::$t1)), Expr(:block, _unpack_struct(x, args1), compile_body(m, body, CompileInfo())..., b))
            esc(Expr(:block, fdef1, fdef2, nothing))
        end
        _ => error("the first argument must be a pair like `x => y`.")
    end
end

_match_typecast(ex) = @smatch ex begin
    :($tp($(args...))) => (tp, args)
    :($x::$tp) => (tp, x)
    _ => error("type specification should be `T(args...)` or `x::T`.")
end

function _unpack_struct(obj, args)
    if args isa AbstractVector
        Expr(:(=), Expr(:tuple, args...), :($type2tuple($obj)))
    else
        Expr(:(=), args, obj)
    end
end

_asvector(x::AbstractVector) = x
_asvector(x) = [x]

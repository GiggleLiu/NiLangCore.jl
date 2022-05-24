using Base.Cartesian
export chfield

############# ancillas ################
export @fieldview
"""
    @fieldview fname(x::TYPE) = x.fieldname
    @fieldview fname(x::TYPE) = x[i]
    ...

Create a function fieldview that can be accessed by a reversible program

```jldoctest; setup=:(using NiLangCore)
julia> struct GVar{T, GT}
           x::T
           g::GT
       end

julia> @fieldview xx(x::GVar) = x.x

julia> chfield(GVar(1.0, 0.0), xx, 2.0)
GVar{Float64, Float64}(2.0, 0.0)
```
"""
macro fieldview(ex)
    @match ex begin
        :($f($obj::$tp) = begin $line; $ex end) => begin
            xval = gensym("value")
            esc(Expr(:block,
                :(Base.@__doc__ $f($obj::$tp) = begin $line; $ex end),
                :($NiLangCore.chfield($obj::$tp, ::typeof($f), $xval) = $(Expr(:block, assign_ex(ex, xval, false), obj)))
            ))
        end
        _ => error("expect expression `f(obj::type) = obj.prop`, got $ex")
    end
end

chfield(a, b, c) = error("chfield($a, $b, $c) not defined!")
chfield(x, ::typeof(identity), xval) = xval
chfield(x::T, ::typeof(-), y::T) where T = -y
chfield(x::T, ::typeof(adjoint), y) where T = adjoint(y)

############ dataview patches ############
export tget, subarray

"""
    tget(i::Int)

Get the i-th entry of a tuple.
"""
tget(i::Int) = x::Tuple -> x[i]

"""
    subarray(ranges...)

Get a subarray, same as `view` in Base.
"""
subarray(args...) = x -> view(x, args...)
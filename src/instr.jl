export @dual, @selfdual
export nargs, nouts

"""
    @dual f invf

Define `f` and `invf` as a pair of dual instructions, i.e. reverse to each other.
"""
macro dual(f, invf)
    esc(:(
        NiLangCore.isreversible($f) || begin
            NiLangCore.isreversible(::typeof($f)) = true
        end;
        NiLangCore.isreversible($invf) || begin
            NiLangCore.isreversible(::typeof($invf)) = true
        end;
        NiLangCore.isprimitive($f) || begin
            NiLangCore.isprimitive(::typeof($f)) = true
        end;
        NiLangCore.isprimitive($invf) || begin
            NiLangCore.isprimitive(::typeof($invf)) = true
        end;
        Base.:~($f) === $invf || begin
            Base.:~(::typeof($f)) = $invf;
        end;
        Base.:~($invf) === $f || begin
            Base.:~(::typeof($invf)) = $f;
        end
    ))
end

"""
    @selfdual f

Define `f` as a self-dual instructions.
"""
macro selfdual(f)
    esc(:(
        NiLangCore.isreversible($f) || begin
            NiLangCore.isreversible(::typeof($f)) = true
        end;
        NiLangCore.isreflexive($f) || begin
            NiLangCore.isreflexive(::typeof($f)) = true
        end;
        NiLangCore.isprimitive($f) || begin
            NiLangCore.isprimitive(::typeof($f)) = true
        end;
        Base.:~($f) === $f || begin
            Base.:~(::typeof($f)) = $f
        end
    ))
end

export @assignback

# TODO: include control flows.
"""
    @assignback f(args...)

Assign input variables with output values: `args... = f(args...)`.
"""
macro assignback(ex)
    ex = precom_ex(ex, PreInfo())
    @match ex begin
        :($f($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f($(args...)))
            if startwithdot(f)
                esc(Expr(ex, bcast_assign_vars(notkey(args), symres)))
            else
                esc(Expr(:block, ex, assign_vars(notkey(args), symres)))
            end
        end
        # TODO: support multiple input
        :($f.($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f.($(args...)))
            esc(Expr(:block, ex, bcast_assign_vars(notkey(args), symres)))
        end
        _ => error("got $ex")
    end
end

"""
    assign_vars(args, symres)

Get the expression of assigning `symres` to `args`.
"""
function assign_vars(args, symres)
    exprs = []
    for (i,arg) in enumerate(args)
        exi = @match arg begin
            :($ag...) => begin
                i!=length(args) && error("`args...` like arguments should only appear as the last argument!")
                assign_ex(ag, :(NiLangCore.tailn(NiLangCore.wrap_tuple($symres), Val($i-1))))
            end
            _ => assign_ex(arg, :(NiLangCore.wrap_tuple($symres)[$i]))
        end
        exi !== nothing && push!(exprs, exi)
    end
    Expr(:block, exprs...)
end

wrap_tuple(x) = (x,)
wrap_tuple(x::Tuple) = x

"""The broadcast version of `assign_vars`"""
function bcast_assign_vars(args, symres)
    if length(args) == 1
        @match args[1] begin
            :($args...) => :($args = ([getindex.($symres, j) for j=1:length($symres[1])]...,))
            _ => assign_ex(args[1], symres)
        end
    else
        ex = :()
        for (i,arg) in enumerate(args)
            exi = @match arg begin
                :($ag...) => begin
                    i!=length(args) && error("`args...` like arguments should only appear as the last argument!")
                    :($ag = ([getindex.($symres, j) for j=$i:length($symres[1])]...,))
                end
                _ => assign_ex(arg, :(getindex.($symres, $i)))
            end
            exi !== nothing && (ex = :($ex; $exi))
        end
        ex
    end
end


function assign_ex(arg::Symbol, res)
    _isconst(arg) ? :(@invcheck $arg $res) : :($arg = $res)
end
assign_ex(arg::Union{Number,String}, res) = :(@invcheck $arg $res)
assign_ex(arg::Expr, res) = @match arg begin
    :($x.$k) => :($(_isconst(x) ? :(@invcheck $arg $res) : assign_ex(x, :(chfield($x, $(Val(k)), $res)))))
    :($f($x)) => :($(_isconst(x) ? :(@invcheck $arg $res) : assign_ex(x, :(chfield($x, $f, $res)))))
    :($f.($x)) => :($(assign_ex(x, :(chfield.($x, Ref($f), $res)))))
    :($x') => :($(_isconst(x) ? :(@invcheck $arg $res) : assign_ex(x, :(chfield($x, adjoint, $res)))))
    :($a[$(x...)]) => begin
        :($a[$(x...)] = $res)
    end
    # tuple must be index through tget
    :(tget($a, $(x...))) => begin
        assign_ex(a, :(chfield($a, $(Expr(:tuple, x...)), $res)))
    end
    :(($(args...),)) => begin
        ex = :()
        for i=1:length(args)
            ex = :($ex; $(assign_ex(args[i], :($res[$i]))))
        end
        ex
    end
    _ => :(@invcheck $arg $res)
end

_isconst(x::Symbol) = x in [:im, :π]
_isconst(x::Union{Number,String}) = true
_isconst(x::Expr) = @match x begin
    :($f($(args...))) => all(_isconst, args)
    _ => false
end

iter_assign(a::AbstractArray, val, indices...) = (a[indices...] = val; a)
iter_assign(a::Tuple, val, index) = TupleTools.insertat(a, index, (val,))
tailn(t::Tuple, ::Val{n}) where n = tailn(TupleTools.tail(t), Val(n-1))
tailn(t::Tuple, ::Val{0}) = t

export @assign

"""
    @assign a b

Perform the assign `a = b` in a reversible program.
"""
macro assign(a, b)
    esc(assign_ex(a, b))
end

# TODEP
"""
    nargs(instr)

Number of arguments as the input of `instr`.
"""
function nargs end

# TODEP
"""
    nouts(instr)

Number of output arguments in the input list of `instr`.
"""
function nouts end

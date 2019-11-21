export @dual, @selfdual

"""
define dual instructions

TODO: check address conflicts!
"""
macro dual(f, invf)
    esc(:(
    NiLangCore.isreversible(::typeof($f)) = true;
    NiLangCore.isreversible(::typeof($invf)) = true;
    NiLangCore.isprimitive(::typeof($f)) = true;
    NiLangCore.isprimitive(::typeof($invf)) = true;
    Base.:~(::typeof($f)) = $invf;
    Base.:~(::typeof($invf)) = $f
    ))
end

export @ignore
macro ignore(exs...)
    res = :()
    for ex in exs
        res = :($res; $(@match ex begin
            :($f($(args...))) => :(
                function $f($(args...)) $(Expr(:return, Expr(:tuple, get_argname.(args)...))) end;
                function $(NiLangCore.dual_fname(f))($(args...)) $(Expr(:return, Expr(:tuple, get_argname.(args)...))) end
                )
            _ => error("expect a function call expression, got $ex")
        end))
    end
    return esc(res)
end

"""define a self-dual instruction"""
macro selfdual(f)
    esc(:(
    NiLangCore.isreversible(::typeof($f)) = true;
    NiLangCore.isreflexive(::typeof($f)) = true;
    NiLangCore.isprimitive(::typeof($f)) = true;
    Base.:~(::typeof($f)) = $f
    ))
end

export @instr
macro instr(ex)
    @match ex begin
        :($f($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f($(args...)))
            if startwithdot(f)
                esc(:($ex; $(bcast_assign_vars(args, symres))))
            else
                esc(:($ex; $(assign_vars(args, symres))))
            end
        end
        # TODO: support multiple input
        :($f.($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f.($(args...)))
            esc(:($ex; $(bcast_assign_vars(args, symres))))
        end
        :($a += $f($(args...))) => esc(:(@instr PlusEq($f)($a, $(args...))))
        :($a .+= $f($(args...))) => esc(:(@instr PlusEq($(debcast(f))).($a, $(args...))))
        :($a .+= $f.($(args...))) => esc(:(@instr PlusEq($f).($a, $(args...))))
        :($a -= $f($(args...))) => esc(:(@instr MinusEq($f)($a, $(args...))))
        :($a .-= $f($(args...))) => esc(:(@instr MinusEq($(debcast(f))).($a, $(args...))))
        :($a .-= $f.($(args...))) => esc(:(@instr MinusEq($f).($a, $(args...))))
        :($a ⊻= $f($(args...))) => esc(:(@instr XorEq($f)($a, $(args...))))
        :($a .⊻= $f($(args...))) => esc(:(@instr XorEq($(debcast(f))).($a, $(args...))))
        :($a .⊻= $f.($(args...))) => esc(:(@instr XorEq($f).($a, $(args...))))
        _ => error("got $ex")
    end
end

function assign_vars(args, symres)
    ex = :()
    for (i,arg) in enumerate(args)
        exi = @match arg begin
            :($args...) => :($args = NiLangCore.tailn(NiLangCore.wrap_tuple($symres), Val($i-1)))
            _ => assign_ex(arg, :($symres[$i]))
        end
        exi !== nothing && (ex = :($ex; $exi))
    end
    ex
end

wrap_tuple(x) = (x,)
wrap_tuple(x::Tuple) = x

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
                :($args...) => :($args = ([getindex.($symres, j) for j=$i:length($symres[1])]...,))
                _ => assign_ex(arg, :(getindex.($symres, $i)))
            end
            exi !== nothing && (ex = :($ex; $exi))
        end
        ex
    end
end

function assign_ex(arg::Symbol, res)
    :($arg = $res)
end
assign_ex(arg::Union{Number,String}, res) = :(@invcheck $arg ≈ $res)
assign_ex(arg::Expr, res) = @match arg begin
    :($x.$k) => :($(assign_ex(x, :(chfield($x, $(Val(k)), $res)))))
    :($f($x)) => :($(assign_ex(x, :(chfield($x, $f, $res)))))
    :($x') => :($(assign_ex(x, :(chfield($x, conj, $res)))))
    :($a[$(x...)]) => begin
        if length(x) == 0
            :($a[] = $res)
        else
            :(if ($a isa Tuple)
                $a = NiLangCore.TupleTools.insertat($a, $(x[]), ($res,))
            else
                $a[$(x...)] = $res
            end)
        end
    end
    _ => begin
        if _isconst(arg)
            return nothing
        else
            error("input expression illegal, got $arg.")
        end
    end
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
macro assign(a, b)
    esc(assign_ex(a, b))
end

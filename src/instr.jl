export @dual, @selfdual

"""
define dual instructions

TODO: check address conflicts!
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

export @instr
macro instr(ex)
    ex = precom_ex(ex, PreInfo())
    @match ex begin
        :($f($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f($(args...)))
            if startwithdot(f)
                esc(:($ex; $(bcast_assign_vars(notkey(args), symres))))
            else
                esc(:($ex; $(assign_vars(notkey(args), symres))))
            end
        end
        # TODO: support multiple input
        :($f.($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f.($(args...)))
            esc(:($ex; $(bcast_assign_vars(notkey(args), symres))))
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
        #=
        NOTE 1: not only left side can change, the gradients of right side can also change.
        NOTE 2: the broadcasting over a scalar is not allowed. For,
            * native Julia broadcast can not accumulate gradients properly.
            * NiLang for loop is possible, but hard.
        :($a += $f($(args...))) => esc(:($a = PlusEq($f)($a, $(args...))[1]))
        :($a .+= $f($(args...))) => esc(:($a = getindex.(PlusEq($(debcast(f))).($a, $(args...)),1)))
        :($a .+= $f.($(args...))) => esc(:($a = getindex.(PlusEq($f).($a, $(args...)),1)))
        :($a -= $f($(args...))) => esc(:($a = MinusEq($f)($a, $(args...))[1]))
        :($a .-= $f($(args...))) => esc(:($a = getindex.(MinusEq($(debcast(f))).($a, $(args...)),1)))
        :($a .-= $f.($(args...))) => esc(:($a = getindex.(MinusEq($f).($a, $(args...)),1)))
        :($a ⊻= $f($(args...))) => esc(:($a = XorEq($f)($a, $(args...))[1]))
        :($a .⊻= $f($(args...))) => esc(:($a = getindex.(XorEq($(debcast(f))).($a, $(args...)),1)))
        :($a .⊻= $f.($(args...))) => esc(:($a = getindex.(XorEq($f).($a, $(args...))[1])))

        :($a += $b) => esc(:($a = PlusEq(identity)($a, $b)[1]))
        :($a -= $b) => esc(:($a = MinusEq(identity)($a, $b)[1]))
        :($a ⊻= $b) => esc(:($a = XorEq(identity)($a, $b)[1]))
        :($a .+= $b) => esc(:($a = getindex.(PlusEq(identity).($a, $b),1)))
        :($a .-= $b) => esc(:($a = getindex.(MinusEq(identity).($a, $b),1)))
        :($a .⊻= $b) => esc(:($a = getindex.(XorEq(identity).($a, $b),1)))
        =#
        _ => error("got $ex")
    end
end

function assign_vars(args, symres)
    ex = :()
    for (i,arg) in enumerate(args)
        exi = @match arg begin
            :($ag...) => begin
                i!=length(args) && error("`args...` like arguments should only appear as the last argument!")
                :($ag = NiLangCore.tailn(NiLangCore.wrap_tuple($symres), Val($i-1)))
            end
            _ => assign_ex(arg, :(NiLangCore.wrap_tuple($symres)[$i]))
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
    :($x') => :($(_isconst(x) ? :(@invcheck $arg $res) : assign_ex(x, :(chfield($x, conj, $res)))))
    :($a[$(x...)]) => begin
        :($a = chfield($a, $(Expr(:tuple, x...)), $res))
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
macro assign(a, b)
    esc(assign_ex(a, b))
end

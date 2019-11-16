export @dual, @selfdual, nargs, nouts
using TupleTools

function nargs end
function nouts end

"""
define dual instructions

TODO: check address conflicts!
"""
macro dual(ex)
    @match ex begin
        :($fline; function $f($(args...)) $(body...) end; $invfline;
            function $invf($(invargs...)) $(invbody...)end) => begin
            if length(args) != length(invargs)
                return :(error("forward and reverse function arguments should be the same! got $args and $invargs"))
            end
            esc(:(
            function $f($(args...)) $(body...) end;
            function $invf($(invargs...)) $(invbody...) end;
            NiLangCore.isreversible(::typeof($f)) = true;
            NiLangCore.isreversible(::typeof($invf)) = true;
            NiLangCore.isprimitive(::typeof($f)) = true;
            NiLangCore.isprimitive(::typeof($invf)) = true;
            NiLangCore.nargs(::typeof($f)) = $(length(args));
            NiLangCore.nargs(::typeof($invf)) = $(length(args));
            NiLangCore.nouts(::typeof($f)) = $(count(endwithpang, args));
            NiLangCore.nouts(::typeof($invf)) = $(count(endwithpang, args));
            Base.:~(::typeof($f)) = $invf;
            Base.:~(::typeof($invf)) = $f
            ))
        end
    end
end

"""define a self-dual instruction"""
macro selfdual(ex)
    @match ex begin
        :($fline; function $f($(args...)) $(body...) end) => begin
            esc(:(
            function $f($(args...)) $(body...) end;
            NiLangCore.isreversible(::typeof($f)) = true;
            NiLangCore.isreflexive(::typeof($f)) = true;
            NiLangCore.isprimitive(::typeof($f)) = true;
            NiLangCore.nargs(::typeof($f)) = $(length(args));
            Base.:~(::typeof($f)) = $f
            ))
        end
    end
end

export @instr
macro instr(ex)
    println("excuting => $ex")
    @match ex begin
        :($f($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f($(args...)))
            esc(assign_vars(ex, args, symres))
        end
        # TODO: support multiple input
        :($f.($(args))) => begin
            symres = gensym()
            ex = :($symres = $f.($(args)))
            esc(:($ex; $(assign_ex(args, symres))))
        end
        :($f.($(args...))) => begin
            i = gensym()
            esc(:(
            for $i=1:1:length($(args[1]))
                $(macroexpand(NiLangCore, :(@instr $(Expr(:call, f, [:($arg[$i]) for arg in args]...)))))
            end))
        end
        _ => error("got $ex")
    end
end

function assign_vars(ex, args, symres)
    for (i,arg) in enumerate(args)
        exi = @match arg begin
            :($args...) => :($args = NiLangCore.tailn($symres, Val($i-1)))
            _ => assign_ex(arg, :($symres[$i]))
        end
        exi !== nothing && (ex = :($ex; $exi))
    end
    return ex
end

function assign_ex(arg::Symbol, res)
    :($arg = $res)
end
assign_ex(arg::Union{Number,String}, res) = :(@invcheck $arg ≈ $res)
assign_ex(arg::Expr, res) = @match arg begin
    :($x.$k) => :($(assign_ex(x, :(chvar($x, $(Val(k)), $res)))))
    :($f($x)) => :($(assign_ex(x, :(chvar($x, $f, $res)))))
    :($a[$(x...)]) => :(
        if ($a isa Tuple)
            $a = NiLangCore.TupleTools.insertat($a, $(x[]), ($res,))
        else
            $a[$(x...)] = $res
        end
    )
    _ => error("input expression illegal, got $arg.")
end

iter_assign(a::AbstractArray, val, indices...) = (a[indices...] = val; a)
iter_assign(a::Tuple, val, index) = TupleTools.insertat(a, index, (val,))
tailn(t::Tuple, ::Val{n}) where n = tailn(TupleTools.tail(t), Val(n-1))
tailn(t::Tuple, ::Val{0}) = t

export @assign
macro assign(a, b)
    esc(assign_ex(a, b))
end

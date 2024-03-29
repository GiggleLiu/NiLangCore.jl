export @dual, @selfdual, @dualtype

"""
    @dual f invf

Define `f` and `invf` as a pair of dual instructions, i.e. reverse to each other.
"""
macro dual(f, invf)
    esc(quote
        if !$NiLangCore.isprimitive($f)
            $NiLangCore.isprimitive(::typeof($f)) = true
        end
        if !$NiLangCore.isprimitive($invf)
            $NiLangCore.isprimitive(::typeof($invf)) = true
        end
        if Base.:~($f) !== $invf
            Base.:~(::typeof($f)) = $invf;
        end
        if Base.:~($invf) !== $f
            Base.:~(::typeof($invf)) = $f;
        end
    end)
end

macro dualtype(t, invt)
    esc(quote
        $invtype($t) === $invt || begin
            $NiLangCore.invtype(::Type{$t}) = $invt
            $NiLangCore.invtype(::Type{T}) where T<:$t = $invt{T.parameters...}
        end
        $invtype($invt) === $t || begin
            $NiLangCore.invtype(::Type{$invt}) = $t
            $NiLangCore.invtype(::Type{T}) where T<:$invt = $t{T.parameters...}
        end
    end)
end
@dualtype PlusEq MinusEq
@dualtype DivEq MulEq
@dualtype XorEq XorEq

"""
    @selfdual f

Define `f` as a self-dual instructions.
"""
macro selfdual(f)
    esc(:(@dual $f $f))
end

export @const
@eval macro $(:const)(ex)
    esc(ex)
end

export @skip!
macro skip!(ex)
    esc(ex)
end

export @assignback

# TODO: include control flows.
"""
    @assignback f(args...) [invcheck]

Assign input variables with output values: `args... = f(args...)`, turn off invertibility error check if the second argument is false.
"""
macro assignback(ex, invcheck=true)
    ex = precom_ex(__module__, ex, PreInfo())
    esc(assignback_ex(ex, invcheck))
end

function assignback_ex(ex::Expr, invcheck::Bool)
    @match ex begin
        :($f($(args...))) => begin
            symres = gensym("results")
            ex = :($symres = $f($(args...)))
            res = assign_vars(seperate_kwargs(args)[1], symres, invcheck)
            pushfirst!(res.args, ex)
            return res
        end
        _ => error("assign back fail, got $ex")
    end
end

"""
    assign_vars(args, symres, invcheck)

Get the expression of assigning `symres` to `args`.
"""
function assign_vars(args, symres, invcheck)
    exprs = []
    for (i,arg) in enumerate(args)
        exi = @match arg begin
            :($ag...) => begin
                i!=length(args) && error("`args...` like arguments should only appear as the last argument!")
                ex = :(ntuple(j->$symres[j+$(i-1)], length($ag)))
                assign_ex(ag, i==1 ? :(length($ag) == 1 ? ($symres,) : $ex) : ex, invcheck)
            end
            _ => if length(args) == 1
                assign_ex(arg, symres, invcheck)
            else
                assign_ex(arg, :($symres[$i]), invcheck)
            end
        end
        exi !== nothing && push!(exprs, exi)
    end
    Expr(:block, exprs...)
end

error_message_fcall(arg) = """
function arguments should not contain function calls on variables, got `$arg`, try to decompose it into elementary statements, e.g. statement `z += f(g(x))` should be written as
    y += g(x)
    z += y

If `g` is a dataview (a function map an object to its field or a bijective function), one can also use the pipline like
    z += f(x |> g)
"""

assign_ex(arg, res, invcheck) = @match arg begin
    ::Number || ::String => _invcheck(invcheck, arg, res)
    ::Symbol || ::GlobalRef => _isconst(arg) ? _invcheck(invcheck, arg, res) : :($arg = $res)
    :(@skip! $line $x) => nothing
    :(@fields $line $x) => assign_ex(x, Expr(:call, default_constructor, :(typeof($x)), Expr(:..., res)), invcheck)
    :($x::∅) => assign_ex(x, res, invcheck)
    :($x::$T) => assign_ex(x, :($loaddata($T, $res)), invcheck)
    :($x.$k) => _isconst(x) ? _invcheck(invcheck, arg, res) : assign_ex(x, :(chfield($x, $(Val(k)), $res)), invcheck)
    # tuples must be index through (x |> 1)
    :($a |> tget($x)) => assign_ex(a, :($(TupleTools.insertat)($a, $x, ($res,))), invcheck)
    :($a |> subarray($(ranges...))) => :(($res===view($a, $(ranges...))) || (view($a, $(ranges...)) .= $res))
    :($x |> $f) => _isconst(x) ? _invcheck(invcheck, arg,res) : assign_ex(x, :(chfield($x, $f, $res)), invcheck)
    :($x .|> $f) => _isconst(x) ? _invcheck(invcheck, arg,res) : assign_ex(x, :(chfield.($x, Ref($f), $res)), invcheck)
    :($x') => _isconst(x) ? _invcheck(invcheck, arg, res) : assign_ex(x, :(chfield($x, adjoint, $res)), invcheck)
    :(-$x) => _isconst(x) ? _invcheck(invcheck, arg,res) : assign_ex(x, :(chfield($x, -, $res)), invcheck)
    :($t{$(p...)}($(args...))) => begin
        if length(args) == 1
            assign_ex(args[1], :($getfield($res, 1)), invcheck)
        else
            assign_vars(args, :($type2tuple($res)), invcheck)
        end
    end
    :($f($(args...))) => all(_isconst, args) || error(error_message_fcall(arg))
    :($f.($(args...))) => all(_isconst, args) || error(error_message_fcall(arg))
    :($a[$(x...)]) => begin
        :($a[$(x...)] = $res)
    end
    :(($(args...),)) => begin
        # TODO: avoid possible repeated evaluation (not here, in swap)
        Expr(:block, [assign_ex(args[i], :($res[$i]), invcheck) for i=1:length(args)]...)
    end
    _ => _invcheck(invcheck, arg, res)
end

export @assign

"""
    @assign a b [invcheck]

Perform the assign `a = b` in a reversible program.
Turn off invertibility check if the `invcheck` is false.
"""
macro assign(a, b, invcheck=true)
    esc(assign_ex(a, b, invcheck))
end

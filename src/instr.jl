export @dual, @selfdual, @dualtype

"""
    @dual f invf

Define `f` and `invf` as a pair of dual instructions, i.e. reverse to each other.
"""
macro dual(f, invf)
    esc(:(
        $NiLangCore.isprimitive($f) || begin
            $NiLangCore.isprimitive(::typeof($f)) = true
        end;
        $NiLangCore.isprimitive($invf) || begin
            $NiLangCore.isprimitive(::typeof($invf)) = true
        end;
        Base.:~($f) === $invf || begin
            Base.:~(::typeof($f)) = $invf;
        end;
        Base.:~($invf) === $f || begin
            Base.:~(::typeof($invf)) = $f;
        end
    ))
end

macro dualtype(t, invt)
    esc(:(
        invtype($t) === $invt || begin
            $NiLangCore.invtype(::Type{$t}) = $invt;
        end;
        invtype($invt) === $t || begin
            $NiLangCore.invtype(::Type{$invt}) = $t;
        end
    ))
end

"""
    @selfdual f

Define `f` as a self-dual instructions.
"""
macro selfdual(f)
    esc(:(
        $NiLangCore.isreflexive($f) || begin
            $NiLangCore.isreflexive(::typeof($f)) = true
        end;
        $NiLangCore.isprimitive($f) || begin
            $NiLangCore.isprimitive(::typeof($f)) = true
        end;
        Base.:~($f) === $f || begin
            Base.:~(::typeof($f)) = $f
        end
    ))
end

export @keep
macro keep(ex)
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
    ex = precom_ex(__module__, ex, PreInfo(Symbol[]))
    @smatch ex begin
        :($f($(args...))) => begin
            symres = gensym()
            ex = :($symres = $wrap_tuple($f($(args...))))
            if startwithdot(f)
                esc(Expr(ex, bcast_assign_vars(notkey(args), symres; invcheck=invcheck)))
            else
                esc(Expr(:block, ex, assign_vars(notkey(args), symres; invcheck=invcheck)))
            end
        end
        # TODO: support multiple input
        :($f.($(args...))) => begin
            symres = gensym()
            ex = :($symres = $f.($(args...)))
            esc(Expr(:block, ex, bcast_assign_vars(notkey(args), symres; invcheck=invcheck)))
        end
        _ => error("got $ex")
    end
end

"""
    assign_vars(args, symres; invcheck)

Get the expression of assigning `symres` to `args`.
"""
function assign_vars(args, symres; invcheck)
    exprs = []
    for (i,arg) in enumerate(args)
        exi = @smatch arg begin
            :($ag...) => begin
                i!=length(args) && error("`args...` like arguments should only appear as the last argument!")
                assign_ex(ag, :($tailn($symres, Val($i-1))); invcheck=invcheck)
            end
            _ => assign_ex(arg, :($symres[$i]); invcheck=invcheck)
        end
        exi !== nothing && push!(exprs, exi)
    end
    Expr(:block, exprs...)
end

wrap_tuple(x) = (x,)
wrap_tuple(x::Tuple) = x

"""The broadcast version of `assign_vars`"""
function bcast_assign_vars(args, symres; invcheck)
    if length(args) == 1
        @smatch args[1] begin
            :($args...) => :($args = ([getindex.($symres, j) for j=1:length($symres[1])]...,))
            _ => assign_ex(args[1], symres; invcheck=invcheck)
        end
    else
        ex = :()
        for (i,arg) in enumerate(args)
            exi = @smatch arg begin
                :($ag...) => begin
                    i!=length(args) && error("`args...` like arguments should only appear as the last argument!")
                    :($ag = ([getindex.($symres, j) for j=$i:length($symres[1])]...,))
                end
                _ => assign_ex(arg, :(getindex.($symres, $i)); invcheck=invcheck)
            end
            exi !== nothing && (ex = :($ex; $exi))
        end
        ex
    end
end


function _invcheck(docheck, arg, res)
    if docheck
        :(@invcheck $arg $res)
    else
        nothing
    end
end
function assign_ex(arg::Union{Symbol,GlobalRef}, res; invcheck)
    if _isconst(arg)
        _invcheck(invcheck, arg, res)
    else
        :($arg = $res)
    end
end
assign_ex(arg::Union{Number,String}, res; invcheck) = _invcheck(invcheck, arg, res)
assign_ex(arg::Expr, res; invcheck) = @smatch arg begin
    :(@skip! $line $x) => nothing
    :($x.$k) => _isconst(x) ? _invcheck(invcheck, arg, res) : assign_ex(x, :(chfield($x, $(Val(k)), $res)); invcheck=invcheck)
    # tuples must be index through (x |> 1)
    :($a |> tget($x)) => assign_ex(a, :(chfield($a, $x, $res)); invcheck=invcheck)
    :($x |> $f) => _isconst(x) ? _invcheck(invcheck, arg,res) : assign_ex(x, :(chfield($x, $f, $res)); invcheck=invcheck)
    :($x .|> $f) => _isconst(x) ? _invcheck(invcheck, arg,res) : assign_ex(x, :(chfield.($x, Ref($f), $res)); invcheck=invcheck)
    :($x') => _isconst(x) ? _invcheck(invcheck, arg, res) : assign_ex(x, :(chfield($x, adjoint, $res)); invcheck=invcheck)
    :(-$x) => _isconst(x) ? _invcheck(invcheck, arg,res) : assign_ex(x, :(chfield($x, -, $res)); invcheck=invcheck)
    :(-.$x) => _isconst(x) ? _invcheck(invcheck, arg,res) : assign_ex(x, :(chfield.($x, Ref(-), $res)); invcheck=invcheck)
    :($f($(args...))) => all(_isconst, args) ? nothing : _invcheck(invcheck, arg,res)
    :($f.($(args...))) => all(_isconst, args) ? nothing : _invcheck(invcheck, arg,res)
    :($a[$(x...)]) => begin
        :($a[$(x...)] = $res)
    end
    :(($(args...),)) => begin
        ex = :()
        for i=1:length(args)
            ex = :($ex; $(assign_ex(args[i], :($res[$i]); invcheck=invcheck)))
        end
        ex
    end
    _ => _invcheck(invcheck, arg, res)
end

_isconst(x) = false
_isconst(x::Symbol) = x in [:im, :π, :true, :false]
_isconst(::QuoteNode) = true
_isconst(x::Union{Number,String}) = true
_isconst(x::Expr) = @smatch x begin
    :($f($(args...))) => all(_isconst, args)
    :(@keep $line $ex) => true
    _ => false
end

iter_assign(a::AbstractArray, val, indices...) = (a[indices...] = val; a)
iter_assign(a::Tuple, val, index) = TupleTools.insertat(a, index, (val,))
tailn(t::Tuple, ::Val{n}) where n = tailn(TupleTools.tail(t), Val(n-1))
tailn(t::Tuple, ::Val{0}) = t

export @assign

"""
    @assign a b [invcheck]

Perform the assign `a = b` in a reversible program.
Turn off invertibility check if the `invcheck` is false.
"""
macro assign(a, b, invcheck=true)
    esc(assign_ex(a, b; invcheck=invcheck))
end

function check_shared_rw(args...)
    args_kernel = []
    for arg in args
        out = get_memory_kernel(arg)
        if out isa Vector
            for o in out
                if o !== nothing
                    push!(args_kernel, o)
                end
            end
        elseif out !== nothing
            push!(args_kernel, out)
        end
    end
    for i=1:length(args_kernel)
        for j in i+1:length(args_kernel)
            if args_kernel[i] == args_kernel[j]
                throw(InvertibilityError("$i-th argument and $j-th argument shares the same memory $(args_kernel[i]), shared read and shared write are not allowed!"))
            end
        end
    end
end

get_memory_kernel(ex) = @smatch ex begin
    ::Symbol => ex
    :(@skip! $line $x) => nothing
    :(@keep $line $x) => get_memory_kernel(x)

    :($x.$k) => :($(get_memory_kernel(x)).$k)
    # tuples must be index through (x |> 1)
    :($a |> tget($x)) => :($(get_memory_kernel(a)) |> tget($x))
    :($x |> $f) => get_memory_kernel(x)
    :($x .|> $f) => get_memory_kernel(x)
    :($x') => get_memory_kernel(x)
    :(-$x) => get_memory_kernel(x)
    :(-.$x) => get_memory_kernel(x)  #?
    :($f($(args...))) => nothing
    :($f.($(args...))) => nothing
    :($a[$(x...)]) => :($(get_memory_kernel(a))[$(x...)])
    :(($(args...),)) => Any[get_memory_kernel(arg) for arg in args]
    :($ag...) => get_memory_kernel(ag)
    _ => nothing
end

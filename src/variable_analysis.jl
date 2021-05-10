function variable_analysis_ex(ex, syms::SymbolTable)
    use!(x) = usevar!(syms, x)
    allocate!(x) = allocatevar!(syms, x)
    deallocate!(x) = deallocatevar!(syms, x)
    @smatch ex begin
        # TODO: add variable analysis for `@destruct`
        #=
        :(($(args...),) ↔ @destruct $line $x) => begin
            if x ∈ syms.existing
                deallocate!(x)
                allocate!.(args)
            else
                deallocate!.(args)
                allocate!(x)
            end
        end
        =#
        :($x[$key] ← $val) || :($x[$key] → $val) => (use!(x); use!(key); use!(val))
        :($x ← $val) => allocate!(x)
        :($x → $val) => deallocate!(x)
        :($x ↔ $y) => swapvars!(syms, x, y)
        :($a += $f($(b...))) || :($a -= $f($(b...))) ||
        :($a *= $f($(b...))) || :($a /= $f($(b...))) ||
        :($a .+= $f($(b...))) || :($a .-= $f($(b...))) ||
        :($a .*= $f($(b...))) || :($a ./= $f($(b...))) ||
        :($a .+= $f.($(b...))) || :($a .-= $f.($(b...))) ||
        :($a .*= $f.($(b...))) || :($a ./= $f.($(b...))) => begin
            ex.args[1] = render_arg(a)
            b .= render_arg.(b)
            use!(a)
            use!.(b)
            check_args(Any[a, b...])
        end
        :($a ⊻= $f($(b...))) || :($a .⊻= $f($(b...)))  || :($a .⊻= $f.($(b...))) => begin
            ex.args[1] = render_arg(a)
            b .= render_arg.(b)
            use!(a)
            use!(b)
        end
        :($a ⊻= $b || $c) || :($a ⊻= $b && $c) => begin
            ex.args[1] = render_arg(a)
            ex.args[2].args .= render_arg.(ex.args[2].args)
            use!(a)
            use!(b)
        end
        Expr(:if, _...) => variable_analysis_if(ex, syms)
        :(while $condition; $(body...); end) => begin
            julia_usevar!(syms, condition)
            localsyms = SymbolTable(Symbol[], copy(syms.deallocated), Symbol[])
            variable_analysis_ex.(body, Ref(localsyms))
            checksyms(localsyms)
        end
        :(begin $(body...) end) => begin
            variable_analysis_ex.(body, Ref(syms))
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) => begin
            julia_usevar!(syms, range)
            localsyms = SymbolTable(Symbol[], copy(syms.deallocated), Symbol[])
            variable_analysis_ex.(body, Ref(localsyms))
            checksyms(localsyms)
            ex
        end
        :(@safe $line $subex) => julia_usevar!(syms, subex)
        :(@cuda $line $(args...)) => variable_analysis_ex(args[end], syms)
        :(@launchkernel $line $(args...)) => variable_analysis_ex(args[end], syms)
        :(@inbounds $line $subex) => variable_analysis_ex(subex, syms)
        :(@simd $line $subex) => variable_analysis_ex(subex, syms)
        :(@threads $line $subex) => variable_analysis_ex(subex, syms)
        :(@avx $line $subex) => variable_analysis_ex(subex, syms)
        :(@invcheckoff $line $subex) => variable_analysis_ex(subex, syms)
        # 1. precompile to expand macros
        # 2. get dual expression
        # 3. precompile to analyze vaiables
        :($f($(args...))) => begin
            args .= render_arg.(args)
            check_args(args)
            use!.(args)
        end
        :($f.($(args...))) => begin
            args .= render_arg.(args)
            check_args(args)
            use!.(args)
        end
        :(nothing) => nothing
        ::LineNumberNode => nothing
        ::Nothing => nothing
        _ => error("unsupported statement: $ex")
    end
end

function variable_analysis_if(ex, exsyms)
    syms = copy(exsyms)
    julia_usevar!(exsyms, ex.args[1])
    variable_analysis_ex.(ex.args[2].args, Ref(exsyms))
    checksyms(exsyms, syms)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            variable_analysis_if(ex.args[3], exsyms)
        elseif ex.args[3].head == :block
            syms = copy(exsyms)
            variable_analysis_ex.(ex.args[3].args, Ref(exsyms))
            checksyms(exsyms, syms)
        else
            error("unknown statement following `if` $ex.")
        end
    end
end

usevar!(syms::SymbolTable, arg) = @smatch arg begin
    ::Number || ::String => nothing
    ::Symbol => _isconst(arg) || operate!(syms, arg)
    :(@skip! $line $x) => julia_usevar!(syms, x)
    :($x.$k) => usevar!(syms, x)
    :($a |> subarray($(ranges...))) => (usevar!(syms, a); julia_usevar!.(Ref(syms), ranges))
    :($x |> tget($f)) || :($x |> $f) || :($x .|> $f) || :($x::$f) => (usevar!(syms, x); julia_usevar!(syms, f))
    :($x') || :(-$x) => usevar!(syms, x)
    :($t{$(p...)}($(args...))) => begin
        usevar!(syms, t)
        usevar!.(Ref(syms), p)
        usevar!.(Ref(syms), args)
    end
    :($a[$(x...)]) => begin
        usevar!(syms, a)
        usevar!.(Ref(syms), x)
    end
    :(($(args...),)) => usevar!.(Ref(syms), args)
    _ => julia_usevar!(syms, arg)
end

julia_usevar!(syms::SymbolTable, ex) = @smatch ex begin
    ::Symbol => _isconst(ex) || operate!(syms, ex)
    :($a:$b:$c) => julia_usevar!.(Ref(syms), [a, b, c])
    :($a:$c) => julia_usevar!.(Ref(syms), [a, c])
    :($a && $b) || :($a || $b) || :($a[$b]) => julia_usevar!.(Ref(syms), [a, b])
    :($a.$b) => julia_usevar!(syms, a)
    :(($(v...),)) || :(begin $(v...) end) => julia_usevar!.(Ref(syms), v)
    :($f($(v...))) || :($f[$(v...)]) => begin
        julia_usevar!(syms, f)
        julia_usevar!.(Ref(syms), v)
    end
    :($args...) => julia_usevar!(syms, args)
    Expr(:parameters, targets...) => julia_usevar!.(Ref(syms), targets)
    Expr(:kw, tar, val) => julia_usevar!(syms, val)
    ::LineNumberNode => nothing
    _ => nothing
end

# push a new variable to variable set `x`, for allocating `target`
allocatevar!(st::SymbolTable, target) = @smatch target begin
    ::Symbol => allocate!(st, target)
    :(($(tar...),)) => begin
        for t in tar
            allocatevar!(st, t)
        end
    end
    :($tar = $y) => allocatevar!(st, y)
    :($tar...) => allocatevar!(st, tar)
    :($tar::$tp) => allocatevar!(st, tar)
    Expr(:parameters, targets...) => begin
        for tar in targets
            allocatevar!(st, tar)
        end
    end
    Expr(:kw, tar, val) => begin
        allocatevar!(st, tar)
    end
    _ => _isconst(target) || error("unknown variable expression $(target)")
end

# pop a variable from variable set `x`, for deallocating `target`
deallocatevar!(st::SymbolTable, target) = @smatch target begin
    ::Symbol => deallocate!(st, target)
    :(($(tar...),)) => begin
        for t in tar
            deallocatevar!(st, t)
        end
    end
    _ => error("unknow variable expression $(target)")
end

function swapvars!(st::SymbolTable, x, y)
    e1 = isemptyvar(x)
    e2 = isemptyvar(y)
    # check assersion
    for (e, v) in ((e1, x), (e2, y))
        e && dosymbol(v) do sv
            if sv ∈ st.existing || sv ∈ st.unclassified
                throw(InvertibilityError("can not assert variable to empty: $v"))
            end
        end
    end
    if e1 && e2
    elseif e1 && !e2
        dosymbol(sx -> allocate!(st, sx), x)
        dosymbol(sy -> deallocate!(st, sy), y)
        usevar!(st, x)
    elseif !e1 && e2
        dosymbol(sx -> deallocate!(st, sx), x)
        dosymbol(sy -> allocate!(st, sy), y)
        usevar!(st, y)
    else
        sx = dosymbol(identity, x)
        sy = dosymbol(identity, y)
        if sx !== nothing && sy !== nothing
            swapsyms!(st, sx, sy)
        end
        usevar!(st, x)
        usevar!(st, y)
    end
end
isemptyvar(ex) = @smatch ex begin
    :($x[end+1]) => true
    :($x::∅) => true
    _ => false
end
dosymbol(f, ex) = @smatch ex begin
    x::Symbol => f(x)
    :($x::$T) => dosymbol(f, x)
    _ => nothing
end

_isconst(x) = @smatch x begin
    ::Symbol => x ∈ Symbol[:im, :π, :Float64, :Float32, :Int, :Int64, :Int32, :Bool, :UInt8, :String, :Char, :ComplexF64, :ComplexF32, :(:), :end, :nothing]
    ::QuoteNode || ::Bool || ::Char || ::Number || ::String => true
    :($f($(args...))) => all(_isconst, args)
    :(@const $line $ex) => true
    _ => false
end

# avoid share read/write
function check_args(args)
    args_kernel = []
    for i=1:length(args)
        out = memkernel(args[i])
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
    # error on shared read or shared write.
    for i=1:length(args_kernel)
        for j in i+1:length(args_kernel)
            if args_kernel[i] == args_kernel[j]
                throw(InvertibilityError("$i-th argument and $j-th argument shares the same memory $(args_kernel[i]), shared read and shared write are not allowed!"))
            end
        end
    end
end

# Returns the memory `identifier`, it is used to avoid shared read/write.
memkernel(ex) = @smatch ex begin
    ::Symbol => ex
    :(@const $line $x) => memkernel(x)
    :($a |> subarray($(inds...))) || :($a[$(inds...)]) => :($(memkernel(a))[$(inds...)])
    :($x.$y) => :($(memkernel(x)).$y)
    :($a |> tget($x)) => :($(memkernel(a))[$x])
    :($x |> $f) || :($x .|> $f) || :($x') || :(-$x) || :($x...) => memkernel(x)
    :($t{$(p...)}($(args...))) || :(($(args...),)) => memkernel.(args)
    _ => nothing   # Julia scope, including `@skip!`, `f(x)` et. al.
end

# Modify the argument, e.g. `x.[1,3:5]` is rendered as `x |> subarray(1,3:5)`.
render_arg(ex) = @smatch ex begin
    ::Symbol => ex
    :(@skip! $line $x) => ex
    :(@const $line $x) => Expr(:macrocall, Symbol("@const"), line, render_arg(x))
    :($a.[$(inds...)]) => :($(render_arg(a)) |> subarray($(inds...)))
    :($a |> subarray($(inds...))) => :($(render_arg(a)) |> subarray($(inds...)))
    :($a[$(inds...)]) => :($(render_arg(a))[$(inds...)])
    :($x.$y) => :($(render_arg(x)).$y)
    :($a |> tget($x)) => :($(render_arg(a)) |> tget($x))
    :($x |> $f) => :($(render_arg(x)) |> $f)
    :($x .|> $f) => :($(render_arg(x)) .|> $f)
    :($x') => :($(render_arg(x))')
    :(-$x) => :(-$(render_arg(x)))
    :($ag...) => :($(render_arg(ag))...)
    :($t{$(p...)}($(args...))) => :($t{($p...)}($(render_arg.(args)...)))
    :(($(args...),)) => :(($(render_arg.(args)...),))
    _ => ex   # Julia scope, including `@skip!`, `f(x)` et. al.
end
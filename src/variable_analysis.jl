struct SymbolTable
    existing::Vector{Symbol}
    deallocated::Vector{Symbol}
    unclassified::Vector{Symbol}
end

function SymbolTable()
    SymbolTable(Symbol[], Symbol[], Symbol[])
end

Base.copy(st::SymbolTable) = SymbolTable(copy(st.existing), copy(st.deallocated), copy(st.unclassified))

function removevar!(lst, var)
    index = findfirst(==(var), lst)
    deleteat!(lst, index)
end

function replacevar!(lst, var, var2)
    index = findfirst(==(var), lst)
    lst[index] = var2
end

function allocate!(st::SymbolTable, var::Symbol)
    if var ∈ st.existing
        throw(InvertibilityError("Repeated allocation of variable `$(var)`"))
    elseif var ∈ st.deallocated
        removevar!(st.deallocated, var)
        push!(st.existing, var)
    elseif var ∈ st.unclassified
        throw(InvertibilityError("Variable `$(var)` used before allocation."))
    else
        push!(st.existing, var)
    end
    nothing
end

function findlist(st::SymbolTable, var)
    if var ∈ st.existing
        return st.existing
    elseif var ∈ st.unclassified
        return st.unclassified
    elseif var in st.deallocated
        return st.deallocated
    else
        return nothing
    end
end
function exchangevars!(l1, v1, l2, v2)
    i1 = findfirst(==(v1), l1)
    i2 = findfirst(==(v2), l2)
    l2[i2], l1[i1] = l1[i1], l2[i2]
end

function operate!(st::SymbolTable, var::Symbol)
    if var ∈ st.existing || var ∈ st.unclassified
    elseif var ∈ st.deallocated
        throw(InvertibilityError("Operating on deallocate variable `$(var)`"))
    else
        push!(st.unclassified, var::Symbol)
    end
    nothing
end

function deallocate!(st::SymbolTable, var::Symbol)
    if var ∈ st.deallocated
        throw(InvertibilityError("Repeated deallocation of variable `$(var)`"))
    elseif var ∈ st.existing
        removevar!(st.existing, var)
        push!(st.deallocated, var)
    elseif var ∈ st.unclassified
        throw(InvertibilityError("Deallocating an external variable `$(var)`"))
    else
        throw(InvertibilityError("Deallocating an external variable `$(var)`"))
    end
    nothing
end

"""
collect variable symbols in parameters.
"""
collect_params!(target, out) = @smatch target begin
    ::Symbol => _isconst(target) || push!(out, target)
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

function _swapvars!(st::SymbolTable, var1::Symbol, var2::Symbol)
    lst1 = findlist(st, var1)
    lst2 = findlist(st, var2)
    if lst1 !== nothing && lst2 !== nothing
        exchangevars!(lst1, var1, lst2, var2)
    elseif lst1 !== nothing
        replacevar!(lst1, var1, var2)
        operate!(st, var1)
    elseif lst2 !== nothing
        replacevar!(lst2, var2, var1)
        operate!(st, var2)
    else
        operate!(st, var1)
        operate!(st, var2)
    end
end

function swapvars!(st::SymbolTable, x, y)
    @smatch x begin
        ::Symbol => _swapvars!(st, x, y)
        :(($(xs...),)) => begin
            @smatch y begin
                :(($(ys...),)) => begin
                    if length(xs) !== length(ys)
                        error("tuple size does not match! got $x and $y")
                    else
                        for (a, b) in zip(xs, ys)
                            _swapvars!(st, a, b)
                        end
                    end
                end
                _ => error("unsupported swap between $x and $y")
            end
        end
        _ => error("unknow variable expressions `$x` and `$y`")
    end
    nothing
end

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
        :($a += $b) || :($a -= $b) ||
        :($a *= $b) || :($a /= $b) || 
        :($a .+= $b) ||  :($a .-= $b) || 
        :($a .*= $b) ||  :($a ./= $b) || 
        :($a ⊻= $b) || :($a .⊻= $b) => begin
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
        :($f($(args...))) => use!.(args)
        :($f.($(args...))) => use!.(args)
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

_isconst(x) = @smatch x begin
    ::Symbol => x ∈ Symbol[:im, :π, :Float64, :Float32, :Int, :Int64, :Int32, :Bool, :UInt8, :String, :Char, :ComplexF64, :ComplexF32, :(:), :end, :nothing]
    ::QuoteNode || ::Bool || ::Char || ::Number || ::String => true
    :($f($(args...))) => all(_isconst, args)
    :(@const $line $ex) => true
    _ => false
end

function checksyms(a::SymbolTable, b::SymbolTable=SymbolTable())
    diff = setdiff(a.existing, b.existing)
    if !isempty(diff)
        error("Some variables not deallocated correctly: $diff")
    end
end

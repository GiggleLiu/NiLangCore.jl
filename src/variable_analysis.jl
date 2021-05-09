struct SymbolTable
    existing::Vector{Symbol}
    deallocated::Vector{Symbol}
    unclassified::Vector{Symbol}
end

function SymbolTable()
    SymbolTable(Symbol[], Symbol[], Symbol[])
end

copy(st::SymbolTable) = SymbolTable(copy(st.existing), copy(st.deallocated), copy(st.unclassified))

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
end

"""
collect variable symbols in parameters.
"""
function collect_params!(target, out)
    @smatch target begin
        ::Symbol => _isconst(target) || push!(out, target)
        :(($(tar...),)) => begin
            for t in tar
                pushvar!(st, t)
            end
        end
        :($tar = $y) => pushvar!(st, y)
        :($tar...) => pushvar!(st, tar)
        :($tar::$tp) => pushvar!(st, tar)
        Expr(:parameters, targets...) => begin
            for tar in targets
                pushvar!(st, tar)
            end
        end
        Expr(:kw, tar, val) => begin
            pushvar!(st, tar)
        end
        _ => _isconst(target) || error("unknown variable expression $(target)")
    end
    nothing
end


# push a new variable to variable set `x`, for allocating `target`
function pushvar!(st::SymbolTable, target)
    @smatch target begin
        ::Symbol => allocate!(st, target)
        :(($(tar...),)) => begin
            for t in tar
                pushvar!(st, t)
            end
        end
        :($tar = $y) => pushvar!(st, y)
        :($tar...) => pushvar!(st, tar)
        :($tar::$tp) => pushvar!(st, tar)
        Expr(:parameters, targets...) => begin
            for tar in targets
                pushvar!(st, tar)
            end
        end
        Expr(:kw, tar, val) => begin
            pushvar!(st, tar)
        end
        _ => _isconst(target) || error("unknown variable expression $(target)")
    end
    nothing
end

# pop a variable from variable set `x`, for deallocating `target`
function popvar!(st::SymbolTable, target)
    @smatch target begin
        ::Symbol => deallocate!(st, taget)
        :(($(tar...),)) => begin
            for t in tar
                popvar!(st, t)
            end
        end
        _ => error("unknow variable expression $(target)")
    end
    nothing
end

function swapvars!(st::SymbolTable, xs, ys)
            for t in tar
                popvar!(st, t)
            end
        else => error("unknow variable expressions `$(xs)` and `$ys`")
    end
    nothing
end

@testset "variable analysis" begin
    st = SymbolTable()
    # allocate! : not exist
    allocate!(st, :x)
    allocate!(st, :y)
    @test st.existing == [:x, :y]
    # allocate! : existing
    @test_throws InvertibilityError allocate!(st, :x)
    @test st.existing == [:x, :y]
    # deallocate! : not exist
    @test_throws InvertibilityError deallocate!(st, :z)
    # deallocate! : existing
    deallocate!(st, :y)
    @test st.existing == [:x]
    @test st.deallocated == [:y]
    # deallocate! : deallocated
    @test_throws InvertibilityError deallocate!(st, :y)
    # operate! : deallocated
    @test_throws InvertibilityError operate!(st, :y)
    # allocate! : deallocated
    allocate!(st, :y)
    @test st.existing == [:x, :y]
    @test st.deallocated == []
    # operate! : not exist
    operate!(st, :j)
    @test st.unclassified == [:j]
    # operate! : existing
    operate!(st, :y)
    @test st.unclassified == [:j]
    # allocate! unclassified
    @test_throws InvertibilityError allocate!(st, :j)
    # operate! : unclassified
    operate!(st, :j)
    @test st.unclassified == [:j]
    # deallocate! : unclassified
    @test_throws InvertibilityError deallocate!(st, :j)

    # swap both existing
    swapvars!(st, :j, :x)
    @test st.unclassified == [:x]
    @test st.existing == [:j, :y]

    # swap existing - nonexisting
    swapvars!(st, :j, :k)
    @test st.unclassified == [:x, :j]
    @test st.existing == [:k, :y]

    # swap nonexisting - existing
    swapvars!(st, :o, :x)
    @test st.unclassified == [:o, :j, :x]
    @test st.existing == [:k, :y]

    # swap both not existing
    swapvars!(st, :m, :n)
    @test st.unclassified == [:o, :j, :x, :m, :n]

    # push and pop variables
end

function variable_analysis_ex(m::Module, ex, info)
    operate!(x) -> operate!(info.syms, x)
    allocate!(x) -> pushvar!(info.syms, x)
    deallocate!(x) -> popvar!(info.syms, x)
    @smatch ex begin
        # TODO: add variable analysis for `@unsafe_destruct`
        :($((args...,)) ↔ @destruct $x => begin
            if x ∈ info.syms.existing
                deallocate!(x)
                allocate!.(args)
            else
                deallocate!.(args)
                allocate!(x)
            end
        end
        :($x[$key] ← $val) => begin
            operate!.(Any[x, key, val])
        end
        :($x[$key] → $val) => begin
            operate!.(Any[x, key, val])
        end
        :($x ← $val) => begin
            allocate!(x)
        end
        :($x → $val) => begin
            deallocate!(x)
        end
        :($x ↔ $y) => begin
            swapvars!(st, x, y)
        end
        :($a += _($b...)) || :($a -= _($b...)) ||
        :($a *= _($b...)) || :($a /= _($b...)) || 
        :($a .+= _($b...)) ||  :($a .-= _($b...)) || 
        :($a .*= _($b...)) ||  :($a ./= _($b...)) || 
        :($a ⊻= _($b...)) || :($a .⊻= _($b...)) => begin
            operate!(a)
            operate!.(b)
        end
        Expr(:if, _...) => variable_analysis_if(m, ex, info)
        :(while $condition; $(body...); end) => begin
            julia_variable_analysis_ex(m, condition, info)
            localinfo = copy(info)
            variable_analysis_ex.(m, body, Ref(info))
            checksyms(info, localinfo)
        end
        :(begin $(body...) end) => begin
            variable_analysis_ex.(m, body, Ref(info))
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end) => begin
            julia_variable_analysis_ex(m, range, info)
            localinfo = copy(info)
            variable_analysis_ex.(m, body, Ref(info))
            checksyms(info, localinfo)
            ex
        end
        :(@cuda $line $(args...)) => variable_analysis_ex(m, args[end], info)
        :(@launchkernel $line $(args...)) => variable_analysis_ex(m, args[end], info)
        :(@inbounds $line $subex) => variable_analysis_ex(m, subex, info)
        :(@simd $line $subex) => variable_analysis_ex(m, subex, info)
        :(@threads $line $subex) => variable_analysis_ex(m, subex, info)
        :(@avx $line $subex) => variable_analysis_ex(m, subex, info)
        :(@invcheckoff $line $subex) => variable_analysis_ex(m, subex, info)
        # 1. precompile to expand macros
        # 2. get dual expression
        # 3. precompile to analyze vaiables
        :($f($(args...))) => operate!.(args)
        :($f.($(args...))) => operate!.(args)
        :(nothing) => nothing
        ::LineNumberNode => nothing
        ::Nothing => nothing
        _ => error("unsupported statement: $ex")
    end
end

function variable_analysis_if(m, ex, exinfo)
    info = copy(exinfo)
    julia_variable_analysis_ex(m, ex.args[1], exinfo)
    variable_analysis_ex.(m, ex.args[2].args, Ref(exinfo))
    checksyms(exinfo, info)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            variable_analysis_if(m, ex.args[3], exinfo)
        elseif ex.args[3].head == :block
            info = copy(exinfo)
            variable_analysis_ex.(m, ex.args[3].args, Ref(exinfo))
            checksyms(exinfo, info)
        else
            error("unknown statement following `if` $ex.")
        end
    end
end

function julia_variable_analysis_ex(m, ex, info)
    @smatch ex begin
        v::Symbol => operate!(info.syms, v)
        :($a:$b:$c) => operate!.(Ref(info.syms), [a, b, c])
        :($a:$c) => operate!.(Ref(info.syms), [a, c])
        :($a && $b) || :($a || $b) || :($a[$b]) => operate!.(Ref(info.syms), [a, b])
        :($a.$b) => operate!(info.syms, a)
        :(($(v...),)) || :(_($(v...))) => operate!.(Ref(info.syms), v)
        _ => error("unknown Julia expression $ex.")
    end
end


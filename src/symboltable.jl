# * existing: the ancillas and input arguments in the local scope.
#       They should be protected to avoid duplicated allocation.
# * deallocated: the ancillas removed.
#       They should be recorded to avoid using after deallocation.
# * unclassified: the variables from global scope.
#       They can not be allocation target.
struct SymbolTable
    existing::Vector{Symbol}
    deallocated::Vector{Symbol}
    unclassified::Vector{Symbol}
end

function SymbolTable()
    SymbolTable(Symbol[], Symbol[], Symbol[])
end

Base.copy(st::SymbolTable) = SymbolTable(copy(st.existing), copy(st.deallocated), copy(st.unclassified))

# remove a variable from a list
function removevar!(lst::AbstractVector, var)
    index = findfirst(==(var), lst)
    deleteat!(lst, index)
end

# replace a variable in a list with target variable
function replacevar!(lst::AbstractVector, var, var2)
    index = findfirst(==(var), lst)
    lst[index] = var2
end

# allocate a new variable
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

# find the list containing var
function findlist(st::SymbolTable, var::Symbol)
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

# using a variable
function operate!(st::SymbolTable, var::Symbol)
    if var ∈ st.existing || var ∈ st.unclassified
    elseif var ∈ st.deallocated
        throw(InvertibilityError("Operating on deallocate variable `$(var)`"))
    else
        push!(st.unclassified, var::Symbol)
    end
    nothing
end

# deallocate a variable
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

# check symbol table to make sure there is symbols introduced in the local scope that has not yet deallocated.
# `a` is the symbol table after running local scope, `b` is the symbol table before running the local scope.
function checksyms(a::SymbolTable, b::SymbolTable=SymbolTable())
    diff = setdiff(a.existing, b.existing)
    if !isempty(diff)
        error("Some variables not deallocated correctly: $diff")
    end
end

function swapsyms!(st::SymbolTable, var1::Symbol, var2::Symbol)
    lst1 = findlist(st, var1)
    lst2 = findlist(st, var2)
    if lst1 !== nothing && lst2 !== nothing
        # exchange variables
        i1 = findfirst(==(var1), lst1)
        i2 = findfirst(==(var2), lst2)
        lst2[i2], lst1[i1] = lst1[i1], lst2[i2]
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

function swapsyms_asymetric!(st::SymbolTable, var1s::Vector, var2::Symbol)
    length(var1s) == 0 && return
    lst1 = findlist(st, var1s[1])
    for k=2:length(var1s)
        if findlist(st, var1s[k]) !== lst1
            error("variable status not aligned: $var1s")
        end
    end
    lst2 = findlist(st, var2)
    if lst1 !== nothing
        removevar!.(Ref(lst1), var1s)
        push!(lst1, var2)
    else
        operate!(st, var2)
    end
    if lst2 !== nothing
        removevar!(lst2, var2)
        push!.(Ref(lst2),var1s)
    else
        operate!.(Ref(st), var1s)
    end
end
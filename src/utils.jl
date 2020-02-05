const GLOBAL_ATOL = Ref(1e-8)
# Compile utilities
startwithdot(sym::Symbol) = string(sym)[1] == '.'
startwithdot(sym::Expr) = false
endwithpang(sym::Symbol) = string(sym)[end] == '!'
endwithpang(sym::Expr) = false
removedot(sym::Symbol) = startwithdot(sym) ? Symbol(string(sym)[2:end]) : sym
function debcast(f)
    string(f)[1] == '.' || error("$f is not a broadcasting.")
    Symbol(string(f)[2:end])
end

function get_ftype(fname)
    @match fname begin
        :($x::$tp) => tp
        _ => :($fname isa Type ? Type{$fname} : typeof($fname))
    end
end

get_argname(arg::Symbol) = arg
function get_argname(fname::Expr)
    @match fname begin
        :($x::$t) => x
        :($x::$t=$y) => x
        :($x=$y) => x
        :($x...) => :($x...)
        :($x::$t...) => :($x...)
        Expr(:parameters, args...) => fname
        _ => error("can not get the function name of expression $fname.")
    end
end

function match_function(ex)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => (fname, args, [], body)
        Expr(:function, :($fname($(args...)) where {$(ts...)}), xbody) => (fname, args, ts, xbody.args)
        _ => error("must input a function, got $ex")
    end
end


gentup(struct_T) = NamedTuple{( fieldnames(struct_T)...,), Tuple{(fieldtype(struct_T,i) for i=1:fieldcount(struct_T))...}}

"""convert an object to a named tuple."""
@generated function struct2namedtuple(x)
   nt = Expr(:quote, gentup(x))
   tup = Expr(:tuple)
   for i=1:fieldcount(x)
       push!(tup.args, :(getfield(x, $i)) )
   end
   return :($nt($tup))
end

export almost_same

"""
    almost_same(a, b; atol=GLOBAL_ATOL[], kwargs...) -> Bool

Return true if `a` and `b` are almost same w.r.t. `atol`.
"""
function almost_same(a::T, b::T; atol=GLOBAL_ATOL[], kwargs...) where T <: Number
    isapprox(a, b; atol=atol, kwargs...)
end

function almost_same(a::TA, b::TB; kwargs...) where {TA, TB}
    false
end

@generated function almost_same(a::T, b::T; kwargs...) where T
    nf = fieldcount(a)
    quote
        res = true
        @nexprs $nf i-> res = res && almost_same(getfield(a, i), getfield(b, i); kwargs...)
        res
    end
end

almost_same(x::T, y::T; kwargs...) where T<:AbstractArray = all(almost_same.(x, y; kwargs...))


rmlines(ex::Expr) = begin
    hd = ex.head
    if hd == :macrocall
        Expr(:macrocall, ex.args[1], nothing, ex.args[3] |> rmlines)
    else
        tl = map(rmlines, filter(!islinenumbernode, ex.args))
        Expr(hd, tl...)
    end
end
rmlines(@nospecialize(a)) = a
islinenumbernode(@nospecialize(x)) = x isa LineNumberNode

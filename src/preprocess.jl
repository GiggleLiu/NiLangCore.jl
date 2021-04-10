export precom

struct PreInfo
    vars::Vector{Symbol}
    ancs::MyOrderedDict{Any, Any}
    routines::Vector{Any}
end
PreInfo(vars::Vector) = PreInfo(vars, MyOrderedDict{Any,Any}(), [])

function precom(m::Module, ex)
    mc, fname, args, ts, body = match_function(ex)
    vars = Symbol[]
    newargs = map(args) do arg
        @smatch arg begin
            :(::$tp)=>Expr(:(::), gensym(), tp)
            _ => arg
        end
    end
    for arg in newargs
        pushvar!(vars, arg)
    end
    info = PreInfo(vars)
    body_out = flushancs(precom_body(m, body, info), info)
    if !isempty(info.routines)
        error("`@routine` and `~@routine` must appear in pairs, mising `~@routine`!")
    end
    mc, fname, newargs, ts, body_out
end

function precom_body(m::Module, body::AbstractVector, info)
    Any[precom_ex(m, ex, info) for ex in body]
end

function flushancs(out, info)
    for i in 1:length(info.ancs)
        (x, tp) = pop!(info.ancs)
        popvar!(info.vars, x)
        push!(out, :($x → $tp))
    end
    return out
end

function precom_opm(f, out, arg2)
    if f in [:(+=), :(-=), :(*=), :(/=)]
        @smatch arg2 begin
            :($x |> $view) => Expr(f, out, :(identity($arg2)))
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => Expr(f, out, :(identity($arg2)))
        end
    elseif f in [:(.+=), :(.-=), :(.*=), :(./=)]
        @smatch arg2 begin
            :($x |> $view) || :($x .|> $view) => Expr(f, out, :(identity.($arg2)))
            :($subf.($(subargs...))) => Expr(f, out, arg2)
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => Expr(f, out, :(identity.($arg2)))
        end
    end
end

function precom_ox(f, out, arg2)
    if f == :(⊻=)
        @smatch arg2 begin
            :($x |> $view) => Expr(f, out, :(identity($arg2)))
            :($subf($(subargs...))) ||
            :($a || $b) ||
            :($a && $b) => Expr(f, out, arg2)
            _ => Expr(f, out, :(identity($arg2)))
        end
    elseif f == :(.⊻=)
        @smatch arg2 begin
            :($x |> $view) || :($x .|> $view) => Expr(f, out, :(identity.($arg2)))
            :($subf.($(subargs...))) => Expr(f, out, arg2)
            :($subf($(subargs...))) => Expr(f, out, arg2)
            _ => Expr(f, out, :(identity.($arg2)))
        end
    end
end

# deconstruct `args`, create `x`
function symbol_transfer(xs, xvals, args, info, delete, add)
    if delete
        for arg in args
            # no need to deallocate `arg`.
            if arg ∉ xs
                delete!(info.ancs, arg)
            end
        end
    end
    if add
        for (x, xval) in zip(xs, xvals)
            if x ∉ args
                info.ancs[x] = xval
            end
        end
    end
end

function precom_ex(m::Module, ex, info)
    @smatch ex begin
        #:(($(args...),) → @destruct $line $x) => begin
        #    symbol_transfer(Any[x], Any[ex.args[3]], args, info, true, false)
        #    ex
        #end
        #:(($(args...),) ← @destruct $line $x) => begin
        #    symbol_transfer(args, Any[:(getfield($x, $i)) for i=1:length(args)], Any[x], info, false, true)
        #    ex
        #end
        :($x ← new{$(_...)}($(args...))) ||
        :($x ← new($(args...))) => begin
            symbol_transfer(Any[x], Any[ex.args[3]], args, info, true, true)
            ex
        end
        :($x → new{$(_...)}($(args...))) ||
        :($x → new($(args...))) => begin
            symbol_transfer(args, Any[:(getfield($x, $i)) for i=1:length(args)], Any[x], info, true, true)
            ex
        end
        :($x[$key] ← $val) => ex
        :($x[$key] → $val) => ex
        :($x ← $val) => begin
            info.ancs[x] = val
            pushvar!(info.vars, x)
            ex
        end
        :($x → $val) => begin
            popvar!(info.vars, x)
            delete!(info.ancs, x)
            ex
        end
        :($(xs...), $y ← $val) => precom_ex(m, :(($(xs...), $y) ← $val), info)
        :($(xs...), $y → $val) => precom_ex(m, :(($(xs...), $y) → $val), info)
        :($a += $b) => precom_opm(:+=, a, b)
        :($a -= $b) => precom_opm(:-=, a, b)
        :($a *= $b) => precom_opm(:*=, a, b)
        :($a /= $b) => precom_opm(:/=, a, b)
        :($a ⊻= $b) => precom_ox(:⊻=, a, b)
        :($a .+= $b) => precom_opm(:.+=, a, b)
        :($a .-= $b) => precom_opm(:.-=, a, b)
        :($a .*= $b) => precom_opm(:.*=, a, b)
        :($a ./= $b) => precom_opm(:./=, a, b)
        :($a .⊻= $b) => precom_ox(:.⊻=, a, b)
        Expr(:if, _...) => precom_if(m, copy(ex), info)
        :(while ($pre, $post); $(body...); end) => begin
            post = post == :~ ? pre : post
            info = PreInfo(info.vars)
            Expr(:while, :(($pre, $post)), Expr(:block, flushancs(precom_body(m, body, info), info)...))
        end
        :(@from $line $post while $pre; $(body...); end) => precom_ex(m, Expr(:while, :(($pre, !$post)), ex.args[4].args[2]), info)
        :(begin $(body...) end) => begin
            Expr(:block, precom_body(m, body, info)...)
        end
        # TODO: allow ommit step.
        :(for $i=$range; $(body...); end) ||
        :(for $i in $range; $(body...); end) => begin
            info = PreInfo(info.vars)
            Expr(:for, :($i=$(precom_range(range))), Expr(:block, flushancs(precom_body(m, body, info), info)...))
        end
        :(@safe $line $subex) => ex
        :(@cuda $line $(args...)) => ex
        :(@launchkernel $line $(args...)) => ex
        :(@inbounds $line $subex) => Expr(:macrocall, Symbol("@inbounds"), line, precom_ex(m, subex, info))
        :(@simd $line $subex) => Expr(:macrocall, Symbol("@simd"), line, precom_ex(m, subex, info))
        :(@threads $line $subex) => Expr(:macrocall, Symbol("@threads"), line, precom_ex(m, subex, info))
        :(@avx $line $subex) => Expr(:macrocall, Symbol("@avx"), line, precom_ex(m, subex, info))
        :(@invcheckoff $line $subex) => Expr(:macrocall, Symbol("@invcheckoff"), line, precom_ex(m, subex, info))
        :(@routine $line $name $expr) => begin
            @warn "`@routine name begin ... end` is deprecated, please use `@routine begin ... end`"
            precom_ex(m, :(@routine $expr), info)
        end
        :(~(@routine $line $name)) => begin
            @warn "`~@routine name` is deprecated, please use `~@routine`"
            precom_ex(m, :(~(@routine)), info)
        end
        :(@routine $line $expr) => begin
            precode = precom_ex(m, expr, info)
            push!(info.routines, precode)
            precode
        end
        :(~(@routine $line)) => begin
            if isempty(info.routines)
                error("`@routine` and `~@routine` must appear in pairs, mising `@routine`!")
            end
            precom_ex(m, dual_ex(m, pop!(info.routines)), info)
        end
        # 1. precompile to expand macros
        # 2. get dual expression
        # 3. precompile to analyze vaiables
        :(~$expr) => precom_ex(m, dual_ex(m, precom_ex(m, expr, PreInfo(Symbol[]))), info)
        :($f($(args...))) => :($f($(args...)))
        :($f.($(args...))) => :($f.($(args...)))
        :(nothing) => ex
        Expr(:macrocall, _...) => precom_ex(m, macroexpand(m, ex), info)
        ::LineNumberNode => ex
        ::Nothing => ex
        _ => error("unsupported statement: $ex")
    end
end

precom_range(range) = @smatch range begin
    _ => range
end

function precom_if(m, ex, exinfo)
    _expand_cond(cond) = @smatch cond begin
        :(($pre, ~)) => :(($pre, $pre))
        :(($pre, $post)) => :(($pre, $post))
        :($pre) => :(($pre, $pre))
    end
    if ex.head == :if
        ex.args[1] = _expand_cond(ex.args[1])
    elseif ex.head == :elseif
        ex.args[1].args[2] = _expand_cond(ex.args[1].args[2])
    end
    info = PreInfo(exinfo.vars)
    ex.args[2] = Expr(:block, flushancs(precom_body(m, ex.args[2].args, info), info)...)
    if length(ex.args) == 3
        if ex.args[3].head == :elseif
            ex.args[3] = precom_if(m, ex.args[3], exinfo)
        elseif ex.args[3].head == :block
            info = PreInfo(exinfo.vars)
            ex.args[3] = Expr(:block, flushancs(precom_body(m, ex.args[3].args, info), info)...)
        else
            error("unknown statement following `if` $ex.")
        end
    end
    ex
end

export @code_preprocess

"""
    @code_preprocess ex

Preprocess `ex` and return the symmetric reversible IR.

```jldoctest; setup=:(using NiLangCore)
julia> NiLangCore.rmlines(@code_preprocess if (x < 3, ~) x += exp(3.0) end)
:(if (x < 3, x < 3)
      x += exp(3.0)
  end)
```
"""
macro code_preprocess(ex)
    QuoteNode(precom_ex(__module__, ex, PreInfo(Symbol[])))
end

precom_ex(m::Module, ex) = precom_ex(m, ex, PreInfo(Symbol[]))

function pushvar!(x::Vector{Symbol}, target)
    @smatch target begin
        ::Symbol => begin
            if target in x
                throw(InvertibilityError("Symbol `$target` should not be used as the allocation target, it is an existing variable in the current scope."))
            else
                push!(x, target)
            end
        end
        :(($(tar...),)) => begin
            for t in tar
                pushvar!(x, t)
            end
        end
        :($tar = _) => pushvar!(x, tar)
        :($tar...) => pushvar!(x, tar)
        :($tar::$tp) => pushvar!(x, tar)
        Expr(:parameters, targets...) => begin
            for tar in targets
                pushvar!(x, tar)
            end
        end
        Expr(:kw, tar, val) => begin
            pushvar!(x, tar)
        end
        _ => error("unknown variable expression $(target)")
    end
    nothing
end

function popvar!(x::Vector{Symbol}, target)
    @smatch target begin
        ::Symbol => begin
            if target in x
                filter!(x->x!=target, x)
            else
                throw(InvertibilityError("Variable `$target` has not been defined in current scope."))
            end
        end
        :(($(tar...),)) => begin
            for t in tar
                popvar!(x, t)
            end
        end
        _ => error("unknow variable expression $(target)")
    end
    nothing
end

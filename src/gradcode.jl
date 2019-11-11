export @nograd, @adjoint, @initgrad
export grad_func

# NOTE: back and inv commute.
macro adjoint(ex)
    @match ex begin
        :(function $f'($(args...)) $(body...) end) => begin
            NiLangCore.FUNCDEF[Symbol(f, "'")] = ex
            NiLangCore.INVFUNC[Symbol(f, "'")] = Symbol(~, f, "'")
            afn_grad_compile(f, args, body)
        end
    end
end

macro nograd(f)
    narg = NiLangCore.nargs(@eval $f)
    tp = get_ftype(f)
    args = [gensym() for i=1:narg]
    NiLangCore.FUNCDEF[Symbol(f, "'")] =
    :(function ($f')($(args...), $([gensym() for arg in args]...))
        $(NiLangCore.INVFUNC[f])($(args...))
    end)
    ex = :(function (g::Grad{$tp})($(args...), $([gensym() for arg in args]...))
        $(NiLangCore.INVFUNC[f])($(args...))
    end)
    :(
    $ex;
    )
end

function afn_grad_compile(fname, args, body)
    gex = :(
        function $(grad_name(fname))($(args...));
            $(compile_body(body, ())...);
        end
    )
    if (@eval isreflexive($fname))
        gex = :($gex;
            function (grad_name(inv_name(fname)))($(args...));
                $(compile_body(dual_body(body), ())...);
            end
        )
    end
    return gex
end

"""generate argument names for gradients"""
function gen_gargs(args)
    Dict([(get_argname(arg), gensym()) for arg in args])
end

"""get argument for gradient variable from gargdict"""
function _garg(arg, gargdict)
    try
        name = get_argname(arg)
        return gargdict[name]
    catch e
        # for constants, or generated expression, ignore gradients.
        return nothing
    end
end

function g_fix(args, info)
    gargs = _garg.(args, Ref(info))
    return [args..., gargs...]
end

@gg function (g::Grad{F})(args...) where F
    narg = length(args)
    ex = NiLangCore.FUNCDEF[Symbol(F.instance)]
    @match ex begin
        :(function $fname($(xs...)) $(body...) end) ||
        :($fname($(xs...)) = $(body...)) => begin
            gargdict = gen_gargs(xs)
            res = :()
            for i = 1:narg÷2
                xname = get_argname(xs[i])
                res = :($res;
                $xname = $(args[i]);
                $(gargdict[xname]) = $(args[i+narg÷2])
                )
            end
            :($res; $(grad_body(body, gargdict)...))
        end
    end
end

function grad_func(ex)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) ||
        :($fname($(args...)) = $(body...)) => begin
            gargdict = gen_gargs(args)
            :(function $(grad_name(fname))($(g_fix(args, gargdict)...));
                    $(grad_body(body, gargdict)...);
                end)
        end
        _ => error("must input a function, got $ex")
    end
end

function grad_name(op)
    @match op begin
        :($x::$tp) => :(_::Grad{$tp})
        _ => :(_::Grad{typeof($op)})
    end
end

function grad_body(body, info)
    out = map(st->(grad_ex(st, info)), Iterators.reverse(body))
end

function grad_ex(ex, info)
    @match ex begin
        :($f($(args...))) => begin
            if f in [:⊕, :⊖]
                @match args[2] begin
                    :($subf($(subargs...))) => :($(gradname(f))($subf, $(g_fix([args[1], subargs...], info)...)))
                    _ => error("a function call should be followed after ⊕ and ⊖.")
                end
            elseif f in [:(.⊕), :(.⊖)]
                _f = removedot(f)
                @match args[2] begin
                    :($subf.($(subargs...))) => :($(gradname(_f)).($subf, $(g_fix([args[1], subargs...], info)...)))
                    :($subf($(subargs...))) => :($(gradname(_f)).($(debcast(subf)), $(g_fix([args[1], subargs...], info)...)))
                    _ => error("a broadcasted function call should be followed after .⊕ and .⊖.")
                end
            elseif startwithdot(f)
                :($(gradname(removedot(f))).($(g_fix(args, info)...)))
            else
                :($(gradname(f))($(g_fix(args, info)...)))
            end
        end
        :($f.($(args...))) => :($(gradname(f)).($(g_fix(args, info)...)))
        :(if ($pre, $post); $(tbr...); else; $(fbr...); end) => begin
            :(if ($post, $pre); $(grad_body(tbr, info)...); else; $(grad_body(fbr, info)...); end)
        end
        :(while ($pre, $post); $(body...); end) => begin
            :(while ($post, $pre); $(grad_body(body, info)...); end)
        end
        # TODO: allow ommit step.
        :(for $i=$start:$step:$stop; $(body...); end) => begin
            :(for $i=$stop:(-$step):$start; $(grad_body(body, info)...); end)
        end
        :(@maybe $line $subex) => :(@maybe $(grad_ex(subex)))
        :(@anc $line $x::$tp) => begin
            :(@deanc $line $x::$tp)
        end
        :(@deanc $line $x::$tp) => begin
            :(@anc $line $x::$tp)
        end
        _ => ex
    end
end

function gradname(f)
    :($f')
end

macro initgrad(f)
    :(@eval (grad_func(NiLangCore.FUNCDEF[$f])))
end

#=
export g
function g(f)
    mk_function(@match grad_func(getdef(f)) begin
            :(function $f($(args...)) $(body...) end) =>
                :(function ($(args...),) $(body...) end)
    end)
end
=#

export gradexpr
function gradexpr(f)
    grad_func(NiLangCore.FUNCDEF[f])
end

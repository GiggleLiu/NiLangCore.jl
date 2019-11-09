export Grad, @adjoint

struct Grad{FT} <: Function
    f::FT
end

isinvertible(::Grad) = true

Base.adjoint(f::Function) = Grad(f)
Base.show(io::IO, b::Grad) = print(io, "$(b.f)'")
Base.display(bf::Grad) where f = print(bf)

# back and inv commute.

macro adjoint(ex)
    @match ex begin
        :(function $f'($(args...)) $(body...) end) => afn_grad_compile(f, args, body)
    end
end

function (g::Grad)(args...)
    (~g.f)(args[1:length(args)÷2]...)
end

function (g::Grad)(x, xδ)
    (~g.f)(x)
end

function (g::Grad)(x, y, xδ, yδ)
    (~g.f)(x, y)
end

function (g::Grad)(x, y, z, xδ, yδ, zδ)
    (~g.f)(x, y, z)
end

function afn_grad_compile(fname, args, body)
    gex = :(
        function (_::Grad{typeof($fname)})($(args...));
            $(compile_body(body, ())...);
        end
    )
    if (@eval isreflexive($fname))
        gex = :($gex;
            function (_::Grad{typeof(~$fname)})($(args...));
                $(compile_body(dual_body(body), ())...);
            end
        )
    end
    return gex
end

"""generate argument names for gradients"""
function gen_gargs(args)
    Dict([(_argname(arg), gensym()) for arg in args])
end

"""get argument for gradient variable from gargdict"""
function _garg(arg, gargdict)
    try
        name = _argname(arg)
        return gargdict[name]
    catch e
        # for constants, or generated expression, ignore gradients.
        return nothing
    end
end

# TODO: automatically compile gradient
macro hookgrad(f)
    ex = @eval getdef($f)
    @match ex begin
        :(function $(fname)($(args...)) $(body...) end) || :($fname($(args...)) = $(body...)) =>
        grad_compile(ex, fname, args, body)
        _ => error("must input a function, got $ex")
    end
end

grad_name(op) = :($op')

function g_fix_args(args, info)
    gargs = _garg.(args, Ref(info.gargdict))
    return [args..., gargs...]
end

function compile_grad(ftype, args, gargdict)
    gargdict = gen_gargs(args)
    allargs = [args..., _garg.(args, Ref(gargdict))...]
    :(function (_::Grad{$ftype})($(args...));
        $(hookgrad(body, gargdict)...);
    end)
end

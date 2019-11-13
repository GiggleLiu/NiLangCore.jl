export @dual, @selfdual, nargs

function nargs end

"""
define dual instructions

TODO: check address conflicts!
"""
macro dual(ex)
    @match ex begin
        :($fline; function $f($(args...)) $(body...) end; $invfline;
            function $invf($(invargs...)) $(invbody...)end) => begin
            if length(args) != length(invargs)
                return :(error("forward and reverse function arguments should be the same! got $args and $invargs"))
            end
            esc(:(
            function $f($(args...)) $(body...) end;
            function $invf($(invargs...)) $(invbody...) end;
            NiLangCore.isreversible(::typeof($f)) = true;
            NiLangCore.isreversible(::typeof($invf)) = true;
            NiLangCore.isprimitive(::typeof($f)) = true;
            NiLangCore.isprimitive(::typeof($invf)) = true;
            NiLangCore.nargs(::typeof($f)) = $(length(args));
            NiLangCore.nargs(::typeof($invf)) = $(length(args));
            Base.:~(::typeof($f)) = $invf;
            Base.:~(::typeof($invf)) = $f
            ))
        end
    end
end

"""define a self-dual instruction"""
macro selfdual(ex)
    @match ex begin
        :($fline; function $f($(args...)) $(body...) end) => begin
            esc(:(
            function $f($(args...)) $(body...) end;
            NiLangCore.isreversible(::typeof($f)) = true;
            NiLangCore.isreflexive(::typeof($f)) = true;
            NiLangCore.isprimitive(::typeof($f)) = true;
            NiLangCore.nargs(::typeof($f)) = $(length(args));
            Base.:~(::typeof($f)) = $f
            ))
        end
    end
end

export @instr
macro instr(ex)
    @match ex begin
        :($f($(args...))) => esc(:($(Expr(:tuple, args...)) = $f($(args...))))
        _ => error("got $ex")
    end
end

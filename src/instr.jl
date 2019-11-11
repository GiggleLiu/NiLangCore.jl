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
            NiLangCore.INVFUNC[f] = invf
            NiLangCore.INVFUNC[invf] = f
            if length(args) != length(invargs)
                return :(error("forward and reverse function arguments should be the same! got $args and $invargs"))
            end
            :(
            function $(esc(f))($(args...)) $(body...) end;
            function $(esc(invf))($(invargs...)) $(invbody...) end;
            $(esc(:(NiLangCore.isreversible)))(::typeof($(esc(f)))) = true;
            $(esc(:(NiLangCore.isreversible)))(::typeof($(esc(invf)))) = true;
            $(esc(:(NiLangCore.isprimitive)))(::typeof($(esc(f)))) = true;
            $(esc(:(NiLangCore.isprimitive)))(::typeof($(esc(invf)))) = true;
            $(esc(:(NiLangCore.nargs)))(::typeof($(esc(f)))) = $(length(args));
            $(esc(:(NiLangCore.nargs)))(::typeof($(esc(invf)))) = $(length(args));
            Base.:~(::typeof($(esc(f)))) = $(esc(invf));
            Base.:~(::typeof($(esc(invf)))) = $(esc(f))
            )
        end
    end
end

"""define a self-dual instruction"""
macro selfdual(ex)
    @match ex begin
        :($fline; function $f($(args...)) $(body...) end) => begin
            NiLangCore.INVFUNC[f] = f
            :(
            function $(esc(f))($(args...)) $(body...) end;
            $(esc(:(NiLangCore.isreversible)))(::typeof($(esc(f)))) = true;
            $(esc(:(NiLangCore.isreflexive)))(::typeof($(esc(f)))) = true;
            $(esc(:(NiLangCore.isprimitive)))(::typeof($(esc(f)))) = true;
            $(esc(:(NiLangCore.nargs)))(::typeof($(esc(f)))) = $(length(args));
            Base.:~(::typeof($(esc(f)))) = $(esc(f))
            )
        end
    end
end

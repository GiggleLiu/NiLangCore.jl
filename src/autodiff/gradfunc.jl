export Grad, NGrad

struct NGrad{N,FT} <: Function
    f::FT
end
function NGrad{N}(f::FT) where {N,FT}
    NGrad{N,FT}(f)
end

const Grad{FT} = NGrad{1,FT}
const Hessian{FT} = NGrad{2,FT}

Base.adjoint(f::Function) = Grad(f)
Base.adjoint(f::NGrad{N}) where {N} = NGrad{N+1}(f.f)
Base.show_function(io::IO, b::NGrad{N}, compact::Bool) where {N} = print(io, "$(b.f)"*"'"^N)
Base.show_function(io::IO, ::MIME"text/plain", b::NGrad{N}, compact::Bool) where {N} = print(io, b)
Base.display(bf::NGrad) = print(bf)
Inv(f::NGrad{N}) where {N} = NGrad{N}(~f.f)
(_::Type{Inv{NGrad{N}}})(f::NGrad{M}) where {M, N} = NGrad{M-N}(f.f)
(_::Type{Inv{NGrad{M}}})(f::NGrad{M}) where {M} = f.f
#Grad(f::Inv) = Inv(f.f')

@i function (g::Grad)(args...; kwargs...)
    g.f(args...; kwargs...)
    GVar.(args)
    for i=1:length(args)
        if (args[i] isa GVar{<:Loss}, ~)
            grad(args[i]) ⊕ 1.0
        end
    end
    (~g.f)(args...; kwargs...)
end

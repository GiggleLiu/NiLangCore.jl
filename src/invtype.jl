using Base.Cartesian

@generated function chfield(x, ::Val{FIELD}, xval) where FIELD
    :(@with x.$FIELD = xval)
end
@generated function chfield(x, f::Function, xval)
    :(@invcheck f(x) xval; x)
end

function (_::Type{Inv{T}})(x) where T <: RevType
    kval = invkernel(x)
    invtype_reconstructed = T(kval)
    @invcheck invtype_reconstructed x
    kval
end

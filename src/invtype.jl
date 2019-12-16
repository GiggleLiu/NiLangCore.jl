using Base.Cartesian

@generated function chfield(x, ::Val{FIELD}, xval) where FIELD
    :(@with x.$FIELD = xval)
end
@generated function chfield(x, f::Function, xval)
    :(@invcheck f(x) xval; x)
end

function (_::Type{Inv{T}})(x) where T <: RevType
    kval = invkernel(x)
    recon = T(kval)
    @invcheck recon x
    kval
end

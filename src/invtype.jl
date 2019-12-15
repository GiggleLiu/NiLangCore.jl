using Base.Cartesian

@generated function chfield(x, ::Val{FIELD}, xval) where FIELD
    :(@with x.$FIELD = xval)
end
@generated function chfield(x, f::Function, xval)
    :($(checkconst(:(f(x)), :xval)); x)
end

function (_::Type{Inv{T}})(x) where T <: RevType
    kval = invkernel(x)
    recon = T(kval)
    @invcheck almost_same(recon, x)
    kval
end
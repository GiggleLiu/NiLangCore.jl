using Documenter, NiLangCore, NiLangCore.ADCore

makedocs(;
    modules=[NiLangCore, NiLangCore.ADCore],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/GiggleLiu/NiLangCore.jl/blob/{commit}{path}#L{line}",
    sitename="NiLangCore.jl",
    authors="JinGuo Liu, thautwarm",
    assets=String[],
)

deploydocs(;
    repo="github.com/GiggleLiu/NiLangCore.jl",
)

using NiLangCore, BenchmarkTools

bg = BenchmarkGroup()
# pop!/push!
bg["NiLang"] = @benchmarkable begin 
    @instr PUSH!(x)
    @instr POP!(x)
end seconds=1 setup=(x=3.0)

# @invcheckoff pop!/push!
bg["NiLang-@invcheckoff"] = @benchmarkable begin 
    @instr @invcheckoff PUSH!(x)
    @instr @invcheckoff POP!(x)
end seconds=1 setup=(x=3.0)

# @invcheckoff pop!/push!
bg["NiLang-@invcheckoff-@inbounds"] = @benchmarkable begin 
    @instr @invcheckoff @inbounds PUSH!(x)
    @instr @invcheckoff @inbounds POP!(x)
end seconds=1 setup=(x=3.0)

# Julia pop!/push!
bg["Julia"] = @benchmarkable begin 
    push!(stack, x)
    x = pop!(stack)
end seconds=1 setup=(x=3.0; stack=Float64[])

# setindex
bg["setindex"] = @benchmarkable begin 
    stack[2] = x
    x = 0.0
    x = stack[2]
end seconds=1 setup=(x=3.0; stack=Float64[1.0, 2.0])

# setindex-inbounds
bg["setindex-inbounds"] = @benchmarkable begin 
    stack[2] = x
    x = 0.0
    x = stack[2]
end seconds=1 setup=(x=3.0; stack=Float64[1.0, 2.0])

# FastStack
bg["FastStack"] = @benchmarkable begin 
    push!(stack, x)
    x = 0.0
    x = pop!(stack)
end seconds=1 setup=(x=3.0; stack=FastStack{Float64}(10))

# FastStack-inbounds
bg["FastStack-inbounds"] = @benchmarkable begin 
    @inbounds push!(stack, x)
    x = 0.0
    @inbounds x = pop!(stack)
end seconds=1 setup=(x=3.0; stack=FastStack{Float64}(10))

tune!(bg)
run(bg)
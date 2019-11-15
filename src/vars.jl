export @push, @pop
export @anc, @deanc

const A_STACK = []
const B_STACK = []
const GLOBAL_INFO = Dict{Any,Any}()

"""
push value to A STACK, with initialization.
"""
macro push(ex::Expr)
    @match ex begin
        :($x = $val) =>
        :(
        $(esc(x)) = $(Var(val));
        push!(A_STACK, $(esc(x)))
        )
    end
end

"""
push a value to A STACK from top of B STACK.
"""
macro push(ex::Symbol)
    :(
    $(esc(ex)) = pop!(B_STACK);
    push!(A_STACK, $(esc(ex)))
    )
end

"""
pop a value to B STACK from top of A STACK.
"""
macro pop(ex::Symbol)
    :(
    $(esc(ex)) = pop!(A_STACK);
    push!(B_STACK, $(esc(ex)))
    )
end

"""
pop value to B STACK, with post check.
"""
macro pop(ex::Expr)
    @match ex begin
        :($x = $val) =>
            :(
            push!(A_STACK, $(esc(x)));
            @invcheck $(esc(x)[]) ≈ $val
            )
    end
end

############# ancillas ################
macro deanc(ex)
    @match ex begin
        :($x::$tp) => :(@invcheck $(esc(x)) ≈ zero($tp))
        _ => error("please use like `@deanc x::T`")
    end
end

macro anc(ex)
    @match ex begin
        :($x::$tp) => :($(esc(x)) = zero($tp))
        _ => error("please use like `@anc x::T`")
    end
end

export chvar
function chvar end

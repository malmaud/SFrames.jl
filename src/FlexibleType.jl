module FlexibleTypeMod

@enum(FlexType,
    INTEGER=0,
    FLOAT,
    STRING)


using Cxx
import Cxx: CppValue
import Base: show, +, get, ==

immutable FlexibleType{T}
    val
end

function FlexibleType(x::Integer)
    FlexibleType{Int}(icxx"flexible_type((long)$x);")
end

function FlexibleType(x::Union{Float32,Float64})
    FlexibleType{Float64}(icxx"flexible_type((double)$x);")
end

get(t::FlexibleType{Int}) = icxx"(long)$(t.val);"
get(t::FlexibleType{Float64}) = icxx"(double)$(t.val);"

function show{T}(io::IO, t::FlexibleType{T})
    print(io, "FlexibleType(")
    show(io, get(t))
    print(io, ")")
end

flex_promote_rule(::Type{Float64},::Type{Float64})=Float64
flex_promote_rule(::Any,::Any)=Int

function +{T1,T2}(x1::FlexibleType{T1}, x2::FlexibleType{T2})
    FlexibleType{flex_promote_rule(T1,T2)}(icxx"$(x1.val)+$(x2.val);")
end

==(t1::FlexibleType, t2::Int) = (get(t1) == t2)

end

module FlexibleTypeMod

@enum(FlexType,
    INTEGER=0,
    FLOAT,
    STRING)


using Cxx
import Cxx: CppValue
import Base: show, get, +, -, /, *, >, >=, ==, <, <=

immutable FlexibleType
    val
end

function FlexibleType(x::Integer)
    FlexibleType(icxx"flexible_type((long)$x);")
end

function FlexibleType(x::FlexibleType)
    FlexibleType(x.val)
end

# function FlexibleType(x::Union{Float32,Float64})
#     FlexibleType(icxx"flexible_type((double)$x);")
# end

# get(t::FlexibleType{Int}) = icxx"(long)$(t.val);"::Int
# get(t::FlexibleType{Float64}) = icxx"(double)$(t.val);"::Float64

function gettype(t::FlexibleType)
    icxx"$(t.val).get_type();"
end

function get(t::FlexibleType)
    icxx"$(t.val).get<flex_int>();" |> Base.unsafe_load
end

function show(io::IO, t::FlexibleType)
    print(io, "FlexibleType(")
    show(io, get(t))
    print(io, ")")
end

for (julia_op, c_op) in [
    (:+, "+"),
    (:-, "-"),
    (:/, "/"),
    (:*, "*"),
    (:>, ">"),
    (:>=, ">="),
    (:(==), "=="),
    (:<, "<"),
    (:<=, "<=")
    ]
    cstr = "\$(s1.val) $c_op \$(s2.val);"
    cstr_scalar = "\$(s1.val) $c_op \$s2;"
    @eval  function $julia_op(s1::FlexibleType, s2::FlexibleType)
        FlexibleType($(Expr(:macrocall, Symbol("@icxx_str"), cstr)))
    end

    @eval function $julia_op(s1::FlexibleType, s2::Int)
        FlexibleType($(Expr(:macrocall, Symbol("@icxx_str"), cstr_scalar)))
    end

    @eval $julia_op(s1::Int, s2::FlexibleType) = $julia_op(s2, s1)
end

end

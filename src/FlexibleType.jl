module FlexibleTypeMod

typealias FlexType UInt8

const INTEGER = FlexType(0)
const FLOAT = FlexType(1)
const STRING = FlexType(2)
const VECTOR = FlexType(3)
const LIST = FlexType(4)
const DICT = FlexType(5)
const DATETIME = FlexType(6)
const UNDEFINED = FlexType(7)
const IMAGE = FlexType(8)

using Cxx
import Cxx: CppValue
import Base: show, get, +, -, /, *, >, >=, ==, <, <=
import SFrames.Util: cstring

immutable FlexibleType
    data::Int64
    buf::NTuple{4,UInt8}
    typ::FlexType
    buf2::NTuple{3,UInt8}
end

function FlexibleType(data, typ)
    FlexibleType(data, (0x00, 0x00, 0x00, 0x00), typ, (0x00, 0x00, 0x00))
end

function FlexibleType(x::Int)
    FlexibleType(x, INTEGER)
end

function FlexibleType(x::AbstractString)
    f = icxx"flexible_type();"
    icxx"$f = $(cstring(x));"
    f |> FlexibleType
end

function FlexibleType(c_flex_type::Cxx.CppValue)
    bytes = c_flex_type.data
    # todo make efficient
    pointer_from_objref(bytes) |> Ptr{FlexibleType} |> unsafe_load
end


function FlexibleType(x::Float64)
    FlexibleType(reinterpret(Int,x), FLOAT)
end

const FLEX_NULL = FlexibleType(0, UNDEFINED)

function Base.convert(::Type{Int}, f::FlexibleType)
    f.data
end

function Base.convert(::Type{Float64}, f::FlexibleType)
    reinterpret(Float64, f.data)
end

function Base.convert(::Type{UTF8String}, f::FlexibleType)
    "test"
end

function Base.get(f::FlexibleType)
    if f.typ == INTEGER
        Int(f)
    elseif f.typ == FLOAT
        Float64(f)
    elseif f.typ == UNDEFINED
        nothing
    elseif t.typ == STRING
        UTF8String(f)
    end
end


function FlexibleType(x::FlexibleType)
    FlexibleType(x.data, x.typ)
end


function show(io::IO, t::FlexibleType)
    print(io, "FlexibleType(")
    show(io, get(t))
    print(io, ")")
end

#  todo this is just a rough sketch of defining operators on flex types
for op in [:+, :-, :/, :*]
    @eval function $op(f1::FlexibleType, f2::FlexibleType)
        if f1.typ == INTEGER && f2.typ == INTEGER
            FlexibleType($op(Int(f1), Int(f2)))
        elseif f1.typ == UNDEFINED || f2.typ == UNDEFINED
            FLEX_NULL
        else
            FlexibleType($op(Float64(f1), Float64(f2)))
        end
    end
end

for op in [:(==), :>, :>=, :<, :<=]
    @eval function $op(f1::FlexibleType, f2::FlexibleType)
        f1.typ == f2.typ || error("Invalid comparsion")
        $op(f1.data, f2.data)
    end
end

macro dispatch_numeric(funcs...)
    block = Expr(:block)
    for func in funcs
        e = quote
            function $(esc(func))(f::FlexibleType)
                if f.typ == INTEGER
                    $(esc(func))(Int(f)) |> FlexibleType
                elseif f.typ == FLOAT
                    $(esc(func))(Float64(f)) |> FlexibleType
                else
                    error("Invalid type for operation")
                end
            end
        end
        push!(block.args, e)
    end
    block
end
@dispatch_numeric Base.sin Base.cos Base.tan Base.log Base.exp Base.sqrt Base.mod Base.mod1 Base.expm1 (-)

# for (julia_op, c_op) in [
#     (:+, "+"),
#     (:-, "-"),
#     (:/, "/"),
#     (:*, "*"),
#     (:>, ">"),
#     (:>=, ">="),
#     (:(==), "=="),
#     (:<, "<"),
#     (:<=, "<=")
#     ]
#     cstr = "\$(s1.val) $c_op \$(s2.val);"
#     cstr_scalar = "\$(s1.val) $c_op \$s2;"
#     @eval  function $julia_op(s1::FlexibleType, s2::FlexibleType)
#         FlexibleType($(Expr(:macrocall, Symbol("@icxx_str"), cstr)))
#     end
#
#     @eval function $julia_op(s1::FlexibleType, s2::Int)
#         FlexibleType($(Expr(:macrocall, Symbol("@icxx_str"), cstr_scalar)))
#     end
#
#     @eval $julia_op(s1::Int, s2::FlexibleType) = $julia_op(s2, s1)
# end

end

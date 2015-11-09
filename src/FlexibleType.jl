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
import SFrames.Util: cstring, jlstring

immutable FlexibleType
    val
end

function FlexibleType(x::Int)
    FlexibleType(icxx"return flexible_type((long)$x);")
end

function FlexibleType(x::AbstractString)
    FlexibleType(icxx"return flexible_type($(cstring(x)));")
end

function FlexibleType(x::Float64)
    FlexibleType(icxx"return flexible_type((double)$x);")
end

function Base.convert(::Type{Int}, f::FlexibleType)
    icxx"auto x=$(f.val).get<flex_int>(); return x;"
end

function Base.convert(::Type{Float64}, f::FlexibleType)
    icxx"auto x=$(f.val).get<flex_float>(); return x;"
end

function Base.convert(::Type{UTF8String}, f::FlexibleType)
    icxx"auto x=$(f.val).get<flex_string>().c_str(); return x;" |> bytestring |> utf8
end

function Base.convert{T<:Associative}(::Type{T}, f::FlexibleType)
    d = icxx"$(f.val).get<flex_dict>();"
    b = icxx"$d.begin();"
    e = icxx"$d.end();"
    d_jl = Dict{FlexibleType, FlexibleType}()
    while icxx"$b != $e;"
        val = icxx"*$b;"
        d_jl[FlexibleType(icxx"$val.first;")] = FlexibleType(icxx"$val.second;")
        b = icxx"$b+1;"
    end
    d_jl
end

function Base.get(f::FlexibleType)
    typ = f.val.data[13]
    if typ == INTEGER
        Int(f)
    elseif typ == FLOAT
        Float64(f)
    elseif typ == UNDEFINED
        nothing
    elseif typ == STRING
        UTF8String(f)
    end
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

    @eval function $julia_op(s1::FlexibleType, s2::Union{Int,Float64})
        FlexibleType($(Expr(:macrocall, Symbol("@icxx_str"), cstr_scalar)))
    end

    @eval $julia_op(s1::Union{Int,Float64}, s2::FlexibleType) = $julia_op(s2, s1)
end

macro dispatch_numeric(funcs...)
    block = Expr(:block)
    for func in funcs
        e = quote
            function $(esc(func))(f::FlexibleType)
                typ = f.val.data[13]
                if typ == INTEGER
                    $(esc(func))(Int(f)) |> FlexibleType
                elseif typ == FLOAT
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

end

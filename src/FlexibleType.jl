module FlexibleTypeMod

export FlexibleType, FlexType

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
    val::Cxx.CppValue{Cxx.CxxQualType{Cxx.CppBaseType{symbol("graphlab::flexible_type")},(false,false,false)},16}
end

Base.hash(f::FlexibleType) = hash(f.val.data)


function FlexibleType(x::Int)
    FlexibleType(icxx"return flexible_type((long)$x);")
end

function FlexibleType(x::AbstractString)
    FlexibleType(icxx"return flexible_type($(cstring(x)));")
end

function FlexibleType(x::Float64)
    FlexibleType(icxx"return flexible_type((double)$x);")
end

function FlexibleType(x::Associative)
    d = icxx"vector<pair<flexible_type, flexible_type>>();"
    for (k, v) in x
        k_f = FlexibleType(k)
        v_f = FlexibleType(v)
        icxx"$d.push_back(make_pair($(k_f.val), $(v_f.val)));"
    end
    FlexibleType(icxx"return flexible_type($d);")
end

function FlexibleType(x::AbstractVector{Float64})
    # todo directly initiative stl vector from pointer
    v=icxx"vector<double>();"
    for _ in x
        icxx"$v.push_back((double)$_);"
    end
    FlexibleType(icxx"return flexible_type($v);")
end

function FlexibleType(x::AbstractVector)
    v=icxx"vector<flexible_type>();"
    for _ in x
        icxx"$v.push_back($(FlexibleType(_).val));"
    end
    FlexibleType(icxx"return flexible_type($v);")
end

# FlexibleType(::Void) = FlexibleType(icxx"return flexible_type(flex_type_enum::UNDEFINED);")
#
# const FLEX_NULL = FlexibleType(nothing)

function Base.convert(::Type{Int}, f::FlexibleType)
    icxx"auto x=$(f.val).get<flex_int>(); return x;"
end

function Base.convert(::Type{Float64}, f::FlexibleType)
    icxx"auto x=$(f.val).get<flex_float>(); return x;"
end

function Base.convert(::Type{UTF8String}, f::FlexibleType)
    icxx"auto x=$(f.val).get<flex_string>().c_str(); return x;" |> bytestring |> utf8
end

function Base.convert(::Type{Vector{Float64}}, f::FlexibleType)
    vec = icxx"return $(f.val).get<flex_vec>();"
    pointer_to_array(icxx"$vec.data();", icxx"$vec.size();", false)
end

function Base.convert(::Type{Vector{FlexibleType}}, f::FlexibleType)
    v = FlexibleType[]
    list = icxx"return $(f.val).get<flex_list>();"
    for n=1:icxx"$list.size();"
        push!(v, FlexibleType(icxx"auto x=$list[$n-1]; return x;"))
    end
    v
end

function Base.call{K,V}(::Type{Dict{K,V}}, f::FlexibleType)
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

flex_type(f::FlexibleType) = f.val.data[13]

Base.isnull(f::FlexibleType) = flex_type(f) == UNDEFINED  # Questionable

function Base.get(f::FlexibleType)
    typ = flex_type(f)
    if typ == INTEGER
        Int(f)
    elseif typ == FLOAT
        Float64(f)
    elseif typ == DICT
        Dict(f)
    elseif typ == STRING
        UTF8String(f)
    elseif typ == VECTOR
        convert(Vector{Float64}, f)
    elseif typ == LIST
        convert(Vector{FlexibleType}, f)
    end
end

function show(io::IO, t::FlexibleType)
    print(io, "FlexibleType(")
    show(io, get(t))
    print(io, ")")
end


for (julia_op, c_op, ret_type) in [
    (:+, "+", FlexibleType),
    (:-, "-", FlexibleType),
    (:/, "/", FlexibleType),
    (:*, "*", FlexibleType),
    (:>, ">", Bool),
    (:>=, ">=", Bool),
    (:(==), "==", Bool),
    (:<, "<", Bool),
    (:<=, "<=", Bool)
    ]
    cstr = "\$(s1.val) $c_op \$(s2.val);"
    cstr_scalar = "\$(s1.val) $c_op \$s2;"
    @eval  function $julia_op(s1::FlexibleType, s2::FlexibleType)
        $ret_type($(Expr(:macrocall, Symbol("@icxx_str"), cstr)))
    end

    @eval function $julia_op(s1::FlexibleType, s2::Union{Int,Float64})
        $ret_type($(Expr(:macrocall, Symbol("@icxx_str"), cstr_scalar)))
    end

    @eval $julia_op(s1::Union{Int,Float64}, s2::FlexibleType) = $julia_op(s2, s1)
end

==(f1::FlexibleType, f2::FlexibleType) = f1.val.data == f2.val.data


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

module SArrayMod

export SArray, SArrayTyped, nummissing, clip, clip_lower, clip_upper, fillna, count_ngrams, count_words

using Cxx
using Lazy
import Base: getindex, setindex!, show, +, -, *, /, .+, .-, ./, .*, .>, .<, .==, .>=, .<=

import SFrames: FlexibleTypeMod
import SFrames.FlexibleTypeMod: FlexibleType
import SFrames: head, tail, materialize, ismaterialized, sample, dropna, save, load, unpack
import SFrames.Util: cstring

abstract SAbstractArray

immutable SArray <: SAbstractArray
    val
end

Base.eltype(::SArray) = FlexibleType

immutable SArrayTyped{T} <: SAbstractArray
    array::SArray

    SArrayTyped(array::SArray) = new(array)
    SArrayTyped(val::Cxx.CppValue) = new(SArray(val))
end

cval(s::SArray) = s.val
cval(s::SArrayTyped) = s.array.val


Base.eltype{T}(::SArrayTyped{T}) = T

function SArray{T<:Union{Int,Float64}}(x::AbstractVector{T})
    if T==Int
        writer = icxx"new gl_sarray_writer(flex_type_enum::INTEGER, 1);"
    elseif T==Float64
        writer = icxx"new gl_sarray_writer(flex_type_enum::FLOAT, 1);"
    end
    for _ in x
        icxx"$writer->write($_, 0);"
    end
    array = icxx"$writer->close();"
    icxx"delete $writer;"
    SArray(array)
end

function SArray{T<:AbstractString}(x::AbstractVector{T})
    writer = icxx"return new gl_sarray_writer(flex_type_enum::STRING, 1);"
    for _ in x
        icxx"$writer->write($(cstring(_)), 0);"
    end
    array = icxx"$writer->close();"
    icxx"delete $writer;"
    SArray(array)
end

function SArray{T<:Associative}(x::AbstractVector{T})
    writer = icxx"return new gl_sarray_writer(flex_type_enum::DICT, 1);"
    for _ in x
        icxx"$writer->write($(FlexibleType(_).val), 0);"
    end
    array = icxx"$writer->close();"
    icxx"delete $writer;"
    SArray(array)
end

function getindex{T}(s::SArray, ::Type{T})
    SArrayTyped{T}(s)
end

function getindex{T<:Union{ASCIIString, UTF8String, AbstractString}}(s::SArray, ::Type{T})
    SArrayTyped{UTF8String}(s)
end

function getindex(x::SArray, idx::Int)
    FlexibleType(icxx"$(x.val)[$idx-1];")
end

function getindex(s::SArrayTyped, idx::Int)
    s.array[idx] |> eltype(s)
end

function getindex(s::SAbstractArray, idx::UnitRange)
    icxx"$(cval(s))[{$(idx.start-1), $(idx.stop)}];" |> typeof(s)
end

function getindex(s::SAbstractArray, idx::StepRange)
    icxx"$(cval(s))[{$(idx.start-1), $(idx.step), $(idx.stop)}];" |> typeof(s)
end

function Base.start(s::SAbstractArray)
    ra = icxx"$(cval(s)).range_iterator();"
    (icxx"$ra.begin();", icxx"$ra.end();")
end

function Base.next(s::SArray, state)
    iter, enditer = state
    value = icxx"auto val=*$iter; return val;" |> FlexibleType
    (value, (icxx"$iter+1;", enditer))
end

function Base.next(s::SArrayTyped, state)
    value, next_state = next(s.array, state)
    (eltype(s)(value), next_state)
end

function Base.done(s::SAbstractArray, state)
    iter, enditer = state
    icxx"$iter == $enditer;"
end

function Base.show(io::IO, s::SAbstractArray)
    sstream = icxx"stringstream();"
    icxx"$sstream<<$(cval(s));"
    c = icxx"$sstream.str().c_str();" |> bytestring
    write(io, c)
end


Base.size(x::SAbstractArray) = (Int(icxx"$(cval(x)).size();"),)
Base.ndims(::SAbstractArray) = 1
Base.length(x::SAbstractArray) = size(x)[1]

for (julia_op, c_op) in [
    (:+, "+"),
    (:-, "-"),
    (:/, "/"),
    (:*, "*"),
    (:.>, ">"),
    (:.>=, ">="),
    (:.==, "=="),
    (:.<, "<"),
    (:.<=, "<=")
    ]
    cstr = "\$(cval(s1)) $c_op \$(cval(s2));"
    cstr_scalar = "\$(cval(s1)) $c_op \$s2;"
    for op in [julia_op, Symbol(".$julia_op")]
        @eval  function $op(s1::SAbstractArray, s2::SAbstractArray)
            typeof(s1)($(Expr(:macrocall, Symbol("@icxx_str"), cstr)))
        end
    end

    @eval function $julia_op(s1::SAbstractArray, s2::Int)
        typeof(s1)($(Expr(:macrocall, Symbol("@icxx_str"), cstr_scalar)))
    end

    @eval $julia_op(s1::Int, s2::SAbstractArray) = $julia_op(s2, s1)
end

_get(f::FlexibleType) = get(f)
_get(x) = x

function Base.convert(::Type{Vector}, s::SAbstractArray)
    res = Int[]
    for i=1:length(s)
        push!(res, s[i]|>_get)
    end
    res
end


function save(s::SAbstractArray, dir, format="binary")
    icxx"$(cval(s)).save($dir, $format);"
end

function head(s::SAbstractArray, n)
    icxx"$(cval(s)).head($n);" |> typeof(s)
end

function tail(s::SAbstractArray, n)
    icxx"$(cval(s)).tail($n);" |> typeof(s)
end

function ismaterialized(s::SAbstractArray)
    icxx"$(cval(s)).is_materialized();"
end

function materialize(s::SAbstractArray)
    icxx"$(cval(s)).materialize();"
end

function sample(s::SAbstractArray, fraction)
    icxx"$(cval(s)).sample($fraction);" |> typeof(s)
end

function Base.all(s::SAbstractArray)
    icxx"$(cval(s)).all();"
end

function Base.any(s::SAbstractArray)
    icxx"$(cval(s)).any();"
end

function nummissing(s::SAbstractArray)
    icxx"$(cval(s)).num_missing();" |> Int
end

function clip(s::SAbstractArray, lower, upper)
    icxx"$(cval(s)).clip($lower, $upper);" |> typeof(s)
end

clip_lower(s::SAbstractArray, threshold) =
    icxx"$(cval(s)).clip_lower($threshold);" |> typeof(s)


clip_upper(s::SAbstractArray, threshold) =
    icxx"$(cval(s)).clip_upper($threshold);" |> typeof(s)

function dropna(s::SAbstractArray)
    icxx"$(cval(s)).dropna();" |> typeof(s)
end

function append(s1::SAbstractArray, s2::SAbstractArray)
    icxx"$(s1.val).append($(s2.val));" |> typeof(s)
end

function fillna(s::SAbstractArray, value)
    icxx"$(cval(s)).fillna(value);" |> typeof(s)
end

function Base.unique(s::SAbstractArray)
    icxx"$(cval(s)).unique();"
end

function Base.nnz(s::SAbstractArray)
    icxx"$(cval(s)).nnz();" |> Int
end

function Base.apply(s::SArrayTyped{Int}, f, skip_undefined=true)
    f_ptr = cfunction(f, Int, (Int,))
    res = icxx"$(cval(s)).apply((long (*)(long))$(f_ptr), flex_type_enum::INTEGER);"
    SArrayTyped{Int}(res)
end

function Base.apply(s::SArrayTyped{Float64}, f, skip_undefined=true)
    f_ptr = cfunction(f, Float64, (Float64,))
    res = icxx"$(cval(s)).apply((double (*)(double))$(f_ptr), flex_type_enum::FLOAT);"
    SArrayTyped{Float64}(res)
end

# Base.map(f, s::SAbstractArray) = apply(s, f)

Base.maximum(s::SArray) = icxx"$(cval(s)).max();" |> FlexibleType
Base.minimum(s::SArray) = icxx"$(cval(s)).min();" |> FlexibleType
Base.mean(s::SArray) = icxx"$(cval(s)).mean();" |> FlexibleType
Base.std(s::SArray) = icxx"$(cval(s)).std();" |> FlexibleType

Base.maximum(s::SArrayTyped) = icxx"$(cval(s)).max();" |> FlexibleType |> Float64
Base.minimum(s::SArrayTyped) = icxx"$(cval(s)).min();" |> FlexibleType |> Float64
Base.mean(s::SArrayTyped) = icxx"$(cval(s)).mean();" |> FlexibleType |> Float64
Base.std(s::SArrayTyped) = icxx"$(cval(s)).std();" |> FlexibleType |> Float64

Base.endof(s::SAbstractArray) = length(s)

dict_keys(s::SArray) = icxx"$(s.val).dict_keys();" |> SArray
dict_values(s::SArray) = icxx"$(s.val).dict_values();" |> SArray

function count_ngrams(s::SArray, n=2, method="word", to_lower=true, ignore_space=true)
    icxx"$(s.val).count_ngrams($n, $(cstring(method)), $to_lower, $ignore_space);" |>
    SArray
end

function count_words(s::SArray, to_lower=true)
    icxx"$(s.val).count_words($to_lower);" |> SArray
end


end

module SArrayMod

using Cxx
using Lazy
import Base: getindex, setindex!, show, +, -, *, /, .+, .-, ./, .*, .>, .<, .==, .>=, .<=

import SFrames.FlexibleTypeMod: FlexibleType

immutable SArray
    val
end

function SArray(x::AbstractVector{Int})
    writer = icxx"new gl_sarray_writer(flex_type_enum::INTEGER, 1);"
    for _ in x
        icxx"$writer->write((long)$_, 0);"
    end
    array = icxx"$writer->close();"
    icxx"delete $writer;"
    SArray(array)
end

function getindex(x::SArray, idx::Int)
    FlexibleType(icxx"$(x.val)[$idx-1];")
end

function getindex(s::SArray, idx::UnitRange)
    icxx"$(s.val)[{$(idx.start-1), $(idx.stop)}];" |> SArray
end

function getindex(s::SArray, idx::StepRange)
    icxx"$(s.val)[{$(idx.start-1), $(idx.step), $(idx.stop)}];" |> SArray
end

function Base.start(s::SArray)
    ra = icxx"$(s.val).range_iterator();"
    (icxx"$ra.begin();", icxx"$ra.end();")
end

function Base.next(s::SArray, state)
    iter, enditer = state
    value = icxx"auto val=*$iter; return val;" |> FlexibleType
    (value, (icxx"$iter+1;", enditer))
end

function Base.done(s::SArray, state)
    iter, enditer = state
    icxx"$iter == $enditer;"
end

function Base.show(io::IO, s::SArray)
    sstream = icxx"stringstream();"
    icxx"$sstream<<$(s.val);"
    c = icxx"$sstream.str().c_str();" |> bytestring
    write(io, c)
end

Base.size(x::SArray) = (Int(icxx"$(x.val).size();"),)
Base.ndims(::SArray) = 1
Base.length(x::SArray) = size(x)[1]

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
    cstr = "\$(s1.val) $c_op \$(s2.val);"
    cstr_scalar = "\$(s1.val) $c_op \$s2;"
    for op in [julia_op, Symbol(".$julia_op")]
        @eval  function $op(s1::SArray, s2::SArray)
            SArray($(Expr(:macrocall, Symbol("@icxx_str"), cstr)))
        end
    end

    @eval function $julia_op(s1::SArray, s2::Int)
        SArray($(Expr(:macrocall, Symbol("@icxx_str"), cstr_scalar)))
    end

    @eval $julia_op(s1::Int, s2::SArray) = $julia_op(s2, s1)
end

function Base.convert(::Type{Vector}, s::SArray)
    res = Int[]
    for i=1:length(s)
        push!(res, s[i]|>get)
    end
    res
end

function save(s::SArray, dir, format="binary")
    icxx"$(s.val).save($dir, $format);"
end

function head(s::SArray, n)
    icxx"$(s.val).head($n);" |> SArray
end

function tail(s::SArray, n)
    icxx"$(s.val).tail($n);" |> SArray
end

function ismaterialized(s::SArray)
    icxx"$(s.val).is_materialized();"
end

function materialize(s::SArray)
    icxx"$(s.val).materialize();"
end

function sample(s::SArray, fraction)
    icxx"$(s.val).sample($fraction);" |> SArray
end

function Base.all(s::SArray)
    icxx"$(s.val).all();"
end

function Base.any(s::SArray)
    icxx"$(s.val).any();"
end

function nummissing(s::SArray)
    icxx"$(s.val).num_missing();" |> Int
end

function clip(s::SArray, lower, upper)
    icxx"$(s.val).clip($lower, $upper);" |> SArray
end

function dropna(s::SArray)
    icxx"$(s.val).dropna();" |> SArray
end

function append(s1::SArray, s2::SArray)
    icxx"$(s1.val).append($(s2.val));" |> SArray
end

function fillna(s::SArray, value)
    icxx"$(s.val).fillna(value);" |> SArray
end

function Base.unique(s::SArray)
    icxx"$(s.val).unique();"
end

function Base.nnz(s::SArray)
    icxx"$(s.val).nnz();" |> Int
end

# function Base.apply(s::SArray, f, skip_undefined=true)
#     function genf(val)
#         f(get(val))::Int
#     end
#     c_f = cfunction(genf, Int, Int)
#     icxx"$(s.val).apply($c_f, flex_type_enum::INTEGER, $skip_undefined);" |>
#     SArray
# end



end

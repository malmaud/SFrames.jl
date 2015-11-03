module SFrameMod

using Cxx
import Base: show
import SFrames.FlexibleTypeMod: FlexibleType
import SFrames.SArrayMod: SArray
import SFrames.Util: cstrings, cstring, cstring_map, cstring_vector

immutable SFrame
  val
end

SFrame() = SFrame(icxx"gl_sframe();")

SFrame(x::SFrame) = SFrame(x.val)

function Base.copy(x::SFrame)
    SFrame(icxx"gl_sframe($(x.val));")
end

function Base.getindex(s::SFrame, f::SArray)
    icxx("$(s.val)[$(f.val)];")
end

Base.getindex(s::SFrame, f::AbstractVector{Bool}) =
    s[SArray(f)]

function jlvector(cvector)
    x = FlexibleType[]
    iter = icxx"$cvector.begin();"
    e = icxx"$cvector.end();"
    while icxx"$iter != $e;"
        val = icxx"auto x=*$iter; x;"
        push!(x, FlexibleType(val))
        iter = icxx"$iter + 1;"
    end
    x
end

function Base.getindex(s::SFrame, idx::Integer)
    icxx"$(s.val)[$(Cint(idx-1))];" |> jlvector
end

function Base.start(s::SFrame)
    ra = icxx"$(s.val).range_iterator();"
    (icxx"$ra.begin();", icxx"$ra.end();")
end

function Base.next(s::SFrame, state)
    iter, enditer = state
    value = jlvector(icxx"*$iter;")
    (value, (icxx"$iter+1;", enditer))
end

function Base.done(s::SFrame, state)
    iter, enditer = state
    icxx"$iter == $enditer;"
end

function Base.size(s::SFrame)
    cols = icxx"$(s.val).num_columns();" |> Int
    rows = icxx"$(s.val).size();" |> Int
    (rows, cols)
end

Base.ndims(::SFrame) = 2
Base.length(s::SFrame) = icxx"$(s.val).size();" |> Int

ismaterialized(s::SFrame) = icxx"$(s.val).is_materialized();"

hassize(s::SFrame) = icxx"$(s.val).has_size();"

materialize(s::SFrame) = icxx"$(s.val).materialize();"

function save(s::SFrame, path, format="")
    icxx"$(s.val).save($(cstring(path)), $(cstring(format)))"
end

head(s::SFrame, n) = icxx"$(s.val).head($n);" |> SFrame
tail(s::SFrame, n) = icxx"$(s.val).tail($n);" |> SFrame
sample(s::SFrame, fraction) = icxx"$(s.val).sample($fraction);" |> SFrame
sample(s::SFrame, fraction, seed) =
    icxx"$(s.val).sample($fraction, $seed);" |> SFrame

function topk(s::SFrame, column_name, k=10, reverse=false)
    icxx"$(s.val).topk($(cstring(column_name)), $k, $reverse)" |> SFrame
end

function Base.setindex!(s::SFrame, column::SArray, name::ByteString)
    icxx"$(s.val).replace_add_column($(column.val), $(cstring(name)));"
    column
end

Base.setindex!(s::SFrame, column, name) = s[name] = SArray(column)

function Base.getindex(s::SFrame, name::AbstractString)
    icxx"$(s.val).select_column($(cstring(name)));" |> SArray
end

function Base.getindex(s::SFrame, names::AbstractVector)
    names_c = cstrings(names)
    icxx"$(s.val).select_columns($names_c);" |> SFrame
end

function Base.delete!(s::SFrame, column)
    icxx"$(s.val).remove_column($(cstring(column)));"
    s
end

function append(s1::SFrame, s2::SFrame)
    icxx"$(s1.val).append($(s2.val));" |> SFrame
end

function Base.join(s1::SFrame, s2::SFrame, joinkeys::AbstractVector, how="inner")
    icxx"$(s1.val).join($(s2.val), $(cstrings(joinkeys)), $(cstring(how)));" |>
    SFrame
end

function Base.join(s1::SFrame, s2::SFrame, joinkeys::Associative, how="inner")
    icxx"$(s1.val).join($(s2.val), $(cstring_map(joinkeys)), $(cstring(how)));" |>
    SFrame
end

function dropna(s::SFrame, columns=[], how="any")
    icxx"$(s.val).dropna($(cstring_vector(columns)), $(cstring(how)));" |> SFrame
end

function fillna(s::SFrame, column, value)
    icxx"$(s.val).fillna($(cstring(column)), $value);" |> SFrame
end

function addrownumber(s::SFrame, column_name="id", start=1)
    icxx"$(s.val).add_row_number($(cstring(column_name)), $(Csize_t(start)));" |> SFrame
end

function Base.unique(s::SFrame)
    icxx"$(s.val).unique();" |> SFrame
end

function Base.sort(s::SFrame, column, rev=false)
    icxx"$(s.val).sort($(cstring(column)), $(!rev));" |> SFrame
end

function Base.sort(s::SFrame, columns::AbstractVector, rev=false)
    icxx"$(s.val).sort($(cstrings(columns)), $(!rev));" |> SFrame
end

function stack(s::SFrame, column, new_column, drop_na=false)
    icxx"$(s.val).stack($(cstring(column)), $(cstring(new_column)), $drop_na);" |>
    SFrame
end

function stack(s::SFrame, column, new_columns::AbstractVector, drop_na=false)
    icxx"$(s.val).stack($(cstring(column)), $(cstring_vector(new_columns)),
        $drop_na);" |> SFrame
end

function unstack(s::SFrame, column, new_column="")
    icxx"$(s.val).unstack($(cstring(column)), $(cstring(new_column)));" |> SFrame
end

function unstack(s::SFrame, columns::AbstractVector, new_column="")
    icxx"$(s.val).unstack($(cstring_vector(columns)), $(cstring(new_column)));" |>
    SFrame
end

function Base.show(io::IO, s::SFrame)
    sstream = icxx"stringstream();"
    icxx"$sstream<<$(s.val);"
    c = icxx"$sstream.str().c_str();" |> bytestring
    write(io, c)
end


end

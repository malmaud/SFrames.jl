module SFrameMod

export SFrame, column_names, read_csv, pack_columns, stack, unstack, addrownumber, topk, groupby

using Cxx
import Base: show
import SFrames.FlexibleTypeMod: FlexibleType, FlexType, Cflexible_type
import SFrames.SArrayMod: SArray, SAbstractArray, cval
import SFrames: Util
import SFrames.Util: cstrings, cstring, cstring_map, cstring_vector, jl_vector
import SFrames: head, tail, materialize, ismaterialized, sample, dropna, save, load, unpack


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

immutable SFrame
    val
end

function SFrame(;kwargs...)
    s = SFrame(icxx"gl_sframe();")
    for (col, values) in kwargs
        s[col] = values
    end
    s
end


function SFrame(d::Associative)
    s = SFrame()
    for (col, values) in d
        s[col] = values
    end
    s
end

function SFrame(dir::AbstractString)
    load(dir)
end

function Base.copy(x::SFrame)
    SFrame(icxx"gl_sframe($(x.val));")
end

function Base.getindex(s::SFrame, f::SArray)
    icxx("$(s.val)[$(f.val)];")
end

Base.getindex(s::SFrame, f::AbstractVector{Bool}) =
    s[SArray(f)]


function Base.getindex(s::SFrame, idx::Integer)
    icxx"$(s.val)[$(Cint(idx-1))];" |> jlvector
end

Base.eltype(::SFrame) = Vector{FlexibleType}

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
    icxx"$(s.val).save($(cstring(path)), $(cstring(format)));"
end

function load(dir)
    s = SFrame()
    icxx"$(s.val).construct_from_sframe_index($(cstring(dir)));"
    s
end

head(s::SFrame, n) = icxx"$(s.val).head($n);" |> SFrame
tail(s::SFrame, n) = icxx"$(s.val).tail($n);" |> SFrame
sample(s::SFrame, fraction) = icxx"$(s.val).sample($fraction);" |> SFrame
sample(s::SFrame, fraction, seed) =
    icxx"$(s.val).sample($fraction, $seed);" |> SFrame

function topk(s::SFrame, column_name, k=10, reverse=false)
    icxx"$(s.val).topk($(cstring(column_name)), $k, $reverse);" |> SFrame
end

function Base.setindex!(s::SFrame, column::SAbstractArray, name)
    icxx"$(s.val).replace_add_column($(cval(column)), $(cstring(name)));"
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

function addrownumber(s::SFrame, column_name="id", start=0)
    #  todo get start=1 working
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
    icxx"$sstream<<$(s.val)<<endl;"
    c_str = icxx"$sstream.str();"
    ptr = icxx"$c_str.c_str();"
    write(io, bytestring(ptr))
end

function pack_columns(s::SFrame, column_prefix, new_column_name, dtype)
    icxx"$(s.val).pack_columns(
        $(cstring(column_prefix)), $(cstring(new_column_name)),
        flex_type_enum::DICT);" |> SFrame
end

function unpack(s::SFrame, unpack_column, column_name_prefix="X")
    icxx"$(s.val).unpack($(cstring(unpack_column)), $(cstring(column_name_prefix)));" |>
    SFrame
end

function unpack(s::SArray, column_name_prefix="X")
    icxx"$(s.val).unpack($(cstring(column_name_prefix)));" |> SFrame
end

function read_csv(csv_file; use_header=true, row_limit=-1, skip_rows=-1, delimiter=",", na_values=UTF8String[], comment_char="#", escape_char="\\", quote_char="", skip_initial_space=true, column_types=Dict{UTF8String,FlexType}())
    s = SFrame()
    opts = Dict{UTF8String, FlexibleType}()
    opts["use_header"] = FlexibleType(use_header ? 1 : 0)
    if row_limit ≥ 0
        opts["row_limit"] = FlexibleType(row_limit)
    end
    if skip_rows ≥ 0
        opts["skip_rows"] = FlexibleType(skip_rows)
    end
    opts["delimiter"] = FlexibleType(delimiter)
    opts["comment_char"] = FlexibleType(comment_char)
    opts["escape_char"] = FlexibleType(escape_char)
    opts["quote_char"] = FlexibleType(quote_char)
    opts["na_values"] = FlexibleType(na_values)
    opts["skip_initial_space"] = FlexibleType(skip_initial_space ? 1 : 0)
    opts_c = icxx"map<string, flexible_type>();"
    for (k, v) in opts
        icxx"$opts_c[$(cstring(k))] = $(v.val);"
    end
    c_column_types = icxx"map<string, flex_type_enum>();"
    for (k, v) in column_types
        icxx"$c_column_types[$(cstring(k))] = flex_type_enum($v);"
    end
    icxx"$(s.val).construct_from_csvs($(cstring(csv_file)), $opts_c, $c_column_types);";
    s
end

function column_names(s::SFrame)
    cnames = icxx"$(s.val).column_names();"
    jlnames = UTF8String[]
    b = icxx"$cnames.begin();"
    e = icxx"$cnames.end();"
    while icxx"$b!=$e;"
        push!(jlnames, icxx"(*$b).c_str();" |> bytestring)
        b = icxx"$b+1;"
    end
    jlnames
end

function groupby(s::SFrame, groupkeys, operators)
    c_keys = icxx"vector<string>();"
    c_ops = icxx"map<string, aggregate::groupby_descriptor_type>();"
    for key in groupkeys
        icxx"$c_keys.push_back($(cstring(key)));"
    end
    for (col, op) in operators
        icxx"$c_ops[$(cstring(col))] = $op;"
    end
    icxx"$(s.val).groupby($c_keys, $c_ops);" |> SFrame
end

groupby(s::SFrame, groupkey::AbstractString, operators::Associative) =
    groupby(s, [groupkey], operators)

groupby(s::SFrame, groupkeys, operator::Cxx.CppValue) =
    groupby(s, groupkeys, Dict("value"=>operator))


# todo
function generic_apply(f_ptr)
    f = icxx"(vector<flexible_type>*)$f_ptr);"
    f_jl = jl_vector(f, FlexibleType)
    r = (global_f::Function)(f_jl)
    return r.val::Cflexible_type
end

generic_apply_ptr = cfunction(generic_apply, Cflexible_type, (Ptr{Void},))

# Doesn't work yet
function Base.apply(s::SFrame, f)
    global global_f = f
    icxx"return $(s.val).apply(
        (flexible_type (*)(const vector<flexible_type>&))$generic_apply_ptr, flex_type_enum::INTEGER);" |> SArray
end


end

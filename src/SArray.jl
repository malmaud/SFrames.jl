module SArrayMod

using Cxx
import Base: getindex, setindex!, show, +

import Graphlab.FlexibleTypeMod: FlexibleType

type SArray
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

function getindex(x::SArray, idx)
    FlexibleType{Int}(icxx"$(x.val)[$idx-1];")
end

function Base.show(io::IO, s::SArray)
    write(io, "SArray(N=$(length(s)));")
end


Base.size(x::SArray) = (Int(icxx"$(x.val).size();"),)
Base.ndims(::SArray) =1
Base.length(x::SArray) = size(x)[1]

function +(s1::SArray, s2::SArray)
    SArray(icxx"$(s1.val) + $(s2.val);")
end


end

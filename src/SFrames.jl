module SFrames

export head, tail, materialize, ismaterialized, sample, dropna, unpack, save, load, SArray, SArrayTyped, nummissing, clip, clip_lower, clip_upper, fillna, count_ngrams, count_words, FlexibleType, SFrame, column_names, read_csv, unpack, pack_columns, stack, unstack, addrownumber, topk, Agg, groupby

using Cxx

"""
`head(s::T, n) -> T`

Returns the first `n` elements of `s`.

`s` can be either an `SFrame` or an `SArray`.
"""
function head end
function tail end
function materialize end
function ismaterialized end
function sample end
function dropna end
function unpack end
function save end
function load end

include("Util.jl")
include("FlexibleType.jl")
include("SArray.jl")
include("SFrame.jl")
include("Agg.jl")

# import .SFrameMod: SFrame
# import .SArrayMod: SArray
# import .FlexibleTypeMod: FlexibleType

using .FlexibleTypeMod
using .SArrayMod
using .SFrameMod


export SArray, FlexibleType


function __init__()
    const SFRAME_PATH = get(ENV, "SFRAME_PATH",
        joinpath(homedir(), "SFrame"))
    println("Assuming SFrame is in $SFRAME_PATH")
    Libdl.dlopen(
        joinpath(SFRAME_PATH, "debug/oss_src/unity/libunity_shared.so"), Libdl.RTLD_GLOBAL)

    map(path->addHeaderDir(joinpath(SFRAME_PATH,path), kind=C_System), [
        "oss_src",
        "deps/local/include",
    ])

    map(cxxinclude, [
        "unity/lib/gl_sframe.hpp",
        "unity/lib/gl_sgraph.hpp",
        "unity/lib/gl_sarray.hpp",
        "flexible_type/flexible_type.hpp",
        "flexible_type/flexible_type_base_types.hpp"
    ])

    cxx"""
    #include <iostream>
    #include <ostream>
    #include <sstream>
    #include <string>
    #include <vector>
    #include <map>
    #include <utility>

    using namespace graphlab;
    using namespace std;
    """
end



end # module

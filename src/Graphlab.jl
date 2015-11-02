module Graphlab

using Cxx
using Lazy


include("FlexibleType.jl")
include("SArray.jl")


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

    cxx"using namespace graphlab;"
end


end # module

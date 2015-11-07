using BinDeps

@BinDeps.setup

unity = library_dependency("libunity_shared")



provides(
    Binaries,
    URI(""),
    unity,
    unpacked_dir="",
    sha=""
)


@BinDeps.install Dict("libunity_shared"=>"UNITY_LIB")

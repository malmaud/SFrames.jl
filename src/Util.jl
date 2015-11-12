module Util

using Cxx

function cstrings(jlstrings)
    x = icxx"vector<string>();"
    for _ in jlstrings
        icxx"$x.push_back($(pointer(bytestring(_))));"
    end
    x
end

function cstring(jlstring)
    b = bytestring(jlstring)
    icxx"string($(pointer(b)), $(length(b)));"
end

cstring(jlstring::Symbol) = cstring(string(jlstring))


function cstring_map(jlmap)
    m = icxx"map<string, string>();"
    for (key, val) in jlmap
        icxx"$m[$(cstring(key))] = $(cstring(val));"
    end
    m
end

function cstring_vector(strings)
    x = icxx"vector<string>();"
    for _ in strings
        icxx"$x.push_back($(cstring(_)));"
    end
    x
end

function jlstring(cstr)
    icxx"$cstr.data();" |> bytestring
end

function jl_vector(cvec, T)
    b = icxx"$cvec->begin();"
    e = icxx"$cvec->end();"
    x = T[]
    while icxx"$b != $e"
        push!(x, T(icxx"auto q=*$b; return q;"))
        b = icxx"$b+1;"
    end
    x
end


end

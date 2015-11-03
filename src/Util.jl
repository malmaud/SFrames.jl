module Util

using Cxx

function cstrings(jlstrings)
  x = icxx"vector<string>();"
  for _ in jlstrings
    icxx"$x.push_back($(pointer(bytestring(_))));"
  end
  x
end

end

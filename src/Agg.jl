module Agg

using Cxx
import SFrames.SFrameMod: SFrame
import SFrames.Util: cstring


for f in  [:SUM, :MAX, :MIN, :MEAN, :AVG, :VAR, :VARIANCE, :STD, :STDV, :SELECT_ONE, :CONCAT]
    cxxstr = "aggregate::$f(\$(cstring(col)));"
    macro_e = Expr(:macrocall, Symbol("@icxx_str"), cxxstr)
    @eval function $f(col)
        $macro_e
    end
end

function COUNT()
    icxx"aggregate::COUNT();"
end

function QUANTILE(col, quantile)
    icxx"aggregate::QUANTILE($(cstring(col)), $(Float64(quantile)));"
end

function QUANTILE(col, quantiles::AbstractVector)
    c = icxx"vector<double>();"
    for _ in quantiles
        icxx"$c.push_back($(Float64(_)));"
    end
    icxx"aggregate::QUANTILE($(cstring(col)), $c);"
end

end

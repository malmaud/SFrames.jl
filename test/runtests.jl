using SFrames
using Base.Test

import SFrames.SArrayMod: SArray

# write your own tests here
let res = SArray([1,2]) + SArray([3,4])
    @test res[1] == 4
    @test res[2] == 6
end

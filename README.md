# SFrames



Wrapper around [SFrames SFrame](https://github.com/dato-code/SFrame).

**Work in progress, most functionality missing**

Installation
====

1. Install [Cxx](https://github.com/Keno/Cxx.jl), the Julia C++ FFI.
1. Clone and make a debug build of [SFrame](https://github.com/dato-code/SFrame)
1. Set an environment variable SFRAME_PATH to the directory that SFrame was cloned to.
By default, it is assumed to be in a folder called `SFrame` in your home directory.
1. Then just type `using SFrames` in your Julia REPL. Ssee the tests for usage.

Usage
====

```julia
SArray([1,2]) + SArray([3,4]) == SArray([4, 6]  # true
```

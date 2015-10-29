# Graphlab



Wrapper around [Graphlab SFrames](https://github.com/dato-code/SFrame).

**Work in progress, most functionality missing**

Installation
====

1. Install [Cxx](https://github.com/Keno/Cxx.jl), the Julia C++ FFI.
1. Clone and make a debug build of [SFrames](https://github.com/dato-code/SFrame)
1. Set an environment variable SFRAME_PATH to the directory that SFrames is was cloned to.
By default, it is assumed to be in a folder called `SFrames` in your home directory.
1. Then just type `using Graphlab` in your Julia REPL. Ssee the tests for usage.

Usage
====

```julia
SArray([1,2]) + SArray([3,4]) == SArray([4, 6]  # true
```

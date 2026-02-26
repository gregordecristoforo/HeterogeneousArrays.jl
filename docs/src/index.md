# Welcome to HeterogeneousArrays

HeterogeneousArrays is a Julia package for efficiently storing and operating on heterogeneous data with type-stable broadcasting.

## Installation

```julia
using Pkg
Pkg.add("HeterogeneousArrays")
```

## Basic Usage

Create a heterogeneous vector with mixed types and units:

```julia
using HeterogeneousArrays, Unitful

v = HeterogeneousVector(u = 3.1u"m", v = 5.2u"s")

# Access fields
v.u  # 3.1 m
v.v  # 5.2 s

# Type-stable broadcasting
2.0 .* v .+ v
```
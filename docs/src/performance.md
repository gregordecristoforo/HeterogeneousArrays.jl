# Performance Guide

`HeterogeneousVector` is designed for type-stable operations. Not all usage patterns are equally fast.

## The Core Issue: Type Stability

Julia's compiler optimizes when types are known at compile time. When types are unknown, the compiler must generate conservative (slow) code for multiple possibilities.

**In HeterogeneousArrays:**
- **Named field access** (`v.position`) → type-stable (compiler knows the exact type)
- **Broadcasting** (`v .+ w`) → type-stable (each field computed separately)
- **Flattened indexing** (`v[i]`) → *not* type-stable (compiler doesn't know which field contains index `i`)

## Three Patterns

### Type-Stable: Named Field Access

```julia
v = HeterogeneousVector(x = [1.0, 2.0], y = 5.0)
result = v.x[1] + v.y  # Fast: compiler knows x is Vector{Float64}, y is Float64
```

### Type-Stable: Broadcasting

```julia
v = HeterogeneousVector(a = [1.0, 2.0], b = 3.0)
w = HeterogeneousVector(a = [10.0, 20.0], b = 5.0)
result = v .+ w  # Fast: (a = v.a .+ w.a, b = v.b .+ w.b) computed separately
```

### Not Type-Stable: Flattened Indexing

```julia
v = HeterogeneousVector(x = [1.0, 2.0], y = 42)
x = v[1]  # Slow: could be Float64 or Int; compiler assumes Union{Float64, Int}
for i in 1:length(v)
    result += v[i]  # Slow: each element type is uncertain
end
```

## Benchmark

```julia
v = HeterogeneousVector(a = randn(1000), b = randn(1000), c = 1:1000)

# Fast: Named fields, ~0.02 ms
@time result = v.a .* 2.0 .+ v.b

# Slow: Flattened indexing, ~0.8 ms (40x slower)
@time begin
    total = 0.0
    for i in 1:length(v)
        total += v[i]
    end
end
```

## Best Practices

| Goal | Use | Type-Stable? |
|------|-----|:----------:|
| REPL exploration | `v[i]` | ✗ |
| Quick checks | `v[i]` | ✗ |
| **Loops** | `v.field[i]` | ✓ |
| **Algorithms** | `v.field[i]` | ✓ |
| **Broadcasting** | `v .+ w` or `v .* 2.0` | ✓ |
| **Solvers (ODE, etc.)** | Named fields | ✓ |

**Rule of thumb:** Use `v.field` in performance-critical code, `v[i]` only in the REPL.

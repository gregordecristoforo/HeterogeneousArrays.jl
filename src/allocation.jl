_copy_field(field::Ref) = Ref(_unwrap(field))
_copy_field(field::AbstractArray) = copy(field)

"""
    Base.copy(hv::HeterogeneousVector) -> HeterogeneousVector

Create a shallow copy of a HeterogeneousVector.

For scalar fields, the wrapper `Ref` is copied (the new vector has its own mutable container).
For array fields, the array is deeply copied via `copy()`, creating independent storage.

# Arguments
- `hv`: The HeterogeneousVector to copy

# Returns
A new HeterogeneousVector with the same structure and field names

# Examples
```jldoctest
julia> using HeterogeneousArrays

julia> v = HeterogeneousVector(a = [1, 2], b = 3.0);

julia> w = copy(v);

julia> w.a[1] = 99;  # Modifying copy does not affect original

julia> v.a[1]
1

julia> w.b = 5.0;  # Scalar field is independent

julia> v.b
3.0
```
"""
function Base.copy(hv::HeterogeneousVector)
    copied_x = map(_copy_field, NamedTuple(hv))
    HeterogeneousVector(copied_x)
end

_copy_field!(dst::Ref, src::Ref) = _set_value!(dst, _unwrap(src))
_copy_field!(dst::AbstractArray, src::AbstractArray) = copy!(dst, src)

"""
    Base.copyto!(dst::AbstractHeterogeneousVector, src::AbstractHeterogeneousVector) -> AbstractHeterogeneousVector

Copy data from a source HeterogeneousVector into a destination HeterogeneousVector.

Both vectors must have the same field names. Data is copied in-place into the destination's 
existing storage, preserving its array references for array fields and updating scalar wrappings.

# Arguments
- `dst`: The destination vector (will be modified)
- `src`: The source vector (unchanged)

# Returns
The modified `dst` vector

# Errors
- Throws an `error` if `dst` and `src` have different field names

# Examples
```jldoctest
julia> using HeterogeneousArrays

julia> v = HeterogeneousVector(a = [1, 2], b = 3.0);

julia> w = zero(v);  # Create an empty vector with same structure

julia> copyto!(w, v);  # Copy data from v into w

julia> w.a
2-element Vector{Int64}:
 1
 2
```
"""
function Base.copyto!(dst::AbstractHeterogeneousVector, src::AbstractHeterogeneousVector)
    if propertynames(dst) != propertynames(src)
        error("Cannot copy to $(nameof(typeof(dst))) with different field names: $(propertynames(dst)) vs $(propertynames(src))")
    end
    for name in propertynames(dst)
        src_field = getfield(NamedTuple(src), name)
        dst_field = getfield(NamedTuple(dst), name)
        _copy_field!(dst_field, src_field)
    end
    return dst
end

function Base.copy!(dst::AbstractHeterogeneousVector, src::AbstractHeterogeneousVector)
    Base.copyto!(dst, src)
end

_zero_field(field::Ref) = Ref(zero(_unwrap(field)))
_zero_field(field::AbstractArray) = zero(field)

_similar_field(field::Ref) = Ref(zero(_unwrap(field)))
_similar_field(field::Ref, ::Type{ElType}) where {ElType} = Ref(zero(ElType))
_similar_field(field::AbstractArray) = similar(field)
_similar_field(field::AbstractArray, ::Type{ElType}) where {ElType} = similar(field, ElType)

"""
    Base.similar(hv::HeterogeneousVector) -> HeterogeneousVector

Create a new HeterogeneousVector with the same structure and field names, with uninitialized storage.

Each field is initialized by calling `similar()` on its type, creating uninitialized (or zeroed) 
storage of the same shape and element type as the original. Use `zero()` if you want zeroed values.

# Arguments
- `hv`: The template HeterogeneousVector

# Returns
A new HeterogeneousVector with the same field names and types, containing uninitialized data

# Examples
```jldoctest
julia> using HeterogeneousArrays

julia> v = HeterogeneousVector(a = [1, 2], b = 3.0);

julia> s = similar(v);

julia> length(s.a)
2
```
"""
function Base.similar(hv::HeterogeneousVector{T}) where {T}
    similar_x = map(_zero_field, NamedTuple(hv))
    HeterogeneousVector(similar_x)
end

"""
    Base.zero(hv::HeterogeneousVector) -> HeterogeneousVector

Create a new HeterogeneousVector filled with zero values matching the structure of `hv`.

Each field is zeroed according to its element type. Scalar fields receive `zero(T)`, and 
array fields receive `zero(array)` (an all-zeros array of the same shape).

# Arguments
- `hv`: The template HeterogeneousVector

# Returns
A new HeterogeneousVector with the same field names and types, filled with zeros

# Examples
```jldoctest
julia> using HeterogeneousArrays

julia> v = HeterogeneousVector(a = [1, 2], b = 3.0);

julia> z = zero(v);

julia> z.a
2-element Vector{Int64}:
 0
 0

julia> z.b
0.0
```
"""
function Base.zero(hv::HeterogeneousVector)
    zero_x = map(_zero_field, NamedTuple(hv))
    HeterogeneousVector(zero_x)
end

"""
    Base.similar(hv::HeterogeneousVector, ::Type{T}, ::Type{S}, R::DataType...)

Construct a new `HeterogeneousVector` with the same structure and field names as `hv`, 
but with potentially different element types for each individual field.

This variadic method allows for "per-field" type specialization, similar to `ArrayPartition` 
in `RecursiveArrayTools`. It is particularly useful when you need to maintain 
heterogeneity (e.g., keeping one field as an `Int` while converting another to a `Float64`).

# Arguments
- `hv`: The template `HeterogeneousVector`.
- `T`, `S`, `R...`: A sequence of types. The total number of types provided must 
  exactly match the number of fields in `hv`.

# Returns
- A `HeterogeneousVector` where the i-th field has the i-th provided type. 
  Note that memory is uninitialized (via `similar`).

# Errors
- Throws a `DimensionMismatch` if the number of types provided does not match the 
  number of fields in the vector.

# Implementation Note
This function uses `ntuple` with a compile-time length to ensure the resulting 
`NamedTuple` is type-inferred correctly by the Julia compiler.
"""
function Base.similar(hv::HeterogeneousVector, ::Type{T}, ::Type{S}, R::DataType...) where {
        T, S}
    new_types = (T, S, R...)
    names = propertynames(hv)
    if length(new_types) != length(names)
        throw(DimensionMismatch("Number of types must match number of fields"))
    end
    new_fields_tuple = ntuple(length(names)) do i
        field = getfield(NamedTuple(hv), names[i])
        _similar_field(field, new_types[i])
    end
    return HeterogeneousVector(NamedTuple{names}(new_fields_tuple))
end

"""
    Base.similar(hv::HeterogeneousVector, ::Type{ElType})

Construct a new `HeterogeneousVector` with the same structure and field names as `hv`, 
but with all fields converted to the same uniform element type `ElType`.

This method satisfies the standard `AbstractArray` interface. It is essential for 
ensuring that broadcasting operations (e.g., `hv .* 1.0`) return a `HeterogeneousVector` 
rather than collapsing into a standard flat `Array`.

# Arguments
- `hv`: The template `HeterogeneousVector`.
- `ElType`: The target type for all segments/fields within the new vector.

# Returns
- A `HeterogeneousVector` where every field's elements are of type `ElType`.

# Implementation Note
Uses `map` over the field names to recursively call `_similar_field` on each segment, 
preserving the original `NamedTuple` keys.
"""
function Base.similar(hv::HeterogeneousVector, ::Type{ElType}) where {ElType}
    names = propertynames(hv)
    new_fields = map(names) do name
        field = getfield(NamedTuple(hv), name)
        _similar_field(field, ElType)
    end
    return HeterogeneousVector(NamedTuple{names}(new_fields))
end

"""
    similar(hv::HeterogeneousVector; kwargs...)

Construct a new `HeterogeneousVector` with the same field names and structure as `hv`, 
optionally overriding the element types of specific fields.

This method allows for high-level, name-based type transformation. If a field name is 
provided as a keyword argument, the new vector will use the specified type for that 
segment. Fields not mentioned in `kwargs` will preserve their original element types.

# Arguments
- `hv::HeterogeneousVector`: The template vector providing the names and structure.
- `kwargs...`: Pairs of `fieldname = Type` used to redefine specific segments.

# Returns
- A `HeterogeneousVector` with uninitialized (or zeroed) data in the requested types.

# Errors
- Throws an `ArgumentError` if any key in `kwargs` does not match an existing field 
  name in `hv`. This prevents silent failures caused by typos in field names.

# Performance Note
This implementation avoids `Dict` allocations by operating directly on the `kwargs` 
NamedTuple, making it more efficient and "compiler-friendly" than dictionary-based lookups.

# Example
```jldoctest
julia> using HeterogeneousArrays, Unitful

julia> v = HeterogeneousVector(pos = [1.0, 2.0]u"m", id = [10, 20]);

julia> # Change 'id' to Float64 and 'pos' to a different unit/type
       v2 = similar(v, id = Float64, pos = Float32);

julia> eltype(v2.id)
Float64

julia> # Typos in field names will now trigger an error
       similar(v, poss = Float64)
ERROR: ArgumentError: Field 'poss' does not exist in HeterogeneousVector. Available fields: (:pos, :id)
```
"""
function Base.similar(hv::HeterogeneousVector{T, S}; kwargs...) where {T, S}
    names = propertynames(hv)
    kw_names = keys(kwargs)
    for k in kw_names
        if k !== :_ && !(k in names)
            throw(ArgumentError("Field '$k' does not exist in $(nameof(typeof(hv))). Available fields: $names"))
        end
    end
    new_fields_tuple = ntuple(length(names)) do i
        name = names[i]
        field = getfield(NamedTuple(hv), name)
        target_type = get(kwargs, name, nothing)
        target_type !== nothing ? _similar_field(field, target_type) : _similar_field(field)
    end
    return HeterogeneousVector(NamedTuple{names}(new_fields_tuple))
end

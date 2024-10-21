"""
    $(@__MODULE__)

This packages provides several mutable and immutable collections that
can hold a fixed or limited (small) number of elements and are much more efficient
than `Set` and `Vector`, for example. This applies in particular
to the immutable variants because they don't allocate. At present
`SmallBitSet` and subtypes of `AbstractFixedVector` and `AbstractCapacityVector`
are defined.

If the package `BangBang.jl` is loaded, then many functions defined by
this package are also available in `!!`-form. For example, `setindex!!`
with a `SmallVector` as first argument calls [`setindex`](@ref).

Bounds checking can be skipped for the functions defined in this package
by using the `@inbounds` macro.

See [`SmallBitSet`](@ref), [`AbstractFixedVector`](@ref), [`AbstractCapacityVector`](@ref),
`Base.@inbounds`, [Section "BangBang support"](@ref sec-bangbang).
"""
module SmallCollections

using Base: @propagate_inbounds, BitInteger

using BitIntegers: AbstractBitSigned, AbstractBitUnsigned,
    UInt256, UInt512, UInt1024

"""
    $(@__MODULE__).AbstractBitInteger

This type is the union of `Base.BitInteger`, `BitIntegers.AbstractBitSigned`
and `BitIntegers.AbstractBitUnsigned`.
"""
const AbstractBitInteger = Union{BitInteger,AbstractBitSigned,AbstractBitUnsigned}

const FastInteger = Union{BitInteger,Complex{<:BitInteger}}
const FastFloat = Union{Float32,Float64,Complex{Float32},Complex{Float64}}

export capacity, fasthash

capacity(::T) where T = capacity(T)

fasthash(x) = fasthash(x, UInt(0))

"""
    $(@__MODULE__).element_type(itr) -> Type
    $(@__MODULE__).element_type(::Type) -> Type

Return the element type of an iterator or its type. This differs from `eltype`
in that the element type of a `Tuple` or `NamedTuple` is determined via `promote_type`
instead of `promote_typejoin`. For all other iterators there is no difference.

See also `Base.eltype`, `Base.promote_type`, `Base.promote_typejoin`.

# Example
```jldoctest
julia> eltype((1, 2, 3.0))
Real

julia> $(@__MODULE__).element_type((1, 2, 3.0))
Float64
```
"""
element_type(::I) where I = element_type(I)
element_type(::Type{I}) where I = eltype(I)
element_type(::Type{<:Tuple{Vararg{T}}}) where T = T
element_type(::Type{<:Tuple{Vararg{T}}}) where T <: Pair = T

Base.@assume_effects :foldable function element_type(::Type{I}) where I <: Union{Tuple,NamedTuple}
    promote_type(fieldtypes(I)...)
end

Base.@assume_effects :foldable function element_type(::Type{I}) where I <: Tuple{Vararg{Pair}}
    K = promote_type(map(first∘fieldtypes, fieldtypes(I))...)
    V = promote_type(map(last∘fieldtypes, fieldtypes(I))...)
    Pair{K,V}
end

ntuple(f, n) = Base.ntuple(f, n)
@generated ntuple(f, ::Val{N}) where N = :(Base.Cartesian.@ntuple $N i -> f(i))

include("bits.jl")
include("smallbitset.jl")

include("fixedvector.jl")
include("staticvectors.jl")

include("abstractsmallvector.jl")
include("smallvector.jl")
include("mutablesmallvector.jl")
include("packedvector.jl")
include("smalldict.jl")
include("smallset.jl")

if VERSION > v"1.11-alpha"
    eval(Expr(:public, :default, :bitsize, :FixedVectorStyle, :SmallVectorStyle))
end

end

module BangBangExt

using SmallCollections

using BangBang: BangBang, NoBang, Mutator

BangBang.implements(::Mutator, ::Type{<:Union{SmallDict, SmallSet, SmallBitSet}}) = false

for f in (:push, :pop, :delete)
    @eval NoBang.$f(v::SmallDict, x::Pair) = $f(v, x)
    @eval NoBang.$f(v::Union{SmallSet, SmallBitSet}, x) = $f(v, x)
end

const CapacityVector = Union{SmallVector, PackedVector}

BangBang.implements(::Mutator, ::Type{<:CapacityVector}) = false

for f in (:push, :pop, :pushfirst, :popfirst, :deleteat, :append)
    @eval NoBang.$f(v::CapacityVector, x) = $f(v, x)
end

BangBang.NoBang._setindex(v::CapacityVector, args...) = Base.setindex(v, args...)
# otherwise a Vector is returned

BangBang.add!!(v::CapacityVector, w::AbstractVector) = v+w
# faster than without this line

end # module

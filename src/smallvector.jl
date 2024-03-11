#
# small vectors
#

export SmallVector, setindex,
    push, pop, pushfirst, popfirst, insert, deleteat, popat,
    support, fasthash

import Base: show, ==, copy, empty,
    length, size, getindex, setindex,
    zero, zeros, ones,
    +, -, *, sum, prod, maximum, minimum

struct SmallVector{N,T} <: AbstractVector{T}
    b::Values{N,T}
    n::Int
end

function show(io::IO, v::SmallVector{N,T}) where {N,T}
    print(io, "$T[")
    join(io, v, ',')
    print(io, ']')
end

function ==(v::SmallVector, w::SmallVector)
    length(v) == length(w) && iszero(padded_sub(v.b, w.b))
end

#=
function ==(v::SmallVector, w::SmallVector)
    length(v) == length(w) && all(splat(==), zip(v.b, w.b))
end
=#

fasthash(v::SmallVector, h0::UInt) = hash(bits(v.b), hash(length(v), h0))

copy(v::SmallVector) = v

length(v::SmallVector) = v.n

size(v::SmallVector) = (length(v),)

@inline function getindex(v::SmallVector, i::Int)
    @boundscheck checkbounds(v, i)
    @inbounds v.b[i]
end

@inline function setindex(v::SmallVector, x, i::Integer)
    @boundscheck checkbounds(v, i)
    SmallVector((@inbounds setindex(v.b, x, i)), length(v))
end

empty(v::SmallVector) = SmallVector(zero(v.b), 0)

zero(v::SmallVector) = SmallVector(zero(v.b), length(v))

function zeros(::Type{SmallVector{N,T}}, n::Integer) where {N,T}
    n <= N || error("vector cannot have more than $N elements")
    SmallVector(zero(Values{N,T}), n)
end

function ones(::Type{SmallVector{N,T}}, n::Integer) where {N,T}
    n <= N || error("vector cannot have more than $N elements")
    b = ones(Values{N,T})
    SmallVector((@inbounds padtail(b, -one(T), n)), n)
end

function SmallVector{N,T}(v::SmallVector{M}) where {N,T,M}
    M <= N || length(v) <= N || error("vector cannot have more than $N elements")
    t = ntuple(i -> i <= M ? T(v.b[i]) : zero(T), Val(N))
    SmallVector{N,T}(t, length(v))
end

function SmallVector{N,T}(v::Union{AbstractVector,Tuple}) where {N,T}
    n = length(v)
    n <= N || error("vector cannot have more than $N elements")
    i1 = firstindex(v)
    t = ntuple(i -> i <= n ? T(v[i+i1-1]) : zero(T), Val(N))
    SmallVector{N,T}(t, n)
end

function SmallVector{N,T}(iter) where {N,T}
    b = zero(Values{N,T})
    n = 0
    for (i, x) in enumerate(iter)
        (n = i) <= N || error("vector cannot have more than $N elements")
        b = @inbounds setindex(b, x, i)
    end
    SmallVector(b, n)
end

SmallVector{N}(v::AbstractVector{T}) where {N,T} = SmallVector{N,T}(v)

function SmallVector{N}(v::V) where {N, V <: Tuple}
    T = promote_type(fieldtypes(V)...)
    SmallVector{N,T}(v)
end

+(v::SmallVector) = v

@inline function +(v::SmallVector, w::SmallVector)
    @boundscheck length(v) == length(w) || error("vectors must have the same length")
    SmallVector(padded_add(v.b, w.b), length(v))
end

-(v::SmallVector) = SmallVector(-v.b, length(v))

@inline function -(v::SmallVector, w::SmallVector)
    @boundscheck length(v) == length(w) || error("vectors must have the same length")
    SmallVector(padded_sub(v.b, w.b), length(v))
end

*(c::Number, v::SmallVector) = SmallVector(c*v.b, length(v))

*(v::SmallVector, c::Number) = c*v

function sum(v::SmallVector{N,T}) where {N,T}
    if T <: Base.BitSignedSmall
        sum(Int, v.b)
    elseif T <: Base.BitUnsignedSmall
        sum(UInt, v.b)
    elseif T <: Union{Base.BitInteger,Base.HWReal}
        sum(v.b)
    else
        invoke(sum, Tuple{AbstractVector}, v)
    end
end

function prod(v::SmallVector{N,T}) where {N,T}
    if !(T <: Union{Base.BitInteger,Base.HWReal})
        invoke(prod, Tuple{AbstractVector}, v)
    else
        b = padtail(v.b, T(1), length(v))
        if T <: Base.BitSignedSmall
            prod(Int, b)
        elseif T <: Base.BitUnsignedSmall
            prod(UInt, b)
        else
            prod(b)
        end
    end
end

@inline function maximum(v::SmallVector{N,T}) where {N,T}
    @boundscheck iszero(length(v)) && error("vector must not be empty")
    if T <: Unsigned
        maximum(v.b)
    else
        @inbounds maximum(padtail(v.b, typemin(T), length(v)))
    end
end

@inline function minimum(v::SmallVector{N,T}) where {N,T}
    @boundscheck iszero(length(v)) && error("vector must not be empty")
    @inbounds minimum(padtail(v.b, typemax(T), length(v)))
end

@inline function push(v::SmallVector{N}, x) where N
    n = length(v)
    @boundscheck n < N || error("vector cannot have more than $N elements")
    @inbounds SmallVector(setindex(v.b, x, n+1), n+1)
end

@propagate_inbounds push(v::SmallVector, xs...) = foldl(push, xs; init = v)

@inline function pop(v::SmallVector{N,T}) where {N,T}
    n = length(v)
    @boundscheck iszero(n) && error("vector must not be empty")
    @inbounds SmallVector(setindex(v.b, zero(T), n), n-1), v[n]
end

@inline function pushfirst(v::SmallVector{N}, x) where N
    n = length(v)
    @boundscheck n < N || error("vector cannot have more than $N elements")
    SmallVector(pushfirst(v.b, x), n+1)
end

@propagate_inbounds pushfirst(v::SmallVector, xs...) = foldr((x, v) -> pushfirst(v, x), xs; init = v)

@inline function popfirst(v::SmallVector)
    n = length(v)
    @boundscheck iszero(n) && error("vector must not be empty")
    c, x = popfirst(v.b)
    SmallVector(c, n-1), x
end

@inline function insert(v::SmallVector{N}, i::Integer, x) where N
    n = length(v)
    @boundscheck begin
        1 <= i <= n+1 || throw(BoundsError(v, i))
        n < N || error("vector cannot have more than $N elements")
    end
    @inbounds SmallVector(insert(v.b, i, x), n+1)
end

@propagate_inbounds deleteat(v::SmallVector, i) = first(popat(v, i))

@inline function popat(v::SmallVector, i::Integer)
    n = length(v)
    @boundscheck checkbounds(v, i)
    c, x = @inbounds popat(v.b, i)
    SmallVector(c, n-1), x
end

# TODO: do we want UInt?
support(v::SmallVector) = convert(SmallSet{UInt}, bits(map(!iszero, v.b)))

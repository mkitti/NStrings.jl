
"""
    StaticString(data::NTuple{N,UInt8})
    static"string"N

[`AbstractStaticString`](@ref) that stores codeunits in a NTuple{N,UInt8}.
"""
struct StaticString{N} <: AbstractStaticString{N}
    data::NTuple{N,UInt8}
    StaticString{0}(data::Tuple{}) = new{0}(data)
    StaticString{N}(data::NTuple{N,UInt8}) where N = new{N}(data)
    StaticString(data::NTuple{N,UInt8}) where N = new{N}(data)
    StaticString(data::Tuple{}) = new{0}(data)
end

"""
    SubStaticString(data::NTuple{N, UInt8}, ind::Integer)
    SubStaticString(data::NTuple{N, UInt8}, ind::AbstractUnitRange)
    substatic"string"N

[`AbstractStaticString`](@ref) that stores up to `N` codeunits in a NTuple{N,UInt8}.
The actual codeunits used are a subset indicated by an AbstractUnitRange.
"""
struct SubStaticString{N, R <: AbstractUnitRange} <: AbstractStaticString{N}
    data::NTuple{N, UInt8}
    ind::R
    function SubStaticString{N,R}(data, ind::R) where {N,R <: AbstractUnitRange}
        ind ⊆ eachindex(data) || ArgumentError("$ind is not a subset of $(eachindex(data)), the indices of data")
        return new{N, R}(data, ind)
    end
    function SubStaticString{N,R}(data::AbstractString, ind::R) where {N,R <: AbstractUnitRange}
        return SubStaticString{N, R}(StaticString{N}(data), ind)
    end

    function SubStaticString{N,R}(ass::AbstractStaticString, ind::R) where {N,R <: AbstractUnitRange}
        return SubStaticString{N, R}(data(ass), ind)
    end
    SubStaticString(data::NTuple{N,UInt8}, ind::R) where {N, R <: AbstractUnitRange} = SubStaticString{N,R}(data, ind)
end
SubStaticString{N}(data::NTuple{N, UInt8}, ind::R) where {N, R <: AbstractUnitRange} = SubStaticString{N, R}(data, ind)
SubStaticString(data::NTuple{N, UInt8}, ind::Integer=length(data)) where N = SubStaticString(data, Base.OneTo(ind))
SubStaticString(data::Tuple{}, ind::Integer=length(data)) where N = SubStaticString(data, Base.OneTo(ind))
SubStaticString{N}(data::NTuple{N, UInt8}, ind::Integer=length(data)) where N = SubStaticString{N}(data, Base.OneTo(ind))
SubStaticString{0}(data::Tuple{}, ind::Integer=length(data)) where N = SubStaticString{N}(data, Base.OneTo(ind))
@inline Base.ncodeunits(s::SubStaticString) = length(s.ind)
@inline Base.codeunits(s::SubStaticString) = s.data[s.ind]

"""
    CStaticString(data::NTuple{N,UInt8})
    cstatic"string"N

[`AbstractStaticString`](@ref) that stores codeunits in a NTuple{N,UInt8} but requires NUL codeunits to be at the end.

N.B. The size of a `CStaticString{N}` is `N+1` bytes.
"""
struct CStaticString{N} <: AbstractStaticString{N}
    data::NTuple{N,UInt8}
    _nul::UInt8
    function CStaticString(data::NTuple{N,UInt8}) where N
        _check_for_nuls(data)
        return new{N}(data, 0x0)
    end
    function CStaticString{N}(data::NTuple{M,UInt8}) where {N,M}
        _data = ntuple(i->i <= M ? data[i] : 0x0, Val(N))
        return CStaticString(_data)
    end
    CStaticString{N}(::Tuple{}) where {N} = new{N}(ntuple(i->0x0, Val(N)), 0x0)
    CStaticString{0}(::Tuple{}) = new{0}((), 0x0)
    CStaticString(::Tuple{}) = new{0}((), 0x0)
end
function _check_for_nuls(data::NTuple{N,UInt8}) where N
    first_nul = 0
    last_nonnul = 0
    for i in eachindex(data)
        if data[i] == 0x0
            if first_nul == 0
                first_nul = i
            end
        else
            last_nonnul = i
        end
    end
    # Allow for no nul byte since we have a safety nul byte
    last_nonnul <= first_nul || first_nul == 0 ||
        throw(ArgumentError("The data of a CStaticString must only contain terminal null bytes at the end."))
end

function Base.ncodeunits(string::CStaticString{N}) where N
    pos = findfirst(==(0x0), string.data)
    if isnothing(pos)
        return N
    else
        return pos-1
    end
end

"""
    PaddedStaticString{N,PAD}(data::NTuple{N,UInt8})
    padded"string[PAD]"N

[`AbstractStaticString`](@ref) that is padded with `PAD`.
"""
struct PaddedStaticString{N,PAD} <: AbstractStaticString{N}
    data::NTuple{N,UInt8}
    function PaddedStaticString{N,PAD}(data::NTuple{M,UInt8}) where {N,M,PAD}
        _data = ntuple(i->i <= M ? data[i] : UInt8(PAD), Val(N))
        return new{N,UInt8(PAD)}(_data)
    end
    function PaddedStaticString{N,PAD}(s::AbstractString) where {N,PAD}
        data = codeunits(s)
        M = ncodeunits(s)
        _data = ntuple(i->i <= M ? data[i] : UInt8(PAD), Val(N))
        return new{N,UInt8(PAD)}(_data)
    end
    PaddedStaticString{N,PAD}(data::Tuple{}) where {N,PAD} = new{N,UInt8(PAD)}(ntuple(i->UInt8(PAD), Val(N)))
    PaddedStaticString{N,PAD}(ass::AbstractStaticString) where {N,PAD} = PaddedStaticString{N,PAD}(data(ass))
    PaddedStaticString{N}(data::AbstractString) where N = PaddedStaticString{N,0x0}(data)
    PaddedStaticString{N}(data::NTuple{M,UInt8} where M) where N = PaddedStaticString{N,0x0}(data)
    PaddedStaticString{N}(data::Tuple{}) where N = PaddedStaticString{N,0x0}(data)
end

"""
    StaticStrings.pad(string::PaddedStaticString)

Retrieve the UInt8 code unit used for padding.
"""
pad(string::PaddedStaticString{N,PAD} where N) where PAD = PAD::UInt8

function Base.ncodeunits(string::PaddedStaticString{N,PAD}) where {N,PAD}
    pos = findlast(!=(UInt8(PAD)), string.data)
    if isnothing(pos)
        return 0
    else
        return pos
    end
end

const StaticStringSubTypes = (StaticString, SubStaticString, CStaticString, PaddedStaticString)

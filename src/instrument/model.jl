export InstrumentModel

abstract type AbstractInstrumentModel end

"""
    IdealInstrument(array::AbstractArrayConfiguration)

Constructs an ideal instrument that has no corruptions including feed rotations.
"""
struct IdealInstrumentModel{A} <: AbstractInstrumentModel
    array::A
end





struct InstrumentModel{J<:AbstractJonesMatrix, PI, B, A<:AbstractArrayConfiguration, P<:PolBasis} <: AbstractInstrumentModel
    """
    The instrument model for the telescope. This is usually a sparse matrix that multiplies
    the visibilties.
    """
    instrument::J
    """
    The prior for the instrument model
    """
    prior::PI
    """
    The baseline site lookup for the instrument model
    """
    bsitelookup::B
    """
    Abstract array configuration
    """
    array::A
    """
    The reference basis for the instrument model
    """
    polbasis::P
end

"""
    InstrumentModel(jones, prior, array; refbasis = CirBasis())

Builds an instrument model using the jones matrix `jones`, with priors `prior` and the
array configuration `array`. The reference basis is `refbasis` and is used to define what
the ideal basis is. Namely, the basis that you have the ideal visibilties to be represented in.
"""
function InstrumentModel(jones::AbstractJonesMatrix, prior::NamedTuple{N, <:NTuple{M, ArrayPrior}}, array::AbstractArrayConfiguration; refbasis = CirBasis()) where {N, M}
    # 1. preallocate and jones matrices
    Jpre = preallocate_jones(jones, array, refbasis)
    # 2. construct the prior with the array you have
    prior_obs = NamedDist(map(x->ObservedArrayPrior(x, array), prior))
    # 3. construct the baseline site map for each prior
    x = rand(prior_obs)
    bsitemaps = map(x->_construct_baselinemap(array, x), x)
    return InstrumentModel(Jpre, prior_obs, bsitemaps, array, refbasis)
end


struct BaselineSiteLookup{V<:AbstractArray{<:Integer}}
    indices_1::V
    indices_2::V
end

function _construct_baselinemap(array::EHTArrayConfiguration, x::SiteArray)
    T = array[:Ti]
    F = array[:Fr]
    bl = array[:sites]

    tcal = times(x)
    scal = sites(x)
    fcal = frequencies(x)
    tsf = StructArray((tcal, scal, fcal))
    ind1 = similar(T, Int)
    ind2 = similar(T, Int)
    for i in eachindex(T, F, bl, ind1, ind2)
        t = T[i]
        f = F[i]
        s1, s2 = bl[i]
        i1 = findfirst(x->(t∈x[1])&&(x[2]==s1), tsf)
        i2 = findfirst(x->(t∈x[1])&&(x[2]==s2), tsf)
        isnothing(i1) && throw(AssertionError("$t, $f, $((s1)) not found in SiteArray"))
        isnothing(i2) && throw(AssertionError("$t, $f, $((s2)) not found in SiteArray"))
        ind1[i] = i1
        ind2[i] = i2
    end
    BaselineSiteLookup(ind1, ind2)
end


intout(vis::AbstractArray{<:StokesParams{T}}) where {T<:Real} = similar(vis, SMatrix{2,2, Complex{T}, 4})
intout(vis::AbstractArray{T}) where {T<:Real} = similar(vis, Complex{T})
intout(vis::AbstractArray{<:CoherencyMatrix{A,B,T}}) where {A,B,T<:Real} = similar(vis, SMatrix{2,2, Complex{T}, 4})

intout(vis::AbstractArray{<:StokesParams{T}}) where {T<:Complex} = similar(vis, SMatrix{2,2, T, 4})
intout(vis::AbstractArray{T}) where {T<:Complex} = similar(vis, T)
intout(vis::AbstractArray{<:CoherencyMatrix{A,B,T}}) where {A,B,T<:Complex} = similar(vis, SMatrix{2,2, T, 4})


function apply_instrument(vis, J::AbstractInstrumentModel, x)
    vout = intout(vis)
    apply_instrument!(vout, vis, J, x)
    return vout
end

function apply_instrument!(vout, vis, J::AbstractInstrumentModel, x)
    @inbounds for i in eachindex(vout, vis)
        vout[i] = apply_jones(vis[i], i, J, x)
    end
    # vout .= apply_jones.(vis, eachindex(vis), Ref(J), Ref(x))
    return nothing
end

@inline get_indices(bsitemaps, index, ::Val{1}) = map(x->getindex(x.indices_1, index), bsitemaps)
@inline get_indices(bsitemaps, index, ::Val{2}) = map(x->getindex(x.indices_2, index), bsitemaps)
@inline get_params(x::NamedTuple{N}, indices::NamedTuple{N}) where {N} = NamedTuple{N}(map((xx, ii)->getindex(xx, ii), x, indices))

@inline function apply_jones(v, index::Int, J::InstrumentModel, x)
    indices1 = get_indices(J.bsitelookup, index, Val(1))
    indices2 = get_indices(J.bsitelookup, index, Val(2))
    params1 = get_params(x, indices1)
    params2 = get_params(x, indices2)
    j1 = jonesmatrix(J.instrument, params1, index, Val(1))
    j2 = jonesmatrix(J.instrument, params2, index, Val(2))
    vout =  _apply_jones(v, j1, j2, J.polbasis)
    return vout
end

@inline _apply_jones(v::Number, j1, j2, ::B) where {B} = j1*v*conj(j2)
@inline _apply_jones(v::CoherencyMatrix, j1, j2, ::B) where {B} = j1*CoherencyMatrix{B,B}(v)*j2'
@inline _apply_jones(v::StokesParams, j1, j2, ::B) where {B} = j1*CoherencyMatrix{B,B}(v)*j2'



apply_instrument(vis, ::IdealInstrumentModel, x) = vis

function ChainRulesCore.rrule(::typeof(apply_instrument), vis, J::InstrumentModel, x)
    out = apply_instrument(vis, J, x)
    function _apply_instrument_pb(Δ)
        Δout = similar(out)
        Δout .= unthunk(Δ)
        dx = map(zero, x)
        dvis = zero(vis)
        autodiff(Reverse, apply_instrument!, Duplicated(out, Δout), Duplicated(vis, dvis), Const(J), Duplicated(x, dx))
        return NoTangent(), dvis, NoTangent(), Tangent{typeof(x)}(;dx...)
    end
    return out, _apply_instrument_pb
end

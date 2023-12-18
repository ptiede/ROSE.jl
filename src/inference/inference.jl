using AbstractMCMC


"""
    $(TYPEDEF)

Specifies that the sampling algorithm usually expects a hypercube transform
"""
struct IsCube end

"""
    $(TYPEDEF)

Specifies that the sampling algorithm usually expects a uncontrained transform
"""
struct IsFlat end

struct HasDeriv end
struct NoDeriv end

export sample


"""
    samplertype(::Type)

Sampler type specifies whether to use a unit hypercube or unconstrained transformation.
"""
samplertype(::Type) = ArgumentError("samplertype not specified")


"""
    sample(post::Posterior, sampler::S, args...; initial_params=nothing, kwargs...)

Sample a posterior `post` using the `sampler`. You can optionally pass the starting location
of the sampler using `initial_params`, otherwise a random draw from the prior will be used.
"""
function AbstractMCMC.sample(rng::Random.AbstractRNG, post::Posterior, sampler::S, args...; initial_params=nothing, kwargs...) where {S}
    θ0 = initial_params
    if isnothing(initial_params)
        θ0 = prior_sample(post)
    end
    return _sample(samplertype(S), rng, post, sampler, args...; initial_params=θ0, kwargs...)
end

function AbstractMCMC.sample(post::Posterior, sampler, args...; initial_params=nothing, kwargs...)
    sample(Random.default_rng(), post, sampler, args...; initial_params, kwargs...)
end

function _sample(::IsFlat, rng, post, sampler, args...; initial_params, kwargs...)
    tpost = asflat(post)
    θ0 = HypercubeTransform.inverse(tpost, initial_params)
    return sample(rng, tpost, sampler, args...; initial_params=θ0, kwargs...)
end

function _sample(::IsCube, rng, post, sampler, args...; initial_params, kwargs...)
    tpost = ascube(post)
    θ0 = HypercubeTransform.inverse(tpost, initial_params)
    return sample(rng, tpost, sampler, args...; initial_params=θ0, kwargs...)
end


# include(joinpath(@__DIR__, "fishermatrix.jl"))

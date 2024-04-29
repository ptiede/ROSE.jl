struct ArrayPrior{D, A, R}
    default_dist::D
    override_dist::A
    refant::R
end

function ArrayPrior(dist; refant=NoReference(), kwargs...)
    return ArrayPrior(dist, kwargs, refant)
end

function site_priors(d::ArrayPrior, array)
    return site_tuple(array, d.default_dist; d.override_dist...)
end


struct ObservedArrayPrior{D, S} <: Distributions.ContinuousMultivariateDistribution
    dists::D
    sitemap::S
end
Base.eltype(d::ObservedArrayPrior) = eltype(d.dists)
Base.length(d::ObservedArrayPrior) = length(d.dists)
Dists._logpdf(d::ObservedArrayPrior, x::AbstractArray{<:Real}) = Dists._logpdf(d.dists, x)
Dists._rand!(rng::Random.AbstractRNG, d::ObservedArrayPrior, x::AbstractArray{<:Real}) = SiteArray(Dists._rand!(rng, d.dists, x), d.sitemap)
asflat(d::ObservedArrayPrior) = asflat(d.dists)
ascube(d::ObservedArrayPrior) = ascube(d.dists)

function build_sitemap(d::ArrayPrior, array)
    # construct the site by site prior
    sites_prior = site_tuple(array, d.default_dist; d.override_dist...)
    fs  = unique(array[:Fr])

    # Now we need all possible times to make sure we have all combinations
    T  = array[:Ti]
    F  = array[:Fr]



    # Ok to so this we are going to construct the schema first over sites.
    # At the end we may re-order depending on the schema ordering we want
    # to use.
    tlists = map(keys(sites_prior)) do s
        seg = segmentation(sites_prior[s])
        # get all the indices where this site is present
        inds_s = findall(x->((x[1]==s)||x[2]==s), array[:sites])
        # Get all the unique times
        ts = unique(T[inds_s])
        # Now makes the acceptable time stamps given the segmentation
        tstamp = timestamps(seg, array)
        # Now we find commonalities
        times = eltype(tstamp)[]
        for t in tstamp
            if any(x->x∈t, ts) && (!(t.t0 ∈ times))
                push!(times, t)
            end
        end
        return times
    end
    # construct the schema
    slist = mapreduce((t,s)->fill(s, length(t)), vcat, tlists, keys(sites_prior))
    tlist = reduce(vcat, tlists)

    tlistre = similar(tlist)
    slistre = similar(slist)
    # Now rearrange so we have time site ordering (sites are the fastest changing)
    tuni = sort(unique(getproperty.(tlist, :t0)))
    ind0 = 1
    for t in tuni
        ind = findall(x->x.t0==t, tlist)
        tlistre[ind0:ind0+length(ind)-1] .= tlist[ind]
        slistre[ind0:ind0+length(ind)-1] .= slist[ind]
        ind0 += length(ind)
    end
    freqs = Fill(F[1], length(tlistre))
    return SiteLookup(slistre, tlistre, freqs)
end

function ObservedArrayPrior(d::ArrayPrior, array::EHTArrayConfiguration)
    smap = build_sitemap(d, array)
    site_dists = site_tuple(array, d.default_dist; d.override_dist...)
    dists = build_dist(site_dists, smap, array, d.refant)
    return ObservedArrayPrior(dists, smap)
end

struct PartiallyConditionedDist{D<:Distributions.ContinuousMultivariateDistribution, I, F} <: Distributions.ContinuousMultivariateDistribution
    dist::D
    variate_index::I
    fixed_index::I
    fixed_values::F
end

Base.length(d::PartiallyConditionedDist) = length(d.variate_index) + length(d.fixed_index)
Base.eltype(d::PartiallyConditionedDist) = eltype(d.dist)


Distributions.sampler(d::PartiallyConditionedDist) = d

function Distributions._logpdf(d::PartiallyConditionedDist, x)
    xv = @view x[d.variate_index]
    return Dists.logpdf(d.dist, xv)
end

function Distributions._rand!(rng::AbstractRNG, d::PartiallyConditionedDist, x::AbstractArray{<:Real})
    rand!(rng, d.dist, @view(x[d.variate_index]))
    # Now adjust the other indices
    x[d.fixed_index] .= d.fixed_values
    return x
end


function build_dist(dists::NamedTuple, smap::SiteLookup, array, refants)
    ts = smap.times
    ss = smap.sites
    # fs = smap.frequencies
    fixedinds, vals = reference_indices(array, smap, refants)

    variateinds = setdiff(eachindex(ts), fixedinds)
    dist = map(variateinds) do i
        getproperty(dists, ss[i]).dist
    end
    dist = Dists.product_distribution(dist)
    length(fixedinds) == 0 && return dist
    return PartiallyConditionedDist(dist, variateinds, fixedinds, vals)
end

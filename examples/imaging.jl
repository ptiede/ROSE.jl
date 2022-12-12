using Pkg; Pkg.activate(@__DIR__)
#Pkg.add(url="https://github.com/ptiede/RadioImagePriors.jl")
using Comrade
using Distributions
using ComradeOptimization
using ComradeAHMC
using OptimizationBBO
using Plots
using StatsBase
using OptimizationOptimJL
using RadioImagePriors
using DistributionsAD

# load eht-imaging we use this to load eht data
load_ehtim()
# To download the data visit https://doi.org/10.25739/g85n-f134
obs = ehtim.obsdata.load_uvfits(joinpath(@__DIR__, "SR1_M87_2017_101_hi_hops_netcal_StokesI.uvfits"))
obs.add_scans()
# kill 0-baselines since we don't care about
# large scale flux and make scan-average data
obs = scan_average(obs).add_fractional_noise(0.01)
# extract log closure amplitudes and closure phases
damp = extract_amp(obs)
dcphase = extract_cphase(obs; cut_trivial=true)


function model(θ, metadata)
    (;c, f, fg, lgamp) = θ
    (; fovx, fovy, cache, gcache) = metadata
    # Construct the image model
    img = IntensityMap(f*c, fovx, fovy)
    cimg = ContinuousImage(img, BSplinePulse{3}())
    m = modelimage(cimg, cache)
    gaussian = fg*stretched(Gaussian(), μas2rad(1000.0), μas2rad(1000.0))
    # Now corrupt the model with Gains
    g = exp.(lgamp)
    return Comrade.GainModel(gcache, g, m+gaussian)
end



# First we define the station gain priors
distamp = (AA = Normal(0.0, 0.1),
           AP = Normal(0.0, 0.1),
           LM = Normal(0.0, 0.9),
           AZ = Normal(0.0, 0.1),
           JC = Normal(0.0, 0.1),
           PV = Normal(0.0, 0.1),
           SM = Normal(0.0, 0.1)
           )

fovx = μas2rad(75)
fovy = μas2rad(75)
nx = 8
ny = floor(Int, fovy/fovx*nx)
prior = (
          c = ImageDirichlet(0.8, nx, ny),
          f = Normal(0.6, 0.025),
          fg = Uniform(0.0, 1.0),
          lgamp = Comrade.GainPrior(distamp, scantable(damp)),
        )


buffer = IntensityMap(zeros(nx, ny), fovx, fovy)
cache = create_cache(DFTAlg(damp), buffer, BSplinePulse{3}())
gcache = GainCache(scantable(damp))
metadata = (;cache, fovx, fovy, gcache)

lklhd = RadioLikelihood(model, metadata, damp, dcphase)

post = Posterior(lklhd, prior)

tpost = asflat(post)

ℓ = logdensityof(tpost)

using ChainRulesCore

# We will use HMC to sample the posterior.
using StructArrays
# Zygote.@adjoint function Zygote.literal_getproperty(sa::StructArray, ::Val{key}) where {key}
#     key::Symbol
#     result = getproperty(sa, key)
#     function back(Δ::AbstractArray)
#         nt = (; (k => zero(v) for (k,v) in pairs(fieldarrays(sa)))...)
#         return (Base.setindex(nt, Δ, key), nothing)
#     end
#     return result, back
# end

ndim = dimension(tpost)
using Zygote

f = OptimizationFunction(tpost, Optimization.AutoZygote())
prob = OptimizationProblem(f, rand(ndim) .- 0.5, nothing)
sol = solve(prob, LBFGS(); maxiters=6000, callback=(x,p)->(@info ℓ(x); false), g_tol=1e-1)

xopt = transform(tpost, sol)

# Let's see how the fit looks

plot(model(xopt, metadata), fovx=fovx, fovy=fovy, title="MAP")

residual(model(xopt, metadata), damp)
residual(model(xopt, metadata), dcphase)

# Let's also plot the gain curves
gt = Comrade.caltable(model(xopt, metadata))
plot(gt, ylims=:none, layout=(3,3), size=(600,500))

using Measurements


# now we sample using hmc
metric = DiagEuclideanMetric(ndim)
hchain, stats = sample(post, AHMC(;metric, autodiff=AD.ZygoteBackend()), 2000; nadapts=1000, init_params=xopt)

# Now plot the gain table with error bars
gamps = exp.(hcat(hchain.lgamp...))
mga = mean(gamps, dims=2)
sga = std(gamps, dims=2)

using Measurements
gmeas = measurement.(mga, sga)
ctable = caltable(mms.gcache, vec(gmeas))
plot(ctable)

# This takes about 1.75 hours on my laptop. Which isn't bad for a 575 dimensional model!

# Plot the mean image and standard deviation image
using StatsBase
samples = mms.(sample(hchain, 50))
imgs = intensitymap.(samples, fovx, fovy, 96, 96)

mimg, simg = mean_and_std(imgs)

p1 = plot(mimg, title="Mean", clims=(0.0, maximum(mimg)))
p2 = plot(simg,  title="Std. Dev.", clims=(0.0, maximum(mimg)))
p3 = plot(simg./mimg,  title="Fractional Error")
p4 = plot(mimg./simg,  title="SNR")

# Computing information
# ```
# Julia Version 1.7.3
# Commit 742b9abb4d (2022-05-06 12:58 UTC)
# Platform Info:
#   OS: Linux (x86_64-pc-linux-gnu)
#   CPU: 11th Gen Intel(R) Core(TM) i7-1185G7 @ 3.00GHz
#   WORD_SIZE: 64
#   LIBM: libopenlibm
#   LLVM: libLLVM-12.0.1 (ORCJIT, tigerlake)
# ```


#

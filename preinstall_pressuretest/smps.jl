using CSV
using DataFrames
using DifferentialMobilityAnalyzers
using Chain
using MLStyle
using Dates
using Statistics
using Interpolations
using Plots
using Plots.PlotMeasures
using NetCDF

include("processingroutines.jl")

ss = Date(2023, 11, 1)

function get_raw(ss)
    head, cpc, lj = readraw(ss)
    Λ = get_DMA_config(5.0, 0.45, 19.3, 101315.0, :TSILONG, :-)
    δ = setupDMA(Λ, vtoz(Λ, 3000), vtoz(Λ, 10), 60)
    δ1 = setupSMPS(Λ, 10, 3000, 20.0, 1.0/3.0)

    Vr = map(x -> getf64(x, 5), lj)
    state = map(x -> (@chain split(x, ",") getindex(_, 4)), lj)

    ccount = map(x -> getf64(x, 7), lj)
    flow = map(x -> getf64(x, 16), cpc)
    rc = map(x -> getf64(x, 20), cpc)
    pcpc = map(x -> getf64(x, 15), cpc)
    cserial = rc ./ flow .* 60 .* 1013.0 ./ pcpc
    Tcpc = map(x -> getf64(x, 4), cpc)
    ccount_std = ccount .* 1013.0 ./ pcpc

    return Λ, δ, δ1, Vr, state, ccount_std, flow, cserial, pcpc, Tcpc, head
end

@isdefined(state1) ||
    ((Λ, δ, δ1, Vr, state, ccount, flow, cserial, pcpc, Tcpc, head) = get_raw(ss))

function vtod_lookup_function()
    Vs = ncread("lookup_vtod.cdf", "Vs")
    Ts = ncread("lookup_vtod.cdf", "Ts")
    ps = ncread("lookup_vtod.cdf", "ps")
    lookup = ncread("lookup_vtod.cdf", "lookup")
    itp = interpolate((Vs, Ts, ps), lookup, Gridded(Linear()))
    extp = extrapolate(itp, NaN)
    return extp
end

vtod_lookup = vtod_lookup_function()

delay_time_cpc_count = 4
ccount_shift = circshift(ccount, -delay_time_cpc_count)

j1 = state .== "HOLD"
j2 = state .== "UPSCAN"
k1 = state .== "UPHOLD"
k2 = state .== "DOWNSCAN"
upscans = findall(j1[1:end-1] .& j2[2:end])
downscans = findall(k1[1:end-1] .& k2[2:end])

n = minimum([length(upscans), length(downscans)])

𝕟 = mapfoldl(vcat, 1:n) do i
    ii = upscans[i]:upscans[i]+62
    kk = downscans[i]:downscans[i]+62
    Djj = vtod_lookup.(-Vr[ii], Tcpc[ii], pcpc[ii] .* 100)
    Dkk = vtod_lookup.(-Vr[kk], Tcpc[kk], pcpc[kk] .* 100)
    cncountjj = @chain ccount_shift[ii] regrid(_, Djj, δ)
    cncountkk = @chain ccount_shift[kk] regrid(_, Dkk, δ)
    nii = rinv2(cncountjj, δ; λ₁ = 0.1, λ₂ = 1.0, order = 2, initial = false)
    njj = rinv2(cncountkk, δ; λ₁ = 0.1, λ₂ = 1.0, order = 2, initial = false)
    return [nii, njj]
end

𝕞 = mapfoldl(vcat, 1:n) do i
    ii = upscans[i]:upscans[i]+62
    kk = downscans[i]:downscans[i]+62
    Djj = vtod_lookup.(-Vr[ii], Tcpc[ii], pcpc[ii] .* 100)
    Dkk = vtod_lookup.(-Vr[kk], Tcpc[kk], pcpc[kk] .* 100)
    cncountjj = @chain ccount_shift[ii] regrid(_, Djj, δ1)
    cncountkk = @chain ccount_shift[kk] regrid(_, Dkk, δ1)
    nii = rinv2(cncountjj, δ1; λ₁ = 0.1, λ₂ = 1.0, order = 2, initial = false)
    njj = rinv2(cncountkk, δ1; λ₁ = 0.1, λ₂ = 1.0, order = 2, initial = false)
    return [nii, njj]
end

t = mapfoldl(vcat, 1:n) do i
    ii = upscans[i]:upscans[i]+62
    kk = downscans[i]:downscans[i]+62
    return [head[ii[1]], head[kk[1]]]
end

N = mapfoldl(x -> x.N, hcat, 𝕟)
Nt = map(x -> sum(x.N), 𝕟)
Nt1 = map(x -> sum(x.N), 𝕞)


st = DateTime(2023, 11, 1, 12, 50, 0)
et = DateTime(2023, 11, 1, 14, 10, 0)

ii = (head .> st) .& (head .< et)
jj = (t .> st) .& (t .< et)

p1 = plot(head[ii], pcpc[ii], color = :black, label = :none, xlim = (st, et), xticks = (xt,[""]), ylabel = "P (hPa)")
p2 = plot(head[ii], ccount[ii], color = :black, label = :none, xlim = (st, et), xticks = (xt,[""]), ylabel = "N (scm)")
p3 = plot(head[ii], -Vr[ii], yscale = :log10, color = :black, label = :none, xlim = (st, et), xticks = (xt,[""]), ylabel = "V (V)")
p4 = heatmap(
    t[jj],
    reverse(δ.Dp),
    (reverse(N; dims = 1))[:, jj];
    clim = (0, 100),
    yscale = :log10,
    yticks = ([10,100], ["10", "100"]),
    ylabel = "D (nm)",
    c = :jet,
    cbar = :false,
    xlim = (st, et),
    xticks = (xt,[""])
)

xt = st:Minute(10):et
l = Dates.format.(xt, "HH:MM")
p5 = plot(t[jj], Nt[jj], ylabel = "N (cm-3)", color = :black, xlim = (st, et), label = :none,
    xticks = (xt, l), xlabel = "Time (HH:MM)")
p5 = plot!(t[jj], Nt1[jj], ylabel = "N (cm-3)", color = :red, xlim = (st, et), label = :none,
    xticks = (xt, l), xlabel = "Time (HH:MM)")
p = plot(p1, p2, p3, p4, p5; layout = grid(5, 1), topmargin = 0px, right_margin = 30px, left_margin = 40px, size = (800,600), dpi = 300)

 plot(δ.Dp, 𝕟[10].S, xscale = :log10, xlim = [10, 200], minorgrid = :true, color = :black)
 plot!(δ1.Dp, 𝕞[10].S, xscale = :log10, xlim = [10, 200], minorgrid = :true, color = :black)

 #
savefig(p, "pressure_test.png")

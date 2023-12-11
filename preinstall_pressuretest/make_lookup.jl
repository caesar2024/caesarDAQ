using NetCDF
using DifferentialMobilityAnalyzers
using Chain

function get_DMA_config(
    Qsh::Float64,
    Qsa::Float64,
    T::Float64,
    p::Float64,
    column::Symbol,
    polarity::Symbol,
)
    lpm = 1.666666e-5
    (column == :TSILONG) && ((r₁, r₂, l) = (9.37e-3, 1.961e-2, 0.44369))
    (column == :HFDMA) && ((r₁, r₂, l) = (0.05, 0.058, 0.6))
    (column == :RDMA) && ((r₁, r₂, l) = (2.4e-3, 50.4e-3, 10e-3))
    (column == :HELSINKI) && ((r₁, r₂, l) = (2.65e-2, 3.3e-2, 10.9e-2))
    (column == :VIENNASHORT) && ((r₁, r₂, l) = (25e-3, 33.5e-2, 0.11))
    (column == :VIENNAMEDIUM) && ((r₁, r₂, l) = (25e-3, 33.5e-2, 0.28))
    (column == :VIENNALONG) && ((r₁, r₂, l) = (25e-3, 33.5e-2, 0.50))

    form = (column == :RDMA) ? :radial : :cylindrical

    qsh = Qsh * lpm
    qsa = Qsa * lpm
    t = T + 273.15
    leff = 13.0

    Λ = DMAconfig(t, p, qsa, qsh, r₁, r₂, l, leff, polarity, 6, form)

    return Λ
end

vtod(Λ, v) = @chain vtoz(Λ, v) ztod(Λ, 1, _)

function getd(V, T, p; Qsh = 5.0)
    Λ = get_DMA_config(Qsh, 0.45, T, p, :TSILONG, :-)
    return vtod(Λ, V)
end

function main()
    Vs = exp10.(range(log10(10.0), log10(11000.0), 120))
    Ts = 0:2.0:50 |> collect
    ps = 40000:1000.0:102000 |> collect
    Qsh = 5.0
    column = :TSILONG

    lookup = [getd(i, j, k; Qsh = Qsh) for i in Vs, j in Ts, k in ps]

    varatts = Dict(
        "longname" => "Lookup Table for Vs (V), Ts (degree C), and ps (Pa)",
        "Qsh" => Qsh,
        "DMA column" => column,
    )

    filename = "lookup_vtod.cdf"
    isfile(filename) && rm(filename)

    nccreate(filename, "lookup", "i", length(Vs), "j", length(Ts), "k", length(ps), varatts)
    nccreate(filename, "Vs", "i", length(Vs), Dict("longname" => "Voltage Array"))
    nccreate(filename, "Ts", "j", length(Ts), Dict("longname" => "Temperature Array"))
    nccreate(filename, "ps", "k", length(ps), Dict("longname" => "Pressure Array"))
    ncwrite(lookup, filename, "lookup")
    ncwrite(Vs, filename, "Vs")
    ncwrite(Ts, filename, "Ts")
    ncwrite(ps, filename, "ps")

    return 0
end

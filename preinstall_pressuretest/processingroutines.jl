function stats_df(df, ts, f, dt)
    nam = names(df)
    mapfoldl(vcat, ts) do tts
        @chain begin
            filter(:t => t -> (t .>= tts) .& (t .< tts + Minute(dt)), df)
            map(f, eachcol(_[!, 2:end]))
            hcat(DataFrame(; t = tts), DataFrame(_', nam[2:end]))
        end
    end
end

function val2zeroD(x::T) where {T}
    y = Array{T}(undef)
    return fill!(y, x)
end

function nan2zero(x)
    y = deepcopy(x)
    x[isnan.(x)] .= 0.0
    return x
end

function get_DMA_config(Qsh::Float64, Qsa::Float64, T::Float64, p::Float64, column::Symbol, polarity::Symbol)
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

function regrid(N, D, δ)
    return map(1:length(δ.Dp)) do i
        ii = (D .< δ.De[i]) .& (D .> δ.De[i+1])
        x = mean(N[ii])
        if isnan(x)
            return 0.0
        else
            return x
        end
    end
end

getf64(x, i) = @match x begin
    "missing" => missing
    _ => try
        @chain split(x, ",") _[i] parse.(Float64, _)
    catch
        NaN
    end
end

getRIE(x, i) = @match x begin
    "missing" => missing
    _ => @chain split(x, ",") _[4] parse(Int16, _, base = 16)
end

function readraw(ss)
    bp = "data/"

    file = @chain begin
        files = readdir(bp)
        filter(f -> split(f, ".")[end] == "txt", _)
        filter(_) do f
            a = split.(f, "_")[2]
            d = Date(split(a, ".")[1], dateformat"yyyymmdd")
            return (d >= ss) & (d <= ss)
        end
    end

    s = open(bp * file[1]) do file
        return read(file, String)
    end

    a = split(s, "\n")
    head = map(s -> split(s, ";")[1], a[1:end-1])
    tcpc = map(s -> split(s, ";")[2], a[1:end-1])
    tlj = map(s -> split(s, ";")[3], a[1:end-1])

    # General
    t = map(
        x ->
            (@chain split(x, ";") getindex(_, 1) split(_, ",") getindex(_, 1) DateTime),
        head,
    )

    return t, tcpc, tlj
end

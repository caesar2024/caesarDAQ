# Note need to turn off calvolt(v) before running this code 
# calibrateVoltage(v) = getVdac(calvolt(v), :+, true)

using Plots
using DataFrames
using Interpolations
using CSV
using LabjackU6Library
using Reactive
using Dates
using DifferentialMobilityAnalyzers
using YAML
using Chain
unicodeplots()
gr()

include("dma_control.jl")               # High voltage power supply
include("labjack_io.jl")                # Labjack channels I/O

const conf = YAML.load_file("config.yaml")
const HANDLE = openUSBConnection(conf["LJ"]["ID"])
const caliInfo = getCalibrationInformation(HANDLE)
const Λ = get_DMA_config(
    conf["DMA"]["Qsh"],
    conf["DMA"]["Qsa"],
    conf["DMA"]["T"],
    conf["DMA"]["p"],
    Symbol(conf["DMA"]["model"]),
)

calibrateVoltage(v) = getVdac(v, :-, true)
const oneHz = every(1.0)
const theV = Signal(1000.0)
const signalV = map(_ -> calibrateVoltage(theV.value), oneHz)
const labjack_signals = map(labjackReadWrite, signalV)

function get_points(V)
    println(V)
    push!(theV, V)

    sleep(10)
    x = map(1:10) do i
        sleep(1)
        AIN, Tk, rawcount, count = labjack_signals.value
        AIN[conf["LJ"]["AIN"]["V"]+1] |> (x -> abs(x * 1000.0))
    end

    return DataFrame(setV=V, readV=x)
end

df = mapfoldl(get_points, vcat, [10:5:145; 150:50:1000; 2000:1000:10000])
df1 = filter(:readV => x -> abs(x) > 10, df)
df2 = sort(df1, [:readV])

itp = interpolate((df2[!, :readV],), df2[!, :setV], Gridded(Linear()))
xdata = 10:10.0:10000.0
extp = extrapolate(itp, Flat())
p = scatter(abs.(df1[!, :readV]),
    df1[!, :setV], 
    xscale=:log10, 
    yscale=:log10,
    xlim=(10, 10000), 
    ylim=(10, 10000),
    xlabel = "Read Voltage (V)",
    ylabel = "Set Voltage (V)",
    legend = :bottomright,
    color = :darkred,
    label = "Data"
)

p = plot!(xdata, extp.(xdata), color = :black, label = "Fit")

df2 |>  CSV.write("voltage_calibration.csv")
savefig(p, "voltage_calibration.pdf")
display(p)

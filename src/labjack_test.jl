using CondensationParticleCounters
using DifferentialMobilityAnalyzers
using LabjackU6Library

# using PyCall
using CSV
using YAML
using DataFrames
using Reactive
using Dates
using Printf
using Interpolations
using DataStructures
using CircularList
using LibSerialPort
using Chain
# using Plots
# unicodeplots()

const bp = "/home/aerosol/Data/"
const path = "/home/aerosol/Downloads/epcapeDAQ/src/"

const conf = YAML.load_file(path*"config.yaml")

struct State
    dT::Float64     # CCN temperature gradient
    denuded::Bool   # Denuded/undenuded
end

state = circularlist(State(4.49, false))
insert!(state, State(4.49, true))
insert!(state, State(7.06, false))
insert!(state, State(7.06, true))
insert!(state, State(9.63, false))
insert!(state, State(9.63, true))
insert!(state, State(12.2, false))
insert!(state, State(12.2, true))
insert!(state, State(14.77, false))
insert!(state, State(14.77, true))
insert!(state, State(12.2, false))
insert!(state, State(12.2, true))
insert!(state, State(9.63, false))
insert!(state, State(9.63, true))
insert!(state, State(7.06, false))
insert!(state, State(7.06, true))


const Vhi = Signal(35.0)
const Vlow = Signal(6000.0)
const tscan = Signal(240)
const thold = Signal(100)
const tflush = Signal(10)

include(path*"dma_control.jl")               # High voltage power supply
include(path*"labjack_io.jl")                # Labjack channels I/O
include(path*"smps_signals.jl")              # Labjack channels I/O

# const portCPC = CondensationParticleCounters.config(Symbol(conf["CPC"]["model"]), conf["serial"]["CPC"])

const HANDLE = openUSBConnection(-1)
const caliInfo = getCalibrationInformation(HANDLE)

const Λ = get_DMA_config(
    conf["DMA"]["Qsh"],
    conf["DMA"]["Qsa"],
    conf["DMA"]["T"],
    conf["DMA"]["p"],
    Symbol(conf["DMA"]["model"]),
)

const calvolt = get_cal(path * "voltage_calibration.csv")

const classifierV = Signal(200.0)
const dmaState = Signal(:SMPS)
const oneHz = every(1.0)
const smps_start_time = Signal(datetime2unix(now(UTC)))
const smps_elapsed_time = map(t -> Int(round(t - smps_start_time.value; digits = 0)), oneHz)
const smps_scan_state, V, Dp = smps_signals()
const signalV = map(calibrateVoltage, V)
const labjack_signals = map(labjackReadWrite, signalV)



sleep(2)
const sec = map(oneHz) do x
    @chain Dates.value(Time(unix2datetime(x)) - Time(0, 0, 0)) / 1e9 round Int
end

# const reset = map(
#     _ -> push!(smps_start_time, datetime2unix(now(UTC))),
#     filter(t -> t % 600 == 0, sec),
# )


function get_current_record()
    AIN, Tk, rawcount, count = labjack_signals.value
    RH = AIN[conf["LJ"]["AIN"]["RH"]+1] * 100.0
    T = AIN[conf["LJ"]["AIN"]["T"]+1] * 100.0 - 40.0
    readV = AIN[conf["LJ"]["AIN"]["V"]+1] |> (x -> (x * 1000.0))
    readI = AIN[conf["LJ"]["AIN"]["I"]+1] |> (x -> -x * 0.167 * 1000.0)
    @sprintf(
        "LABJCACK,%i,%.3f,%s,%.3f,%.3f,%.3f,%.3f,%.3f",
        smps_elapsed_time.value,
        V.value,
        smps_scan_state.value,
        readV,
        readI,
        RH,
        T,
        count[1] ./ 16.666666
    )
end


# function start_acquisition_loops()
#     @async CondensationParticleCounters.stream(
#         portCPC,
#         Symbol(conf["CPC"]["model"]),
#         bp * "mtsncsucpc3772/cpc",
#     )
# end

function packet()
    # cpc = CondensationParticleCounters.get_current_record()
    lj = get_current_record()
    tc =
        Dates.format(now(), "yyyy-mm-ddTHH:MM:SS") 
    return mapfoldl(x -> string(x) * ";", *, [tc, lj])[1:end-1] * '\n'
end

# start_acquisition_loops()


function acquire()
    x = packet()
    filter(x -> x != '\r', x)
    tc = Dates.format(now(), "yyyymmdd")
    open(bp * "test.txt", "a") do io
    # open(bp * "mtsncsudenudedccn/rack" * "_" * tc * ".txt", "a") do io
        return write(io, x)
    end
end

daqLoop = map(x -> acquire(), oneHz)

# const dataBufferCPCs = CircularBuffer{Float64}(600)
# const dataBufferCPCc = CircularBuffer{Float64}(600)
# const dataBufferVr = CircularBuffer{Float64}(600)
# const dataBufferIr = CircularBuffer{Float64}(600)

# function graphit()
#     x = packet()
#     a = split(x, ";")
#     b = split(a[1], ",")
#     t = DateTime(b[1])
#     cs = @chain split(a[2], ",") getindex(_, 3) parse(Float64, _)
#     cc = @chain split(a[5], ",") getindex(_, 9) parse(Float64, _)
#     Vr = @chain split(a[5], ",") getindex(_, 5) parse(Float64, _)
#     Ir = @chain split(a[5], ",") getindex(_, 6) parse(Float64, _)
#     push!(dataBufferdt, t)
#     push!(dataBufferCPCs, cs)
#     push!(dataBufferCPCc, cc)
#     push!(dataBufferVr, Vr)
#     push!(dataBufferIr, Ir)
#     p1 = plot(del, dataBufferCPCc; legend = false, color = :black)
#     p2 = plot(
#         del,
#         dataBufferVr;
#         legend = false,
#         color = :black,
#         yscale = :log10,
#         ylim = (100, 10000),
#     )

#     pa = plot(p1, p2; layout = grid(2, 1))
#     if typeof(p0) == Plots.Plot{Plots.UnicodePlotsBackend}
#         push!(p, p1)
#     end
# end

# p0 = plot([now()], [1.0])
# p = Signal(p0)

# sleep(4)
# graphLoop = map(_ -> graphit(), oneHz)

# graphHz = every(60.0)
# graphDisp = map(graphHz) do _
#     display(packet())
#     return display(p.value)
# end


###################

function stream(port::Ptr{LibSerialPort.Lib.SPPort}, CPCType::Symbol, file::String)
    Godot = @task _ -> false

    function read(port, file)
        try
            tc = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")
            if (CPCType == :TSI3771) || (CPCType == :TSI3772) || (CPCType == :TSI3776C)
                LibSerialPort.sp_nonblocking_write(port, "RALL\r")
                nbytes_read, bytes = LibSerialPort.sp_nonblocking_read(port, 100)
            elseif  (CPCType == :TSI3022) || (CPCType == :TSI3025)
                LibSerialPort.sp_nonblocking_write(port, "RD\r")
                nbytes_read, bytes = LibSerialPort.sp_nonblocking_read(port, 10)
            end
            str = String(bytes[1:nbytes_read])
            tc = Dates.format(now(), "yyyymmdd")
            open(file*"_"*tc*".txt", "a") do io
                write(io, tc * "," * str)
            end
            push!(dataBuffer, "RALL," * tc * "," * str)
        catch
            println("From CondensationParticleCounters.jl: I fail")
        end
    end

    while(true)
        read(port, file)
        sleep(1)
    end

    wait(Godot)
end

###################

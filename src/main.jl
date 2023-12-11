using CondensationParticleCounters
using DifferentialMobilityAnalyzers
using LabjackU6Library

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
using Genie
using Genie.Renderer
using Genie.Configuration
using JSON      
using Logging

Logging.disable_logging(Logging.Info)

const bp = "/home/aerosol/Data/"
const conf = YAML.load_file("config.yaml")
const Vlow = Signal(20.0)
const Vhi = Signal(2000.0)
const tscan = Signal(60)
const thold = Signal(10)
const tflush = Signal(10)

include("dma_control.jl")               # High voltage power supply
include("labjack_io.jl")                # Labjack channels I/O
include("smps_signals.jl")              # Labjack channels I/O

const portCPC =
CondensationParticleCounters.config(Symbol(conf["CPC"]["model"]), conf["serial"]["CPC"])
const HANDLE = openUSBConnection(conf["LJ"]["ID"])
const caliInfo = getCalibrationInformation(HANDLE)
const Λ = get_DMA_config(
    conf["DMA"]["Qsh"],
    conf["DMA"]["Qsa"],
    conf["DMA"]["T"],
    conf["DMA"]["p"],
    Symbol(conf["DMA"]["model"]),
)

const calvolt = get_cal("voltage_calibration.csv")
const classifierV = Signal(200.0)
const dmaState = Signal(:SMPS)
const oneHz = every(1.0)
const smps_start_time = Signal(datetime2unix(now(UTC)))
const smps_elapsed_time = map(t -> Int(round(t - smps_start_time.value; digits = 0)), oneHz)
const smps_scan_state, V, Dp = smps_signals()
const signalV = map(calibrateVoltage, V)
const labjack_signals = map(labjackReadWrite, signalV)

const dataBufferdt = CircularBuffer{DateTime}(600)
const dataBufferCPCs = CircularBuffer{Float64}(600)
const dataBufferCPCc = CircularBuffer{Float64}(600)
const dataBufferVr = CircularBuffer{Float64}(600)
const dataBufferIr = CircularBuffer{Float64}(600)
const dataBufferP = CircularBuffer{Float64}(600)
const dataBufferQ = CircularBuffer{Float64}(600)

for i = 1:600
    t = now()
    push!(dataBufferdt, t)
    push!(dataBufferCPCs, 0.0)
    push!(dataBufferCPCc, 0.0)
    push!(dataBufferVr, 0.0)
    push!(dataBufferIr, 0.0)
    push!(dataBufferP, 0.0)
    push!(dataBufferQ, 0.0)
end

function get_current_record()
    AIN, Tk, rawcount, count = labjack_signals.value
    readV = AIN[conf["LJ"]["AIN"]["V"]+1] |> (x -> (x * 1000.0))
    readI = AIN[conf["LJ"]["AIN"]["I"]+1] |> (x -> -x * 0.167 * 1000.0)
    @sprintf(
        "LABJCACK,%i,%.3f,%s,%.3f,%.3f,%.3f",
        smps_elapsed_time.value,
        V.value,
        smps_scan_state.value,
        readV,
        readI,
        count[1] ./ 7.41
    )
end

function start_acquisition_loops()
    @async CondensationParticleCounters.stream(
        portCPC,
        Symbol(conf["CPC"]["model"]),
        bp * "krnmagic/cpc",
    )
end

function packet()
    cpc = try
        str = reduce(*,vcat(CondensationParticleCounters.dataBuffer[end-2:end]))
        a = split(str, "\r\n")

        cpcp = a[end-1]
        (cpcp[1:2] .== "20") && (cpcp[end-2:end] .== "132") ? cpcp : "00"
    catch
        "00"
    end
    lj = get_current_record()
    tc = Dates.format(now(), "yyyy-mm-ddTHH:MM:SS")

    return mapfoldl(x -> string(x) * ";", *, [tc, cpc[1:end-2], lj])[1:end-1] * '\n'
end

function acquire()
    x = packet()
    filter(x -> x != '\r', x)
    tc = Dates.format(now(), "yyyymmdd")
    open(bp * "krnsmps/smps" * "_" * tc * ".txt", "a") do io
        return write(io, x)
    end
end

function graphit()
    x = packet()
    a = split(x, ";")
    b = split(a[1], ",")
    t = DateTime(b[1])
    cs = try 
        rawc = @chain split(a[2], ",") getindex(_, 20) parse(Float64, _)
        flow = @chain split(a[2], ",") getindex(_, 16) parse(Float64, _)
        rawc/flow .* 60.0
    catch
        dataBufferCPCs[end]
    end

    flow = try 
        @chain split(a[2], ",") getindex(_, 16) parse(Float64, _)
    catch
        dataBufferQ[end]
    end

    pressure = try 
        @chain split(a[2], ",") getindex(_, 15) parse(Float64, _)
    catch
        dataBufferP[end]
    end
    
    cc = @chain split(a[3], ",") getindex(_, 7) parse(Float64, _)
    Vr = @chain split(a[3], ",") getindex(_, 5) parse(Float64, _)
    Ir = @chain split(a[3], ",") getindex(_, 6) parse(Float64, _)
    push!(dataBufferdt, t)
    push!(dataBufferCPCs, cs)
    push!(dataBufferCPCc, cc)
    push!(dataBufferVr, abs(Vr))
    push!(dataBufferIr, abs(Ir))
    push!(dataBufferP, pressure)
    push!(dataBufferQ, flow)
end

start_acquisition_loops()

const sec = map(oneHz) do x
    @chain Dates.value(Time(unix2datetime(x)) - Time(0, 0, 0)) / 1e9 round Int
end

sleep(1)
const daqLoop   = map(_ -> acquire(), oneHz)

sleep(1)
const graphLoop = map(_ -> graphit(), oneHz)

sleep(1)
const reset = map(
    _ -> push!(smps_start_time, datetime2unix(now(UTC))),
    filter(t -> t % 140 == 0, sec),
)

Genie.config.run_as_server = false
Genie.config.cors_headers["Access-Control-Allow-Origin"] = "http://localhost:8000"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] ="GET,POST,PUT,DELETE,OPTIONS" 
Genie.config.cors_allowed_origins = ["*"]

route("/") do 
    del = @chain (dataBufferdt .- dataBufferdt[1]) Dates.value.(_) _ ./ 1000
    json([del, dataBufferVr, dataBufferCPCc, dataBufferCPCs, dataBufferP, dataBufferQ])
end

up()


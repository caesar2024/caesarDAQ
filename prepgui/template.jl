
using Plotly
using PlotlyExtras
using JSON

t = get_layout("default.json")

trace1a = Dict{Symbol,Any}(
    :template => t,
    :x => [1,2,3,4],
    :y => [10,15,13,17],
    :name => "P (hPa)",
    :mode => "lines",
    :line => Dict(:color => "rgb(0, 0, 0)"),
    :showlegend => true
)

trace1b = Dict{Symbol,Any}(
    :template => t,
    :x => [1,2,3,4],
    :y => [10,15,13,17],
    :name => "Q (ccm)",
    :mode => "lines",
    :line => Dict(:color => "rgb(0, 0, 0.8)"),
    :showlegend => true
)

trace2 = Dict{Symbol,Any}(
    :template => t,
    :x => [1,2,3,4],
    :y => [10,10,13,17],
    :name => "V read",
    :mode => "lines",
   :line => Dict(:color => "rgb(0, 0, 0)"),
 :showlegend => true
)

trace3a = Dict{Symbol,Any}(
    :template => t,
    :x => [1,2,3,4],
    :y => [10,10,13,17],
    :name => "N serial",
    :mode => "lines",
   :line => Dict(:color => "rgb(0, 0, 0)"),
 :showlegend => true
)

trace3b = Dict{Symbol,Any}(
    :template => t,
    :x => [1,2,3,4],
    :y => [10,10,13,17],
    :name => "N pulse",
    :mode => "lines",
   :line => Dict(:color => "rgb(0.7, 0, 0)"),
 :showlegend => true
)

data1 = [GenericTrace("lines", trace1a), GenericTrace("lines", trace1b)]
data2 = [GenericTrace("lines", trace2)]
data3 = [GenericTrace("lines", trace3a), GenericTrace("lines", trace3b)]

layout1 = Dict{Symbol,Any}(
    :template => t,
    :dragmode => "false",
    :margin => Dict(:l => 50, :r => 10, :t => 10, :b => 20),
    #:width => 800,
    :height => 170,
    :yaxis1 => Dict(
        :title => "Pressure (hPa)",
        :range => [0, 1000]
    )
)


layout2 = Dict{Symbol,Any}(
    :template => t,
    :dragmode => "false",
    :margin => Dict(:l => 50, :r => 10, :t => 10, :b => 20),
    #:width => 800,
    :height => 170,
    :yaxis1 => Dict(
        :type => "log",
        :title => "Voltage",
        :range => [1,3.7]
    )
)

layout3 = Dict{Symbol,Any}(
    :template => t,
    :dragmode => "false",
    :margin => Dict(:l => 50, :r => 10, :t => 10, :b => 50),
    #:width => 800,
    :height => 200,
    :xaxis => Dict(
        :title => "Elapsed Time (s)"
    ),
    :yaxis1 => Dict(
        :title => "N (cm-3)"
    )
)

p1 = Plot(data1, Layout(layout1))
p2 = Plot(data2, Layout(layout2))
p3 = Plot(data3, Layout(layout3))

to_html("index.html", [p1,p2,p3])

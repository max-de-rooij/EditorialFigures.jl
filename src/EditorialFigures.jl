"""
    EditorialFigures.jl

Lightweight SVG figures in an editorial style: hairline gridlines and axes, a muted ink
palette with one accent, direct labels and generous whitespace.

A figure ([`Fig`](@ref)) holds panels ([`panel!`](@ref), [`grid!`](@ref)) that hold marks
([`line!`](@ref), [`points!`](@ref), [`bars!`](@ref), [`band!`](@ref), [`note!`](@ref), …).
Limits, ticks, margins and legends are worked out when the figure is rendered with
[`svg`](@ref) or written with [`savesvg`](@ref): for the web (colors that follow light and
dark mode, tooltips) or as static files with every style baked in (slides, papers).
"""
module EditorialFigures

using Printf: @sprintf

export Fig, Panel, Theme, LIGHT, DARK
export panel!, grid!, axes!, frame!, title!, legend!
export line!, band!, area!, points!, bars!, hist!, errorbars!, segments!, rect!, vspan!, hspan!,
    polygon!, circle!, ellipse!, arrow!, hline!, vline!, note!, annotate!, contours!, heatmap!, mask!
export svg, savesvg, stylesheet, nice_ticks, text_width

include("theme.jl")
include("text.jl")
include("scales.jl")
include("figure.jl")
include("contour.jl")
include("marks.jl")
include("layout.jl")
include("render.jl")

end

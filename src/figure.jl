# Figures and panels. A figure only describes what to draw: limits, ticks, margins and
# legends are worked out when it is rendered (see layout.jl and render.jl).

abstract type Mark end

const Lim = Tuple{Union{Nothing, Float64}, Union{Nothing, Float64}}

"""
    Panel

A plot area with its own scales, axes, title and marks; created with [`panel!`](@ref) or
[`grid!`](@ref). Its settings are fields that can also be changed later, for example
`ax.ylabel = "cost"`, or with [`axes!`](@ref) and [`frame!`](@ref).
"""
mutable struct Panel
    fig::Any
    box::Union{Nothing, NTuple{4, Float64}}   # explicit plot area (x, y, width, height) in px
    cell::Union{Nothing, NTuple{4, Int}}      # (row, col, rowspan, colspan) in the figure grid
    xlim::Lim
    ylim::Lim
    xscale::Symbol
    yscale::Symbol
    nice::Union{Nothing, Bool}
    aspect::Union{Nothing, Float64}
    style::Symbol
    xlabel::String
    ylabel::String
    xticks::Any
    yticks::Any
    xformat::Any
    yformat::Any
    grid::Symbol
    title::String
    subtitle::String
    legend::Symbol
    legend_corner::Symbol
    marks::Vector{Mark}
end

"""
    Fig(width = 680, height = 400; title, subtitle, credit, layout = (1, 1), kwargs...)

A figure of `width × height` pixels.

- `title`, `subtitle`: headline and dek above the panels; `credit`: a source line below.
- `layout = (rows, cols)`: the grid that [`panel!`](@ref) fills; `hgap`, `vgap` are the
  gaps between grid cells in pixels and `padding` the margin around the figure.
- `legend = :top` or `:bottom` gathers the labelled marks of all panels into one legend
  (instead of one per panel).
- `label`: a description for screen readers (defaults to the title).
- `id`: prefix of the element ids in the SVG; by default derived from the content.

Figures display inline in notebooks and editors that show SVG; write them with
[`savesvg`](@ref) or get the markup with [`svg`](@ref).
"""
mutable struct Fig
    width::Float64
    height::Float64
    title::String
    subtitle::String
    credit::String
    padding::Float64
    layout::Tuple{Int, Int}
    hgap::Float64
    vgap::Float64
    legend::Symbol
    legend_items::Vector{Any}
    panels::Vector{Panel}
    marks::Vector{Mark}
    id::Union{Nothing, String}
    label::String
end

function Fig(
        width::Real = 680, height::Real = 400; title::AbstractString = "",
        subtitle::AbstractString = "", credit::AbstractString = "", padding::Real = 16,
        layout::Tuple{Integer, Integer} = (1, 1), hgap::Real = 48, vgap::Real = 56,
        legend::Symbol = :none, id = nothing, label::AbstractString = ""
    )
    legend in (:none, :top, :bottom) || throw(ArgumentError("legend must be :none, :top or :bottom"))
    return Fig(width, height, title, subtitle, credit, padding, (layout[1], layout[2]), hgap, vgap,
        legend, Any[], Panel[], Mark[], id === nothing ? nothing : string(id), label)
end

Base.show(io::IO, f::Fig) = print(io, "Fig($(fmt(f.width)) × $(fmt(f.height)), $(length(f.panels)) panel",
    length(f.panels) == 1 ? "" : "s", isempty(f.title) ? "" : ", \"$(f.title)\"", ")")
Base.show(io::IO, p::Panel) = print(io, "Panel(", p.box !== nothing ? "box $(fmt.(p.box))" :
    p.cell !== nothing ? "row $(p.cell[1]), col $(p.cell[2])" : "unplaced", ", $(length(p.marks)) marks)")

lim(::Nothing) = (nothing, nothing)
function lim(l)
    length(l) == 2 || throw(ArgumentError("limits must be a pair (lo, hi); use nothing for an automatic end"))
    return (l[1] === nothing ? nothing : Float64(l[1]), l[2] === nothing ? nothing : Float64(l[2]))
end
aspect_value(::Nothing) = nothing
aspect_value(a::Symbol) = a === :equal ? 1.0 : throw(ArgumentError("aspect must be :equal, a number or nothing"))
aspect_value(a::Real) = Float64(a)

const PANEL_KEYS = (:xlim, :ylim, :xscale, :yscale, :nice, :aspect, :style, :xlabel, :ylabel,
    :xticks, :yticks, :xformat, :yformat, :grid, :title, :subtitle, :legend, :legend_corner)

function configure!(p::Panel; kwargs...)
    for (k, v) in kwargs
        k in PANEL_KEYS || throw(ArgumentError("unknown panel setting `$k`; settings are $(join(PANEL_KEYS, ", "))"))
        if k === :xlim || k === :ylim
            setfield!(p, k, lim(v))
        elseif k === :aspect
            p.aspect = aspect_value(v)
        elseif k in (:xscale, :yscale)
            v in (:linear, :log) || throw(ArgumentError("$k must be :linear or :log"))
            setfield!(p, k, v)
        elseif k === :style
            v in (:axes, :frame, :none) || throw(ArgumentError("style must be :axes, :frame or :none"))
            p.style = v
        elseif k === :grid
            v in (:auto, :x, :y, :both, :none) || throw(ArgumentError("grid must be :auto, :x, :y, :both or :none"))
            p.grid = v
        elseif k === :legend
            v in (:auto, :top, :bottom, :right, :inside, :none) ||
                throw(ArgumentError("legend must be :auto, :top, :bottom, :right, :inside or :none"))
            p.legend = v
        elseif k === :legend_corner
            v in (:topleft, :topright, :bottomleft, :bottomright) ||
                throw(ArgumentError("legend_corner must be :topleft, :topright, :bottomleft or :bottomright"))
            p.legend_corner = v
        elseif k in (:xlabel, :ylabel, :title, :subtitle)
            setfield!(p, k, string(v))
        else
            setfield!(p, k, v)
        end
    end
    return p
end

function new_panel(fig::Fig, box, cell; kwargs...)
    p = Panel(fig, box, cell, (nothing, nothing), (nothing, nothing), :linear, :linear, nothing, nothing,
        :axes, "", "", :auto, :auto, nothing, nothing, :auto, "", "", :auto, :topright, Mark[])
    configure!(p; kwargs...)
    push!(fig.panels, p)
    return p
end

"""
    panel!(fig; kwargs...)
    panel!(fig, row, col; rowspan = 1, colspan = 1, kwargs...)
    panel!(fig, x, y, width, height; kwargs...)

Add a panel to `fig` and return it. The first form takes the next free cell of the figure's
`layout` grid, the second a given cell, the third an explicit plot area in pixels (the
rectangle inside the axes; tick labels and titles go around it).

Settings (all optional):

- `xlim`, `ylim`: `(lo, hi)` with `nothing` for an automatic end; `(hi, lo)` reverses the
  axis. Automatic limits span the data and, with `nice = true`, are rounded out to the
  next ticks (the default for `:axes`; `:frame` panels fit the data exactly).
- `xscale`, `yscale`: `:linear` or `:log`.
- `aspect`: `:equal` or a number to fix the ratio of y to x scale (for parameter spaces).
- `style`: `:axes` (horizontal gridlines and a baseline, the default), `:frame` (a thin box,
  for maps of parameter spaces) or `:none` (diagrams).
- `xlabel`, `ylabel`: axis titles; the y title sits above the axis, horizontally.
- `xticks`, `yticks`: `:auto`, a vector of values, `(values, labels)` or `nothing`.
- `xformat`, `yformat`: functions from a tick value to its label.
- `grid`: `:auto`, `:x`, `:y`, `:both` or `:none`.
- `title`, `subtitle`: set above the panel.
- `legend`: `:auto` (a row above the panel when two or more marks have a `label`, not
  counting lines labelled at their end), `:top`, `:bottom`, `:right`, `:inside` (in the
  `legend_corner`) or `:none`.
"""
function panel!(fig::Fig; kwargs...)
    nr, nc = fig.layout
    taken = Set((p.cell[1], p.cell[2]) for p in fig.panels if p.cell !== nothing)
    for r in 1:nr, c in 1:nc
        (r, c) in taken && continue
        return new_panel(fig, nothing, (r, c, 1, 1); kwargs...)
    end
    throw(ArgumentError("all $(nr * nc) cells of the figure layout $(fig.layout) are taken; " *
        "use Fig(...; layout = (rows, cols)), panel!(fig, row, col) or panel!(fig, x, y, w, h)"))
end

function panel!(fig::Fig, row::Integer, col::Integer; rowspan::Integer = 1, colspan::Integer = 1, kwargs...)
    nr, nc = fig.layout
    (1 <= row && row + rowspan - 1 <= nr && 1 <= col && col + colspan - 1 <= nc) ||
        throw(ArgumentError("cell ($row, $col) with span ($rowspan, $colspan) is outside the layout $(fig.layout)"))
    return new_panel(fig, nothing, (row, col, rowspan, colspan); kwargs...)
end

function panel!(fig::Fig, x::Real, y::Real, width::Real, height::Real; kwargs...)
    return new_panel(fig, (Float64(x), Float64(y), Float64(width), Float64(height)), nothing; kwargs...)
end

"""
    grid!(fig, rows, cols; kwargs...) -> Matrix{Panel}

Set the layout of an empty figure to `rows × cols` and fill it with panels that share the
settings `kwargs` (see [`panel!`](@ref)). Panels in a row share their top and bottom
margins and panels in a column their left and right margins, so their axes line up.
"""
function grid!(fig::Fig, rows::Integer, cols::Integer; kwargs...)
    isempty(fig.panels) || throw(ArgumentError("grid! needs a figure without panels"))
    fig.layout = (rows, cols)
    return [panel!(fig, r, c; kwargs...) for r in 1:rows, c in 1:cols]
end

"""
    axes!(ax; kwargs...)

Use axes in the editorial style for the panel (hairline gridlines, a baseline, tick labels
in the muted ink, the y title above the axis) and update its settings; see
[`panel!`](@ref) for the keywords.
"""
axes!(p::Panel; kwargs...) = (configure!(p; style = :axes, kwargs...); p.fig)

"""
    frame!(ax; kwargs...)

Draw the panel as a thin frame with tick labels outside, as for maps of a parameter space
(the frame is the boundary of the plotted region), and update its settings.
"""
frame!(p::Panel; kwargs...) = (configure!(p; style = :frame, kwargs...); p.fig)

"""
    title!(ax, title; subtitle = "")
    title!(fig, title; subtitle = "", credit = "")

Set the title (and subtitle) of a panel or a figure, and the credit line of a figure.
"""
function title!(p::Panel, title::AbstractString; subtitle::AbstractString = p.subtitle)
    p.title, p.subtitle = title, subtitle
    return p.fig
end
function title!(f::Fig, title::AbstractString; subtitle::AbstractString = f.subtitle, credit::AbstractString = f.credit)
    f.title, f.subtitle, f.credit = title, subtitle, credit
    return f
end

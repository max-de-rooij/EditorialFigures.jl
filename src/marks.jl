# Marks: what can be drawn in a panel. Every mark function adds a mark to the panel and
# returns the figure, so that notebooks redraw it after each call.

floats(v) = Float64[x === nothing || x === missing ? NaN : Float64(x) for x in v]

function widthpx(w)
    w isa Real && return Float64(w)
    w === :normal && return 2.0
    w === :thin && return 1.3
    w === :hair && return 0.7
    w === :bold && return 3.0
    throw(ArgumentError("width must be a number of pixels or :hair, :thin, :normal or :bold"))
end

function dashpattern(d)
    (d === false || d === nothing) && return nothing
    (d === true || d === :dash) && return "5 4"
    d === :dot && return "1.5 3"
    d isa AbstractString && return String(d)
    d isa Union{Tuple, AbstractVector} && return join(fmt.(d), " ")
    throw(ArgumentError("dash must be true, false, :dash, :dot, a dash array or an SVG dasharray string"))
end

function tipvec(tips, n)
    tips === nothing && return String[]
    length(tips) == n || throw(DimensionMismatch("$(length(tips)) tips for $n points"))
    return String[string(t) for t in tips]
end

function checklen(a, b, what = "x and y")
    length(a) == length(b) || throw(DimensionMismatch("$what have different lengths ($(length(a)) and $(length(b)))"))
end

add!(p::Panel, m::Mark) = (push!(p.marks, m); p.fig)

# ---- lines and areas --------------------------------------------------------------------

struct LineMark <: Mark
    x::Vector{Float64}
    y::Vector{Float64}
    color::Paint
    width::Float64
    dash::Union{Nothing, String}
    opacity::Float64
    label::String
    endlabel::Bool
    clip::Bool
    tip::String
end

"""
    line!(ax, x, y; color = 1, width = :normal, dash = false, opacity = 1, label = "",
          endlabel = false, clip = true, tip = "")
    line!(ax, f, a, b; n = 200, kwargs...)

A line through the points `(x[i], y[i])`; `NaN`, `nothing` or `missing` break it. The second
form plots the function `f` on `[a, b]`.

- `color`: a series index (1 to 8), a color name (`:ink`, `:ink2`, `:muted`, `:accent`,
  …) or a CSS color; see [Colors](@ref colors).
- `width`: pixels or `:hair`, `:thin`, `:normal` (2 px), `:bold`.
- `dash`: `true` (5 4), `:dot`, a vector of lengths or an SVG dasharray string.
- `label`: the entry in the legend; with `endlabel = true` it is also written at the end
  of the line (a direct label).
- `tip`: tooltip text in web figures.
"""
function line!(p::Panel, x, y; color = 1, width = :normal, dash = false, opacity::Real = 1.0,
        label::AbstractString = "", endlabel::Bool = false, clip::Bool = true, tip::AbstractString = "")
    checklen(x, y)
    return add!(p, LineMark(floats(x), floats(y), paint(color), widthpx(width), dashpattern(dash),
        opacity, label, endlabel, clip, tip))
end
function line!(p::Panel, f::Function, a::Real, b::Real; n::Integer = 200, kwargs...)
    x = p.xscale === :log ? exp10.(range(log10(a), log10(b); length = n)) : range(a, b; length = n)
    return line!(p, x, f.(x); kwargs...)
end

struct BandMark <: Mark
    x::Vector{Float64}
    lo::Vector{Float64}
    hi::Vector{Float64}
    color::Paint
    opacity::Float64
    label::String
    clip::Bool
end

"""
    band!(ax, x, lo, hi; color = 1, opacity = 0.13, label = "", clip = true)

A shaded band between the curves `lo` and `hi` over `x`, such as a prediction interval.
"""
function band!(p::Panel, x, lo, hi; color = 1, opacity::Real = 0.13, label::AbstractString = "", clip::Bool = true)
    checklen(x, lo, "x and lo")
    checklen(x, hi, "x and hi")
    return add!(p, BandMark(floats(x), floats(lo), floats(hi), paint(color), opacity, label, clip))
end

"""
    area!(ax, x, y; baseline = 0, color = 1, opacity = 0.13, label = "", clip = true)

The area between `y` and the `baseline`.
"""
area!(p::Panel, x, y; baseline::Real = 0.0, kwargs...) = band!(p, x, fill(baseline, length(x)), y; kwargs...)

# ---- points -----------------------------------------------------------------------------

struct PointsMark <: Mark
    x::Vector{Float64}
    y::Vector{Float64}
    color::Paint
    size::Float64
    marker::Symbol
    open::Bool
    ring::Bool
    opacity::Float64
    label::String
    tips::Vector{String}
    clip::Bool
end

"""
    points!(ax, x, y; color = 1, size = 4, marker = :circle, open = false, ring = true,
            opacity = 1, label = "", tips = nothing, clip = false)

Dots at `(x[i], y[i])`. `size` is the radius in pixels and `marker` one of `:circle`,
`:square`, `:diamond` and `:triangle`. Filled dots get a thin ring in the background
color (`ring`), which keeps overlapping dots apart; `open = true` draws hollow dots. In
web figures, `tips` (one string per point) become tooltips with generous hit targets.
"""
function points!(p::Panel, x, y; color = 1, size::Real = 4, marker::Symbol = :circle, open::Bool = false,
        ring::Bool = true, opacity::Real = 1.0, label::AbstractString = "", tips = nothing, clip::Bool = false)
    checklen(x, y)
    marker in (:circle, :square, :diamond, :triangle) ||
        throw(ArgumentError("marker must be :circle, :square, :diamond or :triangle"))
    return add!(p, PointsMark(floats(x), floats(y), paint(color), size, marker, open, ring, opacity, label,
        tipvec(tips, length(x)), clip))
end

# ---- bars, histograms, error bars ---------------------------------------------------------

struct BarsMark <: Mark
    lo::Vector{Float64}     # bar edges along the category axis
    hi::Vector{Float64}
    v::Vector{Float64}      # values
    baseline::Float64
    horizontal::Bool
    color::Paint
    gap::Float64            # pixels between neighbouring bars
    radius::Float64         # rounding of the data end, pixels
    opacity::Float64
    label::String
    tips::Vector{String}
end

"""
    bars!(ax, x, y; width = nothing, offset = 0, color = 1, baseline = 0,
          horizontal = false, gap = 0, radius = 3, opacity = 1, label = "", tips = nothing)

Bars from `baseline` to `y[i]` centred at `x[i] + offset`, with the data end rounded by
`radius` pixels. `width` is in data units (by default 70 % of the smallest spacing of `x`);
`gap` leaves pixels between neighbouring bars. With `horizontal = true` the bars run along
x and `x` gives their positions on the y axis. For grouped bars, use `offset` and a
narrower `width`; for categories, plot at `1:n` and set `xticks = (1:n, names)`.
"""
function bars!(p::Panel, x, y; width = nothing, offset::Real = 0.0, color = 1, baseline::Real = 0.0,
        horizontal::Bool = false, gap::Real = 0.0, radius::Real = 3.0, opacity::Real = 1.0,
        label::AbstractString = "", tips = nothing)
    checklen(x, y)
    xs = floats(x) .+ offset
    w = if width === nothing
        d = diff(sort(unique(filter(isfinite, xs))))
        0.7 * (isempty(d) ? 1.0 : minimum(d))
    else
        Float64(width)
    end
    return add!(p, BarsMark(xs .- w / 2, xs .+ w / 2, floats(y), baseline, horizontal, paint(color), gap,
        radius, opacity, label, tipvec(tips, length(x))))
end

"""
    hist!(ax, data; bins = 20, normalize = false, color = 1, gap = 2, radius = 2,
          opacity = 1, label = "")

A histogram of `data` (non-finite values are skipped). `bins` is a number of equal bins or
a vector of bin edges; `normalize = true` scales the bars to a probability density.
"""
function hist!(p::Panel, data; bins = 20, normalize::Bool = false, color = 1, gap::Real = 2.0,
        radius::Real = 2.0, opacity::Real = 1.0, label::AbstractString = "")
    v = filter(isfinite, floats(data))
    isempty(v) && throw(ArgumentError("no finite data"))
    edges = if bins isa Integer
        lo, hi = extrema(v)
        lo == hi && (lo -= 0.5; hi += 0.5)
        collect(range(lo, hi; length = bins + 1))
    else
        floats(bins)
    end
    counts = zeros(length(edges) - 1)
    for a in v
        i = searchsortedlast(edges, a)
        i == length(edges) && a == edges[end] && (i -= 1)
        1 <= i <= length(counts) && (counts[i] += 1)
    end
    normalize && (counts ./= (length(v) .* diff(edges)))
    tips = ["$(format_tick(edges[i]; step = (edges[2] - edges[1]) / 10)) to $(format_tick(edges[i + 1]; step = (edges[2] - edges[1]) / 10)): " *
            (normalize ? @sprintf("%.3g", counts[i]) : string(round(Int, counts[i]))) for i in eachindex(counts)]
    return add!(p, BarsMark(edges[1:(end - 1)], edges[2:end], counts, 0.0, false, paint(color), gap, radius,
        opacity, label, plaintext.(tips)))
end

struct ErrorBarsMark <: Mark
    x::Vector{Float64}
    lo::Vector{Float64}
    hi::Vector{Float64}
    color::Paint
    width::Float64
    cap::Float64
    horizontal::Bool
end

"""
    errorbars!(ax, x, lo, hi; color = :ink2, width = :thin, cap = 4, horizontal = false)

Error bars from `lo[i]` to `hi[i]` at `x[i]`, with caps of `cap` pixels on either side
(`cap = 0` for none). With `horizontal = true` they run along x at heights `x[i]`.
"""
function errorbars!(p::Panel, x, lo, hi; color = :ink2, width = :thin, cap::Real = 4.0, horizontal::Bool = false)
    checklen(x, lo, "x and lo")
    checklen(x, hi, "x and hi")
    return add!(p, ErrorBarsMark(floats(x), floats(lo), floats(hi), paint(color), widthpx(width), cap, horizontal))
end

# ---- shapes -----------------------------------------------------------------------------

struct SegmentsMark <: Mark
    x1::Vector{Float64}
    y1::Vector{Float64}
    x2::Vector{Float64}
    y2::Vector{Float64}
    color::Paint
    width::Float64
    dash::Union{Nothing, String}
    opacity::Float64
    label::String
    clip::Bool
end

"""
    segments!(ax, segs; color = :ink, width = :thin, dash = false, opacity = 1, label = "", clip = true)

Straight segments `segs = [(x1, y1, x2, y2), ...]`, drawn as one path.
"""
function segments!(p::Panel, segs; color = :ink, width = :thin, dash = false, opacity::Real = 1.0,
        label::AbstractString = "", clip::Bool = true)
    s = collect(segs)
    return add!(p, SegmentsMark(floats(getindex.(s, 1)), floats(getindex.(s, 2)), floats(getindex.(s, 3)),
        floats(getindex.(s, 4)), paint(color), widthpx(width), dashpattern(dash), opacity, label, clip))
end

struct RectMark <: Mark
    x1::Float64
    y1::Float64
    x2::Float64
    y2::Float64
    fill::Paint
    fillopacity::Float64
    stroke::Paint
    width::Float64
    dash::Union{Nothing, String}
    radius::Float64
    label::String
    tip::String
    clip::Bool
    under::Bool
end

"""
    rect!(ax, x1, y1, x2, y2; fill = :accent, opacity = 0.13, stroke = nothing,
          width = :thin, dash = false, radius = 0, label = "", tip = "", clip = true)

A rectangle with corners `(x1, y1)` and `(x2, y2)` in data coordinates; `radius` rounds its
corners (pixels).
"""
function rect!(p::Panel, x1, y1, x2, y2; fill = :accent, opacity::Real = 0.13, stroke = nothing,
        width = :thin, dash = false, radius::Real = 0.0, label::AbstractString = "", tip::AbstractString = "",
        clip::Bool = true)
    return add!(p, RectMark(x1, y1, x2, y2, paint(fill), opacity, paint(stroke), widthpx(width), dashpattern(dash),
        radius, label, tip, clip, false))
end

const SPAN_DOC = """
    vspan!(ax, x1, x2; color = :ink, opacity = 0.05, label = "")
    hspan!(ax, y1, y2; color = :ink, opacity = 0.05, label = "")

Shade the full height between `x1` and `x2` (or the full width between `y1` and `y2`),
for example a training range. Spans are drawn beneath the gridlines and do not affect the
automatic limits along the other axis.
"""

@doc SPAN_DOC
vspan!(p::Panel, x1, x2; color = :ink, opacity::Real = 0.05, label::AbstractString = "") =
    add!(p, RectMark(x1, -Inf, x2, Inf, paint(color), opacity, nothing, 0.0, nothing, 0.0, label, "", true, true))

@doc SPAN_DOC
hspan!(p::Panel, y1, y2; color = :ink, opacity::Real = 0.05, label::AbstractString = "") =
    add!(p, RectMark(-Inf, y1, Inf, y2, paint(color), opacity, nothing, 0.0, nothing, 0.0, label, "", true, true))

struct PolygonMark <: Mark
    x::Vector{Float64}
    y::Vector{Float64}
    fill::Paint
    fillopacity::Float64
    stroke::Paint
    width::Float64
    dash::Union{Nothing, String}
    label::String
    clip::Bool
end

"""
    polygon!(ax, x, y; fill = :accent, opacity = 0.13, stroke = nothing, width = :thin,
             dash = false, label = "", clip = true)

A closed polygon through `(x[i], y[i])`; `NaN` starts a new ring, so rings with holes and
several shapes fit in one call.
"""
function polygon!(p::Panel, x, y; fill = :accent, opacity::Real = 0.13, stroke = nothing, width = :thin,
        dash = false, label::AbstractString = "", clip::Bool = true)
    checklen(x, y)
    return add!(p, PolygonMark(floats(x), floats(y), paint(fill), opacity, paint(stroke), widthpx(width),
        dashpattern(dash), label, clip))
end

struct CircleMark <: Mark
    x::Float64
    y::Float64
    r::Float64
    fill::Paint
    fillopacity::Float64
    stroke::Paint
    width::Float64
    dash::Union{Nothing, String}
    label::String
    tip::String
    clip::Bool
end

"""
    circle!(ax, x, y, r; fill = nothing, opacity = 1, stroke = :ink, width = :thin,
            dash = false, label = "", tip = "", clip = false)

A circle of radius `r` pixels around `(x, y)`, by default an open ring that marks a point.
"""
function circle!(p::Panel, x, y, r; fill = nothing, opacity::Real = 1.0, stroke = :ink, width = :thin,
        dash = false, label::AbstractString = "", tip::AbstractString = "", clip::Bool = false)
    return add!(p, CircleMark(x, y, r, paint(fill), opacity, paint(stroke), widthpx(width), dashpattern(dash),
        label, tip, clip))
end

struct EllipseMark <: Mark
    x::Float64
    y::Float64
    a::Float64
    b::Float64
    rotate::Float64
    fill::Paint
    fillopacity::Float64
    stroke::Paint
    width::Float64
    dash::Union{Nothing, String}
    label::String
    clip::Bool
end

"""
    ellipse!(ax, x, y, a, b; rotate = 0, fill = :accent, opacity = 0.07, stroke = :accent,
             width = 1.2, dash = false, label = "", clip = true)

An ellipse around `(x, y)` with semi-axes `a` along x and `b` along y in data units, turned
by `rotate` degrees (counterclockwise on screen).
"""
function ellipse!(p::Panel, x, y, a, b; rotate::Real = 0.0, fill = :accent, opacity::Real = 0.07,
        stroke = :accent, width = 1.2, dash = false, label::AbstractString = "", clip::Bool = true)
    return add!(p, EllipseMark(x, y, a, b, rotate, paint(fill), opacity, paint(stroke), widthpx(width),
        dashpattern(dash), label, clip))
end

struct ArrowMark <: Mark
    x1::Float64
    y1::Float64
    x2::Float64
    y2::Float64
    color::Paint
    width::Float64
    head::Float64
    dash::Union{Nothing, String}
    label::String
    clip::Bool
end

"""
    arrow!(ax, x1, y1, x2, y2; color = :ink, width = :normal, head = 7, dash = false,
           label = "", clip = false)

An arrow from `(x1, y1)` to `(x2, y2)` with a filled head of `head` pixels.
"""
function arrow!(p::Panel, x1, y1, x2, y2; color = :ink, width = :normal, head::Real = 7.0, dash = false,
        label::AbstractString = "", clip::Bool = false)
    return add!(p, ArrowMark(x1, y1, x2, y2, paint(color), widthpx(width), head, dashpattern(dash), label, clip))
end

# ---- reference lines --------------------------------------------------------------------

struct RefLineMark <: Mark
    horizontal::Bool
    v::Float64
    color::Paint
    width::Float64
    dash::Union{Nothing, String}
    label::String
    labelpos::Symbol
end

const REFLINE_DOC = """
    hline!(ax, y; color = :ink2, width = 1, dash = true, label = "", labelpos = :right)
    vline!(ax, x; color = :ink2, width = 1, dash = true, label = "", labelpos = :top)

A reference line across the panel. Its `label` is written along the line (at the `:right`
or `:left` end of a horizontal line, at the `:top` or `:bottom` of a vertical one), not in
the legend.
"""

@doc REFLINE_DOC
hline!(p::Panel, y::Real; color = :ink2, width = 1.0, dash = true, label::AbstractString = "", labelpos::Symbol = :right) =
    add!(p, RefLineMark(true, y, paint(color), widthpx(width), dashpattern(dash), label, labelpos))

@doc REFLINE_DOC
vline!(p::Panel, x::Real; color = :ink2, width = 1.0, dash = true, label::AbstractString = "", labelpos::Symbol = :top) =
    add!(p, RefLineMark(false, x, paint(color), widthpx(width), dashpattern(dash), label, labelpos))

# ---- text -------------------------------------------------------------------------------

struct NoteMark <: Mark
    x::Float64
    y::Float64
    text::String
    anchor::Symbol
    valign::Symbol
    dx::Float64
    dy::Float64
    size::Union{Symbol, Float64}
    color::Paint
    bold::Bool
    italic::Bool
    halo::Bool
    rotate::Float64
    clip::Bool
    pixels::Bool   # coordinates in pixels (figure-level notes)
end

const NOTE_DOC = """
- `anchor`: `:start`, `:middle` or `:end` of the text at the point;
  `valign`: `:middle`, `:top`, `:bottom` or `:baseline`.
- `dx`, `dy`: offset in pixels.
- `size`: pixels or `:note`, `:tick`, `:label`, `:title`.
- `color`: `:ink` (default), `:ink2`, `:muted` or any other color.
- `bold`, `italic`, `rotate` (degrees).
- `halo = true` draws a band of background color behind the text, which keeps labels
  readable on top of lines and contours.

The text accepts the label markup `x_{i}`, `10^{-5}` and `**bold**`.
"""

"""
    note!(ax, x, y, text; anchor = :start, valign = :middle, dx = 0, dy = 0, size = :note,
          color = :ink, bold = false, italic = false, halo = false, rotate = 0, clip = false)
    note!(fig, x, y, text; kwargs...)

Text at `(x, y)` in data coordinates of the panel `ax`, or in pixels of the figure `fig`.

$NOTE_DOC
"""
function note!(p::Panel, x::Real, y::Real, text::AbstractString; kwargs...)
    return add!(p, note(x, y, text, false; kwargs...))
end
function note!(f::Fig, x::Real, y::Real, text::AbstractString; kwargs...)
    push!(f.marks, note(x, y, text, true; kwargs...))
    return f
end

function note(x, y, text, pixels; anchor::Symbol = :start, valign::Symbol = :middle, dx::Real = 0.0, dy::Real = 0.0,
        size = :note, color = :ink, bold::Bool = false, italic::Bool = false, halo::Bool = false,
        rotate::Real = 0.0, clip::Bool = false)
    anchor in (:start, :middle, :end) || throw(ArgumentError("anchor must be :start, :middle or :end"))
    valign in (:middle, :top, :bottom, :baseline) || throw(ArgumentError("valign must be :middle, :top, :bottom or :baseline"))
    sz = size isa Real ? Float64(size) : size
    sz isa Symbol && !(sz in (:note, :tick, :label, :title)) &&
        throw(ArgumentError("size must be a number or :note, :tick, :label, :title"))
    return NoteMark(x, y, text, anchor, valign, dx, dy, sz, paint(color), bold, italic, halo, rotate, clip, pixels)
end

struct AnnotationMark <: Mark
    x::Float64
    y::Float64
    text::String
    dx::Float64
    dy::Float64
    color::Paint
    bold::Bool
    halo::Bool
    dot::Bool
end

"""
    annotate!(ax, x, y, text; dx = 24, dy = -24, color = :ink, bold = false, halo = true, dot = false)

A callout: `text` placed `(dx, dy)` pixels away from the point `(x, y)` with a thin leader
line to it (and a small dot on the point with `dot = true`). The text is anchored on the
side facing away from the point.
"""
function annotate!(p::Panel, x::Real, y::Real, text::AbstractString; dx::Real = 24.0, dy::Real = -24.0,
        color = :ink, bold::Bool = false, halo::Bool = true, dot::Bool = false)
    return add!(p, AnnotationMark(x, y, text, dx, dy, paint(color), bold, halo, dot))
end

# ---- fields -----------------------------------------------------------------------------

struct ContourMark <: Mark
    xr::Tuple{Float64, Float64}   # extent of the field
    yr::Tuple{Float64, Float64}
    levels::Vector{Float64}
    lines::Vector{Tuple{Vector{Float64}, Vector{Float64}}}   # per level, NaN-separated polylines
    color::Paint
    width::Float64
    fade::Bool
    strong::Vector{Bool}
    label::String
    clip::Bool
end

"""
    contours!(ax, x, y, Z; levels = 10, color = :contour, width = 0.8, fade = true,
              strong = [], label = "", clip = true)

Contour lines of the field `Z[i, j]` given at `(x[i], y[j])`. `levels` is a number of
evenly spaced levels or a vector of values. With `fade = true` lower levels are drawn
darker, a depth cue that needs no color; levels listed in `strong` are drawn in ink.
`NaN` values leave holes.
"""
function contours!(p::Panel, x, y, Z::AbstractMatrix; levels = 10, color = :contour, width = 0.8,
        fade::Bool = true, strong = Float64[], label::AbstractString = "", clip::Bool = true)
    size(Z) == (length(x), length(y)) || throw(DimensionMismatch("Z must be length(x) × length(y)"))
    zs = floats(Z)
    lv = if levels isa Integer
        lo, hi = extrema(filter(isfinite, zs))
        collect(range(lo, hi; length = levels + 2)[2:(end - 1)])
    else
        sort(floats(levels))
    end
    xs, ys, Zf = floats(x), floats(y), reshape(zs, size(Z))
    lines = [isoline(xs, ys, Zf, l) for l in lv]
    st = [any(s -> isapprox(s, l; rtol = 1.0e-9, atol = 1.0e-12), floats(strong)) for l in lv]
    return add!(p, ContourMark(extrema(xs), extrema(ys), lv, lines, paint(color), widthpx(width), fade, st, label, clip))
end

struct HeatmapMark <: Mark
    x::Vector{Float64}
    y::Vector{Float64}
    Z::Matrix{Float64}
    color::Paint
    lo::Float64
    hi::Float64
    steps::Int
    label::String
end

"""
    heatmap!(ax, x, y, Z; color = :accent, range = nothing, steps = 9, label = "")

Cells centred at `(x[i], y[j])` shaded by `Z[i, j]`: a single hue whose opacity grows with
the value, which reads the same on light and dark backgrounds. `range = (lo, hi)` fixes
the values mapped to the lightest and darkest step (default: the extrema of `Z`); values
are quantized into `steps` levels, which keeps the SVG small. Drawn beneath the gridlines.
"""
function heatmap!(p::Panel, x, y, Z::AbstractMatrix; color = :accent, range = nothing, steps::Integer = 9,
        label::AbstractString = "")
    size(Z) == (length(x), length(y)) || throw(DimensionMismatch("Z must be length(x) × length(y)"))
    zs = reshape(floats(Z), size(Z))
    lo, hi = range === nothing ? extrema(filter(isfinite, zs)) : Float64.(range)
    return add!(p, HeatmapMark(floats(x), floats(y), zs, paint(color), lo, hi, steps, label))
end

struct MaskMark <: Mark
    x::Vector{Float64}
    y::Vector{Float64}
    M::Matrix{Bool}
    color::Paint
    opacity::Float64
    label::String
end

"""
    mask!(ax, x, y, M; color = :accent, opacity = 0.13, label = "")

Shade the grid cells centred at `(x[i], y[j])` where `M[i, j]` is true, for example the
region of acceptable parameters. Drawn beneath the gridlines.
"""
function mask!(p::Panel, x, y, M::AbstractMatrix{Bool}; color = :accent, opacity::Real = 0.13, label::AbstractString = "")
    size(M) == (length(x), length(y)) || throw(DimensionMismatch("M must be length(x) × length(y)"))
    return add!(p, MaskMark(floats(x), floats(y), Matrix(M), paint(color), opacity, label))
end

# ---- legends ----------------------------------------------------------------------------

const LEGEND_KINDS = (:line, :dash, :dot, :opendot, :linedot, :box, :arrow, :ring)

"""
    legend!(ax; position = :top, corner = :topright, items = nothing)
    legend!(fig; position = :top, items = nothing)

Show a legend for the panel (or one for the whole figure). Entries are collected from the
marks with a `label`, in the order they were added; marks sharing a label share an entry
(a line and points with one label become a line with a dot).

`position` is `:top` (a row above the plot area), `:bottom`, `:right` (a column) or
`:inside` (a column in the given `corner`) for panels and `:top` or `:bottom` for figures.
`items` replaces the collected entries with `(kind, color, label)` tuples, where `kind` is
one of `$(join(":" .* string.(LEGEND_KINDS), ", "))`.
"""
function legend!(p::Panel; position::Symbol = :top, corner::Symbol = :topright, items = nothing)
    configure!(p; legend = position, legend_corner = corner)
    items === nothing || push!(p.marks, LegendItemsMark(legend_items(items)))
    return p.fig
end
function legend!(f::Fig; position::Symbol = :top, items = nothing)
    position in (:top, :bottom) || throw(ArgumentError("a figure legend goes at the :top or the :bottom"))
    f.legend = position
    items === nothing || (f.legend_items = legend_items(items))
    return f
end

struct LegendItemsMark <: Mark
    items::Vector{Any}
end

function legend_items(items)
    return map(collect(items)) do it
        kind, color, label = it
        kind in LEGEND_KINDS || throw(ArgumentError("legend kind must be one of $(join(LEGEND_KINDS, ", "))"))
        (kind = kind, color = paint(color), opacity = kind === :box ? 0.3 : 1.0, label = string(label))
    end
end

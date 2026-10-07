# Layout: automatic limits, ticks, legends, margins, and the plot areas of the panels.

# ---- extents of marks (xlo, xhi, ylo, yhi) ------------------------------------------------

const NOEXT = (Inf, -Inf, Inf, -Inf)

function lohi(v, log::Bool)
    lo, hi = Inf, -Inf
    for a in v
        isfinite(a) || continue
        log && a <= 0 && continue
        lo = min(lo, a)
        hi = max(hi, a)
    end
    return lo, hi
end
ext(xs, ys, xl, yl) = (lohi(xs, xl)..., lohi(ys, yl)...)
combine(a, b) = (min(a[1], b[1]), max(a[2], b[2]), min(a[3], b[3]), max(a[4], b[4]))

function cell_edges(c::Vector{Float64})
    length(c) == 1 && return [c[1] - 0.5, c[1] + 0.5]
    mids = (c[1:(end - 1)] .+ c[2:end]) ./ 2
    return vcat(2c[1] - mids[1], mids, 2c[end] - mids[end])
end

extent(::Mark, xl, yl) = NOEXT
extent(m::LineMark, xl, yl) = ext(m.x, m.y, xl, yl)
extent(m::BandMark, xl, yl) = ext(m.x, vcat(m.lo, m.hi), xl, yl)
extent(m::PointsMark, xl, yl) = ext(m.x, m.y, xl, yl)
function extent(m::BarsMark, xl, yl)
    pos, val = vcat(m.lo, m.hi), vcat(m.v, m.baseline)
    return m.horizontal ? ext(val, pos, xl, yl) : ext(pos, val, xl, yl)
end
extent(m::ErrorBarsMark, xl, yl) = m.horizontal ? ext(vcat(m.lo, m.hi), m.x, xl, yl) : ext(m.x, vcat(m.lo, m.hi), xl, yl)
extent(m::SegmentsMark, xl, yl) = ext(vcat(m.x1, m.x2), vcat(m.y1, m.y2), xl, yl)
extent(m::RectMark, xl, yl) = ext((m.x1, m.x2), (m.y1, m.y2), xl, yl)
extent(m::PolygonMark, xl, yl) = ext(m.x, m.y, xl, yl)
extent(m::CircleMark, xl, yl) = ext((m.x,), (m.y,), xl, yl)
extent(m::EllipseMark, xl, yl) = ext((m.x - m.a, m.x + m.a), (m.y - m.b, m.y + m.b), xl, yl)
extent(m::ArrowMark, xl, yl) = ext((m.x1, m.x2), (m.y1, m.y2), xl, yl)
extent(m::RefLineMark, xl, yl) = m.horizontal ? (Inf, -Inf, lohi((m.v,), yl)...) : (lohi((m.v,), xl)..., Inf, -Inf)
extent(m::AnnotationMark, xl, yl) = ext((m.x,), (m.y,), xl, yl)
extent(m::ContourMark, xl, yl) = ext(m.xr, m.yr, xl, yl)
extent(m::HeatmapMark, xl, yl) = ext(cell_edges(m.x), cell_edges(m.y), xl, yl)
extent(m::MaskMark, xl, yl) = ext(cell_edges(m.x), cell_edges(m.y), xl, yl)

# ---- limits and ticks -------------------------------------------------------------------

# limits (and, when rounded to ticks, the tick step) of an axis
function axis_limits(l::Lim, lo::Float64, hi::Float64, log::Bool, nice::Bool, n::Int)
    l[1] !== nothing && l[2] !== nothing && l[1] != l[2] && return l[1], l[2], nothing   # explicit (may be reversed)
    a = l[1] === nothing ? lo : l[1]
    b = l[2] === nothing ? hi : l[2]
    if !isfinite(a) && !isfinite(b)
        a, b = log ? (1.0, 10.0) : (0.0, 1.0)
    elseif !isfinite(a)
        a = log ? b / 10 : b - 1
    elseif !isfinite(b)
        b = log ? a * 10 : a + 1
    end
    log && a <= 0 && throw(ArgumentError("a logarithmic axis needs positive limits, got $a"))
    if a == b
        a, b = log ? (a / sqrt(10), b * sqrt(10)) : (a - (a == 0 ? 1.0 : abs(a) / 10), b + (b == 0 ? 1.0 : abs(b) / 10))
    end
    step = nothing
    if nice
        if log
            l[1] === nothing && (a = 10.0^floor(log10(a) + 1.0e-9))
            l[2] === nothing && (b = 10.0^ceil(log10(b) - 1.0e-9))
        else
            step = nice_step((b - a) / max(n, 1))
            l[1] === nothing && (a = floor(a / step + 1.0e-9) * step)
            l[2] === nothing && (b = ceil(b / step - 1.0e-9) * step)
        end
    end
    return a, b, step
end

function axis_ticks(spec, s::Scale, n::Int, format, step = nothing)
    (spec === nothing || (spec isa AbstractVector && isempty(spec))) && return Float64[], String[]
    lo, hi = minmax(s.d0, s.d1)
    tol = 1.0e-9 * (s.log ? hi : hi - lo)
    inside(v) = lo - tol <= v <= hi + tol
    if spec isa Tuple && length(spec) == 2 && spec[2] isa AbstractVector
        keep = [inside(v) for v in floats(spec[1])]
        return floats(spec[1])[keep], string.(spec[2])[keep]
    end
    t = if spec !== :auto
        filter(inside, floats(spec))
    elseif step !== nothing && !s.log
        k0, k1 = ceil(Int, lo / step - 1.0e-9), floor(Int, hi / step + 1.0e-9)
        [abs(k) < 1.0e-12 ? 0.0 : k * step for k in k0:k1]
    else
        ticks_for(s, n)
    end
    step = length(t) > 1 ? minimum(diff(sort(t))) : max(hi - lo, 1.0e-300)
    powers = s.log && any(v -> !(1.0e-2 <= v <= 1.0e4), t)
    labels = format === nothing ? [format_tick(v; step, log = s.log, powers) for v in t] : [string(format(v)) for v in t]
    return t, labels
end

# ---- legends ----------------------------------------------------------------------------

le(kind, color, label; opacity = 1.0) = isempty(label) ? nothing : (kind = kind, color = color, opacity = opacity, label = label)
wash(o) = max(o, 0.18)

legend_entry(::Mark) = nothing
legend_entry(m::LineMark) = le(m.dash === nothing ? :line : :dash, m.color, m.label; opacity = m.opacity)
legend_entry(m::SegmentsMark) = le(m.dash === nothing ? :line : :dash, m.color, m.label; opacity = m.opacity)
legend_entry(m::BandMark) = le(:box, m.color, m.label; opacity = wash(m.opacity))
legend_entry(m::PointsMark) = le(m.open ? :opendot : :dot, m.color, m.label; opacity = m.opacity)
legend_entry(m::BarsMark) = le(:box, m.color, m.label; opacity = m.opacity)
legend_entry(m::RectMark) = le(:box, something(m.fill, m.stroke, :ink), m.label; opacity = wash(m.fillopacity))
legend_entry(m::PolygonMark) = le(:box, something(m.fill, m.stroke, :ink), m.label; opacity = wash(m.fillopacity))
legend_entry(m::EllipseMark) = le(:box, something(m.fill, m.stroke, :ink), m.label; opacity = wash(m.fillopacity))
legend_entry(m::CircleMark) = le(:ring, something(m.stroke, m.fill, :ink), m.label)
legend_entry(m::ArrowMark) = le(:arrow, m.color, m.label)
legend_entry(m::ContourMark) = le(:line, m.color, m.label)
legend_entry(m::HeatmapMark) = le(:box, m.color, m.label; opacity = 0.5)
legend_entry(m::MaskMark) = le(:box, m.color, m.label; opacity = wash(m.opacity))

# `direct = false` leaves out lines that carry their label at their end
function legend_entries(marks; direct::Bool = true)
    for m in marks
        m isa LegendItemsMark && return m.items
    end
    entries = Any[]
    for m in marks
        !direct && m isa LineMark && m.endlabel && continue
        e = legend_entry(m)
        e === nothing && continue
        k = findfirst(x -> x.label == e.label, entries)
        if k === nothing
            push!(entries, e)
        else
            old = entries[k]
            if (old.kind in (:line, :dash) && e.kind in (:dot, :opendot)) || (old.kind in (:dot, :opendot) && e.kind in (:line, :dash))
                entries[k] = merge(old, (kind = :linedot,))
            end
        end
    end
    return entries
end

swatch_width(kind) = kind in (:line, :dash) ? 20.0 : kind === :linedot ? 22.0 : kind in (:dot, :opendot) ? 10.0 :
    kind === :box ? 14.0 : kind === :arrow ? 20.0 : 12.0
entry_width(e, size) = swatch_width(e.kind) + 6 + text_width(e.label, size)
const ROW = 18.0      # height of a legend row
const ENTRY_GAP = 18.0

"""Entries split greedily into rows that fit in `width` pixels."""
function legend_rows(entries, width, size)
    rows = Vector{Vector{Int}}()
    x = Inf
    for (i, e) in enumerate(entries)
        w = entry_width(e, size)
        if isempty(rows) || x + w > width
            push!(rows, [i])
            x = w + ENTRY_GAP
        else
            push!(rows[end], i)
            x += w + ENTRY_GAP
        end
    end
    return rows
end

# ---- panel plans --------------------------------------------------------------------------

Base.@kwdef mutable struct Plan
    p::Panel
    xlim::Tuple{Float64, Float64}
    ylim::Tuple{Float64, Float64}
    xt::Vector{Float64}
    xtl::Vector{String}
    yt::Vector{Float64}
    ytl::Vector{String}
    entries::Vector{Any}
    legend::Symbol
    rows::Vector{Vector{Int}} = Vector{Int}[]
    margins::Vector{Float64} = zeros(4)   # left, right, top, bottom
    slot::NTuple{4, Float64} = (0.0, 0.0, 0.0, 0.0)
    box::NTuple{4, Float64} = (0.0, 0.0, 0.0, 0.0)
    sx::Scale = Scale(false, 0, 1, 0, 1)
    sy::Scale = Scale(false, 0, 1, 0, 1)
end

function plan_panel(p::Panel, slotw::Float64, sloth::Float64, t::Theme, figlegend::Bool)
    xlog, ylog = p.xscale === :log, p.yscale === :log
    e = NOEXT
    for m in p.marks
        e = combine(e, extent(m, xlog, ylog))
    end
    nx = max(2, round(Int, max(slotw - 70, 40) / 90))
    ny = max(2, round(Int, max(sloth - 70, 30) / 55))
    nice = p.nice === nothing ? p.style !== :frame : p.nice
    x0, x1, xstep = axis_limits(p.xlim, e[1], e[2], xlog, nice, nx)
    y0, y1, ystep = axis_limits(p.ylim, e[3], e[4], ylog, nice, ny)
    xl, yl = (x0, x1), (y0, y1)
    none = p.style === :none
    xt, xtl = none ? (Float64[], String[]) : axis_ticks(p.xticks, Scale(xlog, xl..., 0, 1), nx, p.xformat, xstep)
    yt, ytl = none ? (Float64[], String[]) : axis_ticks(p.yticks, Scale(ylog, yl..., 0, 1), ny, p.yformat, ystep)
    entries = legend_entries(p.marks; direct = p.legend !== :auto)
    pos = p.legend === :auto ? (figlegend || length(entries) < 2 ? :none : :top) : p.legend
    isempty(entries) && (pos = :none)
    pl = Plan(; p, xlim = xl, ylim = yl, xt, xtl, yt, ytl, entries, legend = pos)

    # margins
    l = none ? 4.0 : isempty(ytl) ? 6.0 : maximum(s -> text_width(s, t.tick), ytl) + 10
    r = 8.0
    if !isempty(xtl)
        l = max(l, text_width(xtl[1], t.tick) / 2 + 2)
        r = max(r, text_width(xtl[end], t.tick) / 2 + 2)
    end
    for m in p.marks
        m isa LineMark && m.endlabel && !isempty(m.label) && (r = max(r, text_width(m.label, t.note; bold = true) + 14))
    end
    pos === :right && (r += maximum(x -> entry_width(x, t.legend), entries) + 16)
    top = 0.0
    isempty(p.title) || (top += t.title + 9)
    isempty(p.subtitle) || (top += t.subtitle + 7)
    if pos === :top
        pl.rows = legend_rows(entries, max(slotw - l - r, 80), t.legend)
        top += length(pl.rows) * ROW + 4
    end
    top += !none && !isempty(p.ylabel) ? 20.0 : isempty(ytl) ? 4.0 : 8.0
    bottom = none ? 4.0 : isempty(xtl) ? 8.0 : 24.0
    isempty(p.xlabel) || none || (bottom += 16)
    if pos === :bottom
        pl.rows = legend_rows(entries, max(slotw - l - r, 80), t.legend)
        bottom += length(pl.rows) * ROW + 8
    elseif pos in (:right, :inside)
        pl.rows = [[i] for i in eachindex(entries)]
    end
    pl.margins = [l, r, top, bottom]
    return pl
end

# ---- figure layout ------------------------------------------------------------------------

struct Layout
    plans::Vector{Plan}
    figentries::Vector{Any}
    figrows::Vector{Vector{Int}}
    content::NTuple{4, Float64}   # x, y, width, height of the panel area
end

function figure_entries(fig::Fig)
    fig.legend === :none && return Any[]
    isempty(fig.legend_items) || return fig.legend_items
    return legend_entries(reduce(vcat, (p.marks for p in fig.panels); init = Mark[]))
end

function layout(fig::Fig, t::Theme)
    pad = fig.padding
    top = pad
    isempty(fig.title) || (top += t.figtitle + 8)
    isempty(fig.subtitle) || (top += t.figsubtitle + 8)
    figentries = figure_entries(fig)
    figrows = legend_rows(figentries, fig.width - 2pad, t.legend)
    fig.legend === :top && !isempty(figentries) && (top += length(figrows) * ROW + 6)
    top > pad && (top += 10)
    bottom = fig.height - pad
    isempty(fig.credit) || (bottom -= t.credit + 10)
    fig.legend === :bottom && !isempty(figentries) && (bottom -= length(figrows) * ROW + 8)

    nr, nc = fig.layout
    cw = (fig.width - 2pad - (nc - 1) * fig.hgap) / nc
    ch = (bottom - top - (nr - 1) * fig.vgap) / nr
    function slot(cell)
        r, c, rs, cs = cell
        return (pad + (c - 1) * (cw + fig.hgap), top + (r - 1) * (ch + fig.vgap),
            cs * cw + (cs - 1) * fig.hgap, rs * ch + (rs - 1) * fig.vgap)
    end
    figlegend = fig.legend !== :none
    plans = map(fig.panels) do p
        s = p.cell === nothing ? (p.box[1], p.box[2], p.box[3] + 70, p.box[4] + 70) : slot(p.cell)
        pl = plan_panel(p, s[3], s[4], t, figlegend)
        pl.slot = s
        pl
    end

    # panels in a column share left and right margins, panels in a row top and bottom ones
    L, R, T, B = zeros(nc), zeros(nc), zeros(nr), zeros(nr)
    for pl in plans
        pl.p.cell === nothing && continue
        r, c, rs, cs = pl.p.cell
        L[c] = max(L[c], pl.margins[1])
        R[c + cs - 1] = max(R[c + cs - 1], pl.margins[2])
        T[r] = max(T[r], pl.margins[3])
        B[r + rs - 1] = max(B[r + rs - 1], pl.margins[4])
    end
    for pl in plans
        p = pl.p
        if p.cell === nothing
            x0, y0, w, h = p.box
            pl.slot = (x0 - pl.margins[1], y0 - pl.margins[3], w + pl.margins[1] + pl.margins[2], h + pl.margins[3] + pl.margins[4])
        else
            r, c, rs, cs = p.cell
            sx, sy, sw, sh = pl.slot
            pl.margins = [L[c], R[c + cs - 1], T[r], B[r + rs - 1]]
            x0, y0 = sx + L[c], sy + T[r]
            w, h = sw - L[c] - R[c + cs - 1], sh - T[r] - B[r + rs - 1]
        end
        w, h = max(w, 10.0), max(h, 10.0)
        if p.aspect !== nothing && p.xscale === :linear && p.yscale === :linear
            dx, dy = abs(pl.xlim[2] - pl.xlim[1]), abs(pl.ylim[2] - pl.ylim[1])
            need = p.aspect * w * dy / dx
            need <= h ? (h = need) : (w = h * dx / (p.aspect * dy))
        end
        pl.box = (x0, y0, w, h)
        pl.sx = Scale(p.xscale === :log, pl.xlim..., x0, x0 + w)
        pl.sy = Scale(p.yscale === :log, pl.ylim..., y0 + h, y0)
    end
    return Layout(plans, figentries, figrows, (pad, top, fig.width - 2pad, bottom - top))
end

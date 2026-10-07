# Rendering: SVG for the web (colors as CSS variables that follow light and dark mode,
# native tooltips) or static SVG (every style baked in, for PowerPoint, Keynote, Inkscape).

mutable struct Ctx
    io::IOBuffer
    mode::Symbol
    t::Theme
    id::String
    hits::IOBuffer
end

const IDTOKEN = "@@hlid@@"

# paint attributes: in web mode theme colors become CSS variables in a style attribute
function pa(ctx::Ctx, props::Pair...)
    io = IOBuffer()
    styles = String[]
    for (k, c) in props
        if ctx.mode === :web && (c isa Symbol || c isa Int)
            push!(styles, "$k:var($(cssvar(c)))")
        else
            print(io, " ", k, "=\"", xmlesc(resolve(ctx.t, c)), "\"")
        end
    end
    isempty(styles) || print(io, " style=\"", join(styles, ";"), "\"")
    return String(take!(io))
end

dasha(d) = d === nothing ? "" : " stroke-dasharray=\"$d\""
opa(name, o) = o >= 1 ? "" : " $name=\"$(@sprintf("%.3g", o))\""
tipel(ctx::Ctx, tip::AbstractString) = ctx.mode === :web && !isempty(tip) ? "<title>$(xmlesc(plaintext(tip)))</title>" : ""

function pathd(xs, ys; close::Bool = false)
    io = IOBuffer()
    pen = false
    lx, ly = NaN, NaN
    n = length(xs)
    for i in 1:n
        x, y = xs[i], ys[i]
        if !(isfinite(x) && isfinite(y))
            pen && close && print(io, "Z")
            pen = false
            continue
        end
        if pen
            last = i == n || !(isfinite(xs[i + 1]) && isfinite(ys[i + 1]))
            !last && abs(x - lx) < 0.35 && abs(y - ly) < 0.35 && continue
            print(io, "L", fmt(x), ",", fmt(y))
        else
            print(io, "M", fmt(x), ",", fmt(y))
            pen = true
        end
        lx, ly = x, y
    end
    pen && close && print(io, "Z")
    return String(take!(io))
end

size_of(t::Theme, s) = s isa Real ? Float64(s) : s === :tick ? t.tick : s === :label ? t.label : s === :title ? t.title : t.note

function text!(ctx::Ctx, x, y, s::AbstractString; size::Real, color = :ink, anchor::Symbol = :start,
        valign::Symbol = :middle, weight::Int = 400, italic::Bool = false, halo::Bool = false, rotate::Real = 0)
    isempty(s) && return
    content = text_content(s, ctx.mode, size)
    dy = valign === :middle ? 0.34 * size : valign === :top ? 0.78 * size : valign === :bottom ? -0.22 * size : 0.0
    attrs = " x=\"$(fmt(x))\" y=\"$(fmt(y + dy))\" font-size=\"$(fmt(size))\"" *
        (anchor === :start ? "" : " text-anchor=\"$anchor\"") *
        (weight == 400 ? "" : " font-weight=\"$weight\"") * (italic ? " font-style=\"italic\"" : "") *
        (rotate == 0 ? "" : " transform=\"rotate($(fmt(-rotate)) $(fmt(x)) $(fmt(y)))\"")
    if halo
        print(ctx.io, "<text", attrs, pa(ctx, "fill" => :bg, "stroke" => :bg),
            " stroke-width=\"4\" stroke-linejoin=\"round\" aria-hidden=\"true\">", content, "</text>")
    end
    print(ctx.io, "<text", attrs, pa(ctx, "fill" => color), ">", content, "</text>")
    return
end

# ---- marks --------------------------------------------------------------------------------

isunder(::Mark) = false
isunder(m::RectMark) = m.under
isunder(::HeatmapMark) = true
isunder(::MaskMark) = true

clips(m::Mark) = hasfield(typeof(m), :clip) ? getfield(m, :clip) : true
clips(::NoteMark) = false
clips(::AnnotationMark) = false
clips(::RefLineMark) = true
clips(::ErrorBarsMark) = false

draw!(ctx::Ctx, ::Union{Plan, Nothing}, ::Mark) = nothing

function draw!(ctx::Ctx, pl::Plan, m::LineMark)
    d = pathd(pl.sx.(m.x), pl.sy.(m.y))
    isempty(d) && return
    print(ctx.io, "<path d=\"", d, "\" fill=\"none\"", pa(ctx, "stroke" => m.color), " stroke-width=\"", fmt(m.width),
        "\" stroke-linejoin=\"round\" stroke-linecap=\"round\"", dasha(m.dash), opa("stroke-opacity", m.opacity))
    tip = tipel(ctx, m.tip)
    print(ctx.io, isempty(tip) ? "/>" : ">$tip</path>")
end

function draw!(ctx::Ctx, pl::Plan, m::BandMark)
    io = IOBuffer()
    ok = [isfinite(m.x[i]) && isfinite(m.lo[i]) && isfinite(m.hi[i]) for i in eachindex(m.x)]
    i = 1
    while i <= length(ok)
        if !ok[i]
            i += 1
            continue
        end
        j = i
        while j < length(ok) && ok[j + 1]
            j += 1
        end
        r = i:j
        print(io, pathd(vcat(pl.sx.(m.x[r]), reverse(pl.sx.(m.x[r]))), vcat(pl.sy.(m.hi[r]), reverse(pl.sy.(m.lo[r]))); close = true))
        i = j + 1
    end
    d = String(take!(io))
    isempty(d) || print(ctx.io, "<path d=\"", d, "\"", pa(ctx, "fill" => m.color), opa("fill-opacity", m.opacity), "/>")
end

function marker_el(marker, x, y, r)
    marker === :circle && return "<circle cx=\"$(fmt(x))\" cy=\"$(fmt(y))\" r=\"$(fmt(r))\"/>"
    if marker === :square
        a = 0.89r
        return "<rect x=\"$(fmt(x - a))\" y=\"$(fmt(y - a))\" width=\"$(fmt(2a))\" height=\"$(fmt(2a))\"/>"
    elseif marker === :diamond
        a = 1.25r
        return "<path d=\"M$(fmt(x)),$(fmt(y - a))L$(fmt(x + a)),$(fmt(y))L$(fmt(x)),$(fmt(y + a))L$(fmt(x - a)),$(fmt(y))Z\"/>"
    else
        a = 1.3r
        return "<path d=\"M$(fmt(x)),$(fmt(y - a))L$(fmt(x + 0.866a)),$(fmt(y + 0.5a))L$(fmt(x - 0.866a)),$(fmt(y + 0.5a))Z\"/>"
    end
end

function draw!(ctx::Ctx, pl::Plan, m::PointsMark)
    style = m.open ? pa(ctx, "fill" => :bg, "stroke" => m.color) * " stroke-width=\"1.6\"" :
        m.ring ? pa(ctx, "fill" => m.color, "stroke" => :bg) * " stroke-width=\"1.5\"" : pa(ctx, "fill" => m.color)
    print(ctx.io, "<g", style, opa("opacity", m.opacity), ">")
    for i in eachindex(m.x)
        x, y = pl.sx(m.x[i]), pl.sy(m.y[i])
        (isfinite(x) && isfinite(y)) || continue
        print(ctx.io, marker_el(m.marker, x, y, m.size))
        if ctx.mode === :web && !isempty(m.tips)
            print(ctx.hits, "<circle cx=\"", fmt(x), "\" cy=\"", fmt(y), "\" r=\"", fmt(max(9, m.size + 5)),
                "\" fill=\"#000\" fill-opacity=\"0\" data-tip=\"", xmlesc(plaintext(m.tips[i])), "\"><title>",
                xmlesc(plaintext(m.tips[i])), "</title></circle>")
        end
    end
    print(ctx.io, "</g>")
end

function draw!(ctx::Ctx, pl::Plan, m::BarsMark)
    print(ctx.io, "<g", pa(ctx, "fill" => m.color), opa("fill-opacity", m.opacity), ">")
    for i in eachindex(m.v)
        isfinite(m.v[i]) || continue
        pos, val = m.horizontal ? (pl.sy, pl.sx) : (pl.sx, pl.sy)
        a, b = minmax(pos(m.lo[i]), pos(m.hi[i]))
        a, b = a + m.gap / 2, b - m.gap / 2
        b - a < 0.5 && (b = a + 0.5)
        base, top = val(m.baseline), val(m.v[i])
        (isfinite(base) && isfinite(top)) || continue
        r = min(m.radius, (b - a) / 2, abs(top - base))
        s = top < base ? 1 : -1          # direction from the data end towards the baseline
        if m.horizontal
            sx = top > base ? -1 : 1
            d = "M$(fmt(base)),$(fmt(a))H$(fmt(top + sx * r))Q$(fmt(top)),$(fmt(a)) $(fmt(top)),$(fmt(a + r))" *
                "V$(fmt(b - r))Q$(fmt(top)),$(fmt(b)) $(fmt(top + sx * r)),$(fmt(b))H$(fmt(base))Z"
        else
            d = "M$(fmt(a)),$(fmt(base))V$(fmt(top + s * r))Q$(fmt(a)),$(fmt(top)) $(fmt(a + r)),$(fmt(top))" *
                "H$(fmt(b - r))Q$(fmt(b)),$(fmt(top)) $(fmt(b)),$(fmt(top + s * r))V$(fmt(base))Z"
        end
        tip = isempty(m.tips) ? "" : tipel(ctx, m.tips[i])
        print(ctx.io, "<path d=\"", d, "\"", isempty(tip) ? "/>" : ">$tip</path>")
    end
    print(ctx.io, "</g>")
end

function draw!(ctx::Ctx, pl::Plan, m::ErrorBarsMark)
    io = IOBuffer()
    c = m.cap
    for i in eachindex(m.x)
        if m.horizontal
            y, a, b = pl.sy(m.x[i]), pl.sx(m.lo[i]), pl.sx(m.hi[i])
            (isfinite(y) && isfinite(a) && isfinite(b)) || continue
            print(io, "M", fmt(a), ",", fmt(y), "H", fmt(b))
            c > 0 && print(io, "M", fmt(a), ",", fmt(y - c), "v", fmt(2c), "M", fmt(b), ",", fmt(y - c), "v", fmt(2c))
        else
            x, a, b = pl.sx(m.x[i]), pl.sy(m.lo[i]), pl.sy(m.hi[i])
            (isfinite(x) && isfinite(a) && isfinite(b)) || continue
            print(io, "M", fmt(x), ",", fmt(a), "V", fmt(b))
            c > 0 && print(io, "M", fmt(x - c), ",", fmt(a), "h", fmt(2c), "M", fmt(x - c), ",", fmt(b), "h", fmt(2c))
        end
    end
    print(ctx.io, "<path d=\"", String(take!(io)), "\" fill=\"none\"", pa(ctx, "stroke" => m.color),
        " stroke-width=\"", fmt(m.width), "\" stroke-linecap=\"round\"/>")
end

function draw!(ctx::Ctx, pl::Plan, m::SegmentsMark)
    io = IOBuffer()
    for i in eachindex(m.x1)
        a, b, c, d = pl.sx(m.x1[i]), pl.sy(m.y1[i]), pl.sx(m.x2[i]), pl.sy(m.y2[i])
        all(isfinite, (a, b, c, d)) && print(io, "M", fmt(a), ",", fmt(b), "L", fmt(c), ",", fmt(d))
    end
    print(ctx.io, "<path d=\"", String(take!(io)), "\" fill=\"none\"", pa(ctx, "stroke" => m.color), " stroke-width=\"",
        fmt(m.width), "\" stroke-linecap=\"round\"", dasha(m.dash), opa("stroke-opacity", m.opacity), "/>")
end

function shape_style(ctx, fill, fillopacity, stroke, width, dash)
    return pa(ctx, "fill" => fill, "stroke" => stroke) * opa("fill-opacity", fillopacity) *
        (stroke === nothing ? "" : " stroke-width=\"$(fmt(width))\"" * dasha(dash))
end

function bounded(s::Scale, v, lo, hi)
    v == -Inf && return lo
    v == Inf && return hi
    return s(v)
end

function draw!(ctx::Ctx, pl::Plan, m::RectMark)
    x0, y0, w, h = pl.box
    xa, xb = bounded(pl.sx, m.x1, x0, x0 + w), bounded(pl.sx, m.x2, x0, x0 + w)
    ya, yb = bounded(pl.sy, m.y1, y0 + h, y0), bounded(pl.sy, m.y2, y0 + h, y0)
    all(isfinite, (xa, xb, ya, yb)) || return
    a, b = minmax(xa, xb)
    c, d = minmax(ya, yb)
    tip = tipel(ctx, m.tip)
    print(ctx.io, "<rect x=\"", fmt(a), "\" y=\"", fmt(c), "\" width=\"", fmt(b - a), "\" height=\"", fmt(d - c), "\"",
        m.radius > 0 ? " rx=\"$(fmt(m.radius))\"" : "", shape_style(ctx, m.fill, m.fillopacity, m.stroke, m.width, m.dash),
        isempty(tip) ? "/>" : ">$tip</rect>")
end

function draw!(ctx::Ctx, pl::Plan, m::PolygonMark)
    d = pathd(pl.sx.(m.x), pl.sy.(m.y); close = true)
    isempty(d) || print(ctx.io, "<path d=\"", d, "\" fill-rule=\"evenodd\"", shape_style(ctx, m.fill, m.fillopacity, m.stroke, m.width, m.dash),
        m.stroke === nothing ? "" : " stroke-linejoin=\"round\"", "/>")
end

function draw!(ctx::Ctx, pl::Plan, m::CircleMark)
    x, y = pl.sx(m.x), pl.sy(m.y)
    (isfinite(x) && isfinite(y)) || return
    tip = tipel(ctx, m.tip)
    print(ctx.io, "<circle cx=\"", fmt(x), "\" cy=\"", fmt(y), "\" r=\"", fmt(m.r), "\"",
        shape_style(ctx, m.fill, m.fillopacity, m.stroke, m.width, m.dash), isempty(tip) ? "/>" : ">$tip</circle>")
end

function draw!(ctx::Ctx, pl::Plan, m::EllipseMark)
    x, y = pl.sx(m.x), pl.sy(m.y)
    rx, ry = abs(pl.sx(m.x + m.a) - x), abs(pl.sy(m.y + m.b) - y)
    all(isfinite, (x, y, rx, ry)) || return
    print(ctx.io, "<ellipse cx=\"", fmt(x), "\" cy=\"", fmt(y), "\" rx=\"", fmt(rx), "\" ry=\"", fmt(ry), "\"",
        m.rotate == 0 ? "" : " transform=\"rotate($(fmt(-m.rotate)) $(fmt(x)) $(fmt(y)))\"",
        shape_style(ctx, m.fill, m.fillopacity, m.stroke, m.width, m.dash), "/>")
end

function arrow_el!(ctx::Ctx, a1, b1, a2, b2, color, width, head, dash)
    L = hypot(a2 - a1, b2 - b1)
    (isfinite(L) && L > 1.0e-6) || return
    ux, uy = (a2 - a1) / L, (b2 - b1) / L
    h = min(head, 0.6L)
    bx, by = a2 - h * ux, b2 - h * uy
    w = 0.42h
    print(ctx.io, "<path d=\"M", fmt(a1), ",", fmt(b1), "L", fmt(bx + 0.3h * ux), ",", fmt(by + 0.3h * uy), "\" fill=\"none\"",
        pa(ctx, "stroke" => color), " stroke-width=\"", fmt(width), "\" stroke-linecap=\"round\"", dasha(dash), "/>")
    print(ctx.io, "<path d=\"M", fmt(a2), ",", fmt(b2), "L", fmt(bx - w * uy), ",", fmt(by + w * ux), "L", fmt(bx + w * uy), ",",
        fmt(by - w * ux), "Z\"", pa(ctx, "fill" => color), "/>")
end

draw!(ctx::Ctx, pl::Plan, m::ArrowMark) =
    arrow_el!(ctx, pl.sx(m.x1), pl.sy(m.y1), pl.sx(m.x2), pl.sy(m.y2), m.color, m.width, m.head, m.dash)

function draw!(ctx::Ctx, pl::Plan, m::RefLineMark)
    x0, y0, w, h = pl.box
    if m.horizontal
        y = pl.sy(m.v)
        isfinite(y) || return
        print(ctx.io, "<path d=\"M", fmt(x0), ",", fmt(y), "H", fmt(x0 + w), "\"", pa(ctx, "stroke" => m.color),
            " stroke-width=\"", fmt(m.width), "\"", dasha(m.dash), "/>")
        left = m.labelpos === :left
        text!(ctx, left ? x0 + 2 : x0 + w - 2, y - 5, m.label; size = ctx.t.note, color = :ink2,
            anchor = left ? :start : :end, valign = :baseline, halo = true)
    else
        x = pl.sx(m.v)
        isfinite(x) || return
        print(ctx.io, "<path d=\"M", fmt(x), ",", fmt(y0), "V", fmt(y0 + h), "\"", pa(ctx, "stroke" => m.color),
            " stroke-width=\"", fmt(m.width), "\"", dasha(m.dash), "/>")
        bottom = m.labelpos === :bottom
        text!(ctx, x + 5, bottom ? y0 + h - 8 : y0 + 10, m.label; size = ctx.t.note, color = :ink2, halo = true)
    end
end

function draw!(ctx::Ctx, pl::Union{Plan, Nothing}, m::NoteMark)
    x, y = m.pixels ? (m.x, m.y) : (pl.sx(m.x), pl.sy(m.y))
    (isfinite(x) && isfinite(y)) || return
    text!(ctx, x + m.dx, y + m.dy, m.text; size = size_of(ctx.t, m.size), color = m.color, anchor = m.anchor,
        valign = m.valign, weight = m.bold ? 600 : 400, italic = m.italic, halo = m.halo, rotate = m.rotate)
end

function draw!(ctx::Ctx, pl::Plan, m::AnnotationMark)
    x, y = pl.sx(m.x), pl.sy(m.y)
    (isfinite(x) && isfinite(y)) || return
    tx, ty = x + m.dx, y + m.dy
    L = hypot(m.dx, m.dy)
    if L > 8
        ux, uy = m.dx / L, m.dy / L
        print(ctx.io, "<path d=\"M", fmt(x + 3ux), ",", fmt(y + 3uy), "L", fmt(tx - 3ux), ",", fmt(ty - 3uy), "\"",
            pa(ctx, "stroke" => :ink2), " stroke-width=\"0.8\"/>")
    end
    m.dot && print(ctx.io, "<circle cx=\"", fmt(x), "\" cy=\"", fmt(y), "\" r=\"2.5\"", pa(ctx, "fill" => m.color), "/>")
    text!(ctx, tx + (m.dx >= 0 ? 2 : -2), ty, m.text; size = ctx.t.note, color = m.color, anchor = m.dx >= 0 ? :start : :end,
        weight = m.bold ? 600 : 400, halo = m.halo)
end

function draw!(ctx::Ctx, pl::Plan, m::ContourMark)
    nl = length(m.levels)
    for (k, (X, Y)) in enumerate(m.lines)
        d = pathd(pl.sx.(X), pl.sy.(Y))
        isempty(d) && continue
        strong = m.strong[k]
        op = m.fade && !strong ? 0.85 - 0.6 * (k - 1) / max(nl - 1, 1) : 1.0
        print(ctx.io, "<path d=\"", d, "\" fill=\"none\"", pa(ctx, "stroke" => strong ? :ink : m.color), " stroke-width=\"",
            fmt(strong ? max(m.width, 1.2) : m.width), "\" stroke-linejoin=\"round\"", opa("stroke-opacity", op), "/>")
    end
end

function cells_path(ex, ey, cells)
    io = IOBuffer()
    for (i, j) in cells
        a, b = minmax(ex[i], ex[i + 1])
        c, d = minmax(ey[j], ey[j + 1])
        print(io, "M", fmt(a), ",", fmt(c), "H", fmt(b), "V", fmt(d), "H", fmt(a), "Z")
    end
    return String(take!(io))
end

function draw!(ctx::Ctx, pl::Plan, m::HeatmapMark)
    ex, ey = pl.sx.(cell_edges(m.x)), pl.sy.(cell_edges(m.y))
    span = m.hi - m.lo
    bins = [Tuple{Int, Int}[] for _ in 1:m.steps]
    for j in axes(m.Z, 2), i in axes(m.Z, 1)
        z = m.Z[i, j]
        isfinite(z) || continue
        f = span > 0 ? clamp((z - m.lo) / span, 0, 1) : 0.5
        push!(bins[clamp(1 + floor(Int, f * m.steps), 1, m.steps)], (i, j))
    end
    for (b, cells) in enumerate(bins)
        isempty(cells) && continue
        print(ctx.io, "<path d=\"", cells_path(ex, ey, cells), "\"", pa(ctx, "fill" => m.color),
            opa("fill-opacity", 0.06 + 0.84 * (b - 0.5) / m.steps), "/>")
    end
end

function draw!(ctx::Ctx, pl::Plan, m::MaskMark)
    ex, ey = pl.sx.(cell_edges(m.x)), pl.sy.(cell_edges(m.y))
    io = IOBuffer()
    for j in axes(m.M, 2)
        i = 1
        while i <= size(m.M, 1)
            if m.M[i, j]
                i2 = i
                while i2 < size(m.M, 1) && m.M[i2 + 1, j]
                    i2 += 1
                end
                a, b = minmax(ex[i], ex[i2 + 1])
                c, d = minmax(ey[j], ey[j + 1])
                print(io, "M", fmt(a), ",", fmt(c), "H", fmt(b), "V", fmt(d), "H", fmt(a), "Z")
                i = i2 + 1
            else
                i += 1
            end
        end
    end
    d = String(take!(io))
    isempty(d) || print(ctx.io, "<path d=\"", d, "\"", pa(ctx, "fill" => m.color), opa("fill-opacity", m.opacity), "/>")
end

# ---- guides -------------------------------------------------------------------------------

gridmode(p::Panel) = p.grid === :auto ? (p.style === :axes ? :y : :none) : p.grid

function draw_grid!(ctx::Ctx, pl::Plan)
    p = pl.p
    p.style === :none && return
    x0, y0, w, h = pl.box
    g = gridmode(p)
    io = IOBuffer()
    if g in (:y, :both)
        for v in pl.yt
            y = pl.sy(v)
            isfinite(y) && print(io, "M", fmt(x0), ",", fmt(y), "H", fmt(x0 + w))
        end
    end
    if g in (:x, :both)
        for v in pl.xt
            x = pl.sx(v)
            isfinite(x) && print(io, "M", fmt(x), ",", fmt(y0), "V", fmt(y0 + h))
        end
    end
    d = String(take!(io))
    isempty(d) || print(ctx.io, "<path d=\"", d, "\" fill=\"none\"", pa(ctx, "stroke" => :grid), " stroke-width=\"1\"/>")
end

function tick_group!(f, ctx::Ctx, anchor)
    print(ctx.io, "<g font-size=\"", fmt(ctx.t.tick), "\"", anchor === :start ? "" : " text-anchor=\"$anchor\"",
        pa(ctx, "fill" => :muted), ">")
    f()
    print(ctx.io, "</g>")
end

function draw_axes!(ctx::Ctx, pl::Plan)
    p = pl.p
    p.style === :none && return
    x0, y0, w, h = pl.box
    t = ctx.t
    frame = p.style === :frame
    if frame
        print(ctx.io, "<rect x=\"", fmt(x0), "\" y=\"", fmt(y0), "\" width=\"", fmt(w), "\" height=\"", fmt(h),
            "\" fill=\"none\"", pa(ctx, "stroke" => :ink), " stroke-width=\"1\"/>")
    else
        io = IOBuffer()
        print(io, "M", fmt(x0), ",", fmt(y0 + h), "H", fmt(x0 + w))
        for v in pl.xt
            x = pl.sx(v)
            isfinite(x) && print(io, "M", fmt(x), ",", fmt(y0 + h), "v4")
        end
        print(ctx.io, "<path d=\"", String(take!(io)), "\" fill=\"none\"", pa(ctx, "stroke" => :axis), " stroke-width=\"1\"/>")
    end
    ylab = frame ? y0 + h + 15 : y0 + h + 17
    if !isempty(pl.xt)
        tick_group!(ctx, :middle) do
            for (v, s) in zip(pl.xt, pl.xtl)
                x = pl.sx(v)
                isfinite(x) || continue
                print(ctx.io, "<text x=\"", fmt(x), "\" y=\"", fmt(ylab + 0.34t.tick), "\">", text_content(s, ctx.mode, t.tick), "</text>")
            end
        end
    end
    if !isempty(pl.yt)
        tick_group!(ctx, :end) do
            for (v, s) in zip(pl.yt, pl.ytl)
                y = pl.sy(v)
                isfinite(y) || continue
                print(ctx.io, "<text x=\"", fmt(x0 - (frame ? 5 : 6)), "\" y=\"", fmt(y + 0.34t.tick), "\">",
                    text_content(s, ctx.mode, t.tick), "</text>")
            end
        end
    end
    text!(ctx, x0 + w, isempty(pl.xt) ? y0 + h + 18 : ylab + 17, p.xlabel; size = t.label, color = :ink2, anchor = :end,
        valign = :baseline)
    text!(ctx, frame ? x0 : x0 - 6, y0 - (frame ? 8 : 10), p.ylabel; size = t.label, color = :ink2, valign = :baseline)
end

function swatch!(ctx::Ctx, e, x, y)
    k, c = e.kind, e.color
    op = opa("stroke-opacity", e.opacity)
    if k in (:line, :dash, :linedot)
        print(ctx.io, "<path d=\"M", fmt(x), ",", fmt(y), "h", k === :linedot ? "22" : "20", "\"", pa(ctx, "stroke" => c),
            " stroke-width=\"2\" stroke-linecap=\"round\"", k === :dash ? " stroke-dasharray=\"4 3\"" : "", op, "/>")
        k === :linedot && print(ctx.io, "<circle cx=\"", fmt(x + 11), "\" cy=\"", fmt(y), "\" r=\"3.5\"",
            pa(ctx, "fill" => c, "stroke" => :bg), " stroke-width=\"1.5\"/>")
    elseif k === :dot
        print(ctx.io, "<circle cx=\"", fmt(x + 5), "\" cy=\"", fmt(y), "\" r=\"4.5\"", pa(ctx, "fill" => c, "stroke" => :bg),
            " stroke-width=\"1.5\"", opa("opacity", e.opacity), "/>")
    elseif k === :opendot
        print(ctx.io, "<circle cx=\"", fmt(x + 5), "\" cy=\"", fmt(y), "\" r=\"4\"", pa(ctx, "fill" => :bg, "stroke" => c),
            " stroke-width=\"1.6\"/>")
    elseif k === :box
        print(ctx.io, "<rect x=\"", fmt(x), "\" y=\"", fmt(y - 6), "\" width=\"14\" height=\"12\" rx=\"2\"", pa(ctx, "fill" => c),
            opa("fill-opacity", e.opacity), "/>")
    elseif k === :arrow
        arrow_el!(ctx, x, y, x + 19, y, c, 2.0, 7.0, nothing)
    else
        print(ctx.io, "<circle cx=\"", fmt(x + 6), "\" cy=\"", fmt(y), "\" r=\"5.5\" fill=\"none\"", pa(ctx, "stroke" => c),
            " stroke-width=\"1.2\"/>")
    end
end

function draw_entries!(ctx::Ctx, entries, rows, x, y; column::Bool = false)
    size = ctx.t.legend
    for (r, row) in enumerate(rows)
        cx = x
        cy = y + (r - 1) * ROW
        for i in row
            e = entries[i]
            swatch!(ctx, e, cx, cy)
            sw = swatch_width(e.kind)
            text!(ctx, cx + sw + 6, cy, e.label; size, color = :ink2)
            cx += entry_width(e, size) + ENTRY_GAP
        end
    end
end

function draw_legend!(ctx::Ctx, pl::Plan)
    pos = pl.legend
    pos === :none && return
    p, t = pl.p, ctx.t
    x0, y0, w, h = pl.box
    xl = p.style === :axes ? x0 - 6 : x0
    if pos === :top
        y = pl.slot[2] + (isempty(p.title) ? 0 : t.title + 9) + (isempty(p.subtitle) ? 0 : t.subtitle + 7) + ROW / 2
        draw_entries!(ctx, pl.entries, pl.rows, xl, y)
    elseif pos === :bottom
        y = y0 + h + (isempty(pl.xt) ? 8 : 24) + (isempty(p.xlabel) ? 0 : 16) + 4 + ROW / 2
        draw_entries!(ctx, pl.entries, pl.rows, xl, y)
    else
        lw = maximum(e -> entry_width(e, t.legend), pl.entries)
        lh = length(pl.entries) * ROW
        if pos === :right
            x, y = pl.slot[1] + pl.slot[3] - lw - 8, y0 + ROW / 2
        else
            c = p.legend_corner
            x = c in (:topleft, :bottomleft) ? x0 + 10 : x0 + w - lw - 10
            y = c in (:topleft, :topright) ? y0 + 8 + ROW / 2 : y0 + h - lh - 8 + ROW / 2
            print(ctx.io, "<rect x=\"", fmt(x - 6), "\" y=\"", fmt(y - ROW / 2 - 4), "\" width=\"", fmt(lw + 12), "\" height=\"",
                fmt(lh + 8), "\" rx=\"3\"", pa(ctx, "fill" => :bg), " fill-opacity=\"0.88\"/>")
        end
        draw_entries!(ctx, pl.entries, pl.rows, x, y)
    end
end

function draw_titles!(ctx::Ctx, pl::Plan)
    p, t = pl.p, ctx.t
    x = p.style === :axes ? pl.box[1] - 6 : pl.box[1]
    y = pl.slot[2]
    if !isempty(p.title)
        text!(ctx, x, y + t.title, p.title; size = t.title, weight = 700, valign = :baseline)
        y += t.title + 9
    end
    isempty(p.subtitle) || text!(ctx, x, y + t.subtitle, p.subtitle; size = t.subtitle, color = :ink2, valign = :baseline)
end

function draw_endlabels!(ctx::Ctx, pl::Plan)
    labels = Tuple{Float64, Float64, String}[]
    for m in pl.p.marks
        (m isa LineMark && m.endlabel && !isempty(m.label)) || continue
        xs, ys = pl.sx.(m.x), pl.sy.(m.y)
        k = findlast(i -> isfinite(xs[i]) && isfinite(ys[i]), eachindex(xs))
        k === nothing || push!(labels, (ys[k], xs[k], m.label))
    end
    isempty(labels) && return
    sort!(labels)
    ys = first.(labels)
    gap = ctx.t.note + 2
    for i in 2:length(ys)                 # push apart downwards ...
        ys[i] = max(ys[i], ys[i - 1] + gap)
    end
    bottom = pl.box[2] + pl.box[4] - 2    # ... and back up from the bottom of the plot
    ys[end] = min(ys[end], bottom)
    for i in (length(ys) - 1):-1:1
        ys[i] = min(ys[i], ys[i + 1] - gap)
    end
    for (i, (_, x, s)) in enumerate(labels)
        text!(ctx, x + 6, ys[i], s; size = ctx.t.note, weight = 600, halo = true)
    end
end

function draw_panel!(ctx::Ctx, pl::Plan, k::Int)
    clipattr = " clip-path=\"url(#$(ctx.id)-c$k)\""
    function marks!(sel)
        open = false
        for m in pl.p.marks
            sel(m) || continue
            c = clips(m)
            if c && !open
                print(ctx.io, "<g", clipattr, ">")
                open = true
            elseif !c && open
                print(ctx.io, "</g>")
                open = false
            end
            draw!(ctx, pl, m)
        end
        open && print(ctx.io, "</g>")
    end
    marks!(isunder)
    draw_grid!(ctx, pl)
    marks!(!isunder)
    draw_axes!(ctx, pl)
    draw_endlabels!(ctx, pl)
    draw_titles!(ctx, pl)
    draw_legend!(ctx, pl)
end

function draw_figure_header!(ctx::Ctx, fig::Fig, lay::Layout)
    t = ctx.t
    pad = fig.padding
    y = pad
    if !isempty(fig.title)
        text!(ctx, pad, y + t.figtitle * 0.8, fig.title; size = t.figtitle, weight = 700, valign = :baseline)
        y += t.figtitle + 8
    end
    if !isempty(fig.subtitle)
        text!(ctx, pad, y + t.figsubtitle * 0.8, fig.subtitle; size = t.figsubtitle, color = :ink2, valign = :baseline)
        y += t.figsubtitle + 8
    end
    if !isempty(lay.figentries)
        if fig.legend === :top
            draw_entries!(ctx, lay.figentries, lay.figrows, pad, y + ROW / 2)
        else
            yb = fig.height - pad - (isempty(fig.credit) ? 0 : t.credit + 10) - length(lay.figrows) * ROW + ROW / 2
            draw_entries!(ctx, lay.figentries, lay.figrows, pad, yb)
        end
    end
    isempty(fig.credit) || text!(ctx, pad, fig.height - pad, fig.credit; size = t.credit, color = :muted, valign = :bottom)
end

# ---- entry points -------------------------------------------------------------------------

function themes(theme, mode)
    if theme isa Theme
        return theme, nothing
    elseif theme isa NamedTuple
        return theme.light, theme.dark
    elseif theme === :auto
        return mode === :web ? (LIGHT, DARK) : (LIGHT, nothing)
    elseif theme === :light
        return LIGHT, nothing
    elseif theme === :dark
        return DARK, nothing
    end
    throw(ArgumentError("theme must be :auto, :light, :dark, a Theme or (light = Theme, dark = Theme)"))
end

"""
    svg(fig; mode = :web, theme = :auto, background, embed_style = true, font = nothing,
        responsive) -> String

The figure as an SVG document.

- `mode = :web`: colors are CSS variables, so that the figure follows the reader's light or
  dark mode (with `theme = :auto`) or a page's `data-theme`; marks with tips get native
  tooltips. `embed_style = false` leaves out the style block for pages that include
  [`stylesheet`](@ref) once themselves.
- `mode = :static`: every color, halo and sub- or superscript is written out, as needed by
  PowerPoint, Keynote, Inkscape and LaTeX; `theme = :light` (default) or `:dark`.

`theme` can also be a [`Theme`](@ref) or a named tuple `(light = ..., dark = ...)`.
`background` (default: on for the web, off for static files, so that slides show through)
fills the figure with the theme's background color. `font` overrides the theme's font
family (static files default to Arial). `responsive` lets the figure shrink with its
container on web pages.
"""
function svg(fig::Fig; mode::Symbol = :web, theme = :auto, background::Bool = mode === :web, embed_style::Bool = true,
        font = nothing, responsive::Bool = mode === :web)
    mode in (:web, :static) || throw(ArgumentError("mode must be :web or :static"))
    light, dark = themes(theme, mode)
    t = mode === :static && theme === :auto ? LIGHT : light
    fontfamily = font !== nothing ? string(font) : mode === :static ? "Arial, Helvetica, sans-serif" : t.font
    t = Theme(t; font = fontfamily)
    lay = layout(fig, t)
    ctx = Ctx(IOBuffer(), mode, t, IDTOKEN, IOBuffer())
    io = ctx.io
    W, H = fmt(fig.width), fmt(fig.height)
    label = isempty(fig.label) ? (isempty(fig.title) ? "Figure" : plaintext(fig.title)) : fig.label
    print(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $W $H\" width=\"$W\" height=\"$H\" role=\"img\" aria-label=\"",
        xmlesc(label), "\" font-family=\"", xmlesc(fontfamily), "\"")
    mode === :web && print(io, " class=\"hl-root\"")
    responsive && print(io, " style=\"max-width:100%;height:auto\"")
    print(io, ">")
    if mode === :web && embed_style
        css = dark === nothing ? ".hl-root{$(cssvars(light))}" : stylesheet(; light, dark)
        print(io, "<style>", css, "</style>")
    end
    print(io, "<defs>")
    for (k, pl) in enumerate(lay.plans)
        x0, y0, w, h = pl.box
        print(io, "<clipPath id=\"", IDTOKEN, "-c", k, "\"><rect x=\"", fmt(x0), "\" y=\"", fmt(y0), "\" width=\"", fmt(w),
            "\" height=\"", fmt(h), "\"/></clipPath>")
    end
    print(io, "</defs>")
    background && print(io, "<rect width=\"100%\" height=\"100%\"", pa(ctx, "fill" => :bg), "/>")
    for (k, pl) in enumerate(lay.plans)
        draw_panel!(ctx, pl, k)
    end
    draw_figure_header!(ctx, fig, lay)
    for m in fig.marks
        draw!(ctx, nothing, m)
    end
    print(io, String(take!(ctx.hits)), "</svg>")
    out = String(take!(io))
    id = fig.id !== nothing ? fig.id : "hl" * string(hash(out), base = 36)[1:min(8, end)]
    return replace(out, IDTOKEN => id)
end

"""
    savesvg(path, fig; kwargs...) -> path

Write the figure to `path`; the keywords are those of [`svg`](@ref). For slides use
`mode = :static` (and `theme = :dark` for dark slides).
"""
function savesvg(path::AbstractString, fig::Fig; kwargs...)
    s = svg(fig; kwargs...)
    open(path, "w") do io
        get(kwargs, :mode, :web) === :static && println(io, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        print(io, s)
    end
    return path
end

Base.show(io::IO, ::MIME"image/svg+xml", fig::Fig) = print(io, svg(fig))
# notebooks and documentation sites inline the SVG (which enables tooltips and page styles)
Base.show(io::IO, ::MIME"text/html", fig::Fig) = print(io, svg(fig))

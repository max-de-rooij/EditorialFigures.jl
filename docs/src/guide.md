# Guide

```@setup guide
using EditorialFigures
```

## Figures and panels

A [`Fig`](@ref) is a canvas of a given size in pixels. It holds **panels**, the plot
areas with their own axes, and each panel holds **marks**. Nothing is drawn until the
figure is rendered, so the order in which you set things up does not matter.

```@example guide
fig = Fig(680, 300; title = "Two panels", subtitle = "Side by side in a 1 × 2 layout",
    credit = "Source: simulated", layout = (1, 2))
a = panel!(fig; title = "Growth", xlabel = "day")
b = panel!(fig; title = "Decay", xlabel = "day")
line!(a, 0:10, exp.(0.2 .* (0:10)))
line!(b, 0:10, exp.(-0.3 .* (0:10)); color = 2)
fig
```

There are three ways to place a panel:

| Call | Placement |
|:-----|:----------|
| `panel!(fig)` | the next free cell of the figure's `layout` (row by row) |
| `panel!(fig, row, col; rowspan, colspan)` | a given cell, possibly spanning several |
| `panel!(fig, x, y, width, height)` | an explicit plot area in pixels |

[`grid!`](@ref) fills a whole layout at once and returns a matrix of panels that share
their settings. Panels in a row share their top and bottom margins and panels in a column
their left and right margins, so axes line up even when one panel has wider tick labels:

```@example guide
fig = Fig(680, 420; title = "A 2 × 2 grid")
axs = grid!(fig, 2, 2; xlabel = "x")
for (k, ax) in enumerate(axs)
    line!(ax, x -> x^k, 0, 2; color = k)
    title!(ax, "x^{$k}")
end
fig
```

Panel settings are keyword arguments of `panel!` and `grid!` and fields of the panel, so
they can also be changed later: `ax.ylabel = "cost"`, or with [`axes!`](@ref) and
[`frame!`](@ref), which also switch the panel style.

**Panel styles.** `style = :axes` (the default) draws horizontal gridlines, a baseline
and tick labels in a muted ink, with the y title set horizontally above the axis.
`style = :frame` draws a thin box, the natural choice for maps of a parameter space, where
the frame is the boundary of the region shown. `style = :none` draws no axes at all, for
diagrams.

## Scales, limits and ticks

By default the limits span the data and are rounded out to the next tick (`nice = true`;
`:frame` panels fit the data exactly). Bars and areas include their baseline. Reference
lines, spans and the points of callouts count as data; notes do not.

| Setting | Effect |
|:--------|:-------|
| `xlim = (0, 10)` | fixed limits; `(0, nothing)` fixes only the lower end |
| `ylim = (10, 0)` | a reversed axis |
| `xscale = :log`, `yscale = :log` | logarithmic axes, with decades as ticks |
| `xticks = [0, 5, 10]` | ticks at given values |
| `xticks = (1:3, ["a", "b", "c"])` | ticks with given labels, for categories |
| `xticks = nothing` | no ticks |
| `xformat = v -> "$(v) %"` | a function from tick value to label |
| `grid = :x`, `:y`, `:both`, `:none` | which gridlines to draw |
| `aspect = :equal` | the same scale on both axes |

Tick labels use as few decimals as the step needs, thousands separators, a real minus
sign, and powers of ten for very large or small values.

```@example guide
fig = Fig(680, 280; layout = (1, 2))
a = panel!(fig; yscale = :log, title = "Logarithmic y", xlabel = "iteration")
line!(a, 1:50, 10.0 .^ (-0.25 .* (1:50)))
b = panel!(fig; title = "Categories", xticks = (1:4, ["PSO", "TR", "BFGS", "NM"]), ylabel = "wins")
bars!(b, 1:4, [12, 7, 3, 1]; color = 2)
fig
```

## Marks

| Function | Draws |
|:---------|:------|
| [`line!`](@ref) | a line through points, or a function on an interval |
| [`band!`](@ref), [`area!`](@ref) | a shaded band between two curves, or down to a baseline |
| [`points!`](@ref) | dots (circles, squares, diamonds, triangles), filled or open |
| [`bars!`](@ref), [`hist!`](@ref) | bars with rounded data ends; histograms |
| [`errorbars!`](@ref) | intervals with caps |
| [`hline!`](@ref), [`vline!`](@ref) | labelled reference lines |
| [`vspan!`](@ref), [`hspan!`](@ref) | shaded ranges, beneath the gridlines |
| [`contours!`](@ref), [`heatmap!`](@ref), [`mask!`](@ref) | fields on a grid |
| [`rect!`](@ref), [`polygon!`](@ref), [`circle!`](@ref), [`ellipse!`](@ref), [`segments!`](@ref), [`arrow!`](@ref) | shapes |
| [`note!`](@ref), [`annotate!`](@ref) | text and callouts |

Marks are drawn in the order they are added (spans, heatmaps and masks go beneath the
gridlines). Lines and areas are clipped to the panel; points, error bars, arrows and text
are not, so markers at the edge stay whole. `NaN`, `nothing` and `missing` break lines and
bands.

Common keywords: `color` (see [Colors](@ref colors)), `width` (pixels or `:hair`, `:thin`,
`:normal`, `:bold`), `dash` (`true`, `:dot` or a dash array), `opacity`, `label` (the
legend entry) and `tip` or `tips` (tooltips in web figures).

## Text

Every string accepts a small markup: `x_{i}` for a subscript, `10^{-5}` for a superscript
and `**bold**` for bold; `\_`, `\^` and `\*` give the characters themselves.

- [`note!`](@ref) places text at a data point (or, on a figure, at a pixel position), with
  `anchor`, `valign`, an offset `dx`, `dy` in pixels and an optional **halo** that keeps it
  readable on top of lines.
- [`annotate!`](@ref) is a callout: text set off from a point with a thin leader line.
- `line!(...; label, endlabel = true)` writes the label at the end of the line, which
  usually reads better than a legend. Overlapping end labels are moved apart.
- Reference lines carry their own `label`.

```@example guide
fig = Fig(560, 300)
ax = panel!(fig; xlabel = "θ_{1}", ylabel = "loss L(θ)")
line!(ax, x -> (x - 1)^2 + 0.5, -1, 3; label = "L", endlabel = true)
annotate!(ax, 1, 0.5, "minimum at θ_{1} = 1"; dx = 20, dy = -40, dot = true)
note!(ax, -1, 4, "**steep** on the left"; dx = 6, color = :ink2)
fig
```

## Legends

A panel shows a legend when two or more of its marks have a `label` (`legend = :auto`);
lines labelled at their end (`endlabel = true`) do not count, since they need no legend. A
line and points with the same label share one entry. Choose a position with `legend` (or
[`legend!`](@ref)): `:top` (a row above the plot, the default), `:bottom`, `:right`,
`:inside` with a `legend_corner`, or `:none`. `Fig(...; legend = :top)` gathers the labels
of all panels into one legend for the figure, and `legend!(..., items = ...)` writes the
entries by hand.

```@example guide
fig = Fig(560, 300)
ax = panel!(fig; legend = :inside, legend_corner = :topleft, xlabel = "x")
x = 0:0.5:6
band!(ax, x, sin.(x) .- 0.3, sin.(x) .+ 0.3; label = "interval")
line!(ax, x, sin.(x); label = "mean")
points!(ax, x, sin.(x) .+ 0.1 .* cos.(3x); label = "data", color = :ink)
fig
```

## [Colors and themes](@id colors)

The `color` of a mark is one of:

- an **integer from 1 to 8**: a slot of the categorical palette. Slot 1 is the accent.
  Assign slots in a fixed order and keep a series on its slot across figures; with more
  than eight series, fold the rest into "other" or use small multiples.
- a **name**: `:ink`, `:ink2` and `:muted` (text and neutral lines), `:accent` and
  `:accent2` (slots 1 and 2), `:grid`, `:axis`, `:rule`, `:contour`, `:bg` and `:bgsoft`.
- any **CSS color** string, such as `"#7a5195"`; it is the same in light and dark mode.

Names and slots resolve to the theme when the figure is rendered, which is what lets one
figure appear in light and dark versions.

```@example guide
fig = Fig(680, 120; title = "The categorical palette")
ax = panel!(fig; style = :none, xlim = (0.5, 8.5), ylim = (0, 1))
for k in 1:8
    rect!(ax, k - 0.4, 0.2, k + 0.4, 0.8; fill = k, opacity = 1, radius = 3)
    note!(ax, k, 0.5, string(k); anchor = :middle, color = :bg, bold = true)
end
fig
```

A [`Theme`](@ref) holds the colors and type sizes. [`LIGHT`](@ref) and [`DARK`](@ref) are
built in; derive your own from them, for example a brand palette or a larger type size
for slides:

```julia
slides = Theme(LIGHT; tick = 16, label = 17, note = 17, legend = 17, title = 20)
savesvg("slide.svg", fig; mode = :static, theme = slides)
```

## Output

[`svg`](@ref) returns the SVG markup and [`savesvg`](@ref) writes it to a file; both take
the same keywords.

| Keyword | Values |
|:--------|:-------|
| `mode` | `:web` (default) or `:static` |
| `theme` | `:auto` (web: light and dark), `:light`, `:dark`, a `Theme`, or `(light = ..., dark = ...)` |
| `background` | fill the figure with the background color (default: on for the web, off for static files) |
| `embed_style` | include the color definitions in a web figure (default `true`) |
| `font` | override the font family |
| `responsive` | let web figures shrink with their container |

**Web figures** use CSS variables for every theme color, so they follow the reader's
system setting, or a page's `data-theme="light"`/`"dark"` attribute on an ancestor.
A site with many figures can include [`stylesheet`](@ref) once and render with
`embed_style = false`. Points and bars with `tips` get native tooltips (and a `data-tip`
attribute for custom tooltip scripts).

**Static figures** have every color, halo and sub- or superscript written out and use
Arial by default, which is what PowerPoint, Keynote, Inkscape and LaTeX's `svg` package
need. Their background is transparent unless `background = true`; use `theme = :dark`
for dark slides. Insert them in PowerPoint with *Insert → Pictures*; they stay vector
graphics.

Element ids are derived from the content, so rendering the same figure twice gives the
same file, and different figures on one page do not clash.

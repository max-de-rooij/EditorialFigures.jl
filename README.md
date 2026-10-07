# Hairline.jl

*Lightweight SVG figures in an editorial style.*

Hairline draws figures the way a good newspaper graphics desk would: hairline gridlines, a
muted palette with one accent, labels next to the data instead of in a key, and plenty of
white space. It writes plain SVG, depends on nothing but Julia's standard library, and
renders a figure in milliseconds.

![Two lines with direct labels on a logarithmic axis](docs/src/assets/readme-lines.svg)

```julia
using Hairline

k = 1:60
fig = Fig(680, 320; title = "Convergence", subtitle = "Gap to the optimum per iteration")
ax = panel!(fig; yscale = :log, xlabel = "iteration", ylabel = "f(x_{k}) − f^{*}")
line!(ax, k, 10.0 .^ (-0.2 .* k); label = "trust region", endlabel = true)
line!(ax, k, 10.0 .^ (-0.08 .* k .+ 1); color = 2, label = "gradient descent", endlabel = true)
hline!(ax, 1e-8; label = "tolerance")

savesvg("convergence.svg", fig)                       # for the web: follows light and dark mode
savesvg("convergence-slide.svg", fig; mode = :static) # for PowerPoint, Keynote, LaTeX
```

![A contour map of a parameter space and a prediction interval](docs/src/assets/readme-panels.svg)

## Features

- **Automatic layout.** Limits, ticks, tick labels, margins and legends are worked out when
  the figure is drawn. Panels in a grid line up their axes; overlapping end labels are
  moved apart.
- **One figure, several outputs.** Web figures use CSS variables for their colors, so they
  follow the reader's light or dark mode, and they get native tooltips. Static figures have
  every style written out (light or dark, transparent background, Arial) for slides and
  papers.
- **Marks for scientific figures:** lines, bands and areas, points, bars and histograms,
  error bars, reference lines and spans, contours, heatmaps and masks, rectangles, polygons,
  circles, ellipses, arrows, notes and callouts.
- **Label markup:** `x_{i}`, `10^{-5}` and `**bold**` in any text.
- **Inline display** in VS Code, Jupyter and Pluto; a `Fig` is shown as SVG.
- **Themes:** `LIGHT` and `DARK` built in; derive your own with `Theme(LIGHT; ...)`.

## Installation

Hairline is not registered yet:

```julia
using Pkg
Pkg.develop(path = "path/to/Hairline.jl")
```

## Documentation

The documentation has a guide, a gallery with code, notes on the design rules behind the
defaults and the API reference. Build it with

```sh
julia --project=docs -e 'using Pkg; Pkg.instantiate()'
julia --project=docs docs/make.jl
```

and open `docs/build/index.html`.

## In short

| Task | Call |
|:-----|:-----|
| A figure | `fig = Fig(width, height; title, subtitle, credit, layout = (rows, cols))` |
| A panel | `ax = panel!(fig; xlabel, ylabel, xscale = :log, style = :frame, ...)` |
| A grid of panels | `axs = grid!(fig, rows, cols; shared settings...)` |
| Marks | `line!`, `band!`, `area!`, `points!`, `bars!`, `hist!`, `errorbars!`, `hline!`, `vline!`, `vspan!`, `hspan!`, `contours!`, `heatmap!`, `mask!`, `rect!`, `polygon!`, `circle!`, `ellipse!`, `segments!`, `arrow!` |
| Text | `note!(ax, x, y, "text")`, `annotate!(ax, x, y, "text")`, `line!(...; label, endlabel = true)`, `title!` |
| Legends | automatic for two or more labels; `legend!(ax; position)`, `Fig(...; legend = :top)` |
| Output | `svg(fig; mode, theme)`, `savesvg(path, fig; mode, theme)` |

Run the tests with `julia --project -e 'using Pkg; Pkg.test()'`.

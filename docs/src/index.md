# EditorialFigures.jl

*Lightweight SVG figures in an editorial style.*

EditorialFigures draws figures the way a good newspaper graphics desk would: hairline gridlines,
a muted palette with one accent, labels written next to the data instead of in a key,
and plenty of white space. It produces plain SVG, has no dependencies beyond Julia's
standard library, and each figure renders in milliseconds.

```@example home
using EditorialFigures

t = range(0, 20; length = 200)
fig = Fig(680, 340; title = "Substrate and product", subtitle = "A Michaelis–Menten reaction at three enzyme levels")
ax = panel!(fig; xlabel = "time (s)", ylabel = "concentration (mM)")
for (k, e) in enumerate((0.04, 0.08, 0.16))
    s = exp.(-e * 4 .* t)
    line!(ax, t, s; color = k, label = "E₀ = $e", endlabel = true)
end
hline!(ax, 0.5; label = "half-way")
fig
```

## What it does

- **Automatic layout.** Limits, tick values, tick labels, margins and legends are worked
  out when the figure is drawn; panels in a grid line up their axes.
- **One figure, several outputs.** For the web, colors are CSS variables, so a figure
  follows the reader's light or dark mode and gets native tooltips. For slides and papers,
  `mode = :static` writes every color out, in a light or a dark theme, in a form that
  PowerPoint, Keynote, Inkscape and LaTeX read correctly.
- **The marks scientific figures need**: lines, bands, points, bars, histograms, error
  bars, reference lines and spans, contours, heatmaps, masks, shapes, arrows, notes and
  callouts, with sub- and superscripts in any label (`x_{i}`, `10^{-5}`).
- **Displays inline** in VS Code, Jupyter and Pluto, which render SVG.

## Installation

EditorialFigures is not registered. Install it from its folder:

```julia
using Pkg
Pkg.develop(path = "path/to/EditorialFigures.jl")
```

## A first figure, step by step

```@example home
fig = Fig(560, 300)                                   # 560 × 300 pixels
ax = panel!(fig; xlabel = "x", ylabel = "sin x")      # one panel filling the figure
line!(ax, sin, 0, 2π)                                 # plot a function on [0, 2π]
points!(ax, [π / 2, 3π / 2], [1, -1]; color = 2)      # mark the extremes
annotate!(ax, π / 2, 1, "maximum"; dx = 30, dy = 10)  # a callout
fig
```

Every function that adds something returns the figure, so in a notebook the figure
redraws after each step. To write it to a file:

```julia
savesvg("sine.svg", fig)                           # for the web
savesvg("sine-slide.svg", fig; mode = :static)     # for slides and papers
```

The [Guide](guide.md) explains figures, panels, scales, marks, legends, colors and output
in turn; the [Gallery](gallery.md) shows complete examples; [Style](style.md) describes the
design rules behind the defaults.

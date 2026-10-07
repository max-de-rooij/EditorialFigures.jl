# Gallery

Complete examples, each rendered when these pages are built. Hover over the points and
bars for tooltips.

```@setup gallery
using EditorialFigures, Random
```

## Lines with direct labels

```@example gallery
k = 1:60
fig = Fig(640, 340; title = "Convergence", subtitle = "Gap to the optimum per iteration")
ax = panel!(fig; yscale = :log, xlabel = "iteration", ylabel = "f(x_{k}) − f^{*}")
line!(ax, k, 10.0 .^ (-0.2 .* k); label = "trust region", endlabel = true)
line!(ax, k, 10.0 .^ (-0.08 .* k .+ 1); color = 2, label = "gradient descent", endlabel = true)
hline!(ax, 1e-8; label = "tolerance")
fig
```

## Scatter with a fit and a callout

```@example gallery
rng = Xoshiro(1)
x = 10 .* rand(rng, 40)
y = 0.8 .* x .+ randn(rng, 40)
fig = Fig(600, 360; title = "Response to dose", subtitle = "40 patients and a linear fit")
ax = panel!(fig; xlabel = "dose (mg)", ylabel = "response")
points!(ax, x, y; label = "patients", tips = ["patient $i: $(round(y[i]; digits = 2))" for i in 1:40])
line!(ax, d -> 0.8d, 0, 10; color = :ink, width = :thin, dash = true, label = "fit y = 0.8x")
i = argmax(y .- 0.8 .* x)
annotate!(ax, x[i], y[i], "largest residual"; dx = -30, dy = -24)
fig
```

## Bars

```@example gallery
shares = [0.42, 0.31, 0.12, 0.09, 0.06]
fig = Fig(680, 300; layout = (1, 2))
a = panel!(fig; title = "Share of wins", xticks = (1:5, ["PSO", "TR", "BFGS", "NM", "SA"]))
bars!(a, 1:5, shares; tips = ["$(round(Int, 100s)) %" for s in shares])
b = panel!(fig; title = "Run time", yticks = (1:4, ["alpha", "beta", "gamma", "delta"]), grid = :x,
    xlabel = "seconds")
bars!(b, 1:4, [3.2, 1.1, 2.4, 0.6]; horizontal = true, color = 2)
fig
```

Grouped bars use `offset` and a narrower `width`:

```@example gallery
fig = Fig(600, 300; title = "Grouped bars")
ax = panel!(fig; xticks = (1:4, ["Q1", "Q2", "Q3", "Q4"]), ylabel = "revenue")
bars!(ax, 1:4, [3, 4, 4.5, 5]; offset = -0.18, width = 0.34, label = "2025")
bars!(ax, 1:4, [3.5, 4.2, 5.1, 6]; offset = 0.18, width = 0.34, color = 2, label = "2026")
fig
```

## Histogram with a density

```@example gallery
z = randn(Xoshiro(2), 2000)
fig = Fig(600, 320; title = "Standard normal samples")
ax = panel!(fig; xlabel = "z", ylabel = "density")
hist!(ax, z; bins = 40, normalize = true, label = "2,000 samples")
line!(ax, t -> exp(-t^2 / 2) / sqrt(2π), -4, 4; color = :ink, width = :thin, label = "N(0, 1)")
fig
```

## Bands and error bars

```@example gallery
t = range(0, 10; length = 100)
m = 1 .- exp.(-0.4 .* t)
fig = Fig(680, 320; layout = (1, 2))
a = panel!(fig; title = "Prediction interval", xlabel = "time", ylim = (0, 1.2))
band!(a, t, m .- 0.1 .* sqrt.(t), m .+ 0.1 .* sqrt.(t); label = "95 % interval")
line!(a, t, m; label = "mean")
vspan!(a, 0, 4)
note!(a, 2, 1.1, "training data"; anchor = :middle, color = :ink2)
b = panel!(fig; title = "Means per week", xlabel = "week", legend = :none)
w = 1:6
mu = [2.0, 2.6, 3.1, 3.0, 3.6, 4.2]
errorbars!(b, w, mu .- 0.5, mu .+ 0.5)
points!(b, w, mu; tips = ["week $i: $(mu[i])" for i in w])
fig
```

## A parameter space

Contour lines of the Rosenbrock function, a path to its minimum and an equal aspect
ratio. Lower contour levels are drawn darker.

```@example gallery
f(a, b) = (1 - a)^2 + 5 * (b - a^2)^2
xs, ys = range(-2, 2; length = 161), range(-1, 3; length = 161)
Z = [log10(f(a, b) + 0.01) for a in xs, b in ys]
path = [(-1.6, 2.6), (-1.0, 1.1), (-0.3, 0.2), (0.4, 0.1), (0.8, 0.6), (1.0, 1.0)]
fig = Fig(440, 460; title = "Rosenbrock")
ax = panel!(fig; style = :frame, aspect = :equal, xlabel = "θ_{1}", ylabel = "θ_{2}")
contours!(ax, xs, ys, Z; levels = 12)
line!(ax, first.(path), last.(path); width = :thin)
points!(ax, first.(path), last.(path); size = 3)
points!(ax, [1.0], [1.0]; color = 2, size = 5)
note!(ax, 1.0, 1.0, "minimum"; dx = 8, dy = 12, bold = true, halo = true)
note!(ax, -1.6, 2.6, "start"; dx = 8, halo = true)
fig
```

## Fields

```@example gallery
xs = ys = range(-3, 3; length = 60)
Z = [exp(-(a^2 + b^2) / 2) + 0.5exp(-((a - 1.5)^2 + (b + 1)^2)) for a in xs, b in ys]
fig = Fig(680, 340; layout = (1, 2))
a = panel!(fig; style = :frame, aspect = :equal, title = "Heatmap")
heatmap!(a, xs, ys, Z)
b = panel!(fig; style = :frame, aspect = :equal, title = "Region and contours")
mask!(b, xs, ys, Z .> 0.4)
contours!(b, xs, ys, Z; levels = [0.1, 0.2, 0.4, 0.6, 0.8], strong = [0.4])
note!(b, 0, 0, "Z > 0.4"; anchor = :middle, halo = true)
fig
```

## Small multiples with one legend

```@example gallery
fig = Fig(720, 360; title = "Three rate constants", legend = :top)
axs = grid!(fig, 1, 3; ylim = (0, 1), xlabel = "time")
t = range(0, 10; length = 100)
for (j, ax) in enumerate(axs)
    k = (0.2, 0.4, 0.6)[j]
    line!(ax, t, 1 .- exp.(-k .* t); label = "product")
    line!(ax, t, exp.(-k .* t); color = 2, label = "substrate")
    title!(ax, "k = $k")
end
axs[1].ylabel = "concentration"
fig
```

## A diagram

```@example gallery
fig = Fig(600, 220)
ax = panel!(fig; style = :none, xlim = (0, 10), ylim = (0, 4))
rect!(ax, 0.5, 1, 3, 3; fill = :bgsoft, opacity = 1, stroke = :rule, radius = 4)
rect!(ax, 7, 1, 9.5, 3; fill = :accent, opacity = 0.1, stroke = :accent, radius = 4)
note!(ax, 1.75, 2, "**data**"; anchor = :middle)
note!(ax, 8.25, 2, "**model**"; anchor = :middle)
arrow!(ax, 3.2, 2, 6.8, 2)
note!(ax, 5, 2.4, "fit"; anchor = :middle, color = :ink2)
fig
```

## Static output for slides

The same figure as a static file, written out for a dark slide:

```@example gallery
fig = Fig(560, 260; title = "On a dark slide")
ax = panel!(fig; xlabel = "x")
line!(ax, sin, 0, 2π; label = "sin", endlabel = true)
line!(ax, cos, 0, 2π; color = 2, label = "cos", endlabel = true)
s = svg(fig; mode = :static, theme = :dark, background = true)
HTML(s)
```

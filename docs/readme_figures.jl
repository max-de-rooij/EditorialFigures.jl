# Figures of the README, written to docs/src/assets/ as web-mode SVG (they follow the
# reader's light or dark mode on GitHub):
#
#   julia --project=docs docs/readme_figures.jl      (from the EditorialFigures.jl folder)

using EditorialFigures

const ASSETS = joinpath(@__DIR__, "src", "assets")

# convergence of two methods, with direct labels on a logarithmic axis
k = 1:60
fig = Fig(680, 320; title = "Convergence", subtitle = "Gap to the optimum per iteration")
ax = panel!(fig; yscale = :log, xlabel = "iteration", ylabel = "f(x_{k}) − f^{*}")
line!(ax, k, 10.0 .^ (-0.2 .* k); label = "trust region", endlabel = true)
line!(ax, k, 10.0 .^ (-0.08 .* k .+ 1); color = 2, label = "gradient descent", endlabel = true)
hline!(ax, 1e-8; label = "tolerance")
savesvg(joinpath(ASSETS, "readme-lines.svg"), fig)

# a parameter space and a prediction interval side by side
f(a, b) = (1 - a)^2 + 5 * (b - a^2)^2
xs, ys = range(-2, 2; length = 161), range(-1, 3; length = 161)
Z = [log10(f(a, b) + 0.01) for a in xs, b in ys]
path = [(-1.6, 2.6), (-1.0, 1.1), (-0.3, 0.2), (0.4, 0.1), (0.8, 0.6), (1.0, 1.0)]
t = range(0, 10; length = 100)
m = 1 .- exp.(-0.4 .* t)
fig = Fig(680, 330; layout = (1, 2))
a = panel!(fig; style = :frame, aspect = :equal, title = "A parameter space", xlabel = "θ_{1}", ylabel = "θ_{2}")
contours!(a, xs, ys, Z; levels = 12)
line!(a, first.(path), last.(path); width = :thin)
points!(a, first.(path), last.(path); size = 3)
points!(a, [1.0], [1.0]; color = 2, size = 5)
note!(a, 1.0, 1.0, "minimum"; dx = 8, dy = 12, bold = true, halo = true)
b = panel!(fig; title = "A prediction interval", xlabel = "time", ylim = (0, 1.2))
vspan!(b, 0, 4)
band!(b, t, m .- 0.1 .* sqrt.(t), m .+ 0.1 .* sqrt.(t))
line!(b, t, m)
note!(b, 2, 1.1, "training data"; anchor = :middle, color = :ink2)
savesvg(joinpath(ASSETS, "readme-panels.svg"), fig)

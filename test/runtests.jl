using EditorialFigures
using Test

const H = EditorialFigures

"Crude well-formedness check: every opened element is closed in order."
function balanced(s::AbstractString)
    stack = String[]
    for m in eachmatch(r"<(/?)([a-zA-Z][a-zA-Z0-9]*)[^>]*?(/?)>", s)
        closing, name, selfclosing = m.captures
        if closing == "/"
            (isempty(stack) || pop!(stack) != name) && return false
        elseif selfclosing != "/"
            push!(stack, name)
        end
    end
    return isempty(stack)
end

function demo()
    fig = Fig(600, 360; title = "Demo", subtitle = "All the marks", credit = "Source: tests", layout = (1, 2))
    a = panel!(fig; xlabel = "x", ylabel = "y_{1}", title = "Left")
    x = range(0, 2π; length = 50)
    line!(a, x, sin.(x); label = "sin", endlabel = true, tip = "a sine")
    line!(a, x, cos.(x); color = 2, dash = true, label = "cos")
    band!(a, x, sin.(x) .- 0.2, sin.(x) .+ 0.2; label = "band")
    points!(a, [1, 2, NaN], [0.5, 0.2, 0.1]; tips = ["p1", "p2", "p3"], marker = :diamond, label = "pts")
    hline!(a, 0.5; label = "ref")
    vline!(a, 3.0; label = "t")
    vspan!(a, 4, 5)
    annotate!(a, 1, 0.5, "callout"; dot = true)
    note!(a, 0.5, -0.5, "**bold** and 10^{-3}"; halo = true)
    arrow!(a, 0, 0, 1, 1; label = "arrow")
    b = panel!(fig; style = :frame, aspect = :equal, title = "Right", legend = :inside)
    xs, ys = range(-1, 1; length = 30), range(-1, 1; length = 30)
    Z = [u^2 + v^2 for u in xs, v in ys]
    heatmap!(b, xs, ys, Z)
    contours!(b, xs, ys, Z; levels = [0.25, 0.5], strong = [0.5], label = "contours")
    mask!(b, xs, ys, Z .< 0.25)
    circle!(b, 0, 0, 5)
    ellipse!(b, 0, 0, 0.5, 0.3; rotate = 30)
    polygon!(b, [-0.5, 0.5, 0.0], [-0.5, -0.5, 0.5])
    rect!(b, -0.9, -0.9, -0.6, -0.6; radius = 2)
    segments!(b, [(-1, -1, 1, 1), (-1, 1, 1, -1)])
    note!(fig, 590, 350, "figure note"; anchor = :end)
    return fig
end

@testset "EditorialFigures.jl" begin
    @testset "ticks and formatting" begin
        @test nice_ticks(0, 1) ≈ [0, 0.2, 0.4, 0.6, 0.8, 1.0]
        @test nice_ticks(0, 100; n = 4) ≈ [0, 20, 40, 60, 80, 100] || nice_ticks(0, 100; n = 4) ≈ [0, 50, 100]
        @test H.log_ticks(1, 1000) ≈ [1, 10, 100, 1000]
        @test all(H.isdecade, H.log_ticks(1e-12, 10))
        @test H.format_tick(0.4; step = 0.2) == "0.4"
        @test H.format_tick(10.0; step = 2.0) == "10"
        @test H.format_tick(-3.0; step = 1.0) == "−3"
        @test H.format_tick(12000.0; step = 2000.0) == "12,000"
        @test H.format_tick(2.0e7; step = 1.0e7) == "2×10^{7}"
        @test H.format_tick(1.0e-6; log = true, powers = true) == "10^{−6}"
        @test H.format_tick(0.01; log = true) == "0.01"
    end

    @testset "markup" begin
        runs = H.parse_markup("a_{1} + b^{2} **c** \\_d")
        @test [r.shift for r in runs] == [:none, :sub, :none, :sup, :none, :none, :none]
        @test any(r -> r.bold && r.text == "c", runs)
        @test H.plaintext("x_{i}^{2}") == "xi2"
        @test H.text_content("10^{-5}", :static, 12) == "10⁻⁵"
        @test occursin("<tspan dy=", H.text_content("10^{-5}", :web, 12))
        @test H.text_content("a < b & c", :static, 12) == "a &lt; b &amp; c"
        @test text_width("iii", 12) < text_width("WWW", 12)
    end

    @testset "contours" begin
        xs = collect(range(-2, 2; length = 81))
        Z = [x^2 + y^2 for x in xs, y in xs]
        X, Y = H.isoline(xs, xs, Z, 1.0)
        r = hypot.(filter(isfinite, X), filter(isfinite, Y))
        @test maximum(abs.(r .- 1)) < 0.01
        @test count(isnan, X) == 1   # one closed curve
        @test (X[1], Y[1]) == (X[end - 1], Y[end - 1])
    end

    @testset "limits" begin
        fig = Fig()
        ax = panel!(fig)
        bars!(ax, 1:3, [2, 5, 3])
        lay = H.layout(fig, LIGHT)
        @test lay.plans[1].ylim[1] == 0          # bars include their baseline
        @test lay.plans[1].ylim[2] >= 5
        ax2 = panel!(Fig(); yscale = :log)
        line!(ax2, 1:10, 10.0 .^ (1:10))
        pl = H.layout(ax2.fig, LIGHT).plans[1]
        @test pl.ylim == (10.0, 1.0e10)
        ax3 = panel!(Fig(); ylim = (10, 0))     # reversed
        line!(ax3, 1:3, 1:3)
        pl = H.layout(ax3.fig, LIGHT).plans[1]
        @test pl.sy(10) > pl.sy(0)             # 10 at the bottom
        ax4 = panel!(Fig(); style = :frame)
        line!(ax4, [0.3, 0.7], [0.1, 0.9])
        @test H.layout(ax4.fig, LIGHT).plans[1].xlim == (0.3, 0.7)   # frames fit the data
    end

    @testset "layout" begin
        fig = Fig(800, 400)
        axs = grid!(fig, 2, 2)
        axs[1, 1].ylabel = "a long label"
        line!(axs[1, 1], 1:3, [1, 1000, 100000])
        line!(axs[2, 1], 1:3, 1:3)
        pl = H.layout(fig, LIGHT).plans
        @test pl[1].box[1] == pl[2].box[1]       # a column shares its left margin
        @test pl[1].box[2] == pl[3].box[2]       # a row shares its top margin
        @test_throws ArgumentError panel!(fig)   # layout is full
        f2 = Fig()
        p = panel!(f2, 50, 40, 300, 200)
        @test H.layout(f2, LIGHT).plans[1].box == (50.0, 40.0, 300.0, 200.0)
    end

    @testset "legends" begin
        fig = Fig()
        ax = panel!(fig)
        line!(ax, 1:3, 1:3; label = "a")
        points!(ax, 1:3, 1:3; label = "a")
        band!(ax, 1:3, 0:2, 2:4; label = "b")
        e = H.legend_entries(ax.marks)
        @test [x.kind for x in e] == [:linedot, :box]
        @test H.plan_panel(ax, 600.0, 400.0, LIGHT, false).legend === :top
        legend!(ax; position = :right)
        @test occursin(">a</text>", svg(fig))
        fig2 = Fig(; legend = :bottom)
        a, b = panel!(fig2, 50, 50, 200, 100), panel!(fig2, 350, 50, 200, 100)
        line!(a, 1:2, 1:2; label = "shared")
        line!(b, 1:2, 1:2; label = "shared")
        @test length(H.figure_entries(fig2)) == 1
    end

    @testset "rendering" begin
        fig = demo()
        web = svg(fig)
        static = svg(fig; mode = :static)
        dark = svg(fig; mode = :static, theme = :dark)
        @test balanced(web) && balanced(static) && balanced(dark)
        @test occursin("var(--hl-", web) && occursin("prefers-color-scheme", web)
        @test !occursin("var(", static) && !occursin("class=", static) && !occursin("<title>", static)
        @test occursin(DARK.bg, dark) && occursin(DARK.series[1], dark)
        @test occursin("<title>p1</title>", web)
        @test !occursin("p3", web)               # the NaN point gets no tooltip
        @test !occursin("<style>", svg(fig; embed_style = false))
        @test occursin("font-family=\"Arial", static)
        @test svg(fig) == web                    # deterministic, including the ids
        @test occursin("id=\"$(match(r"clipPath id=\"([a-z0-9]+)-c1", web).captures[1])-c1\"", web)
        custom = Theme(LIGHT; series = ["#000000", "#111111", "#222222", "#333333", "#444444", "#555555", "#666666", "#777777"])
        @test occursin("#000000", svg(fig; mode = :static, theme = custom))
        path = joinpath(mktempdir(), "fig.svg")
        @test savesvg(path, fig; mode = :static) == path
        @test startswith(read(path, String), "<?xml")
        @test showable(MIME"image/svg+xml"(), fig)
        @test balanced(svg(Fig()))               # an empty figure renders
    end

    @testset "argument checks" begin
        ax = panel!(Fig())
        @test_throws ArgumentError line!(ax, 1:2, 1:2; color = :nonsense)
        @test_throws ArgumentError line!(ax, 1:2, 1:2; color = 9)
        @test_throws DimensionMismatch line!(ax, 1:2, 1:3)
        @test_throws ArgumentError panel!(Fig(); style = :fancy)
        @test_throws ArgumentError panel!(Fig(); nonsense = 1)
        @test_throws ArgumentError svg(Fig(); mode = :pdf)
    end
end

# Themes: the colors and type sizes of a figure.

"""
    Theme(; kwargs...)
    Theme(base::Theme; kwargs...)

Colors and typography of a figure. The second form copies `base` and replaces the given
fields, for example `Theme(LIGHT; series = ["#1f6feb", "#d1242f"])`.

Colors are CSS color strings. Marks refer to them by name (see [Colors](@ref colors)):

- `bg`, `bgsoft`: background and a slightly tinted surface (halos, legend boxes).
- `ink`, `ink2`, `muted`: primary, secondary and tertiary text and lines.
- `rule`, `grid`, `axis`, `contour`: hairlines of different weight.
- `series`: the categorical palette; `series[1]` is the accent.

Typography: `font` (a CSS font-family list) and the sizes in pixels `tick`, `label`,
`note`, `legend`, `title`, `subtitle`, `figtitle`, `figsubtitle` and `credit`.

The built-in themes are [`LIGHT`](@ref) and [`DARK`](@ref).
"""
Base.@kwdef struct Theme
    name::Symbol = :light
    bg::String = "#ffffff"
    bgsoft::String = "#f7f7f5"
    ink::String = "#121212"
    ink2::String = "#4a4a48"
    muted::String = "#767470"
    rule::String = "#e2e1dc"
    grid::String = "#e8e7e2"
    axis::String = "#b9b8b1"
    contour::String = "#8d8b85"
    series::Vector{String} = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
    font::String = "\"Libre Franklin\", \"Helvetica Neue\", Helvetica, Arial, sans-serif"
    tick::Float64 = 11.5
    label::Float64 = 12.0
    note::Float64 = 12.5
    legend::Float64 = 12.5
    title::Float64 = 13.5
    subtitle::Float64 = 12.5
    figtitle::Float64 = 18.0
    figsubtitle::Float64 = 14.0
    credit::Float64 = 11.0
end

function Theme(base::Theme; kwargs...)
    fields = Dict{Symbol, Any}(f => getfield(base, f) for f in fieldnames(Theme))
    for (k, v) in kwargs
        haskey(fields, k) || throw(ArgumentError("Theme has no field `$k`"))
        fields[k] = v
    end
    return Theme(; fields...)
end

"""
    LIGHT

The default light theme: near-black ink on white, warm grays for hairlines and an
eight-color categorical palette that keeps adjacent colors apart for color-blind readers.
"""
const LIGHT = Theme()

"""
    DARK

The dark theme: the same roles as [`LIGHT`](@ref), with every color stepped for a dark
surface rather than inverted.
"""
const DARK = Theme(;
    name = :dark, bg = "#131312", bgsoft = "#1b1b1a", ink = "#ecebe6", ink2 = "#bdbcb5",
    muted = "#8f8d87", rule = "#2f2f2c", grid = "#2a2a28", axis = "#4a4a46", contour = "#7c7a74",
    series = ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300", "#9085e9", "#e66767"]
)

const TOKENS = (:bg, :bgsoft, :ink, :ink2, :muted, :rule, :grid, :axis, :contour)

# A paint is a color reference: a token name, a series index, a literal CSS color, or
# `nothing` for none. They are resolved when a figure is rendered.
const Paint = Union{Nothing, Symbol, Int, String}

"""Validate a user-supplied color and turn it into a paint."""
function paint(c)
    c === nothing && return nothing
    c === :none && return nothing
    if c isa Symbol
        c in TOKENS || c in (:accent, :accent2) ||
            throw(ArgumentError("unknown color :$c; use one of $(join(":" .* string.((TOKENS..., :accent, :accent2)), ", ")), an integer series index or a CSS color string"))
        return c
    elseif c isa Integer
        1 <= c <= 8 || throw(ArgumentError("series index $c is out of range 1:8; fold further series into \"other\" or use small multiples"))
        return Int(c)
    elseif c isa AbstractString
        return String(c)
    end
    throw(ArgumentError("invalid color $(repr(c))"))
end

function resolve(t::Theme, c::Paint)
    c === nothing && return "none"
    c isa String && return c
    c isa Int && return t.series[c]
    c === :accent && return t.series[1]
    c === :accent2 && return t.series[2]
    return getfield(t, c)
end

cssvar(c::Symbol) = c === :accent ? "--hl-s1" : c === :accent2 ? "--hl-s2" : "--hl-$c"
cssvar(c::Int) = "--hl-s$c"

function cssvars(t::Theme)
    vars = ["--hl-$k:$(getfield(t, k))" for k in TOKENS]
    append!(vars, ["--hl-s$i:$c" for (i, c) in enumerate(t.series)])
    return join(vars, ";")
end

"""
    stylesheet(; light = LIGHT, dark = DARK, selector = ".hl-root")

The CSS that defines the colors of web-mode figures. Figures embed it by default; a site
that shows many figures can include it once and render with `embed_style = false`.

Dark colors apply when the reader's system prefers a dark scheme, unless the page sets
`data-theme="light"` on an ancestor; `data-theme="dark"` forces them.
"""
function stylesheet(; light::Theme = LIGHT, dark::Theme = DARK, selector = ".hl-root")
    l, d = cssvars(light), cssvars(dark)
    return "$selector{$l}@media (prefers-color-scheme: dark){$selector{$d}[data-theme=\"light\"] $selector{$l}}[data-theme=\"dark\"] $selector{$d}"
end

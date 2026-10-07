# Text: escaping, the label markup, and width estimates for layout.
#
# Labels accept a small markup: `x_{i}` for subscripts, `10^{-5}` for superscripts and
# `**bold**` for bold runs; `\_`, `\^` and `\*` give the literal characters.

xmlesc(s) = replace(string(s), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

struct Run
    text::String
    shift::Symbol   # :none, :sub or :sup
    bold::Bool
end

function parse_markup(s::AbstractString)
    runs = Run[]
    buf = IOBuffer()
    bold = false
    function flush!()
        t = String(take!(buf))
        isempty(t) || push!(runs, Run(t, :none, bold))
    end
    cs = collect(s)
    i = 1
    while i <= length(cs)
        c = cs[i]
        nxt = i < length(cs) ? cs[i + 1] : '\0'
        if c == '\\' && nxt in ('_', '^', '*', '\\')
            print(buf, nxt)
            i += 2
            continue
        elseif (c == '_' || c == '^') && nxt == '{'
            j = findnext(==('}'), cs, i + 2)
            if j !== nothing
                flush!()
                push!(runs, Run(String(cs[(i + 2):(j - 1)]), c == '_' ? :sub : :sup, bold))
                i = j + 1
                continue
            end
        elseif c == '*' && nxt == '*'
            flush!()
            bold = !bold
            i += 2
            continue
        end
        print(buf, c)
        i += 1
    end
    flush!()
    return runs
end

const SUBS = Dict(zip("0123456789+-−=()aeoxhklmnpstijruv", "₀₁₂₃₄₅₆₇₈₉₊₋₋₌₍₎ₐₑₒₓₕₖₗₘₙₚₛₜᵢⱼᵣᵤᵥ"))
const SUPS = Dict(zip("0123456789+-−=()niT", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁻⁼⁽⁾ⁿⁱᵀ"))

"""The run as Unicode sub- or superscript characters, or `nothing` if one has none."""
function unicode_shift(r::Run)
    table = r.shift === :sub ? SUBS : SUPS
    all(c -> haskey(table, c), r.text) || return nothing
    return String([table[c] for c in r.text])
end

"""
SVG content of a text element for the markup string `s` at font size `size`. Shifted runs
become Unicode characters in static mode where they exist (robust in PowerPoint and other
editors) and baseline-shifted tspans otherwise.
"""
function text_content(s::AbstractString, mode::Symbol, size::Real)
    io = IOBuffer()
    pending = 0.0   # baseline shift to undo before the next run
    for r in parse_markup(s)
        u = r.shift !== :none && mode === :static ? unicode_shift(r) : nothing
        if r.shift === :none || u !== nothing
            t = xmlesc(u === nothing ? r.text : u)
            attrs = (pending != 0 ? " dy=\"$(fmt(-pending))\"" : "") * (r.bold ? " font-weight=\"700\"" : "")
            print(io, isempty(attrs) ? t : "<tspan$attrs>$t</tspan>")
            pending = 0.0
        else
            dy = r.shift === :sub ? 0.3 * size : -0.4 * size
            print(io, "<tspan dy=\"$(fmt(dy - pending))\" font-size=\"$(fmt(0.75 * size))\"",
                r.bold ? " font-weight=\"700\"" : "", ">", xmlesc(r.text), "</tspan>")
            pending = dy
        end
    end
    return String(take!(io))
end

"""The text without markup, for tooltips and accessible labels."""
plaintext(s::AbstractString) = join(r.text for r in parse_markup(s))

# Advance widths of Helvetica (per 1000 units of font size), used to estimate text widths
# for layout. Libre Franklin and Arial are within a few percent.
const WIDTHS = Dict{Char, Int}(zip(
    " !\"#\$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~",
    (278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556,
        556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, 1015, 667, 667, 722, 722, 667,
        611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667,
        667, 611, 278, 278, 278, 469, 556, 333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500,
        222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584)
))

"""
    text_width(s, size; bold = false)

Estimated width in pixels of the markup string `s` at font size `size`.
"""
function text_width(s::AbstractString, size::Real; bold::Bool = false)
    w = 0.0
    for r in parse_markup(s)
        f = r.shift === :none ? 1.0 : 0.75
        for c in r.text
            w += f * get(WIDTHS, c, isascii(c) ? 556 : 600) * (bold || r.bold ? 1.06 : 1.0)
        end
    end
    return 1.04 * w * size / 1000
end

# number formatting for coordinates: one decimal, without a trailing ".0"
function fmt(v::Real)
    s = @sprintf("%.1f", v)
    s = endswith(s, ".0") ? s[1:(end - 2)] : s
    return s == "-0" ? "0" : s
end

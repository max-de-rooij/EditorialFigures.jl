# Scales map data to pixels; ticks and their labels.

struct Scale
    log::Bool
    d0::Float64   # domain
    d1::Float64
    r0::Float64   # range in pixels
    r1::Float64
end

function (s::Scale)(v::Real)
    if s.log
        v > 0 || return NaN
        t = (log10(v) - log10(s.d0)) / (log10(s.d1) - log10(s.d0))
    else
        t = (v - s.d0) / (s.d1 - s.d0)
    end
    return s.r0 + t * (s.r1 - s.r0)
end

"""
    nice_ticks(a, b; n = 5)

Round tick values (steps of 1, 2 or 5 times a power of ten) covering `[a, b]` with about
`n` intervals.
"""
function nice_ticks(a::Real, b::Real; n::Integer = 5)
    a, b = minmax(Float64(a), Float64(b))
    a == b && return [a]
    step = nice_step((b - a) / max(n, 1))
    first = ceil(a / step - 1.0e-9) * step
    return [abs(t) < 1.0e-12 * step ? 0.0 : t for t in first:step:(b + 1.0e-9 * (b - a))]
end

function nice_step(raw::Float64)
    mag = 10.0^floor(log10(raw))
    r = raw / mag
    return mag * (r < 1.5 ? 1 : r < 3.5 ? 2 : r < 7.5 ? 5 : 10)
end

"""Ticks of a logarithmic axis: decades, thinned for wide ranges and filled in for narrow ones."""
function log_ticks(a::Real, b::Real; n::Integer = 5)
    a, b = minmax(Float64(a), Float64(b))
    k0, k1 = ceil(Int, log10(a) - 1.0e-9), floor(Int, log10(b) + 1.0e-9)
    every = 1
    for e in (1, 2, 3, 4, 5, 10, 20, 50, 100)
        every = e
        (k1 - k0) / e <= max(n, 1) && break
    end
    ticks = [10.0^k for k in k0:k1 if mod(k, every) == 0]
    if length(ticks) < 3
        extra = [m * 10.0^k for k in (k0 - 1):k1 for m in (2, 5)]
        ticks = sort!(unique!(vcat(ticks, filter(t -> a * (1 - 1.0e-9) <= t <= b * (1 + 1.0e-9), extra))))
    end
    return ticks
end

ticks_for(s::Scale, n) = s.log ? log_ticks(s.d0, s.d1; n) : nice_ticks(s.d0, s.d1; n)

# decimals needed to show every multiple of `step` exactly
function decimals(step::Float64)
    for d in 0:10
        x = step * 10.0^d
        abs(x - round(x)) < 1.0e-6 * max(1, x) && return d
    end
    return 10
end

function group_thousands(s::AbstractString)
    neg = startswith(s, "-")
    s = neg ? s[2:end] : s
    int, frac = occursin('.', s) ? split(s, '.'; limit = 2) : (s, "")
    groups = reverse([reverse(int)[i:min(i + 2, end)] for i in 1:3:length(int)])
    out = join(reverse.(groups), ",") * (isempty(frac) ? "" : "." * frac)
    return neg ? "-" * out : out
end

isdecade(v) = v > 0 && isapprox(v, 10.0^round(log10(v)); rtol = 1.0e-9)
supk(k) = "10^{$(replace(string(k), "-" => "−"))}"

"""
    format_tick(v; step, log = false, powers = false)

Tick label for the value `v` of an axis with tick spacing `step`: just enough decimals,
thousands separators, a proper minus sign, and powers of ten (as `10^{k}` markup) for very
large or small values. On logarithmic axes, `powers = true` writes every tick as a power
of ten (used when some ticks fall outside 0.01 to 10,000).
"""
function format_tick(v::Real; step::Real = 1.0, log::Bool = false, powers::Bool = false)
    v = Float64(v)
    if log
        k = floor(Int, log10(v) + 1.0e-9)
        if powers
            isdecade(v) && return supk(round(Int, log10(v)))
            return @sprintf("%.3g", v / 10.0^k) * "×" * supk(k)
        end
        return format_tick(v; step = 10.0^k)
    end
    abs(v) < 1.0e-12 * max(abs(step), 1.0e-300) && return "0"
    if abs(v) >= 1.0e6 || abs(step) < 1.0e-4
        k = floor(Int, log10(abs(v)))
        m = v / 10.0^k
        ms = replace(@sprintf("%.3g", m), "-" => "−")
        return (ms == "1" ? "" : ms == "−1" ? "−" : ms * "×") * "10^{$(replace(string(k), "-" => "−"))}"
    end
    d = decimals(Float64(step))
    s = @sprintf("%.*f", d, v)
    occursin('.', s) && (s = rstrip(rstrip(s, '0'), '.'))
    abs(v) >= 1000 && (s = group_thousands(s))
    return replace(s, "-" => "−")
end

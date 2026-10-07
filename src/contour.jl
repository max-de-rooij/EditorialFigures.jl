# Contour lines by marching squares, with the cell segments joined into polylines.

# An edge of the grid: (i, j, 0) joins nodes (i, j) and (i + 1, j); (i, j, 1) joins (i, j)
# and (i, j + 1).
const EdgeKey = NTuple{3, Int}

"""
    isoline(x, y, Z, level) -> (X, Y)

The contour of `Z[i, j]` (given at `(x[i], y[j])`) at `level`, as polylines separated by
`NaN`. Saddle cells are resolved with the value at the cell centre; cells with a
non-finite corner are skipped.
"""
function isoline(xs::Vector{Float64}, ys::Vector{Float64}, Z::Matrix{Float64}, L::Float64)
    nx, ny = size(Z)
    segs = Tuple{EdgeKey, EdgeKey}[]
    for j in 1:(ny - 1), i in 1:(nx - 1)
        v00, v10, v11, v01 = Z[i, j], Z[i + 1, j], Z[i + 1, j + 1], Z[i, j + 1]
        (isfinite(v00) && isfinite(v10) && isfinite(v11) && isfinite(v01)) || continue
        a00, a10, a11, a01 = v00 > L, v10 > L, v11 > L, v01 > L
        kb, kr, kt, kl = (i, j, 0), (i + 1, j, 1), (i, j + 1, 0), (i, j, 1)
        crossed = EdgeKey[]
        a00 != a10 && push!(crossed, kb)
        a10 != a11 && push!(crossed, kr)
        a01 != a11 && push!(crossed, kt)
        a00 != a01 && push!(crossed, kl)
        if length(crossed) == 2
            push!(segs, (crossed[1], crossed[2]))
        elseif length(crossed) == 4
            if ((v00 + v10 + v11 + v01) / 4 > L) == a00
                push!(segs, (kb, kr), (kt, kl))
            else
                push!(segs, (kb, kl), (kr, kt))
            end
        end
    end

    function point(k::EdgeKey)
        i, j, d = k
        if d == 0
            va, vb = Z[i, j], Z[i + 1, j]
            t = (L - va) / (vb - va)
            return xs[i] + t * (xs[i + 1] - xs[i]), ys[j]
        else
            va, vb = Z[i, j], Z[i, j + 1]
            t = (L - va) / (vb - va)
            return xs[i], ys[j] + t * (ys[j + 1] - ys[j])
        end
    end

    adj = Dict{EdgeKey, Vector{Int}}()
    for (s, (a, b)) in enumerate(segs)
        push!(get!(adj, a, Int[]), s)
        push!(get!(adj, b, Int[]), s)
    end
    used = falses(length(segs))
    X, Y = Float64[], Float64[]
    for s0 in eachindex(segs)
        used[s0] && continue
        used[s0] = true
        chain = EdgeKey[segs[s0][1], segs[s0][2]]
        for _ in 1:2   # extend from one end, then from the other
            while true
                k = chain[end]
                next = 0
                for s in adj[k]
                    used[s] || (next = s; break)
                end
                next == 0 && break
                used[next] = true
                a, b = segs[next]
                push!(chain, a == k ? b : a)
            end
            reverse!(chain)
        end
        for k in chain
            px, py = point(k)
            push!(X, px)
            push!(Y, py)
        end
        push!(X, NaN)
        push!(Y, NaN)
    end
    return X, Y
end

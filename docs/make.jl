# Build the documentation:
#
#   julia --project=docs docs/make.jl       (from the Hairline.jl folder)
#
# and open docs/build/index.html. The figures on the pages are rendered by the examples
# when the site is built.

using Documenter
using EditorialFigures

# Documenter switches to its dark theme with a class on <html>; make the figures follow it
# (they follow the reader's system setting otherwise).
write(joinpath(@__DIR__, "src", "assets", "hairline.css"),
    "html:not(.theme--documenter-dark) .hl-root{$(EditorialFigures.cssvars(LIGHT))}" *
    "html.theme--documenter-dark .hl-root{$(EditorialFigures.cssvars(DARK))}" *
    ".hl-root{display:block;margin:0.5rem 0 1rem}\n")

makedocs(;
    sitename = "EditorialFigures.jl",
    modules = [EditorialFigures],
    format = Documenter.HTML(; prettyurls = false, assets = ["assets/hairline.css"], size_threshold = 2^21,
        example_size_threshold = 2^20, size_threshold_warn = 2^20),
    pages = [
        "Home" => "index.md",
        "Guide" => "guide.md",
        "Gallery" => "gallery.md",
        "Style" => "style.md",
        "Reference" => "api.md",
    ],
    checkdocs = :exports,
    warnonly = [:missing_docs],
)

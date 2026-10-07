# Style

The defaults follow a few rules from editorial graphics. They are what makes a EditorialFigures
figure look calm, and they are worth keeping when you change things.

```@setup style
using EditorialFigures
```

**The data are the darkest thing on the page.** Gridlines, axes and tick labels are drawn
in light warm grays; lines and dots are drawn in strong colors. Only horizontal gridlines
are drawn by default, because values are read off the y axis.

**One accent.** Series 1 is the accent; most figures need no more than it and the inks.
Use more colors only when the series really are different categories, assign them in a
fixed order and keep each series on its color everywhere.

**Text wears ink, not series colors.** Titles, labels and notes are set in `:ink`,
`:ink2` or `:muted`; a colored mark next to the text identifies the series. Reserve colored
text for the rare label that must be tied to a mark from a distance.

**Label the data directly.** An end label or a note next to a line is read faster than a
legend. Legends are drawn only when two or more labelled marks share a panel, as a row
above it, not inside the data.

**The y title sits above the axis**, horizontally, so it reads like a column heading and
leaves the left margin to the tick labels.

**Thin marks with clean ends.** Lines are 2 pixels wide with round joins; bars have
rounded data ends and square ends on the baseline; dots have a ring in the background
color, so overlapping dots stay distinct; a halo of background color keeps notes readable
on top of lines.

**Shading is light.** Bands and washes use the accent at 13 % opacity; spans that mark a
range (such as a training interval) use the ink at 5 %.

## Colors

The categorical palette and the inks, in the light and the dark theme. The eight colors
are ordered so that neighbours stay distinct for readers with color-vision deficiencies;
the dark theme steps each color for a dark background rather than inverting it.

```@example style
function swatches(t)
    fig = Fig(680, 150; padding = 8)
    ax = panel!(fig; style = :none, xlim = (0.5, 8.5), ylim = (0, 2))
    for k in 1:8
        rect!(ax, k - 0.42, 1.1, k + 0.42, 1.9; fill = t.series[k], opacity = 1, radius = 3)
        note!(ax, k, 0.9, t.series[k]; anchor = :middle, size = :tick, color = t.muted)
    end
    for (k, name) in enumerate((:ink, :ink2, :muted, :axis, :grid))
        rect!(ax, k - 0.42, 0.1, k + 0.42, 0.5; fill = getfield(t, name), opacity = 1, radius = 3)
        note!(ax, k, 0.7, ":$name"; anchor = :middle, size = :tick, color = t.muted)
    end
    return fig
end
HTML(svg(swatches(LIGHT); mode = :static, theme = LIGHT, background = true))
```

```@example style
HTML(svg(swatches(DARK); mode = :static, theme = DARK, background = true))
```

## Typography

Text uses a sans-serif (Libre Franklin on the web when the page provides it, falling back
to Helvetica and Arial; Arial in static files). Sizes are in pixels and set by the theme:

| Role | Theme field | Size |
|:-----|:------------|:-----|
| Tick labels | `tick` | 11.5 |
| Axis titles | `label` | 12 |
| Notes, legends | `note`, `legend` | 12.5 |
| Panel titles (bold) | `title` | 13.5 |
| Panel subtitles | `subtitle` | 12.5 |
| Figure title (bold) | `figtitle` | 18 |
| Figure subtitle | `figsubtitle` | 14 |
| Credit line | `credit` | 11 |

For slides, scale them up with a derived theme, e.g.
`Theme(LIGHT; tick = 16, label = 17, note = 17, legend = 17, title = 20, figtitle = 26)`.

library(magick)
library(MetBrewer)
library(colorspace)
library(ggplot2)
library(glue)
library(stringr)

img = image_read("images/massachusetts_untitled.png")

colors = met.brewer("Tam")
swatchplot(colors)
text_color = darken(colors[7], .25)
swatchplot(text_color)

img |> 
  image_crop(gravity = "center", geometry = "6000x4000") |> 
  image_annotate("Massachusetts Population Density", gravity = "north", location = "+20+100", color = text_color, size = 350, weight = 800, font = "Futura") |>
  image_annotate("Density of population in Massachusetts calculated using", gravity = "northwest", location = "+370+700", color = text_color, size = 100, font = "Futura") |>
  image_annotate("400 meter hexagons, equivalent to about 1/4 of a mile.  ", gravity = "northwest", location = "+370+830", color = text_color, size = 100, font = "Futura") |>
  image_annotate("Graphic made by Michael Gillis (@mgillis33 on Github) based on Spenser Shein's (@Pencers on Github) Youtube tutorial on Kontur Rayshader.", gravity = "southwest", location = "+565+200", color = text_color, size = 75, font = "Futura") |>
  image_annotate("Data from the United States subset of the Kontur Population Dataset. Published on 6/30/2022.", gravity = "southwest", location = "+565+100", color = text_color, size = 75, font = "Futura") |>
  image_write("images/massachusetts_final.png")
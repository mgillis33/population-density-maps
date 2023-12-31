library(sf)
library(tidyverse)
library(elevatr)
library(rayshader)
library(glue)
library(colorspace)
library(tigris)
library(stars)
library(MetBrewer)

# Set map name that will be used in file names, and 
# to get get boundaries from master NPS list

map <- "new_england"

# Kontur data source: https://data.humdata.org/dataset/kontur-population-united-states-of-america

data <- st_read("desktop/projects/population/kontur_population_US_20220630.gpkg")

ne_states <- c(
  "Maine",
  "Connecticut",
  "Rhode Island",
  "Massachusetts",
  "New Hampshire",
  "Vermont"
)

s <- states() |> 
  st_transform(crs = st_crs(data))

st <- s |> 
  filter(NAME %in% ne_states) |> 
  st_union()

longs <- map_df(c(-67, -73), function(i) {
  tibble(x = i,
         y = seq(from = 40, to = 48, by = 1)) |> 
    st_as_sf(coords = c("x", "y"), crs = 4326) |> 
    summarise() |> 
    st_cast(to = "LINESTRING") |> 
    st_transform(crs = 2249) |> 
    st_buffer(1609.34 * .5) |> 
    transmute(geom = geometry,
              population = 1)
})

lats <- map_df(c(47, 44, 41), function(i) {
  tibble(y = i,
         x = seq(from = -74, to = -66, by = 1)) |> 
    st_as_sf(coords = c("x", "y"), crs = 4326) |> 
    summarise(do_union = FALSE) |> 
    st_cast(to = "LINESTRING") |> 
    st_transform(crs = 2249) |> 
    st_buffer(1609.34 * .5) |> 
    transmute(geom = geometry,
              population = 1)
})

grid <- bind_rows(lats, longs)

grid |> 
  ggplot() +
  geom_sf() +
  geom_sf(data = st) +
  coord_sf(crs = 2249)

st |> 
  ggplot() +
  geom_sf() +
  coord_sf(crs = 2249)

int <- st_intersects(data, st)

st_dd <- map_dbl(int, function(i) {
  if (length(i) > 0) {
    return(i)
  } else {
    return(0)
  }
})

st_dd <- data[which(st_dd == 1),] |> 
  st_transform(crs = 2249)

st_d <- bind_rows(st_dd, grid) 

#st_d <- st_intersection(data, st)

bb <- st_bbox(st_d)
yind <- st_distance(st_point(c(bb[["xmin"]], bb[["ymin"]])), 
                    st_point(c(bb[["xmin"]], bb[["ymax"]])))
xind <- st_distance(st_point(c(bb[["xmin"]], bb[["ymin"]])), 
                    st_point(c(bb[["xmax"]], bb[["ymin"]])))

if (yind > xind) {
  y_rat <- 1
  x_rat <- xind / yind
} else {
  x_rat <- 1
  y_rat <- yind / xind
}

size <- 1000
rast <- st_rasterize(st_d |> 
                       select(population, geom),
                     nx = floor(size * x_rat), ny = floor(size * y_rat))


mat <- matrix(rast$population, nrow = floor(size * x_rat), ncol = floor(size * y_rat))

# set up color palette

pal <- "demuth"

c1 <- met.brewer("Demuth", 10)
colors <- c1[c(6:9, 2:5)]
swatchplot(colors)

texture <- grDevices::colorRampPalette(colors, bias = 3)(256)

swatchplot(texture)


###################
# Build 3D Object #
###################

# Keep this line so as you're iterating you don't forget to close the
# previous window

try(rgl::rgl.close())

# Create the initial 3D object
mat |> 
  height_shade(texture = texture) |> 
  plot_3d(heightmap = mat, 
          # This is my preference, I don't love the `solid` in most cases
          solid = FALSE,
          soliddepth = 0,
          # You might need to hone this in depending on the data resolution;
          # lower values exaggerate the height
          z = 100,
          # Set the location of the shadow, i.e. where the floor is.
          # This is on the same scale as your data, so call `zelev` to see the
          # min/max, and set it however far below min as you like.
          shadowdepth = 0,
          # Set the window size relatively small with the dimensions of our data.
          # Don't make this too big because it will just take longer to build,
          # and we're going to resize with `render_highquality()` below.
          windowsize = c(1000,1000), 
          # This is the azimuth, like the angle of the sun.
          # 90 degrees is directly above, 0 degrees is a profile view.
          phi = 20, 
          zoom = 0.5, 
          # `theta` is the rotations of the map. Keeping it at 0 will preserve
          # the standard (i.e. north is up) orientation of a plot
          theta = 0, 
          background = "white") 

# Use this to adjust the view after building the window object
render_camera(phi = 40, zoom = 0.6, theta = -29)

###############################
# Create High Quality Graphic #
###############################

# You should only move on if you have the object set up
# as you want it, including colors, resolution, viewing position, etc.

# Ensure dir exists for these graphics
if (!dir.exists(glue("desktop/{map}"))) {
  dir.create(glue("desktop/{map}"))
}

# Set up outfile where graphic will be saved.
# Note that I am not tracking the `images` directory, and this
# is because these files are big enough to make tracking them on
# GitHub difficult. 
outfile <- "../new_england/final.png"

{
  # I like to track when I start the render
  start_time <- Sys.time()
  cat(glue("Start Time: {start_time}"), "\n")
  render_highquality(
    # We test-wrote to this file above, so we know it's good
    outfile, 
    # See rayrender::render_scene for more info, but best
    # sample method ('sobol') works best with values over 256
    samples = 300,
    light = TRUE,
    lightdirection = rev(c(265, 265, 255, 255)),
    lightcolor = c(colors[3], "white", colors[8], "white"),
    lightintensity = c(750, 200, 1000, 200),
    lightaltitude = c(10, 80, 10, 80),
    # lightintensity = c(750, 50, 1000, 50),
    # lightaltitude = c(20, 80, 20, 80),
    # All it takes is accidentally interacting with a render that takes
    # hours in total to decide you NEVER want it interactive
    interactive = FALSE,
    # HDR lighting used to light the scene
    # environment_light = "assets/env/phalzer_forest_01_4k.hdr",
    # # environment_light = "assets/env/small_rural_road_4k.hdr",
    # # Adjust this value to brighten or darken lighting
    # intensity_env = 1.5,
    # # Rotate the light -- positive values move it counter-clockwise
    # rotate_env = 130,
    # This effectively sets the resolution of the final graphic,
    # because you increase the number of pixels here.
    # width = round(6000 * wr), height = round(6000 * hr),
    width = 600, height = 600
  )
  end_time <- Sys.time()
  cat(glue("Total time: {end_time - start_time}"), "\n")
}

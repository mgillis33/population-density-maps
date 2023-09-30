library(sf)
library(tigris)
library(tidyverse)
library(stars)
library(rayshader)
library(MetBrewer)
library(colorspace)

#Load kontur data

data <- st_read("../data/kontur_population_US_20220630.gpkg")

#Load states 

state_columns <- states()

#Filter for Massachusetts

massachusetts <- state_columns %>% 
  filter(NAME == "Massachusetts") %>%  
  st_transform(crs = st_crs(data))

#Check with map

massachusetts %>% 
  ggplot() +
  geom_sf()

#Do intersection on data to limit kontur to Massachusetts

st_massachusetts <- st_intersection(data, massachusetts)

# define aspect ratio based on bounding box

bb <- st_bbox(st_massachusetts)

bottom_left <- st_point(c(bb[["xmin"]], bb[["ymin"]])) %>% 
  st_sfc(crs = st_crs(data))

bottom_right <- st_point(c(bb[["xmax"]], bb[["ymin"]])) %>% 
  st_sfc(crs = st_crs(data))

# check by plotting points

massachusetts %>% 
  ggplot() +
  geom_sf() +
  geom_sf(data = bottom_left) +
  geom_sf(data = bottom_right, color = "red")

width <- st_distance(bottom_left, bottom_right)

top_left <- st_point(c(bb[["xmin"]], bb[["ymax"]])) %>%  
  st_sfc(crs = st_crs(data))

height <- st_distance(bottom_left, top_left)

# handle conditions of width or height being the longer side

if (width > height) {
  w_ratio = 1
  h_ratio = height / width
} else {
  h_ration = 1
  w_ratio = width / height
}

# convert to raster so we can then convert to matrix

size <- 1000

massachusetts_raster <- st_rasterize(st_massachusetts, nx = floor(size * w_ratio), ny = floor(size * h_ratio))

mat <- matrix(massachusetts_raster$population, nrow = floor(size * w_ratio), ncol = floor(size * h_ratio))

# create color palette

color1 <- met.brewer("Tam")
swatchplot(color1)

texture <- grDevices::colorRampPalette(color1, bias = 2)(256)
swatchplot(texture)

# plot that 3d thing!

mat %>%  
  height_shade(texture = texture) %>%  
  plot_3d(heightmap = mat, zscale = 100, solid = FALSE, shadowdepth = 0)

render_camera(theta = -20, phi = 45, zoom = .8)

img_name <- "../images/massachusetts_test.png"

{
  start_time <- Sys.time()
  cat(crayon::cyan(start_time), "\n")
  if (!file.exists(img_name)) {
    png::writePNG(matrix(1), target = img_name)
  }
  render_highquality(
    filename = img_name,
    interactive = FALSE,
    lightdirection = 280,
    lightaltitude = c(20, 80),
    lightcolor = c(color1[2], "white"),
    lightintensity = c(600, 100),
    samples = 300,
    width = 500,
    height = 500)
  end_time <- Sys.time()
  diff <- end_time - start_time
  cat(crayon::cyan(diff), "\n")
}

# plot that 3d thing!

mat2 %>%  
  height_shade(texture = texture) %>%  
  plot_3d(heightmap = mat2, zscale = 100, solid = FALSE, shadowdepth = 0)

render_camera(theta = -20, phi = 45, zoom = .8)

img_name2 <- "../images/massachusetts.png"

{
  start_time <- Sys.time()
  cat(crayon::cyan(start_time), "\n")
  if (!file.exists(img_name)) {
    png::writePNG(matrix(1), target = img_name)
  }
  render_highquality(
    filename = img_name2,
    interactive = FALSE,
    lightdirection = 280,
    lightaltitude = c(20, 80),
    lightcolor = c(color1[2], "white"),
    lightintensity = c(600, 100),
    samples = 300,
    width = 500,
    height = 500)
  end_time <- Sys.time()
  diff <- end_time - start_time
  cat(crayon::cyan(diff), "\n")
}

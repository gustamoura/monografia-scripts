library(tidyverse)
library(sf)
library(terra)

# shapefile sp tract (setor censitário)====

# população por setor censitário

geo_br_all <- geobr::read_census_tract(code_tract = 35, year = 2010)

sp_geo_br <- geo_br_all %>% 
  dplyr::filter(name_muni == "São Paulo") 

# dataset com variável de população por setor censitário
c_br <- read.csv("explanatory_variables/raw_data/census_tracts2010_brazil.csv")

sp <- c_br %>%
  dplyr::filter(code_muni == "3550308") %>%
  dplyr::mutate(code_tract = code_tract %>% as.character()) %>%
  dplyr::select(code_tract, pop_total)

# apenas setores censitários de sp que possuem população
sp_pop_geom <- sp_geo_br %>% 
  dplyr::filter(code_tract %in% c(sp$code_tract %>% unique)) %>% 
  dplyr::select(code_tract, zone, name_district) %>% 
  sf::st_transform(crs = 4326)


# listing .tif files in directory
tif_files <- list.files(path = "C:/Users/gusaz/Documents/nightlight/nightlight-raster/median-masked/",
                        pattern = "*.tif",
                        full.names = T)

# looping through .tif files, reading as raster with terra package, 
# raster cropping to just view the city of São Paulo 
# every element in the list is a raster from 2012 to 2016
nlt_list <- lapply(tif_files,
                   function(x){
                     nightlight <- terra::rast(x)
                     nightlight <- terra::crop(nightlight, sp_pop_geom, mask = TRUE) %>% 
                       terra::mask(sp_pop_geom)
                     return(nightlight)
                   })

# merging all the SpatRasters to create a single multilayered raster
# it makes easier some spatial data operations
nighttime_light_sp <- do.call(c, nlt_list)

# aggregate radiance median by census tract and by year  
# weighted average of the raster by the area inside the polygons
nlt_census_tract <- terra::extract(nighttime_light_sp, 
                                   terra::vect(sp_pop_geom),
                                   exact = T, 
                                   touches = T,
                                   fun = "mean")

# Mediana da radiância de luminosidade noturna por distrito e ano na cidade de São Paulo
# PUTTING BACK DISTRICT NAME VARIABLE, PIVOTING AND CREATING YEAR VARIABLE 
radiance_tract <- nlt_census_tract %>% 
  dplyr::bind_cols(sp_pop_geom[,"code_tract"] %>% sf::st_drop_geometry()) %>% 
  dplyr::select(code_tract, everything(), -ID) %>% 
  tidyr::pivot_longer(cols = -c("code_tract"), 
                      values_to = "radiance",
                      names_to = "ano",
                      names_pattern = "(\\d{4})") %>%  # extracting year from variable name
  dplyr::mutate(ano = as.numeric(ano)) %>% 
  dplyr::filter(ano <= 2016)

  

  
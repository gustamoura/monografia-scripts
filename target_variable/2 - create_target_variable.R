library(tidyverse)
library(sf)
library(terra)
library(plotly)

# AGREGAR CRIMES ANUALMENTE POR SETOR CENSITÁRIO NA CIDADE DE SP=====

# geometria dos setores censitários da cidade de sp
sp_geom <- geobr::read_census_tract(code_tract = 35, year = 2010) %>% 
  dplyr::filter(name_muni == "São Paulo") %>% 
  dplyr::select(code_tract, zone, name_district) %>% 
  sf::st_transform(crs = 4326)

# dados de crime diarios de sp tratados em outro script
crime_sp <- readRDS("target_variable/raw_crime_data/crime_sp_geo_vars_tidy.rds") %>% 
  sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326) %>%  # transformando colunas de lat e long para geometria
  dplyr::select(id, data_tidy, dist_name) %>%  # apenas variáveis que interessam
  dplyr::filter(data_tidy >= "2011-01-01", data_tidy <= "2016-12-01") # período em que os dados estão bons

# join com pontos de crimes
crime_setor <- sf::st_join(crime_sp, sp_geom) %>% 
  dplyr::filter(!is.na(code_tract))

# obtendo quantidade de ocorrências de crime por setor censitário e mês-ano=====
crime_month_tract <- crime_setor %>% 
  sf::st_drop_geometry() %>% # tirando geometria para group_by rodar mais rápido
  dplyr::group_by(data_tidy,
                  code_tract) %>% 
  dplyr::summarise(q_crime = n()) %>% 
  dplyr::ungroup()

# dados de crime anuais por setor censitário
crime_sp_tract_year <- crime_month_tract %>% 
  dplyr::group_by(code_tract, ano = lubridate::year(data_tidy)) %>% 
  dplyr::summarise(q_crime = sum(q_crime)) %>% 
  dplyr::ungroup() %>% 
  dplyr::filter(ano >= 2012, ano <= 2016)

# calculando taxa de crimes por 1000 habitantes por setor censitário====

# população por setor censitário
pop_tract <- read.csv("explanatory_variables/raw_data/census_tracts2010_brazil.csv") %>% 
  dplyr::filter(code_muni == 3550308) %>% # código IBGE da cidade de São Paulo
  dplyr::mutate(code_tract = as.character(code_tract)) %>% 
  dplyr::select(code_tract, pop_total)

df_crime_final <- crime_sp_tract_year %>% 
  dplyr::ungroup() %>% 
  tidyr::complete(tidyr::nesting(code_tract), 
                  ano = tidyr::full_seq(ano, period = 1)) %>%  # mantém anos com missing em q_crime
  dplyr::left_join(pop_tract, by = c("code_tract")) %>% 
  dplyr::mutate(tx_crime = q_crime/pop_total * 1000) %>% 
  dplyr::mutate(tx_crime = ifelse(is.na(tx_crime), # quando tx_crime é NA, considero valor 0
                                  0,
                                  tx_crime)) %>% 
  dplyr::select(code_tract, ano, tx_crime)


saveRDS(df_crime_final, "target_variable/target_variable.rds")





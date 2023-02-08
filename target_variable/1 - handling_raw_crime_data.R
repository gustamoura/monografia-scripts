library(tidyverse)

# função que trata as ocorrências diárias 
furto_roubo_ocorrencias_diaria_sp <- function(dados_brutos_parquet){
  
  # filtrando apenas para a cidade de São Paulo====
  
  # converte variável CIDADE para character para facilitar filtro
  dados_brutos_parquet$CIDADE <- dados_brutos_parquet$CIDADE %>% as.character()
  
  # como São Paulo aparece no dataset original?
  dados_brutos_parquet %>%
    dplyr::filter(!stringr::str_detect(CIDADE, regex("paulo", ignore_case = T))) %>% 
    dplyr::select(CIDADE) %>% 
    unique()
  
  # São Paulo aparece de 6 formas na coluna CIDADE:
  #   S.PAULO                                 
  #   Sao Paulo                               
  #   SAO PAULO                               
  #   São Paulo                               
  #   SÃO PAULO                               
  #   SÃO PAULOA                              
  
  # filtrando apenas cidade de São Paulo pelas string acima:
  crime_sp_raw <- dados_brutos_parquet %>% 
    dplyr::filter(stringr::str_detect(CIDADE, regex("paulo", ignore_case = T))) %>% 
    dplyr::filter(!stringr::str_detect(CIDADE, regex("faria", ignore_case = T))) # tirando município Paulo de Faria
  
  rm(dados_brutos_parquet)
  
  # roubo e furtos cidade de sp (2012-2021)
  df_sp <- crime_sp_raw
  
  # arrumando nome colunas: nome em minusculo, sem acentos, sem espaço e usar underline no lugar=====
  df_sp <- df_sp %>% janitor::clean_names()
  
  # REMOVENDO LINHAS REPETIDAS PARA OBTER OCORRÊNCIA ÚNICA DE FURTO E ROUBO=====
  
  # dataset original tem mais de uma linha para registrar apenas uma ocorrência de crime
  # ex: se pessoa perdeu 2 objetos num roubo, é registrado 2 linhas com mesmas datas
  # mudando apenas a informação do objeto roubado (uma para o primeiro objeto e outra para o segundo objeto)
  
  # De acordo com o que está em METODOLOGIA.PDF, extraído de http://www.ssp.sp.gov.br/transparenciassp/default.aspx,
  # ocorrências únicas de crimes são identificadas eliminando duplicatas
  # das colunas nome_delegacia, ano_bo, num_bo
  df_sp_2 <- df_sp %>% 
    dplyr::distinct(nome_delegacia,
                    ano_bo,
                    num_bo,
                    .keep_all = T)
  
  # LIMPEZA DE LINHAS COM NAs BASEADO EM VARIÁVEIS IMPORTANTES====
  df_sp_3 <- df_sp_2 %>% 
    tidyr::drop_na(datahora_registro_bo,
                   data_ocorrencia_bo,
                   hora_ocorrencia_bo)
  
  
  # filtrar DATA_OCORRENCIA_BO entre 2002 e 2022, o que irá tirar os anos estranhos como 1990, 0008, 0002, etc. ====
  df_sp_4 <- df_sp_3 %>% 
    dplyr::filter(data_ocorrencia_bo >= "2002-01-01" & data_ocorrencia_bo <= "2021-12-01")
  
  
  # ARRUMANDO COLUNA DE DATAS DE OCORRENCIA====
  # criar coluna de data ocorrência do bo com timestamp
  df_sp_4 <- df_sp_4 %>% 
    dplyr::mutate(datahora_ocorrencia_bo = paste0(data_ocorrencia_bo, " ", hora_ocorrencia_bo)) %>% 
    dplyr::mutate(datahora_ocorrencia_bo = datahora_ocorrencia_bo %>% as.POSIXct(format = "%Y-%m-%d %H:%M", tz = "GMT"))
  
  # checar se datahora_ocorrencia_bo_v2 <= DATA_OCORRENCIA_BO
  # ocorrencia do bo (quando efetivamente aconteceu o crime) deve ser sempre antes ou ao mesmo tempo do registro do bo
  df_sp_4$datahora_registro_bo <- df_sp_4$datahora_registro_bo %>% as.POSIXct(format = "%Y-%m-%d %H:%M:%S", tz = "GMT")
  
  # filtrando apeas linhas em que ocorrencia do bo aconteceu antes do seu registro
  df_sp_5 <- df_sp_4 %>% 
    dplyr::filter(datahora_ocorrencia_bo <= datahora_registro_bo)
  
  # adicionando coluna de id - importante depois
  df_sp_5 <- df_sp_5 %>% 
    dplyr::mutate(id = row_number())
  
  # FILTRANDO APENAS VARIÁVEIS DESEJADAS=====
  df_sp_6 <- df_sp_5 %>% 
    dplyr::select(id,
                  datahora_ocorrencia_bo,
                  data_ocorrencia_bo,
                  datahora_registro_bo,
                  rubrica,
                  latitude,
                  longitude,
                  logradouro,
                  numero_logradouro,
                  cep,
                  bairro)
  
  
  return(df_sp_6)
}

df_sp <- furto_roubo_ocorrencias_diaria_sp(dados_brutos_parquet = arrow::read_parquet(file = "target_variable/raw_crime_data/bulletins.parquet"))

# A PARTIR DAS OCORRENCIAS DIARIAS DE CRIMES NA CIDADE DE SP FAÇO UM TRATAMENTO NAS VARIÁVEIS DE LATITUDE E LONGITUDE

# tratando variaveis de latitude e longitude=====

# trocando vírgula por ponto (separador decimal)

# tem latitude e longitude == 0, não faz sentido, então retirar observações
df_geo_vars_tidy <- df_sp %>% 
  dplyr::mutate(latitude = stringr::str_replace(latitude, pattern = ",", "."),
                longitude = stringr::str_replace(longitude, pattern = ",", ".")) %>% 
  dplyr::mutate(latitude = as.numeric(latitude),
                longitude = as.numeric(longitude)) %>% 
  dplyr::filter(!is.na(latitude), !is.na(longitude)) %>% 
  dplyr::filter(latitude != 0 & longitude != 0)


# criar coluna com ano - mês - 01 para verificar evolução dos crimes ao longo do ano-mês

df_geo_vars_tidy <- df_geo_vars_tidy %>% 
  dplyr::mutate(ano = lubridate::year(data_ocorrencia_bo),
                mes = lubridate::month(data_ocorrencia_bo)) %>% 
  dplyr::mutate(data_tidy = paste0(ano, "-", mes, "-01") %>% as.Date(format = "%Y-%m-%d")) %>% 
  sf::st_as_sf(coords = c("longitude", "latitude"), remove = FALSE) # transformando colunas de lat e long para geometria


# usar geometria da cidade de são paulo para retirar observações com latitude e
# longitude que não estão dentro da área da cidade, mesmo que a coluna "cidade"
# informe que seja em são paulo

# São Paulo districts shapefile
dist_geom_sp <- sf::read_sf("./shapefile/DISTRITOS_SP/DISTRITO_MUNICIPAL_SP_SMDUPolygon.shp") %>% 
  dplyr::select(Nome, geometry) %>% 
  sf::st_transform(crs = 4326) %>% 
  dplyr::transmute(dist_name = snakecase::to_any_case(Nome)) # adjusting district vector name

# mesmo sistema de coordenadas para geometria de distrito e dataset de crimes
st_crs(df_geo_vars_tidy) <- st_crs(dist_geom_sp)

# JOIN pontos de crimes com geometria de são paulo com distritos=====
# para relacionar crime com distrito em que ocorreu
ids_to_delete <- sf::st_join(x = df_geo_vars_tidy, y = dist_geom_sp[,"dist_name"]) %>% 
  dplyr::filter(is.na(dist_name)) %>% # onde tem NA em dist_name é pq não está em sp
  dplyr::select(id) %>% 
  sf::st_drop_geometry() %>% 
  dplyr::pull()

# join geometria distritos com pontos de crime====
df_geo_vars_tidy <- sf::st_join(x = dist_geom_sp[,"dist_name"], y = df_geo_vars_tidy)
# st_join acima retorna um dataset sem NAs e menor que crime_sp, ou seja, 
# elimina os pontos que estão fora da cidade de São Paulo

# SALVA DATASET DE CRIMES COM COLUNAS DE LATITUDE E LONGITUDE TRATADAS
saveRDS(df_geo_vars_tidy %>% sf::st_drop_geometry(), "target_variable/raw_crime_data/crime_sp_geo_vars_tidy.rds")




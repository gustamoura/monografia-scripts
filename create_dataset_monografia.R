library(tidyverse)

# criando dataset final - juntando variável dependente com variáveis explicativas
# em apenas um dataset para posterior estimação de modelo

Y <- readRDS("target_variable/target_variable.rds") %>% 
  dplyr::filter(ano == 2012)

X <- readRDS("explanatory_variables/explanatory_variables.rds")

dataset_monografia <- Y %>% 
  dplyr::left_join(X, by = c("code_tract", "ano")) %>% 
  tidyr::drop_na() # tem setores censitários com população mas sem informações socioeconomicas, escolhi remover essas observações

# SALVAR NO FORMATO DESEJADO E FAZER ANÁLISES E ESTIMAÇÕES.
saveRDS(dataset_monografia, "dataset_monografia.rds")

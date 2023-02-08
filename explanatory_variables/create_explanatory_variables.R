library(tidyverse)
library(geobr)

# algumas variáveis por setor censitário: população, raça e algumas de renda
c_br <- read.csv("explanatory_variables/raw_data/census_tracts2010_brazil.csv")

# filtrando apenas cidade de são paulo
sp_tract_vars1 <- c_br %>% 
  dplyr::filter(code_muni == "3550308") %>% 
  dplyr::mutate(code_tract = code_tract %>% as.character()) %>% 
  dplyr::select(-c(code_muni, code_metro, code_state))

# mais variáveis por setor censitário: variáveis de renda 
# link origem do csv abaixo com dicionário das variáveis https://basedosdados.org/dataset/br-ibge-censo-demografico?bdm_table=setor_censitario_basico_2010
sp_tract_all_vars2 <- read.csv("explanatory_variables/raw_data/pop_sp_setor_censitario_2010_all_vars.csv") %>% 
  dplyr::mutate(id_setor_censitario = id_setor_censitario %>% as.character()) %>% 
  dplyr::filter(id_setor_censitario %in% c(sp_tract_vars1$code_tract %>% unique)) %>% 
  dplyr::select(-sigla_uf)

# variaveis idade homens setor censitário (18 a 29 anos)
sp_tract_vars_men <- read.csv("explanatory_variables/raw_data/homens_idade_setor_censitário.csv") %>% 
  dplyr::mutate(id_setor_censitario = id_setor_censitario %>% as.character()) %>% 
  dplyr::filter(id_setor_censitario %in% c(sp_tract_vars1$code_tract %>% unique)) %>% 
  dplyr::mutate(pop_homens_18_29 = dplyr::select(., v052:v063) %>% rowSums()) %>% 
  dplyr::select(id_setor_censitario, pop_homens_18_29)

# variaveis renda domicilio
sp_tract_vars_renda_dom <- read.csv("explanatory_variables/raw_data/renda_domicilios.csv") %>% 
  dplyr::mutate(id_setor_censitario = id_setor_censitario %>% as.character()) %>% 
  dplyr::filter(id_setor_censitario %in% c(sp_tract_vars1$code_tract %>% unique))

# variaveis pessoas alfabetizadas 5 anos mais
sp_tract_vars_alfab <- read.csv("explanatory_variables/raw_data/alfabetizados_5anos_mais.csv") %>% 
  dplyr::mutate(id_setor_censitario = id_setor_censitario %>% as.character()) %>% 
  dplyr::filter(id_setor_censitario %in% c(sp_tract_vars1$code_tract %>% unique))

# variaveis domicilios alugados
sp_tract_vars_dom_alugados <- read.csv("explanatory_variables/raw_data/domicilios_alugados.csv") %>% 
  dplyr::mutate(id_setor_censitario = id_setor_censitario %>% as.character()) %>% 
  dplyr::filter(id_setor_censitario %in% c(sp_tract_vars1$code_tract %>% unique))

# dataset setor censitario com todas as variáveis: renda, população por idade, raça
df_sp_tract_vars <- dplyr::left_join(sp_tract_vars1, sp_tract_all_vars2, by = c("code_tract" = "id_setor_censitario")) %>% 
  dplyr::left_join(sp_tract_vars_men, by = c("code_tract" = "id_setor_censitario")) %>% 
  dplyr::left_join(sp_tract_vars_renda_dom,  by = c("code_tract" = "id_setor_censitario")) %>% 
  dplyr::left_join(sp_tract_vars_alfab,  by = c("code_tract" = "id_setor_censitario")) %>% 
  dplyr::left_join(sp_tract_vars_dom_alugados,  by = c("code_tract" = "id_setor_censitario")) %>% 
  dplyr::select(-c(v001, v002, v003, v004))# removendo variáveis repetidas que já estão em sp_tract_vars1

# chamando script para criar dataset com dados de radiancia (iluminação pública) por setor censitário
source("explanatory_variables/radiance_by_census_tract.R")

# dataset com as variáveis explicativas
X <- df_sp_tract_vars %>% 
  dplyr::left_join(radiance_tract, by = c("code_tract")) %>% 
  dplyr::filter(ano == 2012) %>% 
  dplyr::mutate(tx_dom_alugados = dom_alugados / households_total,
                tx_alfab = pessoas_5anos_mais_alfab / pop_total,
                log_renda_p_dom = log(total_renda / households_total),
                homens_jovens_prop = pop_homens_18_29/pop_total,
                preto_pardo_prop = (pop_preta + pop_parda)/pop_total,
                lower_min_wage_prop_dezanomais = (income_0 + income_1 + income_2) / pop_total) %>% 
  dplyr::select(code_tract,
                ano,
                radiance,
                favela, 
                tx_dom_alugados, 
                tx_alfab, 
                log_renda_p_dom, 
                homens_jovens_prop,
                preto_pardo_prop, 
                lower_min_wage_prop_dezanomais) %>% 
  dplyr::filter(!is.infinite(log_renda_p_dom)) %>% 
  tidyr::drop_na()

# salva dataset com as variáveis explicativas
saveRDS(X, "explanatory_variables/explanatory_variables.rds")








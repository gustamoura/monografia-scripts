# monografia-scripts
Documentação e organização dos scripts e parte das bases usadas na minha monografia que analisei o impacto da iluminação pública sobre a criminalidade


# Ordem dos códigos para rodar e obter o dataset usado na monografia:

 ## 1 - "target_variable/create_explanatory_variables.R"
  - Script que trata e cria dataset com apenas as variáveis explicativas;
  - Dentro deste script é rodado um script auxiliar que cria a variável de iluminação pública (radiance_by_census_tract.R) mas esse script depende de arquivos .tif vindos daqui
https://eogdata.mines.edu/nighttime_light/annual/v21/2012/, os quais são arquivos muito pesados. Confira antes se tem armazenamento local para baixá-los localmente;

## 2.1 - "target_variable/1 - handling_raw_crime_data.R"
  - Trata os dados brutos de crimes vindos originalmente de um arquivo .parquet, criado por uma outra pessoa que requisitou-os da Secretaria de Segurança Pública de São Paulo. 
  Tive acesso a este .parquet no seguinte link https://www.kaggle.com/datasets/danlessa/sao-paulo-theft-registries mas tenho o protocolo de requisição original de acordo com a lei de acesso a informação;
 
## 2.2 - "target_variable/2 - create_target_variable.R"
  - Agrega os dados diários de crimes feitos no script anterior anualmente e por setor censitário de acordo com o Censo IBGE de 2010;
  - Cria dataset com a variável dependente, isto é, a taxa de crimes por 1000 habitantes;
  
## 3 - "create_dataset_monografia.R"
  - Faz um join entre o dataset com as explicativas e a dependente para criar a cross-section final usado nas regressões da monografia.

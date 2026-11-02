# =============================================================================
# BMC DATALAB CHALLENGE - RETO B | Corre todo el proyecto (main)
#
# Este es el único archivo que hay que correr. Ejecuta, en orden:
#   1. 02_code/setup.R                revisa R, la carpeta de trabajo y los paquetes
#   2. 02_code/descriptivas.R         estadísticas descriptivas y gráficos de las variables
#                                     (03_outputs/descriptivas/, unos segundos)
#   3. 02_code/ipap_concurso_final.R  el modelo: validación, prueba histórica y pronóstico a
#                                     12 meses (03_outputs/, alrededor de 1 hora y 45 minutos)
#
# CARPETAS
#   01_data/           la base de datos
#   02_code/           los scripts
#   03_outputs/        todos los resultados (tablas, gráficos y RESULTADOS.md)
#   04_documentation/  datos, reproducibilidad y referencias
#
# CÓMO SE CORRE
# Abrir ipap-bmc-reto-b.Rproj en RStudio, abrir este archivo y hacer clic en Source
# (Ctrl + Shift + S). Sin RStudio, desde una terminal en la carpeta del repositorio:
#   Rscript main.R
#
# Cada script se corre en un entorno limpio (local = new.env()), así que el orden no cambia
# ningún resultado: da lo mismo que correr cada script por separado.
# =============================================================================

inicio <- Sys.time()

correr <- function(archivo) {
  cat('\n######## Corriendo', archivo, '########\n')
  source(archivo, local = new.env(), print.eval = TRUE, encoding = 'UTF-8')
}

correr('02_code/setup.R')
correr('02_code/descriptivas.R')
correr('02_code/ipap_concurso_final.R')

cat(sprintf('\nProyecto completo. Tiempo total: %.1f minutos.\n',
            as.numeric(difftime(Sys.time(), inicio, units = 'mins'))))

# =============================================================================
# BMC DATALAB CHALLENGE - RETO B | Preparación del entorno (setup)
#
# QUÉ HACE ESTE SCRIPT
# Deja el computador listo para correr el proyecto. No calcula nada del modelo.
#   1. Revisa la versión de R.
#   2. Revisa que la carpeta de trabajo sea la del repositorio (que encuentre el Excel).
#   3. Instala los paquetes que falten.
#   4. Muestra las versiones instaladas junto a las que se usaron para generar la carpeta
#      03_outputs/. Si la de xgboost es distinta, los modelos XGBoost pueden dar cifras algo
#      distintas (ver 04_documentation/REPRODUCIBILIDAD.md).
#
# Lo corre main.R al comienzo. También se puede correr solo: Rscript 02_code/setup.R
# =============================================================================

# 1. Versión de R --------------------------------------------------------------
if (getRversion() < '4.3.0') {
  warning('Se recomienda R 4.3 o más reciente (las versiones actuales de xgboost lo piden). ',
          'Versión instalada: ', getRversion(), call. = FALSE)
}

# 2. Carpeta de trabajo --------------------------------------------------------
if (!file.exists('01_data/IPAP_De_completa.xlsx')) {
  stop('No se encuentra 01_data/IPAP_De_completa.xlsx. Abre el proyecto con ipap-bmc-reto-b.Rproj ',
       'o fija la carpeta de trabajo en la carpeta del repositorio con setwd().', call. = FALSE)
}

# 3. Paquetes ------------------------------------------------------------------
# Versiones con las que se generó la carpeta 03_outputs/
VERSIONES_USADAS <- c(readxl = '1.6.0', ggplot2 = '4.0.3', forecast = '9.0.2', urca = '1.3.4',
                      vars = '1.6.1', lmtest = '0.9.40', tseries = '0.10.63', ranger = '0.18.0',
                      xgboost = '3.4.2.1')

faltan <- names(VERSIONES_USADAS)[!vapply(names(VERSIONES_USADAS), requireNamespace,
                                          logical(1), quietly = TRUE)]
if (length(faltan) > 0) {
  cat('Instalando paquetes que faltan:', paste(faltan, collapse = ', '), '\n')
  install.packages(faltan)
}

# 4. Versiones ------------------------------------------------------------------
version_instalada <- function(p) {
  if (requireNamespace(p, quietly = TRUE)) as.character(packageVersion(p)) else 'NO INSTALADO'
}
versiones <- data.frame(Paquete   = names(VERSIONES_USADAS),
                        Instalada = vapply(names(VERSIONES_USADAS), version_instalada, character(1)),
                        Usada     = unname(VERSIONES_USADAS))
versiones$Igual <- ifelse(versiones$Instalada == versiones$Usada, 'sí', 'no')

cat('\n', R.version.string, '\n', sep = '')
cat('Paquetes (Usada = versión con la que se generó la carpeta 03_outputs/):\n')
print(versiones, row.names = FALSE)
if (versiones$Igual[versiones$Paquete == 'xgboost'] == 'no') {
  cat('\nAviso: la versión de xgboost es distinta. Los modelos XGBoost y los promedios que los\n',
      'incluyen pueden dar cifras algo distintas a las de RESULTADOS.md.\n', sep = '')
}
cat('\nEntorno listo.\n')

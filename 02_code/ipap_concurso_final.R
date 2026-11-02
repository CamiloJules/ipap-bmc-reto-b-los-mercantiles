# =============================================================================
# BMC DATALAB CHALLENGE - RETO B | Pronóstico del IPAP-BMC
#
# QUÉ HACE ESTE SCRIPT
# Pronostica el Índice de Precios Agropecuarios (IPAP) de la Bolsa Mercantil de
# Colombia para los próximos 12 meses. Para eso ajusta siete modelos, los evalúa con una
# prueba histórica y con una validación interna, y entrega como pronóstico final el promedio
# simple de los siete. Todo el modelo se corre de principio a fin con este único archivo (lo
# corre main.R, o se puede correr solo desde la carpeta del repositorio).
#
# MODELOS
#   Autorregresivos (se apoyan en la historia del IPAP; el VECM suma el IPC)
#     1. SARIMA automático
#     2. ARMA(2,2) con componente estacional SAR(1), sobre el crecimiento mensual
#     3. VECM de Johansen entre el IPAP y el IPC de bienes no durables
#   Machine learning (aprenden relaciones no lineales con árboles de decisión)
#     4. Random Forest, solo con la historia del IPAP
#     5. Random Forest con variables exógenas
#     6. XGBoost, solo con la historia del IPAP
#     7. XGBoost con variables exógenas
#   Modelo final ('Promedio (todos)'): promedio simple de los siete. El código lo compara con
#   el mejor modelo individual de ML (el de menor MAPE de validación) en el PASO 11b.
#
# DATOS (un Excel mensual, de enero de 2011 a septiembre de 2026)
#   IPAP                       : Bolsa Mercantil de Colombia (BMC)
#   TRM promedio del mes       : Banco de la República
#   IPC de bienes no durables  : DANE
#   ISE agropecuario           : DANE
#   Precios internacionales de alimentos (índice FAO y subíndices de carne, lácteos, cereales,
#                                aceites y azúcar): FAO
#   Anomalía de lluvia (del mes y acumulada 3 y 6 meses): NASA POWER, promediada entre
#                                20 departamentos con la ponderación de cada uno en el IPAP
#   Insumos (fertilizantes en dólares por tonelada y petróleo): Banco Mundial, Pink Sheet
#
# REGLAS DEL RETO B QUE SIGUE EL CÓDIGO
#   - Prueba histórica : los últimos 12 meses de la muestra (un solo origen, 12 pasos).
#   - MAPE             : sobre el nivel del IPAP, sin excluir ningún mes.
#   - Pronóstico final : se reestima con toda la muestra y se pronostican 12 meses más.
#   - Las decisiones de modelado (hiperparámetros, variables exógenas, modelo final) se toman con
#     una validación interna hecha DENTRO del entrenamiento, nunca con la prueba. Así la prueba
#     histórica queda como una medida honesta de cómo se comportaría el modelo con datos nuevos.
#
# CÓMO ESTÁ ORGANIZADO (cada PASO explica su teoría y su criterio)
#   PASO 0     Instalación de paquetes y librerías.
#   PASO 1     Parámetros: horizonte, número de orígenes de validación, rejillas de
#              hiperparámetros, grupos de exógenas y rezagos de publicación.
#   PASO 2     Carga de la base, construcción de las exógenas y partición en entrenamiento y prueba.
#   PASO 3     Orden de integración de las series (Dickey-Fuller aumentada).
#   PASO 4     Métricas de error (MAPE y RMSE).
#   PASO 5     Modelos autorregresivos: SARIMA, ARMA+SAR y VECM.
#   PASO 6     Pruebas de supuestos sobre los residuos de los modelos autorregresivos.
#   PASO 7     Modelos de ML: atributos, estrategia directa, Random Forest y XGBoost.
#   PASO 8     Validación interna con orígenes móviles (walk-forward).
#   PASO 9     Ajuste de hiperparámetros con el MAPE de validación.
#   PASO 10    Selección de exógenas por ablación de grupos.
#   PASO 11    Evaluación de los siete modelos y de los promedios.
#   PASO 11b   Comparación del modelo final con el mejor modelo de ML.
#   PASO 12    Tablas de entrega: prueba histórica y pronóstico a 12 meses.
#   PASO 13    Importancia de las variables.
#   PASO 14    Gráficos.
#
# ARCHIVOS QUE GENERA (carpeta OUT_DIR)
#   tabla_comparacion_modelos.csv, mape_por_origen.csv, efecto_exogenas.csv
#   comparacion_elegido_vs_mejor_ml.csv, prueba_historica_elegido_vs_mejor_ml.csv,
#   mape_por_origen_elegido_vs_mejor_ml.csv
#   prueba_historica_todos.csv, prueba_historica_elegido.csv
#   pronostico_12m_todos.csv, pronostico_12m_elegido.csv
#   supuestos_arima.csv, grilla_*.csv (una por modelo de ML), ablacion_grupos_exog.csv,
#   importancia_por_grupo.csv, importancia_por_variable.csv
#   g1_prueba_historica.png, g2_pronostico_12m.png, g3_importancia_random_forest.png,
#   g4_importancia_xgboost.png, g5_elegido_vs_mejor_ml.png
#
# -----------------------------------------------------------------------------
# MARCO TEÓRICO Y REFERENCIAS (resumen; cada PASO amplía la parte que le toca)
# -----------------------------------------------------------------------------
# 1. Por qué un promedio de modelos. Los errores de modelos con supuestos distintos (series
#    de tiempo, cointegración, árboles) no se mueven juntos y se compensan en parte, así que
#    su promedio suele errar menos que cada modelo por separado (Bates y Granger, 1969;
#    revisión en Timmermann, 2006). El promedio simple es muy difícil de superar con pesos
#    estimados porque estimar los pesos agrega error (Claeskens et al., 2016), y las
#    combinaciones estuvieron entre los mejores métodos de la competencia M4 (Makridakis
#    et al., 2020). Para precios de alimentos, McWilliams, Stewart e Isengildina Massa (2026)
#    encuentran que promediar un bosque aleatorio autorregresivo con un SARIMA mejora la
#    precisión y el sesgo frente a cada modelo solo.
#    Una aclaración sobre la elección. El promedio no tiene que ser el modelo con menor MAPE de
#    validación; un modelo individual de ML puede serlo. Se escoge el promedio por diversificación
#    del riesgo de especificación (un modelo con exógenas puede fallar si las exógenas cambian de
#    régimen) y por su desempeño en la prueba. Como esa escogencia no sale solo de la validación,
#    el código muestra la comparación con el mejor modelo de ML en validación, prueba y mes a mes
#    (PASO 11b), para que el lector pueda juzgarla.
#
# 2. Por qué Random Forest y XGBoost. Son métodos de árboles que capturan relaciones no
#    lineales e interacciones entre muchas variables sin exigir una forma funcional
#    (Breiman, 2001; Friedman, 2001; Chen y Guestrin, 2016). En pronóstico de inflación con
#    muchos regresores, Random Forest es de lo que mejor funciona frente a modelos lineales
#    y autorregresivos (Medeiros et al., 2021). Para Colombia: el Banco de la República usa
#    Random Forest para el nowcasting de la inflación con datos de búsquedas en línea
#    (Roldán-Ferrín y Parra-Polanía, 2025) y XGBoost para pronosticar 33 canastas de inflación
#    de alimentos, donde el ML supera a los modelos tradicionales (Anzola Bravo y Poveda, 2025).
#    Para precios agrícolas colombianos, Sánchez Conde (2024, Universidad Nacional de Colombia)
#    compara ARIMAX, LSTM, Random Forest, SVM y un modelo híbrido ARIMA + Random Forest (el bosque
#    se entrena con los residuos del ARIMA). El híbrido resulta el mejor, y la autora prefiere
#    Random Forest sobre modelos más complejos por su buen desempeño con pocos datos y su menor
#    propensión al sobreajuste, con validación en divisiones temporales y búsqueda de
#    hiperparámetros en rejilla. Este script sigue la misma lógica de validación y de ajuste, y
#    combina árboles y modelos autorregresivos por promedio en vez de entrenar el bosque sobre
#    residuos.
#
# 3. Estrategia directa. Un modelo por horizonte (h = 1,...,12) evita acumular errores al
#    reutilizar pronósticos y no obliga a pronosticar las exógenas (Ben Taieb et al., 2012).
#
# 4. Validación hacia adelante. Los orígenes móviles nunca entrenan con datos posteriores al
#    origen; es la forma de imitar el uso real del pronóstico (ver la discusión de validación
#    en series autorregresivas en Bergmeir, Hyndman y Koo, 2018).
#
# 5. Selección de exógenas. La importancia por permutación o por ganancia no dice si una
#    variable ayuda a pronosticar fuera de muestra, y se reparte de forma sesgada entre
#    variables correlacionadas (Strobl et al., 2007). Por eso las variables se descartan con
#    una ablación por grupos sobre el MAPE de validación (PASO 10), no por su importancia.
#
# 6. Modelos autorregresivos. SARIMA con selección automática por AICc (Hyndman y Khandakar,
#    2008) y VECM por máxima verosimilitud de Johansen (Johansen, 1988, 1991).
#
# REFERENCIAS (también en 04_documentation/REFERENCIAS.md)
#   Anzola Bravo, C. y Poveda, P. (2025). Forecasting Disaggregated Food Inflation Baskets in
#     Colombia with an XGBoost Model. Borradores de Economía No. 1335, Banco de la República.
#     https://doi.org/10.32468/be.1335
#   Bates, J. M. y Granger, C. W. J. (1969). The combination of forecasts. Operational
#     Research Quarterly, 20(4), 451-468.
#   Ben Taieb, S., Bontempi, G., Atiya, A. F. y Sorjamaa, A. (2012). A review and comparison of
#     strategies for multi-step ahead time series forecasting based on the NN5 forecasting
#     competition. Expert Systems with Applications, 39(8), 7067-7083.
#   Bergmeir, C., Hyndman, R. J. y Koo, B. (2018). A note on the validity of cross-validation
#     for evaluating autoregressive time series prediction. Computational Statistics & Data
#     Analysis, 120, 70-83.
#   Breiman, L. (2001). Random forests. Machine Learning, 45(1), 5-32.
#   Chen, T. y Guestrin, C. (2016). XGBoost: a scalable tree boosting system. Proceedings of
#     the 22nd ACM SIGKDD, 785-794.
#   Claeskens, G., Magnus, J. R., Vasnev, A. L. y Wang, W. (2016). The forecast combination
#     puzzle: a simple theoretical explanation. International Journal of Forecasting, 32(3),
#     754-762.
#   Dickey, D. A. y Fuller, W. A. (1979). Distribution of the estimators for autoregressive time
#     series with a unit root. Journal of the American Statistical Association, 74(366), 427-431.
#   Friedman, J. H. (2001). Greedy function approximation: a gradient boosting machine. Annals
#     of Statistics, 29(5), 1189-1232.
#   Geurts, P., Ernst, D. y Wehenkel, L. (2006). Extremely randomized trees. Machine Learning,
#     63(1), 3-42.
#   Hyndman, R. J. y Khandakar, Y. (2008). Automatic time series forecasting: the forecast
#     package for R. Journal of Statistical Software, 27(3), 1-22.
#   Johansen, S. (1988). Statistical analysis of cointegration vectors. Journal of Economic
#     Dynamics and Control, 12(2-3), 231-254.
#   Johansen, S. (1991). Estimation and hypothesis testing of cointegration vectors in Gaussian
#     vector autoregressive models. Econometrica, 59(6), 1551-1580.
#   Makridakis, S., Spiliotis, E. y Assimakopoulos, V. (2020). The M4 Competition: 100,000 time
#     series and 61 forecasting methods. International Journal of Forecasting, 36(1), 54-74.
#   McWilliams, W., Stewart, S. L. e Isengildina Massa, O. (2026). Food price inflation
#     forecasting: insights from a Macroeconomic Auto-Regressive Random Forest approach.
#     Food Policy, 142, 103115.
#   Medeiros, M. C., Vasconcelos, G. F. R., Veiga, A. y Zilberman, E. (2021). Forecasting
#     inflation in a data-rich environment: the benefits of machine learning methods. Journal
#     of Business & Economic Statistics, 39(1), 98-119.
#   Roldán-Ferrín, F. y Parra-Polanía, J. A. (2025). Enhancing inflation nowcasting with online
#     search data: a random forest application for Colombia. Borradores de Economía No. 1318,
#     Banco de la República. https://doi.org/10.32468/be.1318
#   Sánchez Conde, O. L. (2024). Predicción de precios del mercado agrícola en Colombia:
#     aplicación de modelos de aprendizaje automático y minería de datos para la toma de
#     decisiones en la agricultura. Tesis de Maestría en Ingeniería Analítica, Universidad
#     Nacional de Colombia, Sede Medellín.
#   Strobl, C., Boulesteix, A.-L., Zeileis, A. y Hothorn, T. (2007). Bias in random forest
#     variable importance measures: illustrations, sources and a solution. BMC Bioinformatics, 8, 25.
#   Timmermann, A. (2006). Forecast combinations. En Handbook of Economic Forecasting, vol. 1,
#     cap. 4, 135-196. Elsevier.
# =============================================================================


# PASO 0 - INSTALACIÓN DE PAQUETES Y LIBRERÍAS----------------------------------

paquetes <- c('readxl', 'ggplot2', 'forecast', 'urca', 'vars', 'lmtest',
              'tseries', 'ranger', 'xgboost')
for (p in paquetes) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
suppressPackageStartupMessages({
  library(readxl); library(ggplot2); library(forecast); library(urca)
  library(lmtest); library(tseries); library(ranger)
})
# vars y xgboost son opcionales: si alguno no está instalado, los modelos que dependen
# de él se omiten (el VECM necesita vars; XGBoost necesita xgboost).
vars_ok <- requireNamespace('vars', quietly = TRUE)
xgb_ok  <- requireNamespace('xgboost', quietly = TRUE)
if (vars_ok) suppressPackageStartupMessages(library(vars))
if (xgb_ok)  suppressPackageStartupMessages(library(xgboost))
if (!vars_ok) message('Paquete vars no disponible: se omite el VECM.')
if (!xgb_ok)  message('Paquete xgboost no disponible: se omite XGBoost.')


# PASO 1 - PARÁMETROS-----------------------------------------------------------

RUTA     <- '01_data/IPAP_De_completa.xlsx' # ruta relativa a la carpeta del proyecto
# Excel con la base mensual (primera hoja). Columnas: Fecha, IPAP, trm_promedio_mes, IPC_No_durables,
# ISE_Agro, fao_ffpi_total, fao_carne, fao_lacteos, fao_cereales, fao_aceites, fao_azucar,
# precip_anom, precip_anom_3m, precip_anom_6m, fert_usd y petroleo_usd (ver 04_documentation/DATOS.md).
OUT_DIR  <- '03_outputs'                      # carpeta donde se guardan tablas y gráficos
H        <- 12     # horizonte de pronóstico (meses)
HOLD     <- 12     # meses de prueba (los últimos de la muestra)
NVAL     <- 16     # orígenes de la validación interna (16 cubre desde enero de 2021; usa 8 para pruebas rápidas)
STEP_VAL <- 3      # separación (meses) entre orígenes de validación

# Rejillas de hiperparámetros de los modelos de ML. Cada combinación se evalúa con el MAPE de
# validación (PASO 9) y se escoge la mejor. Las rejillas cubren valores bajos y altos de cada
# hiperparámetro; si el mejor valor cayera en el borde de una rejilla, convendría ampliarla.
GRID_L     <- c(3, 6, 12)           # rezagos del crecimiento del IPAP, modelos sin exógenas
GRID_L_X   <- c(3, 6)               # rezagos del crecimiento del IPAP, modelos con exógenas
GRID_LX    <- c(3, 6)               # rezagos de los precios (TRM, IPC, insumos), modelos con exógenas
GRID_MTRY  <- c(0.1, 0.2, 1/3, 1)   # fracción de atributos por corte, RF con exógenas
GRID_MNS   <- c(5, 20)              # tamaño mínimo de hoja del Random Forest
GRID_SPLIT <- c('variance', 'extratrees')  # RF estándar o Extra Trees (cortes aleatorios, ver PASO 7)
GRID_DEPTH <- c(1, 2, 3)            # profundidad de los árboles de XGBoost
NR         <- c(50, 100, 150, 250)  # rondas de XGBoost sin exógenas
NR_X       <- c(300, 500, 800, 1200)  # rondas de XGBoost con exógenas
NTREE      <- 500                   # árboles del Random Forest
NTHREADS   <- max(1, parallel::detectCores() - 1)  # núcleos para ranger (no cambia los resultados)
SEED     <- 2026

# Grupos de variables exógenas que usan los modelos de ML con exógenas: 'trm', 'ipc', 'ise',
# 'fao' (precios internacionales de alimentos), 'clima' (anomalía de lluvia ponderada por
# departamento) e 'insumos' (fertilizantes y petróleo, en dólares).
GRUPOS_EXOG <- c('trm', 'ipc', 'ise', 'fao', 'clima', 'insumos')

# NOTA: VARIABLES QUE SE PROBARON Y SE QUITARON
# También se probaron el ONI (índice del fenómeno de El Niño y La Niña) y el IPP agropecuario como
# variables exógenas. Se quitaron porque no mejoraban el pronóstico: al sacarlos, el MAPE de
# validación del Random Forest con exógenas bajó (0.18 puntos el ONI y 0.14 el IPP). El efecto del
# clima sobre los precios ya lo recoge la anomalía de lluvia, y el IPP repite la información del
# propio IPAP. Por eso no están en la base ni en el código.
# Decisiones sobre los grupos que se conservan
#  - TRM: se mantiene aunque en la ablación su salida puede mejorar levemente el MAPE, porque el
#    costo de los insumos entra en dólares (fert_usd, petroleo_usd) y la TRM permite al modelo
#    reconstruir su costo en pesos.
#  - Insumos: es el grupo cuya salida más empeora el MAPE en la ablación.
#  - ISE: se mantiene porque en una prueba retrospectiva sobre cuatro cortes históricos, quitarlo
#    empeoró el pronóstico fuera de muestra del Random Forest en todos los cortes.
#  - Clima y FAO: su salida casi no mueve el MAPE de validación, pero ganan importancia en el
#    horizonte de 12 meses, por eso se conservan.

# Estacionalidad en los modelos de ML: 'sincos' (seno y coseno del mes, que unen diciembre con
# enero de forma continua), 'mes' (el número de mes, 1 a 12) o 'ninguna'.
ESTACIONALIDAD <- 'sincos'

# MODELO FINAL. Es el promedio simple de todos los modelos (autorregresivos y de ML). El código
# lo compara con el mejor modelo de ML por MAPE de validación (ver PASO 11b).
MODELO_FINAL <- 'Promedio (todos)'
ARIMA_RAPIDO      <- FALSE         # TRUE = búsqueda stepwise de auto.arima (mucho más rápido, algo menos exhaustiva)

# Rezago de publicación de cada exógena, en meses: la fila del mes t solo usa lo que ya
# era público en ese momento, para que el pronóstico no use información del futuro. El supuesto es
# que el pronóstico se hace cuando ya se publicaron el IPAP y el IPC del último mes (alrededor del
# día 10 del mes siguiente). El ISE llega hasta agosto, un mes menos que el IPAP, por eso su
# rezago es 1. Para una versión más estricta con el ISE, ponlo en 2. FAO, clima e insumos se
# publican a comienzos del mes siguiente y se dejan en 1 por prudencia (ponlos en 0 si al momento
# del pronóstico ya se tiene el dato del mes).
PUB_LAG <- list(trm = 0, ipc = 0, ise = 1, fao = 1, clima = 1, insumos = 1)

dir.create(OUT_DIR, showWarnings = FALSE)
set.seed(SEED)


# PASO 2 - CARGAR LA BASE Y PARTIR EN ENTRENAMIENTO Y PRUEBA--------------------

# Fuente: BMC (IPAP), Banco de la República (TRM), DANE (IPC e ISE), FAO, NASA POWER (lluvia) y Banco Mundial (insumos)
datos <- data.frame(read_excel(RUTA))
COLUMNAS <- c('Fecha', 'IPAP', 'trm_promedio_mes', 'IPC_No_durables', 'ISE_Agro',
              'fao_ffpi_total', 'fao_carne', 'fao_lacteos', 'fao_cereales', 'fao_aceites', 'fao_azucar',
              'precip_anom', 'precip_anom_3m', 'precip_anom_6m', 'fert_usd', 'petroleo_usd')
faltan <- setdiff(COLUMNAS, names(datos))
if (length(faltan) > 0) stop('Faltan columnas en el Excel: ', paste(faltan, collapse = ', '))
datos$Fecha <- as.Date(datos$Fecha)
datos <- datos[order(datos$Fecha), ]

stopifnot(!anyDuplicated(format(datos$Fecha, '%Y-%m')))
idx_mes <- as.integer(format(datos$Fecha, '%Y')) * 12 + as.integer(format(datos$Fecha, '%m'))
stopifnot(all(diff(idx_mes) == 1))                     # sin meses faltantes
stopifnot(!anyNA(datos[, c('IPAP', 'trm_promedio_mes', 'IPC_No_durables')]))

# Meses vacíos al final de una serie (solo se permiten al final)
nas_cola <- function(v) {
  k <- sum(is.na(v))
  stopifnot(k == 0 || all(is.na(tail(v, k))))
  k
}
stopifnot(PUB_LAG$ise >= nas_cola(datos$ISE_Agro))
cat(sprintf('Meses sin dato al final: ISE_Agro = %d (rezago de publicación: %d)\n',
            nas_cola(datos$ISE_Agro), PUB_LAG$ise))

y      <- datos$IPAP
ly     <- log(y)                                       # los modelos trabajan en logaritmos
mes    <- as.integer(format(datos$Fecha, '%m'))
INICIO <- c(as.integer(format(datos$Fecha[1], '%Y')), as.integer(format(datos$Fecha[1], '%m')))
stopifnot(INICIO[2] == 1)    # el VECM usa dummies estacionales que parten de enero

# Variables exógenas, en una matriz con una columna por variable. El nombre de cada columna
# empieza por el nombre de su grupo (trm, ipc, ise, fao, clima, insumos).
COL_EXOG <- c(trm = 'trm_promedio_mes', ipc = 'IPC_No_durables', ise = 'ISE_Agro',
              fao_total = 'fao_ffpi_total', fao_carne = 'fao_carne', fao_lacteos = 'fao_lacteos',
              fao_cereales = 'fao_cereales', fao_aceites = 'fao_aceites', fao_azucar = 'fao_azucar',
              clima_anom = 'precip_anom', clima_3m = 'precip_anom_3m', clima_6m = 'precip_anom_6m',
              insumos_fert_usd = 'fert_usd', insumos_petroleo = 'petroleo_usd')
EXOG <- sapply(COL_EXOG, function(cn) as.numeric(datos[[cn]]))
colnames(EXOG) <- names(COL_EXOG)

# Meses vacíos al final de cada variable: no pueden superar su rezago de publicación
# (los NA al inicio, por ejemplo en acumulados móviles, no importan: esas filas no se usan)
nas_fin <- function(v) { r <- rle(is.na(v)); if (tail(r$values, 1)) tail(r$lengths, 1) else 0L }
for (nm in colnames(EXOG)) {
  g <- sub('_.*', '', nm)
  if (PUB_LAG[[g]] < nas_fin(EXOG[, nm]))
    stop(nm, ' tiene ', nas_fin(EXOG[, nm]), ' meses vacíos al final y su rezago de publicación es ',
         PUB_LAG[[g]], '. Sube el rezago en PUB_LAG o completa la serie.')
  if (anyNA(head(EXOG[, nm], nrow(EXOG) - nas_fin(EXOG[, nm]))) && !(nm %in% c('clima_3m', 'clima_6m')))
    stop(nm, ' tiene meses vacíos en medio de la serie.')
}
cat('Grupos de exógenas en uso:', paste(GRUPOS_EXOG, collapse = ', '), '\n')

n      <- length(y)
n_tr   <- n - HOLD                                     # tamaño de la muestra de entrenamiento
lab    <- format(datos$Fecha, '%Y-%m')
ult    <- as.Date(format(datos$Fecha[n], '%Y-%m-01'))
lab_fut <- format(seq(ult, by = 'month', length.out = H + 1)[-1], '%Y-%m')

# Muestra de entrenamiento: enero de 2011 a septiembre de 2025
# Muestra de prueba (prueba histórica del concurso): octubre de 2025 a septiembre de 2026
cat(sprintf('Muestra: %s a %s (%d meses)\n', lab[1], lab[n], n))
cat(sprintf('Entrenamiento: %s a %s | Prueba: %s a %s\n', lab[1], lab[n_tr], lab[n_tr + 1], lab[n]))
cat(sprintf('Pronóstico futuro: %s a %s\n', lab_fut[1], lab_fut[H]))

real_test <- y[(n_tr + 1):n]
plot(datos$Fecha[1:n_tr], y[1:n_tr], type = 'l', xlab = '', ylab = 'IPAP',
     main = 'IPAP-BMC: muestra de entrenamiento')


# PASO 3 - ORDEN DE INTEGRACIÓN DE LAS SERIES (MUESTRA DE ENTRENAMIENTO)--------

# Dickey-Fuller aumentada (hasta 12 rezagos, el número exacto lo elige el BIC).
# H0: raíz unitaria. Si el estadístico tau es MAYOR que el crítico al 5%, no se rechaza
# H0 y la serie no es estacionaria. Para ser I(1): no estacionaria en niveles y
# estacionaria en diferencias (Dickey y Fuller, 1979). Esto justifica trabajar el IPAP en
# logaritmos y en crecimiento (ARMA), o en niveles con cointegración (VECM).
series_adf <- list(IPAP = ly[1:n_tr], IPC_nodur = log(EXOG[1:n_tr, 'ipc']),
                   TRM = log(EXOG[1:n_tr, 'trm']), ISE_agro = log(EXOG[1:n_tr, 'ise']))
raiz <- do.call(rbind, lapply(names(series_adf), function(v) {
  niv <- ur.df(series_adf[[v]], lags = 12, selectlags = 'BIC', type = 'trend')
  dif <- ur.df(diff(series_adf[[v]]), lags = 12, selectlags = 'BIC', type = 'drift')
  data.frame(variable = v,
             tau_niveles = round(niv@teststat[1], 2), critico_5pct = niv@cval[1, 2],
             tau_diferencias = round(dif@teststat[1], 2), critico_5pct_dif = dif@cval[1, 2],
             orden = ifelse(niv@teststat[1] > niv@cval[1, 2] & dif@teststat[1] < dif@cval[1, 2],
                            'I(1)', 'revisar'))
}))
print(raiz)
# El IPC de no durables tiene una inflación muy persistente (subió mucho en 2021 y 2022),
# por lo que su ADF en diferencias puede salir en 'revisar'. Con menos rezagos, y con las pruebas de
# Phillips-Perron y de Zivot-Andrews (que admite un cambio estructural), sí resulta estacionaria
# en diferencias, de modo que el tratamiento como I(1) se mantiene.


# PASO 4 - MÉTRICAS-------------------------------------------------------------

# MAPE (%) = 100 * promedio de |(dato real - dato pronosticado) / dato real|
mape <- function(real, pred) 100 * mean(abs((real - pred) / real))
rmse <- function(real, pred) sqrt(mean((real - pred)^2))


# PASO 5 - MODELOS AUTORREGRESIVOS----------------------------------------------

# Todos los modelos son funciones f(ly, mes, H, ex) que reciben el historial (en
# logaritmos, el mes calendario y las exógenas hasta el origen) y devuelven el
# pronóstico de los H meses siguientes en NIVEL del IPAP. Así se usan igual en la
# validación, en la prueba y en el pronóstico final.
con_desc <- function(p, d) { attr(p, 'desc') <- d; p }

#---- 5.1 SARIMA automático (sobre el logaritmo del IPAP) ----

# Teoría. El SARIMA (Box y Jenkins) explica la serie con sus propios rezagos y errores pasados,
# y con un componente estacional de período 12. Se trabaja en logaritmos para que las
# variaciones sean porcentuales y la varianza más estable. El orden del modelo se elige con
# el AICc, que penaliza la complejidad en muestras pequeñas (Hyndman y Khandakar, 2008).

# auto.arima elige los órdenes (p,d,q)(P,D,Q)[12] con el criterio AICc y prueba si
# hace falta diferenciar (regular y estacionalmente). Si detecta tendencia incluye deriva.
ajuste_auto <- function(ly) {
  auto.arima(ts(ly, frequency = 12), seasonal = TRUE, stepwise = ARIMA_RAPIDO,
             approximation = FALSE, ic = 'aicc')
}
fc_sarima_auto <- function(ly, mes, H, ex) {
  fit <- ajuste_auto(ly)
  con_desc(exp(as.numeric(forecast(fit, h = H)$mean)), as.character(fit))
}

#---- 5.2 ARMA(2,2) con componente estacional autorregresivo SAR(1) ----

# Teoría. Al diferenciar el logaritmo se obtiene la tasa de crecimiento mensual, que sí es
# estacionaria (PASO 3). Sobre una serie estacionaria basta un ARMA; el SAR(1) captura que el
# crecimiento de este mes se parece al del mismo mes del año anterior.

# Se modela la tasa de crecimiento del IPAP (diferencia del logaritmo), que es
# estacionaria, con un ARMA(2,2) y un término autorregresivo estacional de orden 12.
# Los pronósticos del crecimiento se acumulan para volver al nivel del IPAP:
# IPAP(t+h) = IPAP(t) * exp(suma de los crecimientos pronosticados).
ajuste_arma <- function(d) {
  d <- ts(d, frequency = 12)
  tryCatch(Arima(d, order = c(2, 0, 2), seasonal = list(order = c(1, 0, 0), period = 12),
                 method = 'ML'),
           error = function(e)   # si la estimación por ML no converge, usa CSS
             Arima(d, order = c(2, 0, 2), seasonal = list(order = c(1, 0, 0), period = 12),
                   method = 'CSS'))
}
fc_arma <- function(ly, mes, H, ex) {
  fit <- ajuste_arma(diff(ly))
  pm  <- as.numeric(forecast(fit, h = H)$mean)
  con_desc(exp(tail(ly, 1) + cumsum(pm)), 'ARMA(2,2) + SAR(1)[12] sobre el crecimiento')
}

#---- 5.3 VECM de Johansen: IPAP e IPC de bienes no durables ----

# Teoría. Si dos series I(1) comparten una tendencia estocástica (cointegración), existe una
# combinación lineal estacionaria entre ellas: una relación de equilibrio de largo plazo. El
# VECM modela el crecimiento de cada serie y agrega un término de corrección de error que jala
# el sistema de vuelta al equilibrio cuando se desvía (Johansen, 1988, 1991). Diferenciar sin más
# botaría esa información de largo plazo.

# Especificación. Las pruebas de exclusión de Johansen sobre las variables candidatas dejaron un
# sistema con el IPAP y el IPC de no durables, con una relación de cointegración (r = 1). Se estima
# en logaritmos con K = 2 rezagos, constante en la relación de cointegración y dummies
# estacionales (season = 12). El VECM se reescribe como VAR en niveles (vec2var) y se
# pronostica H meses con las dos series al tiempo, por lo que no hace falta
# pronosticar el IPC aparte. Se reestima en cada origen con los datos disponibles.
sistema_vecm <- function(ly, ex) {
  ts(cbind(IPAP = ly, IPC_nodur = log(ex[, 'ipc'])), start = INICIO, frequency = 12)
}
ajuste_vecm <- function(ly, ex) {
  ca.jo(sistema_vecm(ly, ex), ecdet = 'const', type = 'eigen', K = 2,
        spec = 'transitory', season = 12)
}
fc_vecm <- function(ly, mes, H, ex) {
  v <- vec2var(ajuste_vecm(ly, ex), r = 1)
  p <- predict(v, n.ahead = H, ci = 0.95)
  con_desc(exp(p$fcst$IPAP[, 'fcst']), 'VECM Johansen (IPAP, IPC no durables), K=2, r=1')
}

# Identificación en la muestra de entrenamiento: rango de cointegración, vector de
# cointegración (beta) y velocidades de ajuste (alpha)
jo_tr <- ajuste_vecm(ly[1:n_tr], EXOG[1:n_tr, , drop = FALSE])
cat('\nJohansen, valor propio máximo (se rechaza H0 si el estadístico supera el crítico):\n')
print(data.frame(H0 = c('r = 0', 'r <= 1'), estadistico = round(rev(jo_tr@teststat), 2),
                 critico_5pct = rev(jo_tr@cval[, 2])))
# Se rechaza r = 0 y no se rechaza r <= 1: hay UNA relación de cointegración.
vec_tr <- cajorls(jo_tr, r = 1)
cat('\nVector de cointegración (normalizado en el IPAP):\n'); print(round(vec_tr$beta, 3))
alpha <- t(sapply(coef(summary(vec_tr$rlm)), function(x) x['ect1', c(1, 4)]))
cat('\nVelocidades de ajuste (alpha) y p-valor:\n'); print(round(alpha, 4))
# Exogeneidad débil (H0: alpha = 0, la variable no corrige hacia el equilibrio)
for (i in 1:2) {
  A <- diag(2)[, -i, drop = FALSE]
  cat(c('IPAP', 'IPC_nodur')[i], ': p-valor =', round(alrtest(jo_tr, A = A, r = 1)@pval[1], 4), '\n')
}
# Si el IPAP es débilmente exógeno, el IPAP "jala" y el IPC es el que corrige.

#---- 5.4 Chequeo rápido de los modelos autorregresivos ----

# Se corre cada modelo una vez sobre la muestra de entrenamiento para ver el MAPE de
# la prueba y detectar errores pronto, antes del ajuste de los modelos de ML.
modelos_ar <- list('SARIMA (auto)'     = fc_sarima_auto,
                   'ARMA(2,2)+SAR(1)'  = fc_arma)
if (vars_ok) modelos_ar[['VECM (IPAP-IPC)']] <- fc_vecm
chequeo <- sapply(modelos_ar, function(f)
  mape(real_test, f(ly[1:n_tr], mes[1:n_tr], H, EXOG[1:n_tr, , drop = FALSE])))
cat('\nMAPE de la prueba histórica de los modelos autorregresivos:\n')
print(round(chequeo, 2))


# PASO 6 - VALIDACIÓN DE SUPUESTOS DE LOS MODELOS AUTORREGRESIVOS---------------

# Se evalúan los residuos de cada modelo ajustado con la muestra de entrenamiento.
#   No autocorrelación : Ljung-Box (12 y 24 rezagos) y Breusch-Godfrey (12 rezagos).
#                        H0: no hay autocorrelación.
#   Homocedasticidad   : McLeod-Li, Ljung-Box sobre los residuos al cuadrado (efecto
#                        ARCH). H0: varianza constante.
#   Normalidad         : Jarque-Bera y Shapiro-Wilk. H0: residuos normales.
# Con p-valor mayor a 0.05 no se rechaza H0 y el supuesto se cumple.
# Para qué sirve. La no autocorrelación indica que el modelo ya extrajo la dinámica de la serie.
# La homocedasticidad y la normalidad importan sobre todo para los intervalos de confianza y la
# inferencia, menos para el pronóstico puntual que se evalúa con el MAPE.
supuestos_residuos <- function(e, nombre, gl_modelo = 0) {
  e <- as.numeric(na.omit(e))
  pr <- list(
    list('No autocorrelación: Ljung-Box (12)',   Box.test(e, lag = 12, type = 'Ljung-Box', fitdf = gl_modelo)$p.value),
    list('No autocorrelación: Ljung-Box (24)',   Box.test(e, lag = 24, type = 'Ljung-Box', fitdf = gl_modelo)$p.value),
    list('No autocorrelación: Breusch-Godfrey (12)', bgtest(e ~ 1, order = 12)$p.value),
    list('Homocedasticidad: McLeod-Li (12)',     Box.test(e^2, lag = 12, type = 'Ljung-Box')$p.value),
    list('Normalidad: Jarque-Bera',              jarque.bera.test(e)$p.value),
    list('Normalidad: Shapiro-Wilk',             shapiro.test(e)$p.value))
  data.frame(Modelo = nombre, Prueba = sapply(pr, function(z) z[[1]]),
             p_valor = round(sapply(pr, `[[`, 2), 4),
             Conclusion = ifelse(sapply(pr, `[[`, 2) > 0.05, 'cumple', 'NO cumple'))
}

fit_s <- ajuste_auto(ly[1:n_tr])
fit_a <- ajuste_arma(diff(ly[1:n_tr]))
supuestos <- rbind(
  supuestos_residuos(residuals(fit_s), paste('SARIMA auto', as.character(fit_s)),
                     gl_modelo = sum(fit_s$arma[1:4])),
  supuestos_residuos(residuals(fit_a), 'ARMA(2,2)+SAR(1)', gl_modelo = 5))
cat('\n#---------- Supuestos de los residuos: SARIMA automático y ARMA(2,2)+SAR(1) ----------#\n')
print(supuestos, row.names = FALSE)
write.csv(supuestos, file.path(OUT_DIR, 'supuestos_arima.csv'), row.names = FALSE)

# VECM: pruebas multivariadas de la librería vars sobre el VAR en niveles equivalente
if (vars_ok) {
  v_tr <- vec2var(jo_tr, r = 1)
  cat('\n#---------- Supuestos del VECM (VAR en niveles equivalente) ----------#\n')
  print(serial.test(v_tr, lags.pt = 12, type = 'PT.asymptotic'))   # H0: no hay autocorrelación
  print(serial.test(v_tr, lags.pt = 24, type = 'PT.asymptotic'))
  print(arch.test(v_tr, lags.multi = 12, multivariate.only = TRUE)) # H0: varianza constante
  print(normality.test(v_tr))                                       # H0: residuos normales
}
# Con series económicas es común que se cumpla la no autocorrelación y se violen la
# homocedasticidad y la normalidad (colas pesadas por los choques de 2021 a 2023).


# PASO 7 - MODELOS DE MACHINE LEARNING (RANDOM FOREST Y XGBOOST)----------------

# QUÉ HACEN ESTOS MODELOS, PASO A PASO
#
# 1. Estrategia directa. Para cada horizonte h = 1,...,12 se entrena un modelo aparte
#    que aprende la relación entre lo que se sabe en el mes t y lo que cambia el IPAP
#    entre t y t+h. No se pronostica mes a mes ni se reutilizan pronósticos anteriores,
#    y por eso tampoco hace falta pronosticar las variables exógenas.
#
# 2. Variable a explicar (yh). Es el cambio acumulado del logaritmo del IPAP entre t y
#    t+h, es decir, log(IPAP[t+h]) - log(IPAP[t]). Los árboles no extrapolan: no pueden
#    predecir valores fuera del rango que vieron en el entrenamiento. Un nivel como
#    260 estaría fuera de rango si el IPAP históricamente llegó a 256, mientras que
#    un cambio de +2% sí está dentro de lo observado. El pronóstico del nivel es
#    IPAP[t] * exp(cambio pronosticado).
#
# 3. Atributos (la matriz X, una fila por mes t, con información hasta t):
#    - d_l0, d_l1, ...: crecimiento mensual del IPAP en t, t-1, ... (L rezagos).
#    - d_ma3, d_ma6, d_ma12: crecimiento promedio de los últimos 3, 6 y 12 meses.
#    - dev_nivel: distancia del nivel actual a su promedio de 12 meses (reversión).
#    - estacionalidad: seno y coseno del mes, el número de mes, o nada (ESTACIONALIDAD).
#    - exógenas (solo en los modelos "+ exog"): variaciones mensuales y anuales de la TRM y
#      el IPC, variación anual del ISE agro, los precios internacionales de alimentos de la
#      FAO, la anomalía de lluvia (clima) y los insumos (fertilizantes y petróleo), cada una
#      con su rezago de publicación. El IPP y el ONI se probaron y se quitaron (ver PASO 1).
#
# 4. Filas de entrenamiento. Para el horizonte h solo se usan los meses t cuyo
#    resultado t+h ya ocurrió dentro de la muestra y que tienen todos los atributos.
#
# 5. Random Forest (paquete ranger). Cada árbol se entrena con una muestra bootstrap de
#    las filas y, en cada corte, considera solo mtry atributos elegidos al azar. El
#    pronóstico es el promedio de los árboles. Hiperparámetros: L (rezagos), mtry
#    (fracción de atributos por corte), min.node.size (tamaño mínimo de las hojas,
#    controla el sobreajuste) y num.trees = NTREE.
#
# 6. XGBoost (boosting de gradiente). Construye árboles pequeños uno tras otro y cada
#    uno corrige el error que dejaron los anteriores. Hiperparámetros: max_depth
#    (profundidad de cada árbol), eta (cuánto aporta cada árbol, aquí 0.05 para que
#    el aprendizaje sea gradual), nrounds (número de árboles), subsample y
#    colsample_bytree (0.8, usa el 80% de filas y de atributos por árbol),
#    min_child_weight y lambda (regularización).
#
# 7. Los hiperparámetros se eligen en el PASO 9 con el MAPE de la validación interna.
#
# TEORÍA QUE RESPALDA ESTE PASO
#  - Random Forest (Breiman, 2001) promedia muchos árboles entrenados con muestras bootstrap y
#    atributos al azar en cada corte. Promediar árboles poco correlacionados baja la varianza sin
#    subir mucho el sesgo, por eso funciona bien con pocas observaciones (aquí unos 170 meses) y
#    muchas variables. Medeiros et al. (2021) lo encuentran entre los mejores métodos para
#    pronosticar inflación con muchos regresores, el Banco de la República lo usa para el
#    nowcasting de la inflación de Colombia (Roldán-Ferrín y Parra-Polanía, 2025) y Sánchez Conde
#    (2024) lo escoge para pronosticar precios agrícolas en Colombia por su buen comportamiento
#    con pocos datos y su menor tendencia a sobreajustar que modelos más complejos.
#  - Extra Trees (Geurts et al., 2006) es una variante del bosque en la que los puntos de corte
#    de cada atributo se eligen al azar en vez de buscarse el mejor. Agrega aún más aleatoriedad,
#    baja la varianza y suele rendir bien con muestras pequeñas y ruidosas. En el Random Forest
#    se prueba con split = 'extratrees' dentro de la rejilla, y la validación decide si se usa.
#  - XGBoost (Chen y Guestrin, 2016) es boosting de gradiente (Friedman, 2001): árboles pequeños
#    en secuencia, cada uno ajustado al error del anterior, con regularización (lambda) y
#    contracción (eta = 0.05). Con árboles de profundidad 1 a 3 el modelo es más simple que el
#    bosque, lo que ayuda a no sobreajustar. El Banco de la República lo usa para pronosticar 33
#    canastas de inflación de alimentos, con mejor desempeño que los modelos tradicionales y con
#    selección de rezagos de cada variable (Anzola Bravo y Poveda, 2025). Aquí los rezagos
#    (L y LX) se eligen con la validación, en el mismo espíritu.
#  - Estrategia directa (Ben Taieb et al., 2012): un modelo por horizonte evita que el error de
#    un mes se arrastre al siguiente y no exige pronosticar las exógenas.
#  - Predecir el cambio en logaritmos en vez del nivel es lo que permite que los árboles
#    pronostiquen un IPAP más alto que cualquiera visto en el entrenamiento.

ma <- function(v, k) as.numeric(stats::filter(v, rep(1 / k, k), sides = 1))

# Atributos propios del IPAP (solo usan datos hasta el mes t)
feat_matrix <- function(ly, mes, L) {
  m <- length(ly)
  d <- c(NA, diff(ly))                                  # crecimiento mensual
  lags <- sapply(0:(L - 1), function(k) c(rep(NA, k), d)[1:m])
  colnames(lags) <- paste0('d_l', 0:(L - 1))
  est <- switch(ESTACIONALIDAD,
                sincos  = cbind(m_sin = sin(2 * pi * mes / 12), m_cos = cos(2 * pi * mes / 12)),
                mes     = cbind(mes = mes),
                ninguna = NULL)
  cbind(lags,
        d_ma3  = ma(d, 3),
        d_ma6  = ma(d, 6),
        d_ma12 = ma(d, 12),
        dev_nivel = ly - ma(ly, 12),
        est)
}

# Atributos exógenos. Cada serie se desplaza primero por su rezago de publicación,
# de modo que la fila t solo contiene lo que ya era público en t.
feat_exog <- function(ex, LX, usar) {
  m  <- nrow(ex)
  sh <- function(v, k) if (k == 0) v else c(rep(NA, k), v)[1:m]   # rezago de k meses
  dlog <- function(v) c(NA, diff(log(v)))
  a12  <- function(v) log(v) - sh(log(v), 12)                      # variación anual
  bloque <- function(nom, v) {                 # variación mensual (LX rezagos) y anual
    dv <- dlog(v); out <- list()
    for (k in 0:(LX - 1)) out[[paste0(nom, '_d_l', k)]] <- sh(dv, k)
    out[[paste0(nom, '_a12')]] <- a12(v)
    out
  }
  cols <- list()
  if ('trm' %in% usar) {
    v <- sh(ex[, 'trm'], PUB_LAG$trm)
    cols <- c(cols, bloque('trm', v), list(trm_dev12 = log(v) - ma(log(v), 12)))
  }
  if ('ipc' %in% usar) cols <- c(cols, bloque('ipc', sh(ex[, 'ipc'], PUB_LAG$ipc)))
  if ('ise' %in% usar) {                       # ISE agro: variación anual, en t y t-3
    a <- a12(sh(ex[, 'ise'], PUB_LAG$ise))
    cols <- c(cols, list(ise_a12_l0 = a, ise_a12_l3 = sh(a, 3)))
  }
  if ('fao' %in% usar) {                       # FAO: total (mensual y anual) y subíndices (anual)
    cols <- c(cols, list(fao_total_d_l0 = dlog(sh(ex[, 'fao_total'], PUB_LAG$fao)),
                         fao_total_a12  = a12(sh(ex[, 'fao_total'], PUB_LAG$fao))))
    for (nm in setdiff(grep('^fao_', colnames(ex), value = TRUE), 'fao_total'))
      cols[[paste0(nm, '_a12')]] <- a12(sh(ex[, nm], PUB_LAG$fao))
  }
  if ('clima' %in% usar) {                     # anomalía de lluvia: del mes y acumulada 3 y 6 meses
    cols <- c(cols, list(clima_anom_l0 = sh(ex[, 'clima_anom'], PUB_LAG$clima),
                         clima_3m      = sh(ex[, 'clima_3m'],   PUB_LAG$clima),
                         clima_6m      = sh(ex[, 'clima_6m'],   PUB_LAG$clima)))
  }
  if ('insumos' %in% usar) {                   # fertilizantes y petróleo, en dólares
    # Costo de producción: los fertilizantes y la energía suben el costo del productor y luego el
    # precio. Con el insumo en dólares, la TRM (grupo 'trm') completa el costo en pesos.
    cols <- c(cols, bloque('insumos_fert', sh(ex[, 'insumos_fert_usd'], PUB_LAG$insumos)),
              list(insumos_petroleo_a12 = a12(sh(ex[, 'insumos_petroleo'], PUB_LAG$insumos))))
  }
  do.call(cbind, cols)
}

# par$usar = NULL significa modelo sin exógenas
build_X <- function(ly, mes, par, ex = NULL) {
  X <- feat_matrix(ly, mes, par$L)
  if (!is.null(par$usar)) X <- cbind(X, feat_exog(ex, par$LX, par$usar))
  X
}

# Entrena un modelo por horizonte y devuelve el pronóstico del NIVEL del IPAP
ml_forecast <- function(ly, mes, H, tipo, par, ex = NULL) {
  m    <- length(ly)
  X    <- build_X(ly, mes, par, ex)
  xnew <- X[m, , drop = FALSE]            # atributos del último mes: el origen del pronóstico
  if (anyNA(xnew)) stop('Atributos con NA en el origen: revisa PUB_LAG y el final de las series.')
  out  <- numeric(H)
  for (h in 1:H) {
    # Cambio acumulado a h meses; los últimos h meses no tienen resultado todavía (NA)
    yh <- c(ly[(1 + h):m] - ly[1:(m - h)], rep(NA, h))
    ok <- complete.cases(X) & !is.na(yh)  # filas con atributos y con resultado observado
    if (tipo == 'rf') {
      fit <- ranger(x = as.data.frame(X[ok, , drop = FALSE]), y = yh[ok],
                    num.trees = NTREE,
                    mtry = max(1, floor(par$mtry_frac * ncol(X))),
                    min.node.size = par$mns, seed = SEED + h, num.threads = NTHREADS,
                    splitrule = if (is.null(par$split)) 'variance' else par$split)
      p <- predict(fit, data = as.data.frame(xnew))$predictions
    } else {
      dtr <- xgb.DMatrix(X[ok, , drop = FALSE], label = yh[ok])
      fit <- xgb.train(
        params = list(objective = 'reg:squarederror', max_depth = par$depth,
                      eta = par$eta, subsample = 0.8, colsample_bytree = 0.8,
                      min_child_weight = 3, lambda = 1, nthread = 1, seed = SEED + h),
        data = dtr, nrounds = par$nrounds, verbose = 0)
      p <- predict(fit, xgb.DMatrix(xnew))
    }
    out[h] <- exp(ly[m] + p)              # vuelve del cambio en logaritmos al nivel del IPAP
  }
  out
}

desc_par <- function(tipo, par) {
  d <- if (tipo == 'rf') sprintf('L=%d mtry=%.2f nodesize=%d%s', par$L, par$mtry_frac, par$mns,
                                 if (identical(par$split, 'extratrees')) ' ExtraTrees' else '')
  else sprintf('L=%d depth=%d eta=%.2f rounds=%d', par$L, par$depth, par$eta, par$nrounds)
  if (!is.null(par$usar))
    d <- paste0(d, sprintf(' LX=%d [%s]', par$LX, paste(par$usar, collapse = '+')))
  d
}
hacer_ml <- function(tipo, par) {
  force(tipo); force(par)           # fija los valores al crear el modelo
  function(l, ms, H, ex) con_desc(ml_forecast(l, ms, H, tipo, par, ex), desc_par(tipo, par))
}

# Verificación anti-fuga: los atributos de la fila t no cambian si se descartan los
# datos posteriores a t. Si cambiaran, el modelo estaría usando información del futuro.
chk    <- feat_exog(EXOG, 3, GRUPOS_EXOG)[1:n_tr, ]
chk_tr <- feat_exog(EXOG[1:n_tr, , drop = FALSE], 3, GRUPOS_EXOG)
stopifnot(isTRUE(all.equal(chk, chk_tr, check.attributes = FALSE)))
cat('\nVerificación anti-fuga de las exógenas: OK\n')


# PASO 8 - VALIDACIÓN INTERNA (ORÍGENES MÓVILES DENTRO DEL ENTRENAMIENTO)-------

# En cada origen o (hay NVAL, separados STEP_VAL meses) el modelo se entrena SOLO con
# datos hasta o y pronostica los H meses siguientes, que están dentro del entrenamiento.
# El MAPE de validación es el promedio de esos NVAL pronósticos de H pasos. Es lo que
# se usa para elegir hiperparámetros, variables exógenas y modelo. Es una validación
# walk-forward: nunca entrena con datos posteriores al origen. Esto imita el uso real del
# pronóstico y evita que la elección de hiperparámetros se base en un solo año (la prueba), que
# puede ser atípico (ver la discusión de validación en series autorregresivas en Bergmeir,
# Hyndman y Koo, 2018).
#
# Por qué NVAL = 16. Con pocos orígenes, un par de ellos (por ejemplo los del giro de precios de
# 2023) pueden explicar casi la mitad del error de validación, y el MAPE ordena mal las
# combinaciones de hiperparámetros. Con 16 orígenes, separados 3 meses, la validación cubre desde
# enero de 2021 hasta el final del entrenamiento y ordena mejor. Una prueba retrospectiva con el
# Random Forest en cuatro cortes históricos (selección con los datos previos a cada corte y
# evaluación en los 12 meses siguientes) mostró un MAPE promedio de 2.68 con 16 orígenes frente
# a 3.21 con 8, con mejora en los cuatro cortes. Una advertencia: las ventanas de 12 meses se
# traslapan y los orígenes no agregan datos nuevos, así que la información independiente sigue
# siendo la de unos pocos años.
origenes_val <- (n_tr - H) - STEP_VAL * (0:(NVAL - 1))
stopifnot(min(origenes_val) >= 60)    # cada origen debe tener al menos 5 años de historia
cat('Orígenes de validación:', paste(lab[origenes_val], collapse = ', '), '\n')

# Matriz H x NVAL con los pronósticos de cada origen
val_preds <- function(fc_fn) {
  sapply(origenes_val, function(o)
    as.numeric(fc_fn(ly[1:o], mes[1:o], H, EXOG[1:o, , drop = FALSE])))
}
val_mape_from <- function(P) {
  mean(sapply(seq_along(origenes_val), function(i) {
    o <- origenes_val[i]
    mape(y[(o + 1):(o + H)], P[, i])
  }))
}
val_mape <- function(fc_fn) val_mape_from(val_preds(fc_fn))


# PASO 9 - AJUSTE DE HIPERPARÁMETROS (CRITERIO: MAPE DE VALIDACIÓN)-------------

# Teoría. Los hiperparámetros controlan el sesgo y la varianza: más profundidad, más rondas o
# nodos más pequeños dan modelos más flexibles que ajustan mejor la muestra pero se sobreajustan.
# Con unos 170 meses el riesgo de sobreajustar es alto, por eso las rejillas se limitan a árboles
# poco profundos (depth 1 a 3), contracción lenta (eta = 0.05) y hojas con un mínimo de
# observaciones. Cada combinación se evalúa con el MAPE de validación, nunca con la prueba.

ajustar <- function(grid, tipo, usar, etiqueta) {
  cat('\n>>>', etiqueta, '(', nrow(grid), 'combinaciones )\n')
  t0 <- Sys.time()
  # se recorre fila por fila (no con apply) para que las columnas de texto no vuelvan texto los números
  grid$mape_val <- sapply(seq_len(nrow(grid)), function(i) {
    par <- c(as.list(grid[i, , drop = FALSE]), if (!is.null(usar)) list(usar = usar))
    val_mape(function(l, ms, H, ex) ml_forecast(l, ms, H, tipo, par, ex))
  })
  cat(sprintf('Tiempo: %.1f min\n', as.numeric(difftime(Sys.time(), t0, units = 'mins'))))
  grid <- grid[order(grid$mape_val), ]
  print(head(grid, 5), row.names = FALSE)
  grid
}
mejor <- function(grid, usar = NULL) {
  c(as.list(grid[1, setdiff(names(grid), 'mape_val')]), if (!is.null(usar)) list(usar = usar))
}

grids <- list()
grids[['Random Forest']] <- ajustar(
  expand.grid(L = GRID_L, mtry_frac = c(1/3, 1), mns = c(GRID_MNS[1], 10, GRID_MNS[2]),
              split = GRID_SPLIT, stringsAsFactors = FALSE), 'rf', NULL, 'Random Forest')
grids[['Random Forest + exog']] <- ajustar(
  expand.grid(L = GRID_L_X, LX = GRID_LX, mtry_frac = GRID_MTRY, mns = GRID_MNS,
              split = GRID_SPLIT, stringsAsFactors = FALSE),
  'rf', GRUPOS_EXOG, 'Random Forest + exógenas')
if (xgb_ok) {
  grids[['XGBoost']] <- ajustar(
    expand.grid(L = GRID_L, depth = GRID_DEPTH, eta = 0.05, nrounds = NR), 'xgb', NULL, 'XGBoost')
  grids[['XGBoost + exog']] <- ajustar(
    expand.grid(L = GRID_L_X, LX = GRID_LX, depth = GRID_DEPTH, eta = 0.05, nrounds = NR_X),
    'xgb', GRUPOS_EXOG, 'XGBoost + exógenas')
}
for (nm in names(grids))
  write.csv(grids[[nm]], file.path(OUT_DIR, paste0('grilla_', gsub('[^A-Za-z]+', '_', nm), '.csv')),
            row.names = FALSE)


# PASO 10 - SELECCIÓN DE VARIABLES EXÓGENAS: ABLACIÓN POR GRUPOS----------------

# Por qué una ablación y no la importancia. La importancia por permutación o por ganancia
# (PASO 13) dice qué usa el modelo, no si usarla ayuda a pronosticar fuera de muestra, y se
# reparte de forma sesgada entre variables correlacionadas (Strobl et al., 2007). La ablación
# mide directamente el efecto de cada grupo sobre el error de validación, que es lo que importa.
#
# Qué hace. Se vuelve a evaluar el Random Forest con exógenas con los mismos hiperparámetros,
# quitando un grupo a la vez. Si el MAPE BAJA al quitar un grupo, ese grupo mete ruido y conviene
# sacarlo de GRUPOS_EXOG. Si SUBE, el grupo aporta. Si no cambia, es redundante.
#   - 'quitar X'     : los grupos finales sin el grupo X.
#   - 'sin exógenas' : el RF sin ninguna exógena, para ver cuánto aportan en conjunto.
# Ojo con la lectura. El MAPE de validación tiene ruido (NVAL orígenes que se traslapan), así que
# cambios menores a unos 0.1 puntos no son concluyentes.
par_base <- mejor(grids[['Random Forest + exog']], GRUPOS_EXOG)
filas <- c(list(list(et = 'base (grupos finales)', usar = GRUPOS_EXOG)),
           lapply(GRUPOS_EXOG, function(g) list(et = paste('quitar', g), usar = setdiff(GRUPOS_EXOG, g))),
           list(list(et = 'sin exógenas', usar = NULL)))
abl <- data.frame(Escenario = sapply(filas, `[[`, 'et'), MAPE_validacion = NA_real_)
for (i in seq_along(filas)) {
  par_i <- par_base
  par_i$usar <- filas[[i]]$usar
  abl$MAPE_validacion[i] <- val_mape(function(l, ms, H, ex) ml_forecast(l, ms, H, 'rf', par_i, ex))
}
abl$Cambio_vs_base <- round(abl$MAPE_validacion - abl$MAPE_validacion[1], 2)
abl$MAPE_validacion <- round(abl$MAPE_validacion, 2)
cat('\nAblación por grupos, RF con exógenas (MAPE de validación; cambio negativo = el grupo sobra):\n')
print(abl, row.names = FALSE)
write.csv(abl, file.path(OUT_DIR, 'ablacion_grupos_exog.csv'), row.names = FALSE)


# PASO 11 - EVALUACIÓN DE TODOS LOS MODELOS Y PROMEDIOS-------------------------

# Catálogo: modelos autorregresivos y de ML
modelos <- list('SARIMA (auto)' = fc_sarima_auto, 'ARMA(2,2)+SAR(1)' = fc_arma)
tipo_modelo <- c('SARIMA (auto)' = 'Autorregresivo', 'ARMA(2,2)+SAR(1)' = 'Autorregresivo')
if (vars_ok) {
  modelos[['VECM (IPAP-IPC)']] <- fc_vecm
  tipo_modelo['VECM (IPAP-IPC)'] <- 'Autorregresivo'
}
for (nm in names(grids)) {
  tipo <- if (grepl('^Random Forest', nm)) 'rf' else 'xgb'
  usar <- if (grepl('exog', nm)) GRUPOS_EXOG else NULL
  modelos[[nm]] <- hacer_ml(tipo, mejor(grids[[nm]], usar))
  tipo_modelo[nm] <- 'Machine learning'
}
usa_ex <- setNames(ifelse(names(modelos) %in% c('VECM (IPAP-IPC)') | grepl('exog', names(modelos)),
                          'Si', 'No'), names(modelos))

# Para cada modelo: pronósticos de validación (H x NVAL), de la prueba (entrenado hasta
# el mes n_tr) y del futuro (reentrenado con toda la muestra)
res <- lapply(names(modelos), function(nm) {
  cat('Evaluando', nm, '...\n')
  f  <- modelos[[nm]]
  Pv <- val_preds(f)
  pt <- f(ly[1:n_tr], mes[1:n_tr], H, EXOG[1:n_tr, , drop = FALSE])
  pf <- f(ly, mes, H, EXOG)
  list(nombre = nm, P_val = Pv, mape_val = val_mape_from(Pv),
       pred_test = as.numeric(pt), pred_fut = as.numeric(pf), desc_test = attr(pt, 'desc'))
})
names(res) <- names(modelos)

# Promedios simples de las predicciones (en nivel del IPAP). Para cada mes se promedian
# las predicciones de los modelos del grupo y el MAPE se calcula UNA vez sobre ese
# promedio (no se promedian los MAPE). Se hace en cada origen de validación, en la
# prueba y en el futuro. Los pesos son iguales: con pocos datos, estimar pesos agrega error y
# el promedio simple suele rendir igual o mejor (Claeskens et al., 2016; Timmermann, 2006).
# 'Promedio (todos)' reúne SARIMA, ARMA(2,2)+SAR(1), VECM, Random Forest, RF + exógenas,
# XGBoost y XGBoost + exógenas, y es el MODELO_FINAL.
ar_nm <- names(modelos)[tipo_modelo[names(modelos)] == 'Autorregresivo']
ml_nm <- names(modelos)[tipo_modelo[names(modelos)] == 'Machine learning']
ENS <- list('Promedio (autorregresivos)' = ar_nm,
            'Promedio (ML)'              = ml_nm,
            'Promedio (todos)'           = c(ar_nm, ml_nm))
prom <- function(lst) Reduce(`+`, lst) / length(lst)
for (nm in names(ENS)) {
  mem <- ENS[[nm]]
  Pv  <- prom(lapply(res[mem], `[[`, 'P_val'))
  res[[nm]] <- list(nombre = nm, P_val = Pv, mape_val = val_mape_from(Pv),
                    pred_test = prom(lapply(res[mem], `[[`, 'pred_test')),
                    pred_fut  = prom(lapply(res[mem], `[[`, 'pred_fut')),
                    desc_test = paste('promedio de:', paste(mem, collapse = ', ')))
  tipo_modelo[nm] <- 'Promedio'
  usa_ex[nm]      <- 'Mixto'
}

tabla <- do.call(rbind, lapply(res, function(r) data.frame(
  Modelo          = r$nombre,
  Tipo            = tipo_modelo[[r$nombre]],
  Exogenas        = usa_ex[[r$nombre]],
  MAPE_validacion = r$mape_val,
  MAPE_prueba     = mape(real_test, r$pred_test),
  RMSE_prueba     = rmse(real_test, r$pred_test),
  Especificacion  = r$desc_test)))
rownames(tabla) <- NULL

# Modelo final: el promedio de todos (MODELO_FINAL). Se compara con el mejor modelo de ML, que es
# el de menor MAPE de validación entre Random Forest y XGBoost, con y sin exógenas.
elegido <- MODELO_FINAL
stopifnot(elegido %in% tabla$Modelo)
cand_ml   <- tabla[tabla$Tipo == 'Machine learning', ]
mejor_ml  <- cand_ml$Modelo[which.min(cand_ml$MAPE_validacion)]
mejor_val <- tabla$Modelo[which.min(tabla$MAPE_validacion)]     # mejor de todos por validación
tabla$Elegido <- ifelse(tabla$Modelo == elegido, '<-- elegido',
                        ifelse(tabla$Modelo == mejor_ml, 'mejor ML', ''))
tabla <- tabla[order(tabla$MAPE_prueba), ]
tabla[, c('MAPE_validacion', 'MAPE_prueba', 'RMSE_prueba')] <-
  round(tabla[, c('MAPE_validacion', 'MAPE_prueba', 'RMSE_prueba')], 2)

cat('\n================ COMPARACIÓN DE MODELOS ================\n')
cat('MAPE_validacion: promedio de', NVAL, 'orígenes móviles dentro del entrenamiento (12 pasos)\n')
cat(sprintf('MAPE_prueba: %s a %s, un solo origen (%s), 12 pasos\n', lab[n_tr + 1], lab[n], lab[n_tr]))
cat(sprintf('Elegido: %s | Mejor ML por validación: %s\n', elegido, mejor_ml))
cat(sprintf('Menor MAPE de validación entre todos los modelos: %s\n\n', mejor_val))
print(tabla[, c('Modelo', 'Tipo', 'Exogenas', 'MAPE_validacion', 'MAPE_prueba',
                'RMSE_prueba', 'Elegido')], row.names = FALSE)
cat('\nEspecificaciones:\n')
print(tabla[, c('Modelo', 'Especificacion')], row.names = FALSE)
write.csv(tabla, file.path(OUT_DIR, 'tabla_comparacion_modelos.csv'), row.names = FALSE)

# Efecto de las exógenas: el mismo modelo de ML con y sin exógenas
pares <- data.frame(Base = c('Random Forest', if (xgb_ok) 'XGBoost'),
                    Con  = c('Random Forest + exog', if (xgb_ok) 'XGBoost + exog'))
efecto <- do.call(rbind, lapply(seq_len(nrow(pares)), function(i) {
  a <- tabla[tabla$Modelo == pares$Base[i], ]; b <- tabla[tabla$Modelo == pares$Con[i], ]
  data.frame(Modelo = pares$Base[i], Val_sin = a$MAPE_validacion, Val_con = b$MAPE_validacion,
             Prueba_sin = a$MAPE_prueba, Prueba_con = b$MAPE_prueba)
}))
cat('\nEfecto de las exógenas (MAPE sin vs con):\n')
print(efecto, row.names = FALSE)
write.csv(efecto, file.path(OUT_DIR, 'efecto_exogenas.csv'), row.names = FALSE)

# MAPE por origen de validación y de la prueba. El MAPE de validación de la tabla es el
# promedio de las primeras NVAL filas. Sirve para ver DÓNDE falla cada modelo: un modelo
# puede ser bueno en la prueba (un solo origen, un año tranquilo) y malo en la validación
# porque en algunos orígenes (por ejemplo el giro del IPAP en 2023) se equivoca por mucho.
mape_origen <- do.call(cbind, lapply(res, function(r) {
  c(sapply(seq_along(origenes_val), function(i) {
    o <- origenes_val[i]; mape(y[(o + 1):(o + H)], r$P_val[, i]) }),
    mape(real_test, r$pred_test))
}))
rownames(mape_origen) <- c(paste('val', lab[origenes_val], 'a', lab[origenes_val + H]),
                           paste('PRUEBA', lab[n_tr + 1], 'a', lab[n]))
cat('\nMAPE por origen (cada fila es un año pronosticado):\n')
print(round(mape_origen, 1))
write.csv(round(mape_origen, 2), file.path(OUT_DIR, 'mape_por_origen.csv'))


# PASO 11b - MODELO ELEGIDO (PROMEDIO) FRENTE AL MEJOR MODELO DE ML-------------

# Para qué. El promedio se escogió como modelo final, pero el mejor modelo individual de ML
# (el de menor MAPE de validación) es la alternativa natural. Se comparan tres cosas, que son las
# tres miradas del Reto B: el MAPE de validación (NVAL orígenes), el MAPE de la prueba histórica
# (un origen) y el error mes a mes de la prueba. Si el promedio gana en la prueba pero pierde en
# validación, conviene decirlo: un solo año de prueba tiene poca información. Que el promedio
# gane de manera consistente en orígenes distintos es la evidencia más sólida a su favor.
mo_e <- mape_origen[seq_len(NVAL), elegido]
mo_m <- mape_origen[seq_len(NVAL), mejor_ml]
comp <- tabla[match(c(elegido, mejor_ml), tabla$Modelo),
              c('Modelo', 'Tipo', 'MAPE_validacion', 'MAPE_prueba', 'RMSE_prueba')]
comp$Origenes_val_ganados <- c(sum(mo_e < mo_m), sum(mo_m < mo_e))
rownames(comp) <- NULL
cat('\n================ ELEGIDO VS MEJOR MODELO DE ML ================\n')
print(comp, row.names = FALSE)
cat(sprintf('(Origenes_val_ganados: de %d orígenes de validación, en cuántos tiene menor MAPE que el otro)\n', NVAL))
write.csv(comp, file.path(OUT_DIR, 'comparacion_elegido_vs_mejor_ml.csv'), row.names = FALSE)

# Prueba histórica mes a mes: real, pronóstico de cada uno y error porcentual absoluto (APE)
cmp_mes <- data.frame(Fecha = lab[(n_tr + 1):n], IPAP_real = real_test,
                      Pred_elegido = res[[elegido]]$pred_test, Pred_mejor_ML = res[[mejor_ml]]$pred_test)
cmp_mes$APE_elegido  <- 100 * abs((cmp_mes$IPAP_real - cmp_mes$Pred_elegido)  / cmp_mes$IPAP_real)
cmp_mes$APE_mejor_ML <- 100 * abs((cmp_mes$IPAP_real - cmp_mes$Pred_mejor_ML) / cmp_mes$IPAP_real)
cmp_mes$Menor_error  <- ifelse(cmp_mes$APE_elegido < cmp_mes$APE_mejor_ML, 'elegido', 'mejor ML')
cmp_out <- cbind(Elegido = elegido, Mejor_ML = mejor_ml, cmp_mes)
write.csv(cmp_out, file.path(OUT_DIR, 'prueba_historica_elegido_vs_mejor_ml.csv'), row.names = FALSE)
cat(sprintf('\nPrueba histórica mes a mes. Elegido = %s | Mejor ML = %s\n', elegido, mejor_ml))
print(cbind(cmp_mes[, 1:2], round(cmp_mes[, 3:6], 2), cmp_mes[, 7, drop = FALSE]), row.names = FALSE)
cat(sprintf('MAPE de la prueba: elegido = %.2f | mejor ML = %.2f. El elegido tiene menor error en %d de %d meses.\n',
            mean(cmp_mes$APE_elegido), mean(cmp_mes$APE_mejor_ML),
            sum(cmp_mes$Menor_error == 'elegido'), HOLD))

# MAPE de cada uno en cada origen de validación y en la prueba
write.csv(round(mape_origen[, c(elegido, mejor_ml)], 2),
          file.path(OUT_DIR, 'mape_por_origen_elegido_vs_mejor_ml.csv'))


# PASO 12 - TABLAS DE ENTREGA (PRUEBA HISTÓRICA Y PRONÓSTICO A 12 MESES)--------------

prueba_larga <- do.call(rbind, lapply(res, function(r) data.frame(
  Modelo = r$nombre, Fecha = lab[(n_tr + 1):n], IPAP_real = real_test,
  IPAP_predicho = r$pred_test, APE_pct = 100 * abs((real_test - r$pred_test) / real_test))))
fut_larga <- do.call(rbind, lapply(res, function(r) data.frame(
  Modelo = r$nombre, Fecha = lab_fut, IPAP_pronostico = r$pred_fut)))
rownames(prueba_larga) <- NULL; rownames(fut_larga) <- NULL
write.csv(prueba_larga, file.path(OUT_DIR, 'prueba_historica_todos.csv'), row.names = FALSE)
write.csv(subset(prueba_larga, Modelo == elegido),
          file.path(OUT_DIR, 'prueba_historica_elegido.csv'), row.names = FALSE)
write.csv(fut_larga, file.path(OUT_DIR, 'pronostico_12m_todos.csv'), row.names = FALSE)
write.csv(subset(fut_larga, Modelo == elegido),
          file.path(OUT_DIR, 'pronostico_12m_elegido.csv'), row.names = FALSE)

cat('\n--- Prueba histórica del modelo elegido (', elegido, ') ---\n', sep = '')
print(subset(prueba_larga, Modelo == elegido)[, -1], row.names = FALSE)
cat('\n--- Pronóstico de los siguientes 12 meses (', elegido, ') ---\n', sep = '')
print(subset(fut_larga, Modelo == elegido)[, -1], row.names = FALSE)


# PASO 13 - IMPORTANCIA DE LAS VARIABLES (RANDOM FOREST Y XGBOOST CON EXÓGENAS)--

# Se reporta la participación (%) de cada variable y de cada grupo en la importancia
# total, con el modelo ajustado con toda la muestra, en los horizontes 1, 6 y 12.
#   Random Forest: importancia por permutación (OOB). Se barajan los valores de una
#     variable y se mide cuánto empeora el error del bosque. Más empeora, más importante.
#   XGBoost: ganancia (gain). Suma cuánto reduce el error cada corte que usa la variable.
# Las dos escalas son distintas, por eso solo se comparan participaciones, no valores.
# Cómo leerlas: la importancia dice qué usa el modelo, NO si usarla ayuda a pronosticar
# fuera de muestra ni en qué dirección. Lo que decide si un grupo se queda es el PASO 10.
# La permutación se reparte de forma sesgada cuando hay variables correlacionadas (por ejemplo
# varios rezagos de la misma serie), por eso se agrega por grupo (Strobl et al., 2007).
grupo_de <- function(nombres) {
  ifelse(grepl('^trm', nombres), 'TRM',
  ifelse(grepl('^ipc', nombres), 'IPC no durables',
  ifelse(grepl('^ise', nombres), 'ISE agro',
  ifelse(grepl('^fao', nombres), 'FAO alimentos',
  ifelse(grepl('^clima', nombres), 'Clima (lluvia)',
  ifelse(grepl('^insumos', nombres), 'Insumos (fertilizantes)',
         'Propias del IPAP (rezagos y calendario)'))))))
}

imp_modelo <- function(tipo, par, etiqueta) {
  X <- build_X(ly, mes, par, EXOG)
  do.call(rbind, lapply(c(1, 6, 12), function(h) {
    yh <- c(ly[(1 + h):n] - ly[1:(n - h)], rep(NA, h))
    ok <- complete.cases(X) & !is.na(yh)
    if (tipo == 'rf') {
      fit <- ranger(x = as.data.frame(X[ok, ]), y = yh[ok], num.trees = NTREE,
                    mtry = max(1, floor(par$mtry_frac * ncol(X))), min.node.size = par$mns,
                    importance = 'permutation', seed = SEED, num.threads = NTHREADS,
                    splitrule = if (is.null(par$split)) 'variance' else par$split)
      imp <- pmax(fit$variable.importance, 0)
    } else {
      fit <- xgb.train(
        params = list(objective = 'reg:squarederror', max_depth = par$depth,
                      eta = par$eta, subsample = 0.8, colsample_bytree = 0.8,
                      min_child_weight = 3, lambda = 1, nthread = 1, seed = SEED + h),
        data = xgb.DMatrix(X[ok, , drop = FALSE], label = yh[ok]),
        nrounds = par$nrounds, verbose = 0)
      xi  <- xgb.importance(model = fit)
      imp <- setNames(numeric(ncol(X)), colnames(X))   # variables que nunca se usan = 0
      imp[xi$Feature] <- xi$Gain
    }
    data.frame(Modelo = etiqueta, Horizonte = h, Variable = names(imp),
               Grupo = grupo_de(names(imp)),
               Participacion_pct = 100 * as.numeric(imp) / sum(imp))
  }))
}

graf_importancia <- function(df, titulo) {
  g <- aggregate(Participacion_pct ~ Horizonte + Grupo, data = df, FUN = sum)
  orden <- names(sort(tapply(g$Participacion_pct, g$Grupo, mean)))
  g$Grupo <- factor(g$Grupo, levels = orden)
  g$Panel <- factor(paste('Horizonte', g$Horizonte, 'meses'),
                    levels = paste('Horizonte', c(1, 6, 12), 'meses'))
  g$Tipo  <- ifelse(grepl('^Propias', g$Grupo), 'Propias del IPAP', 'Exógenas')
  ggplot(g, aes(Grupo, Participacion_pct, fill = Tipo)) +
    geom_col() +
    geom_text(aes(label = sprintf('%.0f%%', Participacion_pct)), hjust = -0.1, size = 3) +
    coord_flip(ylim = c(0, max(g$Participacion_pct) * 1.2)) +
    facet_wrap(~ Panel, nrow = 1) +
    scale_fill_manual(values = c('Propias del IPAP' = 'grey55', 'Exógenas' = '#1f77b4')) +
    labs(title = titulo, x = NULL, y = 'Participación en la importancia total (%)') +
    theme_minimal() + theme(legend.position = 'bottom')
}

par_rf_x <- par_base
imp_rf   <- imp_modelo('rf', par_rf_x, 'Random Forest + exog')
imp_todo <- imp_rf
ggsave(file.path(OUT_DIR, 'g3_importancia_random_forest.png'),
       graf_importancia(imp_rf, 'Random Forest + exógenas: importancia por permutación (por grupo)'),
       width = 12, height = 4.5, dpi = 150)
if (xgb_ok) {
  par_xgb_x <- mejor(grids[['XGBoost + exog']], GRUPOS_EXOG)
  imp_xgb   <- imp_modelo('xgb', par_xgb_x, 'XGBoost + exog')
  imp_todo  <- rbind(imp_rf, imp_xgb)
  ggsave(file.path(OUT_DIR, 'g4_importancia_xgboost.png'),
         graf_importancia(imp_xgb, 'XGBoost + exógenas: ganancia (gain) por grupo'),
         width = 12, height = 4.5, dpi = 150)
}
imp <- aggregate(Participacion_pct ~ Modelo + Horizonte + Grupo, data = imp_todo, FUN = sum)
imp$Participacion_pct <- round(imp$Participacion_pct, 1)
cat('\nParticipación de cada grupo en la importancia (%):\n')
print(imp[order(imp$Modelo, imp$Horizonte, -imp$Participacion_pct), ], row.names = FALSE)
write.csv(imp, file.path(OUT_DIR, 'importancia_por_grupo.csv'), row.names = FALSE)
imp_var <- imp_todo; imp_var$Participacion_pct <- round(imp_var$Participacion_pct, 2)
write.csv(imp_var, file.path(OUT_DIR, 'importancia_por_variable.csv'), row.names = FALSE)


# PASO 14 - GRÁFICOS------------------------------------------------------------

fechas  <- as.Date(paste0(lab, '-01'))
ini     <- max(1, n - 60)
paneles <- c('Autorregresivo', 'Machine learning', 'Promedio')
panel_de <- function(m) factor(tipo_modelo[m], levels = paneles)
prueba_larga$Panel <- panel_de(prueba_larga$Modelo)
fut_larga$Panel    <- panel_de(fut_larga$Modelo)
prueba_larga$Fecha_d <- as.Date(paste0(prueba_larga$Fecha, '-01'))
fut_larga$Fecha_d    <- as.Date(paste0(fut_larga$Fecha, '-01'))
hist_g <- merge(data.frame(Fecha = fechas[ini:n], IPAP = y[ini:n]),
                data.frame(Panel = factor(paneles, levels = paneles)))

g1 <- ggplot() +
  geom_line(data = hist_g, aes(Fecha, IPAP), color = 'black', linewidth = 0.9) +
  geom_line(data = prueba_larga, aes(Fecha_d, IPAP_predicho, color = Modelo), linewidth = 0.7) +
  geom_vline(xintercept = as.numeric(fechas[n_tr]), linetype = 2) +
  facet_wrap(~ Panel, ncol = 1) +
  labs(title = 'Prueba histórica: últimos 12 meses (un origen, 12 pasos)', x = NULL, y = 'IPAP-BMC') +
  theme_minimal()
ggsave(file.path(OUT_DIR, 'g1_prueba_historica.png'), g1, width = 10, height = 9, dpi = 150)

g2 <- ggplot() +
  geom_line(data = hist_g, aes(Fecha, IPAP), color = 'black', linewidth = 0.9) +
  geom_line(data = fut_larga, aes(Fecha_d, IPAP_pronostico, color = Modelo,
                                  linewidth = Modelo == elegido)) +
  scale_linewidth_manual(values = c(`TRUE` = 1.4, `FALSE` = 0.5), guide = 'none') +
  facet_wrap(~ Panel, ncol = 1) +
  labs(title = paste('Pronóstico a 12 meses. Elegido:', elegido), x = NULL, y = 'IPAP-BMC') +
  theme_minimal()
ggsave(file.path(OUT_DIR, 'g2_pronostico_12m.png'), g2, width = 10, height = 9, dpi = 150)

# g5: prueba histórica, modelo elegido frente al mejor ML (nivel del IPAP y error mes a mes)
f_test <- fechas[(n_tr + 1):n]
nm_el  <- paste0(elegido, ' (elegido)')
nm_ml  <- paste0(mejor_ml, ' (mejor ML)')
d_niv <- rbind(
  data.frame(Fecha = fechas[(n_tr - 23):n], Serie = 'IPAP real', Valor = y[(n_tr - 23):n]),
  data.frame(Fecha = f_test, Serie = nm_el, Valor = cmp_mes$Pred_elegido),
  data.frame(Fecha = f_test, Serie = nm_ml, Valor = cmp_mes$Pred_mejor_ML))
d_niv$Panel <- 'IPAP-BMC (nivel)'
d_ape <- rbind(data.frame(Fecha = f_test, Serie = nm_el, Valor = cmp_mes$APE_elegido),
               data.frame(Fecha = f_test, Serie = nm_ml, Valor = cmp_mes$APE_mejor_ML))
d_ape$Panel <- 'Error porcentual absoluto (%)'
cols_g5 <- setNames(c('black', '#1f77b4', '#e07b00'), c('IPAP real', nm_el, nm_ml))
g5 <- ggplot() +
  geom_line(data = d_niv, aes(Fecha, Valor, color = Serie), linewidth = 0.9) +
  geom_col(data = d_ape, aes(Fecha, Valor, fill = Serie), position = 'dodge', width = 20) +
  geom_vline(data = data.frame(Panel = 'IPAP-BMC (nivel)'), aes(xintercept = as.numeric(fechas[n_tr])),
             linetype = 2) +
  facet_wrap(~ Panel, ncol = 1, scales = 'free_y') +
  scale_color_manual(values = cols_g5, breaks = names(cols_g5)) +
  scale_fill_manual(values = cols_g5, guide = 'none') +
  labs(title = 'Prueba histórica: modelo elegido frente al mejor modelo de ML',
       subtitle = sprintf('MAPE de la prueba: %s = %.2f | %s = %.2f', elegido,
                          mean(cmp_mes$APE_elegido), mejor_ml, mean(cmp_mes$APE_mejor_ML)),
       x = NULL, y = NULL, color = NULL) +
  theme_minimal() + theme(legend.position = 'bottom')
ggsave(file.path(OUT_DIR, 'g5_elegido_vs_mejor_ml.png'), g5, width = 10, height = 7, dpi = 150)

cat('\nListo. Archivos en:', normalizePath(OUT_DIR), '\n')
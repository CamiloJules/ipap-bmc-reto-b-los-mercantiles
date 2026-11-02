# =============================================================================
# BMC DATALAB CHALLENGE - RETO B | Estadísticas descriptivas de la base
#
# QUÉ HACE ESTE SCRIPT
# Calcula las estadísticas descriptivas de las 15 variables de la base (el IPAP y las 14
# explicativas) y grafica cada una en el tiempo. Es independiente del modelo: no cambia
# ningún resultado de ipap_concurso_final.R y se puede correr antes o después de él.
#
# ARCHIVOS QUE GENERA (en 03_outputs/descriptivas/)
#   estadisticas_descriptivas.csv   N, faltantes, media, desviación estándar, mínimo,
#                                   mediana, máximo y fechas del mínimo y del máximo
#   g0_ipap.png                     el IPAP de enero de 2011 a septiembre de 2026
#   g0_variables.png                las 15 variables, cada una en su propio panel
#
# CÓMO SE CORRE
# Lo corre main.R. Para correrlo solo: abrir ipap-bmc-reto-b.Rproj en RStudio y correr este
# archivo con Source, o desde una terminal en la carpeta del repositorio:
#   Rscript 02_code/descriptivas.R
# =============================================================================


# PASO 0 - PAQUETES-------------------------------------------------------------
for (p in c('readxl', 'ggplot2')) {
  if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
}
library(readxl)
library(ggplot2)


# PASO 1 - CARGAR LA BASE--------------------------------------------------------
RUTA    <- '01_data/IPAP_De_completa.xlsx'
OUT_DIR <- file.path('03_outputs', 'descriptivas')
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

datos <- data.frame(read_excel(RUTA))
datos$Fecha <- as.Date(datos$Fecha)
datos <- datos[order(datos$Fecha), ]

# Nombre, unidad y grupo de cada variable (el diccionario completo está en 04_documentation/DATOS.md)
VARIABLES <- data.frame(
  columna = c('IPAP', 'trm_promedio_mes', 'IPC_No_durables', 'ISE_Agro',
              'fao_ffpi_total', 'fao_carne', 'fao_lacteos', 'fao_cereales', 'fao_aceites', 'fao_azucar',
              'precip_anom', 'precip_anom_3m', 'precip_anom_6m', 'fert_usd', 'petroleo_usd'),
  nombre  = c('IPAP', 'TRM promedio del mes', 'IPC no durables', 'ISE agropecuario',
              'FAO: índice total', 'FAO: carne', 'FAO: lácteos', 'FAO: cereales', 'FAO: aceites', 'FAO: azúcar',
              'Anomalía de lluvia (mes)', 'Anomalía de lluvia (3 meses)', 'Anomalía de lluvia (6 meses)',
              'Fertilizantes', 'Petróleo'),
  unidad  = c('índice', 'pesos por dólar', 'índice, dic-2018 = 100', 'índice, 2015 = 100',
              rep('índice, 2014-2016 = 100', 6), rep('desviaciones estándar', 3),
              'USD por tonelada', 'USD por barril'),
  grupo   = c('Variable objetivo', 'TRM', 'IPC', 'ISE', rep('FAO', 6), rep('Clima', 3),
              rep('Insumos', 2)),
  stringsAsFactors = FALSE)


# PASO 2 - ESTADÍSTICAS DESCRIPTIVAS---------------------------------------------
# Se calculan con los meses que tienen dato. El único vacío de la base es el ISE de
# septiembre de 2026, que el DANE publica un mes después.
mes_txt <- function(f) format(f, '%Y-%m')

describir <- function(col) {
  v  <- datos[[col]]
  ok <- !is.na(v)
  data.frame(
    Variable     = col,
    Desde        = mes_txt(min(datos$Fecha[ok])),
    Hasta        = mes_txt(max(datos$Fecha[ok])),
    N            = sum(ok),
    Faltantes    = sum(!ok),
    Media        = round(mean(v, na.rm = TRUE), 2),
    Desv_est     = round(sd(v, na.rm = TRUE), 2),
    Minimo       = round(min(v, na.rm = TRUE), 2),
    Mes_minimo   = mes_txt(datos$Fecha[which.min(v)]),
    Mediana      = round(median(v, na.rm = TRUE), 2),
    Maximo       = round(max(v, na.rm = TRUE), 2),
    Mes_maximo   = mes_txt(datos$Fecha[which.max(v)]))
}

tabla <- do.call(rbind, lapply(VARIABLES$columna, describir))
tabla <- cbind(tabla[, 1, drop = FALSE], Unidad = VARIABLES$unidad, tabla[, -1])

cat('\nEstadísticas descriptivas (', mes_txt(min(datos$Fecha)), 'a', mes_txt(max(datos$Fecha)), ')\n')
print(tabla, row.names = FALSE)
write.csv(tabla, file.path(OUT_DIR, 'estadisticas_descriptivas.csv'), row.names = FALSE)


# PASO 3 - GRÁFICOS---------------------------------------------------------------
# 3.1 El IPAP solo
g_ipap <- ggplot(datos, aes(Fecha, IPAP)) +
  geom_line(linewidth = 0.8) +
  labs(title = 'IPAP-BMC, enero de 2011 a septiembre de 2026', x = NULL, y = 'Índice') +
  theme_minimal(base_size = 12)
ggsave(file.path(OUT_DIR, 'g0_ipap.png'), g_ipap, width = 10, height = 4.5, dpi = 150)

# 3.2 Las 15 variables, cada una con su propia escala
largo <- do.call(rbind, lapply(seq_len(nrow(VARIABLES)), function(i) {
  data.frame(Fecha = datos$Fecha, Valor = datos[[VARIABLES$columna[i]]],
             Panel = paste0(VARIABLES$nombre[i], '\n(', VARIABLES$unidad[i], ')'),
             Grupo = VARIABLES$grupo[i])
}))
largo <- largo[!is.na(largo$Valor), ]
largo$Panel <- factor(largo$Panel, levels = unique(largo$Panel))   # mismo orden del diccionario
largo$Grupo <- factor(largo$Grupo, levels = unique(VARIABLES$grupo))

g_var <- ggplot(largo, aes(Fecha, Valor, colour = Grupo)) +
  geom_line(linewidth = 0.5) +
  facet_wrap(~ Panel, ncol = 3, scales = 'free_y') +
  labs(title = 'Variables de la base, enero de 2011 a septiembre de 2026', x = NULL, y = NULL,
       colour = 'Grupo') +
  theme_minimal(base_size = 10) +
  theme(legend.position = 'bottom')
ggsave(file.path(OUT_DIR, 'g0_variables.png'), g_var, width = 11, height = 13, dpi = 150)

cat('\nListo. Archivos en:', normalizePath(OUT_DIR), '\n')

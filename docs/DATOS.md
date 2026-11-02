# Datos del proyecto

La base está en [`datos/IPAP_De_completa.xlsx`](../datos/IPAP_De_completa.xlsx). Tiene una sola hoja (`Sheet1`), una fila por mes y 16 columnas: la fecha, el IPAP y 14 variables explicativas.

- **Frecuencia:** mensual.
- **Periodo:** enero de 2011 a septiembre de 2026 (189 meses).
- **Fecha:** la columna `Fecha` trae el último día de cada mes (por ejemplo, `2026-09-30`).
- **Faltantes:** el único dato vacío es el `ISE_Agro` de septiembre de 2026, porque el DANE lo publica un mes después que el IPAP. El código lo maneja con un rezago de publicación de un mes (ver más abajo).

## Diccionario de variables

| Columna | Descripción | Unidad | Fuente | Grupo en el código |
|---|---|---|---|---|
| `Fecha` | Mes de la observación (último día del mes) | fecha | — | — |
| `IPAP` | Índice de Precios Agropecuarios. **Variable a pronosticar** | índice | Bolsa Mercantil de Colombia (BMC) | variable objetivo |
| `trm_promedio_mes` | Tasa de cambio representativa del mercado, promedio del mes | pesos por dólar | Banco de la República | `trm` |
| `IPC_No_durables` | Índice de precios al consumidor de bienes no durables | índice, dic-2018 = 100 | DANE | `ipc` (y VECM) |
| `ISE_Agro` | Indicador de Seguimiento a la Economía, actividades agropecuarias | índice, 2015 = 100 | DANE | `ise` |
| `fao_ffpi_total` | Índice de precios de los alimentos de la FAO, nominal | índice, 2014-2016 = 100 | FAO | `fao` |
| `fao_carne` | Subíndice FAO de carne | índice, 2014-2016 = 100 | FAO | `fao` |
| `fao_lacteos` | Subíndice FAO de lácteos | índice, 2014-2016 = 100 | FAO | `fao` |
| `fao_cereales` | Subíndice FAO de cereales | índice, 2014-2016 = 100 | FAO | `fao` |
| `fao_aceites` | Subíndice FAO de aceites vegetales | índice, 2014-2016 = 100 | FAO | `fao` |
| `fao_azucar` | Subíndice FAO de azúcar | índice, 2014-2016 = 100 | FAO | `fao` |
| `precip_anom` | Anomalía estandarizada de la lluvia del mes, promedio ponderado de 20 departamentos con los pesos de cada uno en el IPAP | desviaciones estándar | NASA POWER | `clima` |
| `precip_anom_3m` | Anomalía de lluvia acumulada de 3 meses, dividida por raíz de 3 (aproximación al SPI-3) | desviaciones estándar | NASA POWER | `clima` |
| `precip_anom_6m` | Anomalía de lluvia acumulada de 6 meses, dividida por raíz de 6 (aproximación al SPI-6) | desviaciones estándar | NASA POWER | `clima` |
| `fert_usd` | Canasta de fertilizantes: media geométrica de urea, DAP y cloruro de potasio | dólares por tonelada | Banco Mundial, Pink Sheet | `insumos` |
| `petroleo_usd` | Petróleo, promedio de referencias | dólares por barril | Banco Mundial, Pink Sheet | `insumos` |

## Estadísticas descriptivas

Calculadas sobre toda la base (enero de 2011 a septiembre de 2026).

| Variable | Periodo con datos | N | Faltantes | Media | Desv. est. | Mínimo | Mediana | Máximo |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `IPAP` | 2011-01 a 2026-09 | 189 | 0 | 153.17 | 57.67 | 88.39 | 129.57 | 256.72 |
| `trm_promedio_mes` | 2011-01 a 2026-09 | 189 | 0 | 3127.55 | 886.50 | 1761.59 | 3155.76 | 4926.66 |
| `IPC_No_durables` | 2011-01 a 2026-09 | 189 | 0 | 112.46 | 35.13 | 73.28 | 99.66 | 184.25 |
| `ISE_Agro` | 2011-01 a 2026-08 | 188 | 1 | 99.75 | 4.04 | 85.92 | 100.48 | 105.65 |
| `fao_ffpi_total` | 2011-01 a 2026-09 | 189 | 0 | 114.47 | 16.96 | 84.90 | 119.10 | 160.20 |
| `fao_carne` | 2011-01 a 2026-09 | 189 | 0 | 106.65 | 11.18 | 84.40 | 105.80 | 131.30 |
| `fao_lacteos` | 2011-01 a 2026-09 | 189 | 0 | 118.16 | 20.92 | 72.70 | 118.10 | 158.20 |
| `fao_cereales` | 2011-01 a 2026-09 | 189 | 0 | 115.74 | 20.50 | 86.00 | 111.60 | 173.50 |
| `fao_aceites` | 2011-01 a 2026-09 | 189 | 0 | 127.36 | 35.85 | 76.59 | 121.52 | 251.80 |
| `fao_azucar` | 2011-01 a 2026-09 | 189 | 0 | 108.49 | 25.52 | 63.20 | 107.70 | 183.20 |
| `precip_anom` | 2011-01 a 2026-09 | 189 | 0 | -0.01 | 0.74 | -1.80 | -0.04 | 3.20 |
| `precip_anom_3m` | 2011-01 a 2026-09 | 189 | 0 | 0.00 | 0.97 | -2.56 | 0.06 | 3.35 |
| `precip_anom_6m` | 2011-01 a 2026-09 | 189 | 0 | 0.02 | 1.15 | -3.41 | 0.05 | 2.47 |
| `fert_usd` | 2011-01 a 2026-09 | 189 | 0 | 392.93 | 147.97 | 225.19 | 365.65 | 1019.84 |
| `petroleo_usd` | 2011-01 a 2026-09 | 189 | 0 | 75.23 | 22.93 | 21.00 | 73.30 | 117.80 |

El IPAP pasa de 89.15 en enero de 2011 a 254.74 en septiembre de 2026. Su mínimo (88.39) es de octubre de 2013 y su máximo (256.72) de marzo de 2026.

## Cómo entra cada variable a los modelos

El código no usa las variables en nivel dentro de los modelos de machine learning. Las transforma en variaciones para que los árboles puedan pronosticar valores que nunca vieron (ver el PASO 7 del código).

| Grupo | Columnas | Transformación en los modelos de ML | Rezago de publicación |
|---|---|---|---|
| IPAP | `IPAP` | Logaritmo. Crecimiento mensual con `L` rezagos, promedios de 3, 6 y 12 meses y distancia al promedio de 12 meses | — |
| `trm` | `trm_promedio_mes` | Variación mensual (`LX` rezagos), variación anual y distancia al promedio de 12 meses | 0 meses |
| `ipc` | `IPC_No_durables` | Variación mensual (`LX` rezagos) y variación anual | 0 meses |
| `ise` | `ISE_Agro` | Variación anual, en `t` y en `t-3` | 1 mes |
| `fao` | `fao_ffpi_total` y subíndices | Índice total: variación mensual y anual. Subíndices: variación anual | 1 mes |
| `clima` | `precip_anom`, `precip_anom_3m`, `precip_anom_6m` | En nivel (ya son anomalías) | 1 mes |
| `insumos` | `fert_usd`, `petroleo_usd` | Fertilizantes: variación mensual (`LX` rezagos) y anual. Petróleo: variación anual | 1 mes |

**Rezago de publicación.** La fila de un mes solo usa lo que ya era público en ese mes. Se supone que el pronóstico se hace cuando ya salieron el IPAP y el IPC del último mes, alrededor del día 10 del mes siguiente. El ISE, la FAO, la lluvia y los insumos se rezagan un mes. Así ningún modelo usa información del futuro. El código lo comprueba en el PASO 7 ("Verificación anti-fuga").

**Modelos autorregresivos.** El SARIMA y el ARMA(2,2)+SAR(1) solo usan el IPAP. El VECM usa el logaritmo del IPAP y del IPC de no durables.

## Variables que se probaron y se quitaron

Se probaron como exógenas el **ONI** (índice del fenómeno de El Niño y La Niña, de la NOAA) y el **IPP agropecuario** (DANE). Se quitaron porque no mejoraban el pronóstico. Al sacarlos, el MAPE de validación del Random Forest con exógenas bajó 0.18 puntos (ONI) y 0.14 puntos (IPP). El efecto del clima ya lo recoge la anomalía de lluvia, y el IPP repite la información del propio IPAP. Por eso no están en la base.

## Notas sobre las fuentes

1. Los valores de la FAO son los de la última versión publicada. La FAO advierte que los datos recientes de carne son en parte proyectados y pueden revisarse.
2. La serie de la FAO se verificó contra los valores que muestra la página de la FAO para septiembre de 2026.
3. La lluvia se construyó con datos de NASA POWER por departamento, ponderados con el peso de cada departamento en el IPAP.
4. Si una fuente revisa sus cifras, los resultados pueden cambiar un poco al actualizar la base.

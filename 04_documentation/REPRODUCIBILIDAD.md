# Reproducibilidad

Este documento explica cómo reproducir los resultados, qué puede cambiar entre computadores y cómo comprobar que una corrida coincide con la publicada.

## Entorno con el que se generó la carpeta `03_outputs/`

| Componente | Versión |
|---|---|
| R | 4.4.3 (2025-02-28) |
| Sistema operativo | Linux, 2 núcleos |

| Paquete | Versión |
|---|---|
| `readxl` | 1.6.0 |
| `ggplot2` | 4.0.3 |
| `forecast` | 9.0.2 |
| `urca` | 1.3.4 |
| `vars` | 1.6.1 |
| `lmtest` | 0.9.40 |
| `tseries` | 0.10.63 |
| `ranger` | 0.18.0 |
| `xgboost` | 3.4.2.1 |

`02_code/setup.R` (que corre al comienzo de `main.R`) muestra las versiones instaladas en el computador al lado de estas y avisa si la de `xgboost` es distinta. También se pueden ver en la consola de R con:

```r
sessionInfo()
packageVersion("xgboost")   # o cualquier otro paquete
```

## Qué garantiza el código

1. **Semilla fija.** `SEED <- 2026` en el PASO 1. Random Forest usa `seed = SEED + h` en cada horizonte y XGBoost también. Con el mismo computador y los mismos paquetes, dos corridas dan exactamente los mismos números.
2. **Rutas relativas.** El Excel se lee de `01_data/IPAP_De_completa.xlsx` y los resultados se guardan en `03_outputs/`. Las rutas parten de la carpeta principal del repositorio, no de `02_code/`. Basta con abrir el proyecto `ipap-bmc-reto-b.Rproj`, o fijar la carpeta de trabajo en la carpeta principal del repositorio.
3. **Revisión de la base al cargarla (PASO 2).** El script se detiene con un mensaje si:
   - falta alguna de las 16 columnas;
   - hay meses repetidos o meses faltantes en la secuencia;
   - el IPAP, la TRM o el IPC tienen datos vacíos;
   - una variable tiene más meses vacíos al final que su rezago de publicación, o tiene vacíos en medio de la serie.
4. **Verificación anti-fuga (PASO 7).** Calcula los atributos exógenos con toda la muestra y con la muestra cortada, y comprueba que son iguales. Si un atributo usara datos del futuro, el script se detiene.
5. **Paquetes.** `02_code/setup.R` y el PASO 0 del modelo instalan los que falten. `vars` y `xgboost` son opcionales: si alguno no se puede instalar, el script sigue y omite el VECM o los modelos XGBoost, con un aviso. En ese caso los resultados **no** son los oficiales.

## Qué puede cambiar entre computadores

- **Versión de `xgboost`.** Es la fuente de diferencias más probable, y se recomienda la versión 2.0 o más reciente (CRAN instala hoy la 3.x). Hay dos razones:
  - **Semilla.** Los modelos XGBoost usan muestreo aleatorio (`subsample = 0.8` y `colsample_bytree = 0.8`). En las versiones 1.x el paquete de R ignora el parámetro `seed` y usa el generador de R, así que una misma especificación podía dar un MAPE en la búsqueda de hiperparámetros y otro en la evaluación. Por eso el código llama `set.seed(SEED + h)` antes de cada `xgb.train`. Con `xgboost` 3.x esa línea no cambia ningún resultado (se comprobó), y con 1.x hace que la búsqueda y la evaluación coincidan.
  - **Punto de partida.** Antes de la versión 2.0, XGBoost empieza todos los árboles desde 0.5. Aquí el objetivo es el cambio del logaritmo del IPAP, que es cercano a 0, así que con pocas rondas el pronóstico queda sesgado. Desde la 2.0 ese punto de partida se estima con los datos. Por eso 1.x y 3.x dan resultados distintos en XGBoost aunque la semilla esté bien fijada. Como ejemplo, el mejor MAPE de validación de XGBoost sin exógenas, con la misma base y el mismo código, fue:

  | Versión de `xgboost` | Mejor MAPE de validación, XGBoost sin exógenas |
  |---|---:|
  | 1.7.6 | 7.96 |
  | 3.1.3 | 7.71 |
  | 3.4.2.1 (la de la carpeta `03_outputs/`) | 7.70 |

  Los modelos que no usan `xgboost` (SARIMA, ARMA, VECM y los dos Random Forest) dan lo mismo con cualquiera de esas versiones.

  Otro ejemplo: en un computador del equipo con Windows, R 4.4.2 y `xgboost` 1.7.11.1, el MAPE de prueba del modelo final fue 0.95, frente a 0.85 con `xgboost` 3.4.2.1. La versión de `xgboost` que instala hoy CRAN es de la serie 3.x.
- **Versión de `ranger`.** Con la misma semilla, versiones distintas pueden producir bosques distintos.
- **Número de núcleos.** El código fija `NTHREADS` según el computador (todos los núcleos menos uno) y lo usa solo en `ranger`; según el comentario del código, eso no cambia los resultados. XGBoost se corre siempre con un solo hilo (`nthread = 1`). Para descartar esta fuente de diferencias, se puede fijar `NTHREADS <- 1` en el PASO 1, que es como se generó la carpeta `03_outputs/` (computador de 2 núcleos).
- **Tildes en los gráficos.** En Windows, Mac y RStudio se ven bien. Si se corre con `Rscript` en Linux sin un idioma UTF-8 configurado, las letras con tilde de los títulos pueden salir mal. Se arregla corriendo `LC_ALL=C.UTF-8 Rscript main.R`. Las cifras no cambian.
- **SARIMA, ARMA y VECM.** Son deterministas: deben dar lo mismo en cualquier computador, salvo diferencias de redondeo en el último decimal.

## Cómo comprobar que una corrida coincide

Después de correr el script completo, se comparan estos archivos de `03_outputs/` con las cifras de [RESULTADOS.md](../03_outputs/RESULTADOS.md):

| Archivo | Qué revisar |
|---|---|
| `tabla_comparacion_modelos.csv` | MAPE de validación y de prueba de cada modelo |
| `prueba_historica_elegido.csv` | IPAP predicho mes a mes en la prueba |
| `pronostico_12m_elegido.csv` | Pronóstico de octubre de 2026 a septiembre de 2027 |

Si los modelos autorregresivos coinciden y solo cambian los de XGBoost, la diferencia viene de la versión de los paquetes, no de los datos ni del código.

## Tiempo de ejecución

La corrida del modelo que generó la carpeta `03_outputs/` tardó **1 hora y 44 minutos** en un computador Linux de 2 núcleos (`NTHREADS = 1`). Casi todo el tiempo se va en la búsqueda de hiperparámetros, porque cada combinación se evalúa en los 16 cortes de validación:

| Etapa | Combinaciones | Tiempo |
|---|---:|---:|
| Random Forest | 36 | 13.4 min |
| Random Forest + exógenas | 64 | 36.8 min |
| XGBoost | 36 | 2.8 min |
| XGBoost + exógenas | 48 | 26.3 min |
| Resto (modelos autorregresivos, ablación, evaluación, importancia y gráficos) | — | unos 24 min |

En un computador con más núcleos, el Random Forest corre más rápido, porque `ranger` usa `NTHREADS` hilos. XGBoost siempre corre con un hilo.

## Cómo actualizar el pronóstico con un mes nuevo

1. Agregar la fila del nuevo mes al final de `01_data/IPAP_De_completa.xlsx`, con las mismas 16 columnas y la fecha como último día del mes.
2. Si alguna fuente publica tarde (como el ISE), se puede dejar vacío **solo el último mes** de esa columna. El código acepta tantos meses vacíos al final como el rezago de publicación de la variable (`PUB_LAG` en el PASO 1).
3. Correr `main.R` (o solo `02_code/ipap_concurso_final.R`). La prueba, la validación y el pronóstico se mueven solos un mes hacia adelante, porque se calculan a partir del último dato.

## Buenas prácticas para el repositorio en GitHub

- **No subir archivos de sesión.** El `.gitignore` excluye `.Rhistory`, `.RData`, `.Rproj.user/`, `Rplots.pdf` y los temporales de Excel (`~$*.xlsx`).
- **Finales de línea.** El `.gitattributes` evita que Windows y Mac/Linux marquen cambios falsos en el código por los saltos de línea, y trata el Excel y los PNG como binarios.
- **Subir los resultados junto con el código.** Así cualquiera puede ver las cifras sin correr nada, y comparar su corrida con la publicada.
- **Un commit por cambio, con un mensaje claro.** Por ejemplo: `Actualiza la base con octubre de 2026` o `Agrega gráfico de la prueba histórica`.
- **Si cambia la base o el código, volver a correr el script y subir los resultados nuevos en el mismo commit**, para que código, datos y resultados siempre coincidan.

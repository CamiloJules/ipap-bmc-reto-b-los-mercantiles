# Referencias

Bibliografía, fuentes de datos y software usados en el proyecto. La bibliografía es la misma que está al comienzo de [`02_code/ipap_concurso_final.R`](../02_code/ipap_concurso_final.R), donde cada referencia se relaciona con la decisión del modelo que respalda.

## Bibliografía

### Combinación de pronósticos

- Bates, J. M. y Granger, C. W. J. (1969). The combination of forecasts. *Operational Research Quarterly*, 20(4), 451-468.
- Claeskens, G., Magnus, J. R., Vasnev, A. L. y Wang, W. (2016). The forecast combination puzzle: a simple theoretical explanation. *International Journal of Forecasting*, 32(3), 754-762.
- Makridakis, S., Spiliotis, E. y Assimakopoulos, V. (2020). The M4 Competition: 100,000 time series and 61 forecasting methods. *International Journal of Forecasting*, 36(1), 54-74.
- McWilliams, W., Stewart, S. L. e Isengildina Massa, O. (2026). Food price inflation forecasting: insights from a Macroeconomic Auto-Regressive Random Forest approach. *Food Policy*, 142, 103115.
- Timmermann, A. (2006). Forecast combinations. En *Handbook of Economic Forecasting*, vol. 1, cap. 4, 135-196. Elsevier.

**Para qué se usan:** respaldan que el modelo final sea el promedio simple de los siete modelos (PASO 1 y PASO 11 del código).

### Machine learning: Random Forest y XGBoost

- Breiman, L. (2001). Random forests. *Machine Learning*, 45(1), 5-32.
- Chen, T. y Guestrin, C. (2016). XGBoost: a scalable tree boosting system. *Proceedings of the 22nd ACM SIGKDD*, 785-794.
- Friedman, J. H. (2001). Greedy function approximation: a gradient boosting machine. *Annals of Statistics*, 29(5), 1189-1232.
- Geurts, P., Ernst, D. y Wehenkel, L. (2006). Extremely randomized trees. *Machine Learning*, 63(1), 3-42.
- Medeiros, M. C., Vasconcelos, G. F. R., Veiga, A. y Zilberman, E. (2021). Forecasting inflation in a data-rich environment: the benefits of machine learning methods. *Journal of Business & Economic Statistics*, 39(1), 98-119.
- Strobl, C., Boulesteix, A.-L., Zeileis, A. y Hothorn, T. (2007). Bias in random forest variable importance measures: illustrations, sources and a solution. *BMC Bioinformatics*, 8, 25.

**Para qué se usan:** los métodos de árboles, la opción Extra Trees, y la decisión de escoger las variables con ablación y no con la importancia (PASOS 7, 10 y 13).

### Aplicaciones en Colombia

- Anzola Bravo, C. y Poveda, P. (2025). Forecasting Disaggregated Food Inflation Baskets in Colombia with an XGBoost Model. *Borradores de Economía* No. 1335, Banco de la República. https://doi.org/10.32468/be.1335
- Roldán-Ferrín, F. y Parra-Polanía, J. A. (2025). Enhancing inflation nowcasting with online search data: a random forest application for Colombia. *Borradores de Economía* No. 1318, Banco de la República. https://doi.org/10.32468/be.1318
- Sánchez Conde, O. L. (2024). *Predicción de precios del mercado agrícola en Colombia: aplicación de modelos de aprendizaje automático y minería de datos para la toma de decisiones en la agricultura*. Tesis de Maestría en Ingeniería Analítica, Universidad Nacional de Colombia, Sede Medellín.

**Para qué se usan:** muestran que estos métodos ya se usan para pronosticar precios e inflación de alimentos en Colombia.

### Validación y estrategia de pronóstico

- Ben Taieb, S., Bontempi, G., Atiya, A. F. y Sorjamaa, A. (2012). A review and comparison of strategies for multi-step ahead time series forecasting based on the NN5 forecasting competition. *Expert Systems with Applications*, 39(8), 7067-7083.
- Bergmeir, C., Hyndman, R. J. y Koo, B. (2018). A note on the validity of cross-validation for evaluating autoregressive time series prediction. *Computational Statistics & Data Analysis*, 120, 70-83.

**Para qué se usan:** la estrategia directa (un modelo por horizonte) y la validación con cortes móviles hacia adelante (PASOS 7 y 8).

### Series de tiempo y cointegración

- Dickey, D. A. y Fuller, W. A. (1979). Distribution of the estimators for autoregressive time series with a unit root. *Journal of the American Statistical Association*, 74(366), 427-431.
- Hyndman, R. J. y Khandakar, Y. (2008). Automatic time series forecasting: the forecast package for R. *Journal of Statistical Software*, 27(3), 1-22.
- Johansen, S. (1988). Statistical analysis of cointegration vectors. *Journal of Economic Dynamics and Control*, 12(2-3), 231-254.
- Johansen, S. (1991). Estimation and hypothesis testing of cointegration vectors in Gaussian vector autoregressive models. *Econometrica*, 59(6), 1551-1580.

**Para qué se usan:** la prueba de raíz unitaria, el SARIMA automático y el VECM (PASOS 3 y 5).

## Fuentes de datos

| Variable | Fuente |
|---|---|
| IPAP | Bolsa Mercantil de Colombia (BMC) |
| TRM promedio del mes | Banco de la República |
| IPC de bienes no durables | DANE |
| ISE agropecuario | DANE |
| Índice de precios de los alimentos y subíndices | FAO, Food Price Index |
| Anomalías de lluvia | NASA POWER (datos por departamento, ponderados por el peso de cada departamento en el IPAP) |
| Fertilizantes y petróleo | Banco Mundial, Commodity Price Data (Pink Sheet) |

El detalle de cada variable (unidades, transformaciones y rezagos de publicación) está en [DATOS.md](DATOS.md).

## Software

- R Core Team. *R: A Language and Environment for Statistical Computing*. R Foundation for Statistical Computing, Viena. Versión 4.4.3.
- Paquetes de R: `readxl`, `ggplot2`, `forecast`, `urca`, `vars`, `lmtest`, `tseries`, `ranger` y `xgboost`. Sus versiones están en [REPRODUCIBILIDAD.md](REPRODUCIBILIDAD.md). La cita de cada paquete se obtiene en R con `citation("nombre_del_paquete")`.

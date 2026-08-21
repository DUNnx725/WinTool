# WinTool

Herramienta de código abierto para diagnóstico, mantenimiento y optimización de Windows.

WinTool está diseñado para hacer que las herramientas de diagnóstico, mantenimiento y rendimiento de Windows sean más fáciles de entender y utilizar, manteniendo los cambios controlados y reversibles siempre que sea posible.

## Funciones principales

- Estado y diagnóstico de la PC
- Alertas inteligentes
- Mantenimiento inteligente
- Optimización para juegos
- Configuración de privacidad recomendada
- Herramientas de red y DNS
- Reparación de Windows
- Herramientas para drivers y hardware
- Actualización de software mediante WinGet
- Análisis de rendimiento
- WinAnalyzer para analizar el rendimiento en juegos

## WinAnalyzer

WinAnalyzer es el módulo de análisis de juegos de WinTool.

Puede medir y mostrar información como:

- FPS promedio
- 1% Low
- FPS mínimo detectado
- Estabilidad de FPS
- Uso de CPU
- Núcleo de CPU más utilizado
- Uso de GPU
- Uso de RAM
- Posibles límites de FPS / VSync
- Posibles cuellos de botella de CPU o GPU

Los resultados principales están diseñados para ser fáciles de entender, mientras que la información más técnica se mantiene disponible por separado.

## Compatibilidad

- Windows 10 de 64 bits
- Windows 11 de 64 bits

## Idiomas

WinTool está disponible en:

- Español
- Inglés

Documentación en inglés: [README.md](README.md)

## Seguridad

WinTool prioriza los cambios controlados y el diagnóstico antes de realizar modificaciones.

Las funciones de optimización están diseñadas para evitar ajustes poco seguros como prioridad de procesos Realtime, cambios arbitrarios de afinidad de CPU, modificaciones de HPET/BCD, desactivar el archivo de paginación o deshabilitar servicios críticos de Windows.

Varias modificaciones incluyen mecanismos de copia de seguridad o restauración.

## Componentes de terceros

WinTool utiliza componentes de código abierto de terceros para determinadas funciones.

PresentMon es utilizado por WinAnalyzer para capturar información sobre el rendimiento de los frames.

Los proyectos de terceros pertenecen a sus respectivos autores y se distribuyen de acuerdo con sus respectivas licencias.

Consulta `THIRD_PARTY_NOTICES.md` para obtener más información.

## Licencia

WinTool es software de código abierto publicado bajo la GNU General Public License v3.0.

Consulta [LICENSE](LICENSE) para obtener más información.

## Autor

Desarrollado por **DUNnx725**.

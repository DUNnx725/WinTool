# WinTool

**Herramienta de código abierto para diagnóstico, mantenimiento y optimización de Windows.**

WinTool está diseñado para hacer que las herramientas de diagnóstico, mantenimiento y rendimiento de Windows sean más fáciles de entender y utilizar, manteniendo los cambios controlados y reversibles siempre que sea posible.

**Windows 10 / 11 • Español / English • Código abierto**

## 🚀 Descarga

Descargá la última versión estable desde la sección **Releases** de este repositorio.

- `WinTool_v1.1.0_ES.zip` — Español
- `WinTool_v1.1.0_EN.zip` — English

> [!IMPORTANT]
> Para uso normal, descargá WinTool desde **Releases** en lugar de utilizar `Code > Download ZIP`.

## ✨ Características

- Estado de la PC y diagnóstico del sistema
- Alertas inteligentes
- Mantenimiento inteligente
- Optimización para juegos
- Configuración de privacidad recomendada
- Herramientas de red y DNS
- Herramientas de reparación de Windows
- Utilidades para controladores y hardware
- Actualización de software mediante WinGet
- Análisis de rendimiento
- Analizador de rendimiento para juegos WinAnalyzer

## 🎮 WinAnalyzer

WinAnalyzer es el módulo de análisis de rendimiento en juegos de WinTool.

Puede medir y presentar información como:

- FPS promedio
- 1% Low FPS
- FPS mínimos detectados
- Estabilidad de los FPS
- Uso de CPU
- Núcleo de CPU más utilizado
- Uso de GPU
- Uso de RAM
- Posibles límites de FPS / VSync
- Posibles cuellos de botella de CPU o GPU

Los resultados principales están diseñados para ser fáciles de entender, mientras que la información más técnica permanece disponible por separado.

## 🧰 Primeros pasos

1. Descargá el ZIP correspondiente desde **Releases**.
2. Extraé el archivo completo.
3. Abrí la carpeta de WinTool extraída.
4. Ejecutá `WinTool.bat`.
5. Seguí las opciones que aparecen en pantalla.

Algunas herramientas pueden solicitar permisos de administrador cuando sean necesarios.

## 🛡️ Seguridad

WinTool prioriza los cambios controlados y el diagnóstico antes de modificar el sistema.

Las funciones de optimización están diseñadas para evitar ajustes inseguros como la prioridad de proceso Realtime, cambios arbitrarios de afinidad de CPU, modificaciones de HPET/BCD, desactivar el archivo de paginación o desactivar servicios críticos de Windows.

Varias modificaciones incluyen mecanismos de copia de seguridad o restauración.

> [!WARNING]
> WinTool puede modificar configuraciones de Windows. Revisá la información mostrada antes de aplicar cambios.

## 🖥️ Compatibilidad

- Windows 10 de 64 bits
- Windows 11 de 64 bits

## 🌐 Idiomas

WinTool está disponible en:

- Español
- Inglés

Documentación en inglés: [README.md](README.md)

## 📦 Componentes de terceros

WinTool utiliza componentes de código abierto de terceros para funciones específicas.

PresentMon es utilizado por WinAnalyzer para capturar información sobre el rendimiento de fotogramas.

Los proyectos de terceros continúan siendo propiedad de sus respectivos autores y se distribuyen de acuerdo con sus respectivas licencias.

Consultá [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) para obtener más información.

## 🔐 Seguridad del proyecto

La información de seguridad y las instrucciones para reportar vulnerabilidades están disponibles en [SECURITY.md](SECURITY.md).

## 📜 Licencia

WinTool es software de código abierto publicado bajo la GNU General Public License v3.0.

Consultá [LICENSE](LICENSE) para más información.

## 👤 Autor

Desarrollado por **DUNnx725**.

# Doctor Chile 🌶️

Aplicación móvil **100% offline** desarrollada en Flutter para el diagnóstico asistido de enfermedades y plagas foliares en plantas de chile (*Capsicum*), utilizando inferencia local con **ONNX Runtime** y un modelo de clasificación **YOLO11s-cls**.

> **Aviso importante:** Esta aplicación es una herramienta de apoyo orientativo y **no sustituye la evaluación de un ingeniero agrónomo o técnico fitosanitario**. Antes de aplicar agroquímicos o retirar plantas, confirme el diagnóstico en campo.

---

## Características principales

- **Operación totalmente sin conexión (Offline-first):** El modelo neuronal (`assets/models/best.onnx`) y la base de datos SQLite se ejecutan íntegramente en el dispositivo, pensado para zonas agrícolas sin cobertura celular.
- **5 clases foliares soportadas:**
  | Índice | Clave | Nombre en UI |
  | :---: | :--- | :--- |
  | `0` | `Curl` | Hoja rizada (Virus del rizado) |
  | `1` | `Healthy` | Hoja sana |
  | `2` | `Spot` | Mancha foliar (Cercospora / bacteriana) |
  | `3` | `Whitefly` | Mosca blanca |
  | `4` | `Yellowish` | Amarillamiento (Deficiencia / virosis) |
- **Sistema de seguridad de 3 estados en el diagnóstico:**
  - **Concluyente (`concluyente`):** Confianza $\ge 70\%$ y margen sobre la segunda clase $\ge 15\%$. Muestra diagnóstico y recomendaciones de manejo.
  - **Poca confianza (`pocaConfianza`):** Confianza entre $45\%$ y $70\%$, o margen reducido entre las dos clases principales. Advierte incertidumbre y oculta recomendaciones químicas.
  - **No reconocido (`noEsHoja`):** Confianza $< 45\%$ o entropía normalizada $\ge 0.85$. Solicita repetir la toma enfocando una sola hoja de chile.
- **Preprocesamiento en segundo plano:** Decodificación EXIF, recorte central cuadrado (*center-crop*) y normalización RGB `NCHW` ejecutados en un `Isolate` secundario para mantener la interfaz fluida.
- **Historial local resiliente:** Almacenamiento en SQLite (`versionEsquema = 3`) con rutas relativas portables, paginación incremental, limpieza automática de imágenes huérfanas y recuperación de cámara en Android (`retrieveLostData`).

---

## Estructura del proyecto

```text
lib/
├── core/
│   ├── constants/       # Definición de clases fitosanitarias y recomendaciones (chili_classes.dart)
│   ├── database/        # Persistencia SQLite v3, migraciones y limpieza de archivos (local_database.dart)
│   ├── errors/          # Jerarquía DoctorChileError y mensajes amigables (app_errors.dart)
│   ├── theme/           # Tema visual Material 3 en modo claro (app_theme.dart)
│   ├── utils/           # Sincronización de inicialización única (carga_unica.dart)
│   └── widgets/         # Componentes transversales (descargo_responsabilidad.dart)
├── features/
│   ├── diagnosis/
│   │   ├── domain/      # Contratos, PredictionResult y EstadoResultado
│   │   ├── presentation/# Pantallas de Inicio, Resultado y widgets de estado
│   │   └── services/    # YoloService (ONNX), preprocesamiento en Isolate y reglas de decisión
│   └── history/
│       ├── domain/      # Entidad DiagnosisRecord
│       └── presentation/# Historial paginado y pantalla de Detalle
└── main.dart            # Punto de entrada, localización es_MX e inyección de dependencias
```

---

## Requisitos e instalación

1. **Flutter SDK:** `>= 3.32.0` (Dart `^3.8.0`)
2. Instalar dependencias:
   ```bash
   flutter pub get
   ```
3. Ejecutar en modo desarrollo:
   ```bash
   flutter run
   ```

---

## Verificación de calidad y pruebas

El proyecto cuenta con pruebas unitarias, de base de datos (`sqflite_common_ffi`), de integridad documental del modelo ONNX y pruebas de widgets:

```bash
# Análisis estático (0 advertencias esperadas)
flutter analyze

# Suite completa de pruebas automatizadas
flutter test
```

---

## Documentación técnica adicional

- [**Contrato y Auditoría del Modelo (`docs/MODEL.md`)**](docs/MODEL.md): Especificación del tensor de entrada/salida, hash SHA-256 del binario `best.onnx`, orden de clases, umbrales de decisión, métricas de entrenamiento y protocolo de validación en campo.
- [**Guía de Compilación, Firma y Publicación (`docs/PUBLICAR.md`)**](docs/PUBLICAR.md): Instrucciones para configurar `key.properties`, generar APKs por ABI (`--split-per-abi`), App Bundles y activar la minificación R8 con ProGuard.

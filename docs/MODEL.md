# Modelo de clasificación (`assets/models/best.onnx`)

Documento de trazabilidad del modelo que empaqueta la aplicación. Si se
reemplaza el archivo `.onnx`, **actualiza este documento** (hash y orden de
clases) y el catálogo en `lib/core/constants/chili_classes.dart`. La prueba
`test/model/model_doc_test.dart` falla si el archivo, el hash documentado o el
orden de clases dejan de coincidir.

## Identificación (`chili_v4` — Activo)

| Campo | Valor |
|---|---|
| Archivo | `assets/models/best.onnx` |
| SHA-256 | `8c0a3f11222b574dfff2233e2c11036c33b57a3e1ad124d95d38b2e527299991` |
| Tamaño | 21 814 160 bytes (≈ 20.8 MB) |
| Arquitectura | `yolo11s-cls` (Small, 5 441 814 parámetros fusionados, opset 17, 6 salidas) |
| Identificador en la app | `best.onnx` (se guarda en cada diagnóstico como `model_version`) |

> El SHA-256 se calcula con `Get-FileHash assets\models\best.onnx -Algorithm SHA256`
> (PowerShell) o `sha256sum assets/models/best.onnx` (Linux/macOS).

## Entrada y salida esperadas

- **Entrada:** tensor `float32` `[1, 3, 224, 224]`, NCHW, RGB, valores 0.0–1.0.
  Preprocesado: corrige orientación EXIF, recorte cuadrado central y
  redimensionado a 224×224 con interpolación lineal.
- **Salida:** vector `output0` de 6 valores `float32` (probabilidades ya
  normalizadas con Softmax por la cabeza `Classify` de Ultralytics; suman 1.0):
  los índices `0..4` corresponden a las 5 clases foliares y el índice `5`
  corresponde a `Z_No_hoja` (rechazo explícito de imágenes no foliares, pasto
  sintético, césped u objetos verdes).
- La app valida en tiempo de ejecución que la salida tenga valores finitos y
  dispara `EstadoResultado.noEsHoja` tanto si la proporción vegetal es baja como
  si la red neuronal predice `Z_No_hoja` en el índice `5`.

## Orden de clases

Es el orden que usa el código para interpretar las 5 clases foliares del modelo:

<!-- CLASES:INICIO -->
0: Curl
1: Healthy
2: Spot
3: Whitefly
4: Yellowish
<!-- CLASES:FIN -->

- **Índice adicional de rechazo (`5`):** `Z_No_hoja` (`indiceClaseNoHoja = 5` en
  `lib/features/diagnosis/services/inference_utils.dart`). Cuando el índice `5`
  obtiene la mayor probabilidad, `evaluarPrediccion` devuelve
  `EstadoResultado.noEsHoja` sin importar el porcentaje de color verde.

> **Verificado (`chili_v4`):** el campo `names` guardado dentro de
> `modelo/chili_v4/weights/best.pt` lista `Curl, Healthy, Spot, Whitefly,
> Yellowish, Z_No_hoja`, conservando intactos los índices `0..4` de
> `ChiliClasses` y coincidiendo con los ejes de las matrices de confusión en
> `modelo/chili_v4_test_eval/`.

## Umbrales y defensas de decisión (en `inference_utils.dart`)

| Defensa / Umbral | Valor | Efecto |
|---|---|---|
| Clase neuronal `Z_No_hoja` (`indiceClaseNoHoja`) | Índice `5` ganador | Resultado `noEsHoja` (bloquea **99.67 % (`306/307`)** de trampas verdes como pasto sintético con caucho negro, césped y tela verde) |
| Proporción mínima de píxeles foliares (`umbralVegetacionMinima`) | `0.15` | Por debajo: resultado `noEsHoja` ("no parece una hoja") |
| Confianza mínima (`umbralConfianzaMinima`) | `0.70` | Por debajo: resultado `pocaConfianza` ("no concluyente") |

## Entrenamiento de `chili_v4` (fuente: `modelo/chili_v4/`)

| Campo | Valor |
|---|---|
| Arquitectura | `yolo11s-cls` (clasificación Small, 6 clases), preentrenada + evaluación con *Model Soup* |
| Épocas / lote / tamaño | 30 / 16 / 224×224 (`patience: 30`) |
| Optimizador e hiperparámetros | `AdamW` (`lr0: 0.0004`, `lrf: 0.01`, `cos_lr: true`, `warmup_epochs: 2.0`, `dropout: 0.25`) |
| Preservación cromática | `auto_augment: None`, HSV moderado (`0.008/0.30/0.30`), rotación `±30°`, `flipud: 0.5`, `fliplr: 0.5`, `scale: 0.30`, `erasing: 0.10` |
| Dataset (`Chili_Dataset_v4`) | **4 dominios deduplicados por `SHA-256` y agrupados por `dHash <= 10`** (0 % de fuga entre particiones): `3 856` `train`, `498` `val`, `501` `test` (`4 855` imágenes efectivas) |
| Dominios incluidos | 1) **Campo original** (`~1600×2100`, 5 clases), 2) **Indonesia** (`100×100`, 5 clases), 3) **PlantVillage** (`256×256`, `Healthy` y `Spot` 1:1), 4) **`No_hoja_coleccion`** (`654` imágenes únicas: `307` trampas verdes, `204` campo sin hoja, `83` objetos cotidianos, `60` texturas) |
| Artefactos | `modelo/chili_v4/`, `modelo/chili_v4_test_eval/` y `modelo/No_hoja_coleccion/` |

## Evolución de métricas (`chili_v1` → `chili_v2` → `chili_v3` → `chili_v4`)

### 1. Particiones oficiales libres de fugas (`Chili_Dataset_v4`: `val` + `test`)

| Split | Total | Campo Original (`~1600×2100`) | Indonesia (`100×100`) | PlantVillage (`256×256`) | `No_hoja` Trampas Verdes | `No_hoja` Otros |
|---|---:|---:|---:|---:|---:|---:|
| `val` | **96.79 %** (`482/498`) | **100.0 %** (`241/241`) | **81.4 %** (`48/59`) | **95.8 %** (`114/119`) | **100.0 %** (`42/42`) | **100.0 %** (`37/37`) |
| `test` | **96.41 %** (`483/501`) | **100.0 %** (`244/244`) | **81.4 %** (`48/59`) | **95.0 %** (`113/119`) | **97.6 %** (`41/42`) | **100.0 %** (`37/37`) |
| **Combinado `val + test` (0 % fuga)** | **96.60 %** (`965/999`) | **100.0 %** (`485/485`) | **81.4 %** (`96/118`) | **95.4 %** (`227/238`) | **98.8 %** (`83/84`) | **100.0 %** (`74/74`) |

### 2. Evaluación exhaustiva sobre las 5 colecciones (`8 635` imágenes)

| Colección | Imágenes | `chili_v3` (5 clases) | `chili_v4` (Global) | `chili_v4` (Solo no vistas en `train`: `4 447`) |
|---|---:|---:|---:|---:|
| `1_PlantVillage_Raiz` (`256×256`) | 2 475 | 99.88 % | **99.47 %** (`2 462/2 475`) | **99.43 %** (`1 736/1 746`) |
| `2_archive_1` (Combinado) | 3 006 | 98.07 % | **96.94 %** (`2 914/3 006`) | **96.39 %** (`1 868/1 938`) |
| `3_archive_3` (`100×100`) | 500 | 93.80 % | **91.40 %** (`457/500`) | **81.36 %** (`96/118`) |
| `4_Con_este_voy_a_entrenar` | 2 000 | 100.00 % | **100.00 %** (`2 000/2 000`) | **100.00 %** (`487/487`) |
| `5_No_hoja_coleccion` (Pasto sintético, objetos, tierra) | 654 | 0.00 % *(86 % falsos concluyentes en trampas verdes)* | **99.85 %** (`653/654`) | **99.37 %** (`157/158`) |
| **TOTAL GLOBAL** | **8 635** | — | **98.27 %** (`8 486/8 635`) | **97.68 %** (`4 344/4 447`) |

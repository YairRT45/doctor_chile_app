# Modelo de clasificación (`assets/models/best.onnx`)

Documento de trazabilidad del modelo que empaqueta la aplicación. Si se
reemplaza el archivo `.onnx`, **actualiza este documento** (hash y orden de
clases) y el catálogo en `lib/core/constants/chili_classes.dart`. La prueba
`test/model/model_doc_test.dart` falla si el archivo, el hash documentado o el
orden de clases dejan de coincidir.

## Identificación (`chili_v3` — Activo)

| Campo | Valor |
|---|---|
| Archivo | `assets/models/best.onnx` |
| SHA-256 | `6cdd091808f2883b007a958aa62d3cdc19b9ba09153979334cd0d9b021377501` |
| Tamaño | 21 809 020 bytes (≈ 20.8 MB) |
| Arquitectura | `yolo11s-cls` (Small, 5 440 533 parámetros fusionados, opset 17) |
| Identificador en la app | `best.onnx` (se guarda en cada diagnóstico como `model_version`) |

> El SHA-256 se calcula con `Get-FileHash assets\models\best.onnx -Algorithm SHA256`
> (PowerShell) o `sha256sum assets/models/best.onnx` (Linux/macOS).

## Entrada y salida esperadas

- **Entrada:** tensor `float32` `[1, 3, 224, 224]`, NCHW, RGB, valores 0.0–1.0.
  Preprocesado: corrige orientación EXIF, recorte cuadrado central y
  redimensionado a 224×224 con interpolación lineal.
- **Salida:** vector `output0` de 5 valores `float32` (probabilidades ya
  normalizadas con Softmax por la cabeza `Classify` de Ultralytics; suman 1.0).
  Si en un modelo futuro fueran logits crudos, `normalizarProbabilidades` aplica
  Softmax automáticamente.
- La app valida en tiempo de ejecución que la salida tenga exactamente 5 valores
  finitos y lanza un error en caso contrario (no asume ninguna clase por defecto).

## Orden de clases

Es el orden que usa el código para interpretar la salida del modelo:

<!-- CLASES:INICIO -->
0: Curl
1: Healthy
2: Spot
3: Whitefly
4: Yellowish
<!-- CLASES:FIN -->

> **Verificado (`chili_v3`):** el campo `names` guardado dentro de
> `modelo/chili_v3/weights/best.pt` lista `Curl, Healthy, Spot, Whitefly,
> Yellowish`, el mismo orden que usa el código, y coincide con los ejes de las
> matrices de confusión en `modelo/chili_v3_test_eval/`.

## Umbrales de decisión (en `inference_utils.dart`)

| Umbral | Valor | Efecto |
|---|---|---|
| Confianza mínima (`umbralConfianzaMinima`) | `0.70` | Por debajo: resultado `pocaConfianza` ("no concluyente") |
| Proporción mínima de píxeles foliares (`umbralVegetacionMinima`) | `0.15` | Por debajo: resultado `noEsHoja` ("no parece una hoja") |

Calibrados sobre objetos no foliares (`modelo/eval_externa/No_hoja/`): con
`umbralVegetacionMinima = 0.15`, se bloquea el **94.1 % (`16/17`)** de imágenes
no foliares antes de emitir un diagnóstico concluyente.

## Entrenamiento de `chili_v3` (fuente: `modelo/chili_v3/`)

| Campo | Valor |
|---|---|
| Arquitectura | `yolo11s-cls` (clasificación Small), preentrenada + evaluación con *Model Soup* (`0.5 * best.pt + 0.5 * last.pt`) |
| Épocas / lote / tamaño | 30 / 16 / 224×224 (`patience: 30`) |
| Optimizador e hiperparámetros | `AdamW` (`lr0: 0.0004`, `lrf: 0.01`, `cos_lr: true`, `warmup_epochs: 2.0`, `dropout: 0.25`) |
| Aumentos | HSV (`0.015/0.7/0.4`), rotación `±30°`, `flipud: 0.5`, `fliplr: 0.5`, `scale: 0.35`, `erasing: 0.15`, RandAugment |
| Dataset (`Chili_Dataset_v3`) | **3 dominios balanceados deduplicados por `SHA-256` y agrupados por `dHash <= 10`** (0 % de fuga de datos entre particiones): `3 360` `train`, `419` `val`, `422` `test` (`4 201` imágenes efectivas) |
| Dominios incluidos | 1) **Campo original** (`~1600×2100`, 5 clases), 2) **Indonesia** (`100×100`, 5 clases incluyendo `healthy`), 3) **PlantVillage** (`256×256`, balanceado 1:1 en `Healthy` y `Bacterial_spot` / `Spot`) |
| Artefactos | `modelo/chili_v3/`, `modelo/chili_v3_test_eval/`, `modelo/chili_v3_eval_dataset_completo/` y `modelo/chili_v3_eval_no_vistas/` |

## Evolución de métricas (`chili_v1` → `chili_v2` → `chili_v3`)

### 1. Particiones oficiales libres de fugas (`Chili_Dataset_v3`: `val` + `test`)

| Split | Total | Dominio 1: Campo Original (`~1600×2100`) | Dominio 2: Indonesia (`100×100`) | Dominio 3: PlantVillage (`256×256`) |
|---|---:|---:|---:|---:|
| `val` | **96.18 %** (`403/419`) | **100.0 %** (`241/241`) | **79.7 %** (`47/59`) | **96.6 %** (`115/119`) |
| `test` | **97.16 %** (`410/422`) | **100.0 %** (`244/244`) | **81.4 %** (`48/59`) | **99.2 %** (`118/119`) |
| **Combinado `val + test` (0 % fuga)** | **96.67 %** (`813/841`) | **100.0 %** (`485/485`) | **80.5 %** (`95/118`) | **97.9 %** (`233/238`) |

### 2. Evaluación exhaustiva sobre las 4 colecciones externas/locales (`7 981` imágenes)

| Colección | Imágenes | `chili_v2` (Global) | `chili_v3` (Global) | `chili_v3` (Solo no vistas en `train`: `4 296`) |
|---|---:|---:|---:|---:|
| `1_PlantVillage_Raiz` (`256×256`) | 2 475 | 73.33 % | **99.88 %** (`2 472/2 475`) | **99.83 %** (`1 747/1 750`) |
| `2_archive_1` (Combinado) | 3 006 | 74.78 % | **98.07 %** (`2 948/3 006`) | **97.47 %** (`1 890/1 939`) |
| `3_archive_3` (`100×100`) | 500 | 75.00 % | **93.80 %** (`469/500`) | **81.51 %** (`97/119`) *(vs 40.2 % en v2)* |
| `4_Con_este_voy_a_entrenar` | 2 000 | 100.00 % | **100.00 %** (`2 000/2 000`) | **100.00 %** (`488/488`) |
| **TOTAL GLOBAL** | **7 981** | **80.67 %** (`6 438/7 981`) | **98.85 %** (`7 889/7 981`) | **98.28 %** (`4 222/4 296`) |

### 3. Exactitud por clase de `chili_v3` en las `7 981` imágenes

| Clase | Aciertos / Total (`7 981` imgs) | Exactitud `chili_v3` | Exactitud `chili_v2` |
|---|---:|---:|---:|
| `Spot` (Mancha foliar / bacteriana) | `2 657 / 2 664` | **99.74 %** | 50.00 % |
| `Healthy` (Hoja sana — 3 dominios) | `3 486 / 3 517` | **99.12 %** | 96.00 % |
| `Whitefly` (Mosca blanca) | `590 / 600` | **98.33 %** | 98.00 % |
| `Curl` (Hoja rizada) | `580 / 600` | **96.67 %** | 97.00 % |
| `Yellowish` (Amarillamiento) | `576 / 600` | **96.00 %** | 96.00 % |

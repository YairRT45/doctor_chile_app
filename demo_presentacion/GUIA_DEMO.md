# Guía Rápida de Demostración (`demo_presentacion`)

Todas las imágenes de esta carpeta fueron probadas contra `assets/models/best.onnx` usando exactamente el mismo recorte, filtro foliar HSV y umbrales de la aplicación **Doctor Chile**.

> **Tip al pasar las fotos al celular:** Pásalas por **cable USB** o envíalas por WhatsApp/Telegram como **"Documento"** (no como galería/imagen comprimida) para conservar los nombres de archivo ordenados y la calidad exacta.

---

## 1. Carpeta `1_Concluyentes/` (10 fotos — 2 por cada clase)
Ideales para mostrar el flujo principal: diagnóstico certero (`100 %`), síntomas, recomendaciones de manejo agrícola y botón principal **"Guardar en el historial"**.

| Archivo | Diagnóstico en pantalla | Confianza | % Vegetal | Estado |
|---|---|---:|---:|---|
| `01_Hoja_Sana_ej1.jpg` | **Hoja Sana** | `100.0 %` | `99.9 %` | `Concluyente` |
| `01_Hoja_Sana_ej2.jpg` | **Hoja Sana** | `100.0 %` | `73.4 %` | `Concluyente` |
| `02_Hoja_Rizada_Curl_ej1.jpg` | **Hoja Rizada (Virus del Rizado)** | `100.0 %` | `98.0 %` | `Concluyente` |
| `02_Hoja_Rizada_Curl_ej2.jpg` | **Hoja Rizada (Virus del Rizado)** | `100.0 %` | `73.3 %` | `Concluyente` |
| `03_Mancha_Foliar_Spot_ej1.jpg` | **Mancha Foliar (Cercospora / Bacteriana)** | `100.0 %` | `53.2 %` | `Concluyente` |
| `03_Mancha_Foliar_Spot_ej2.jpg` | **Mancha Foliar (Cercospora / Bacteriana)** | `100.0 %` | `86.6 %` | `Concluyente` |
| `04_Mosca_Blanca_Whitefly_ej1.jpg` | **Mosca Blanca** | `100.0 %` | `62.1 %` | `Concluyente` |
| `04_Mosca_Blanca_Whitefly_ej2.jpg` | **Mosca Blanca** | `100.0 %` | `74.5 %` | `Concluyente` |
| `05_Amarillamiento_Yellowish_ej1.jpg` | **Amarillamiento (Deficiencia / Virosis)** | `100.0 %` | `82.3 %` | `Concluyente` |
| `05_Amarillamiento_Yellowish_ej2.jpg` | **Amarillamiento (Deficiencia / Virosis)** | `100.0 %` | `99.5 %` | `Concluyente` |

---

## 2. Carpeta `2_Poca_Confianza/` (5 fotos — 1 por cada clase)
Ideales para demostrar la **primera barrera de seguridad (`umbralConfianzaMinima = 70 %`)**: el modelo sí acierta cuál es la afección más probable, pero como la certeza está entre `58 %` y `65 %`, la app marca el resultado como **"Diagnóstico no concluyente"**, **oculta las recomendaciones químicas** para evitar una mala aplicación en campo y promueve tomar otra fotografía.

| Archivo | Clase más probable (acertada) | Confianza | % Vegetal | Estado |
|---|---|---:|---:|---|
| `Dudoso_01_Hoja_Sana.jpg` | Hoja Sana | `62.0 %` | `51.7 %` | `Poca confianza` |
| `Dudoso_02_Hoja_Rizada_Curl.jpg` | Hoja Rizada | `60.0 %` | `57.7 %` | `Poca confianza` |
| `Dudoso_03_Mancha_Foliar_Spot.jpg` | Mancha Foliar | `58.6 %` | `98.0 %` | `Poca confianza` |
| `Dudoso_04_Mosca_Blanca_Whitefly.jpg` | Mosca Blanca | `60.8 %` | `99.8 %` | `Poca confianza` |
| `Dudoso_05_Amarillamiento_Yellowish.jpg` | Amarillamiento | `65.3 %` | `90.6 %` | `Poca confianza` |

---

## 3. Carpeta `3_No_Es_Hoja/` (4 fotos)
Ideales para demostrar la **segunda barrera de seguridad (`umbralVegetacionMinima = 15 %` en espacio HSV)**: aunque la red neuronal por sí sola habría dicho con hasta `94.3 %` de seguridad que una imagen de videojuego o una persona tiene *"Mancha Foliar"*, el filtro foliar de la app detecta que casi no hay tejido vegetal (`1.4 %` a `6.6 %`), **bloquea el diagnóstico falso**, no muestra porcentajes engañosos y pide enfocar una hoja de chile (o también puedes demostrarlo tomando una foto en vivo del salón con la cámara).

| Archivo | % Vegetal detectado | Qué habría dicho el modelo sin defensa | Estado final en la app |
|---|---:|---|---|
| `NoHoja_01_Documento_Comprobante.jpeg` | `4.9 %` | Amarillamiento (`60.4 %`) | **`No es hoja`** |
| `NoHoja_02_Persona_Retrato.jpeg` | `3.3 %` | Mancha Foliar (`73.8 %`) | **`No es hoja`** |
| `NoHoja_03_Videojuego_Escena.jpg` | `1.4 %` | Mancha Foliar (`94.3 %`) | **`No es hoja`** |
| `NoHoja_04_Captura_Pantalla.png` | `6.6 %` | Mancha Foliar (`87.5 %`) | **`No es hoja`** |

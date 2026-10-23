import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../core/errors/app_errors.dart';
import 'inference_utils.dart';

/// Lado (en píxeles) del cuadrado que espera el modelo.
const int tamanoEntradaModelo = 224;

/// Resultado del preprocesado de una fotografía.
class ImagenPreprocesada {
  /// Tensor NCHW `[1, 3, 224, 224]` en RGB, valores 0.0–1.0, aplanado.
  final Float32List tensor;

  /// Proporción de píxeles con tonos foliares (0.0–1.0).
  final double proporcionVegetal;

  const ImagenPreprocesada({
    required this.tensor,
    required this.proporcionVegetal,
  });
}

/// Lee y decodifica la fotografía, corrige la orientación EXIF, recorta el
/// cuadrado central, la redimensiona a 224×224 y construye el tensor de entrada
/// mientras cuenta los píxeles foliares (defensa vegetal).
///
/// Es una función **síncrona y pura** (solo lee el archivo): pesada para el hilo
/// de la interfaz, por eso la app la ejecuta con [preprocesarEnSegundoPlano].
/// Lanza [ImagenInvalidaError] si el archivo no es una imagen decodificable.
ImagenPreprocesada preprocesarImagen(String imagePath) {
  // 1. Leer y decodificar la imagen desde el almacenamiento del dispositivo
  final Uint8List bytes;
  try {
    bytes = File(imagePath).readAsBytesSync();
  } on FileSystemException catch (e) {
    throw ImagenInvalidaError(detalle: 'No se pudo leer el archivo: ${e.message}');
  }

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const ImagenInvalidaError(
      detalle: 'FE.1: No fue posible decodificar el archivo de imagen.',
    );
  }

  // Corregir orientación EXIF si la foto fue tomada con la cámara rotada
  final oriented = img.bakeOrientation(decoded);

  // 2. Recorte cuadrado central y redimensionado a 224x224 (como hace YOLO-cls)
  final resized = img.copyResizeCropSquare(
    oriented,
    size: tamanoEntradaModelo,
    interpolation: img.Interpolation.linear,
  );

  // 3. Crear el tensor de entrada NCHW [1, 3, 224, 224] en formato RGB (0.0 a 1.0)
  // y al mismo tiempo verificar si la imagen contiene tonos foliares (Defensa Vegetal)
  const lado = tamanoEntradaModelo;
  const planeSize = lado * lado;
  final inputData = Float32List(3 * planeSize);
  int pixelesVegetales = 0;

  for (int y = 0; y < lado; y++) {
    for (int x = 0; x < lado; x++) {
      final pixel = resized.getPixel(x, y);
      final r = pixel.r / 255.0;
      final g = pixel.g / 255.0;
      final b = pixel.b / 255.0;

      final idx = y * lado + x;
      inputData[idx] = r; // Canal R
      inputData[planeSize + idx] = g; // Canal G
      inputData[2 * planeSize + idx] = b; // Canal B

      if (esPixelFoliar(r, g, b)) {
        pixelesVegetales++;
      }
    }
  }

  return ImagenPreprocesada(
    tensor: inputData,
    proporcionVegetal: pixelesVegetales / planeSize,
  );
}

/// Ejecuta [preprocesarImagen] en un `Isolate` para no congelar la interfaz
/// (decodificar y recorrer 50 176 píxeles en Dart puro es costoso en gama baja).
///
/// Es una función de nivel superior a propósito: la closure solo captura la ruta
/// (un `String`), nunca objetos de plugin ni de la interfaz.
Future<ImagenPreprocesada> preprocesarEnSegundoPlano(String imagePath) {
  return Isolate.run(() => preprocesarImagen(imagePath));
}

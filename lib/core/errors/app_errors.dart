import 'dart:developer' as developer;

/// Errores propios de la aplicación. Cada uno lleva un mensaje apto para el
/// usuario final ([mensajeUsuario]) y, opcionalmente, un [detalle] técnico que
/// solo debe registrarse en el log, nunca mostrarse en pantalla.
sealed class DoctorChileError implements Exception {
  final String mensajeUsuario;
  final String? detalle;

  const DoctorChileError(this.mensajeUsuario, {this.detalle});

  @override
  String toString() =>
      '$runtimeType: $mensajeUsuario${detalle != null ? ' ($detalle)' : ''}';
}

/// El archivo de imagen no pudo leerse o decodificarse.
final class ImagenInvalidaError extends DoctorChileError {
  const ImagenInvalidaError({super.detalle})
      : super(
          'No se pudo leer la fotografía. Intente tomar o elegir otra imagen.',
        );
}

/// El modelo ONNX no pudo cargarse.
final class ModeloNoDisponibleError extends DoctorChileError {
  const ModeloNoDisponibleError({super.detalle})
      : super(
          'No se pudo cargar el modelo de análisis. Cierre y vuelva a abrir la aplicación.',
        );
}

/// El modelo devolvió una salida que la aplicación no sabe interpretar.
final class SalidaModeloInvalidaError extends DoctorChileError {
  const SalidaModeloInvalidaError({super.detalle})
      : super(
          'El análisis produjo un resultado no válido. Intente con otra fotografía; si el problema continúa, actualice la aplicación.',
        );
}

/// Fallo al leer o escribir en la base de datos o en el almacenamiento.
final class ErrorAlmacenamiento extends DoctorChileError {
  const ErrorAlmacenamiento({super.detalle})
      : super('No se pudo acceder al almacenamiento del dispositivo.');
}

/// Registra el detalle técnico de un error en el log (no en la interfaz).
void registrarError(Object error, [StackTrace? stackTrace, String contexto = '']) {
  developer.log(
    contexto,
    name: 'DoctorChile',
    error: error,
    stackTrace: stackTrace,
    level: 1000,
  );
}

/// Devuelve un mensaje comprensible para el agricultor. Nunca expone
/// excepciones crudas ni trazas técnicas.
String mensajeAmigable(
  Object error, {
  String porDefecto = 'Ocurrió un problema inesperado. Intente de nuevo.',
}) {
  if (error is DoctorChileError) return error.mensajeUsuario;
  return porDefecto;
}

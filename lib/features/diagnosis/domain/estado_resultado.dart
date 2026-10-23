/// Estado de fiabilidad de un resultado de análisis.
enum EstadoResultado {
  /// La imagen parece una hoja y la confianza supera el umbral.
  concluyente('concluyente'),

  /// Es probablemente una hoja, pero la confianza del modelo es baja.
  pocaConfianza('poca_confianza'),

  /// La imagen no parece contener una hoja de chile.
  noEsHoja('no_es_hoja');

  final String clave;
  const EstadoResultado(this.clave);

  /// Convierte el valor guardado en BD. Un valor ausente (registros anteriores
  /// a la versión 2) se considera concluyente; uno desconocido se trata con
  /// cautela como [pocaConfianza].
  static EstadoResultado desdeClave(String? clave) {
    if (clave == null) return EstadoResultado.concluyente;
    for (final e in EstadoResultado.values) {
      if (e.clave == clave) return e;
    }
    return EstadoResultado.pocaConfianza;
  }

  String get etiqueta {
    switch (this) {
      case EstadoResultado.concluyente:
        return 'Concluyente';
      case EstadoResultado.pocaConfianza:
        return 'No concluyente';
      case EstadoResultado.noEsHoja:
        return 'No parece una hoja';
    }
  }
}

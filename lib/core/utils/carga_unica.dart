/// Carga un recurso una sola vez aunque varias partes lo pidan a la vez.
///
/// Guarda el `Future` (no el resultado): dos llamadas simultáneas comparten la
/// misma carga en curso en vez de lanzar dos. Si la carga falla, el error se
/// propaga a quienes esperaban y se permite reintentar en la siguiente llamada.
class CargaUnica<T> {
  final Future<T> Function() _crear;
  Future<T>? _carga;
  T? _valor;
  bool _lista = false;

  CargaUnica(this._crear);

  /// `true` si el recurso ya se cargó con éxito.
  bool get estaLista => _lista;

  /// El recurso cargado, o `null` si todavía no está listo.
  T? get valor => _lista ? _valor : null;

  Future<T> obtener() {
    if (_lista) return Future<T>.value(_valor as T);

    final existente = _carga;
    if (existente != null) return existente;

    final carga = _crear().then<T>(
      (v) {
        _valor = v;
        _lista = true;
        return v;
      },
      onError: (Object e, StackTrace st) {
        // Permite reintentar tras un fallo.
        _carga = null;
        Error.throwWithStackTrace(e, st);
      },
    );
    _carga = carga;
    return carga;
  }

  /// Olvida el recurso (p. ej. tras cerrarlo) para que la próxima llamada lo cargue de nuevo.
  void reiniciar() {
    _carga = null;
    _valor = null;
    _lista = false;
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/chili_classes.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/app_errors.dart';
import '../../diagnosis/domain/diagnosis_record.dart';
import '../../diagnosis/domain/diagnosis_repository.dart';
import '../../diagnosis/domain/estado_resultado.dart';
import '../../diagnosis/presentation/estado_badge.dart';
import 'detail_screen.dart';

/// Pantalla de Historial y Filtros de Diagnósticos (CU-02: Revisar diagnóstico).
class HistoryScreen extends StatefulWidget {
  /// Repositorio de persistencia. Por defecto SQLite; se puede inyectar un
  /// doble en pruebas.
  final DiagnosisRepository? repositorio;

  const HistoryScreen({super.key, this.repositorio});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// Valores del filtro de fiabilidad.
  static const String _fiabilidadTodos = 'TODOS';
  static const String _fiabilidadConcluyentes = 'CONCLUYENTES';
  static const String _fiabilidadNoConcluyentes = 'NO_CONCLUYENTES';

  String _afeccionSeleccionada = 'TODAS';
  String _fiabilidadSeleccionada = _fiabilidadTodos;
  DateTimeRange? _rangoFechas;

  /// Cuántos diagnósticos se cargan por página.
  static const int _tamanoPagina = 30;

  /// A cuántos píxeles del final se pide la siguiente página.
  static const double _margenCarga = 300;

  List<DiagnosisRecord> _diagnosticos = [];
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = false;
  String? _errorBaseDatos;

  /// Identifica la consulta vigente: si el usuario cambia un filtro mientras otra
  /// consulta sigue en curso, la respuesta vieja se ignora (no pisa a la nueva).
  int _peticion = 0;

  final ScrollController _scroll = ScrollController();

  DiagnosisRepository get _repo => widget.repositorio ?? LocalDatabase.instance;

  bool? get _soloConcluyentes {
    switch (_fiabilidadSeleccionada) {
      case _fiabilidadConcluyentes:
        return true;
      case _fiabilidadNoConcluyentes:
        return false;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
    _cargarDiagnosticos();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alDesplazar() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _margenCarga) {
      _cargarMas();
    }
  }

  /// Consulta la primera página de diagnósticos en SQLite aplicando los filtros activos.
  Future<void> _cargarDiagnosticos() async {
    final peticion = ++_peticion;
    setState(() {
      _cargando = true;
      _cargandoMas = false;
      _errorBaseDatos = null;
    });

    try {
      final resultados = await _repo.obtenerDiagnosticos(
        diseaseKey: _afeccionSeleccionada,
        soloConcluyentes: _soloConcluyentes,
        fechaInicio: _rangoFechas?.start,
        fechaFin: _rangoFechas?.end,
        limite: _tamanoPagina,
      );

      if (!mounted || peticion != _peticion) return;
      setState(() {
        _diagnosticos = resultados;
        _hayMas = resultados.isNotEmpty;
        _cargando = false;
      });
    } catch (e, st) {
      // FE.1: Error interno en la base de datos
      registrarError(e, st, 'Error al consultar el historial');
      if (!mounted || peticion != _peticion) return;
      setState(() {
        _cargando = false;
        _errorBaseDatos = mensajeAmigable(
          e,
          porDefecto: 'No se pudieron cargar los diagnósticos guardados. Intente de nuevo.',
        );
      });
    }
  }

  /// Carga la siguiente página y la añade al final de la lista.
  Future<void> _cargarMas() async {
    if (_cargando || _cargandoMas || !_hayMas) return;

    final peticion = _peticion;
    setState(() => _cargandoMas = true);

    try {
      final pagina = await _repo.obtenerDiagnosticos(
        diseaseKey: _afeccionSeleccionada,
        soloConcluyentes: _soloConcluyentes,
        fechaInicio: _rangoFechas?.start,
        fechaFin: _rangoFechas?.end,
        limite: _tamanoPagina,
        offset: _diagnosticos.length,
      );

      if (!mounted || peticion != _peticion) return;

      // Si se omitieron filas corruptas, el desplazamiento puede quedar corto y
      // repetir algún registro: se descartan los ya mostrados.
      final yaMostrados = {for (final d in _diagnosticos) d.id};
      final nuevos = pagina.where((d) => !yaMostrados.contains(d.id)).toList();

      setState(() {
        _diagnosticos = [..._diagnosticos, ...nuevos];
        _hayMas = nuevos.isNotEmpty;
        _cargandoMas = false;
      });
    } catch (e, st) {
      registrarError(e, st, 'Error al cargar más diagnósticos');
      if (!mounted || peticion != _peticion) return;
      setState(() => _cargandoMas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron cargar más diagnósticos. Desplácese de nuevo para reintentar.'),
        ),
      );
    }
  }

  /// FA.1: El agricultor selecciona un par de fechas en el calendario desplegable.
  Future<void> _seleccionarRangoFechas() async {
    final hoy = DateTime.now();
    final seleccion = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(hoy.year + 1, 12, 31),
      initialDateRange: _rangoFechas,
      helpText: 'Seleccione el rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar filtro',
      saveText: 'Filtrar',
    );

    if (seleccion != null) {
      setState(() => _rangoFechas = seleccion);
      await _cargarDiagnosticos();
    }
  }

  void _limpiarFiltros() {
    setState(() {
      _afeccionSeleccionada = 'TODAS';
      _fiabilidadSeleccionada = _fiabilidadTodos;
      _rangoFechas = null;
    });
    _cargarDiagnosticos();
  }

  @override
  Widget build(BuildContext context) {
    final formatoCorto = DateFormat('dd/MM/yyyy');
    final tieneFiltrosActivos = _afeccionSeleccionada != 'TODAS' ||
        _fiabilidadSeleccionada != _fiabilidadTodos ||
        _rangoFechas != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Diagnósticos'),
        actions: [
          if (tieneFiltrosActivos)
            IconButton(
              tooltip: 'Limpiar filtros',
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.filter_alt_off_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          // Panel de Filtros (CU-02 FN.1 y FA.1)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // FN.1: Menú desplegable de afecciones
                DropdownButtonFormField<String>(
                  value: _afeccionSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por afección',
                    prefixIcon: const Icon(Icons.bug_report_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'TODAS',
                      child: Text('Todas las afecciones'),
                    ),
                    for (final clase in ChiliClasses.todas)
                      DropdownMenuItem(
                        value: clase.key,
                        child: Text(clase.nombreEspanol),
                      ),
                  ],
                  onChanged: (valor) {
                    if (valor == null) return;
                    setState(() => _afeccionSeleccionada = valor);
                    _cargarDiagnosticos();
                  },
                ),
                const SizedBox(height: 10),

                // Filtro por fiabilidad del resultado (concluyente / no concluyente)
                DropdownButtonFormField<String>(
                  value: _fiabilidadSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Fiabilidad del resultado',
                    prefixIcon: const Icon(Icons.rule_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _fiabilidadTodos,
                      child: Text('Todos los resultados'),
                    ),
                    DropdownMenuItem(
                      value: _fiabilidadConcluyentes,
                      child: Text('Solo concluyentes'),
                    ),
                    DropdownMenuItem(
                      value: _fiabilidadNoConcluyentes,
                      child: Text('Solo no concluyentes'),
                    ),
                  ],
                  onChanged: (valor) {
                    if (valor == null) return;
                    setState(() => _fiabilidadSeleccionada = valor);
                    _cargarDiagnosticos();
                  },
                ),
                const SizedBox(height: 10),

                // FA.1: Selector de rango de fechas
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _seleccionarRangoFechas,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          _rangoFechas == null
                              ? 'Filtrar por rango de fechas'
                              : '${formatoCorto.format(_rangoFechas!.start)}  →  ${formatoCorto.format(_rangoFechas!.end)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (_rangoFechas != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Quitar filtro de fechas',
                        onPressed: () {
                          setState(() => _rangoFechas = null);
                          _cargarDiagnosticos();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Contenido principal (Lista, Mensaje vacío FA.2 o Error FE.1)
          Expanded(
            child: _construirContenido(),
          ),
        ],
      ),
    );
  }

  Widget _construirContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // FE.1: Error interno en la base de datos
    if (_errorBaseDatos != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                _errorBaseDatos!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargarDiagnosticos,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // FA.2: El sistema no cuenta con diagnósticos registrados
    if (_diagnosticos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 14),
              const Text(
                'No hay diagnósticos registrados',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _afeccionSeleccionada != 'TODAS' ||
                        _fiabilidadSeleccionada != _fiabilidadTodos ||
                        _rangoFechas != null
                    ? 'No se encontraron diagnósticos que coincidan con los filtros seleccionados.'
                    : 'Realice su primer diagnóstico tomando una fotografía de una hoja de chile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // FN.2: Listado de diagnósticos filtrados
    final formatoFechaHora = DateFormat('dd/MM/yyyy • HH:mm');
    // La miniatura mide 58 px: se decodifica a ese tamaño (en píxeles reales)
    // en vez de cargar la foto completa de hasta 1280 px en memoria.
    final anchoMiniatura = (58 * MediaQuery.devicePixelRatioOf(context)).round();
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _diagnosticos.length + (_cargandoMas ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        // Indicador al final mientras se carga la siguiente página.
        if (index >= _diagnosticos.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = _diagnosticos[index];
        final claseInfo = ChiliClasses.porClaveODesconocida(item.diseaseKey);
        // Un resultado dudoso usa color neutro para no parecer un diagnóstico firme.
        final colorItem = item.estado == EstadoResultado.concluyente
            ? claseInfo.colorIndicador
            : Colors.blueGrey.shade600;
        final pct = (item.confidence * 100).toStringAsFixed(1);

        // Marcador que se muestra si la foto no existe o no se puede leer.
        Widget marcador() => Container(
              color: colorItem.withValues(alpha: 0.15),
              child: Icon(claseInfo.icono, color: colorItem),
            );

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Image.file(
                  File(item.imagePath),
                  fit: BoxFit.cover,
                  cacheWidth: anchoMiniatura,
                  errorBuilder: (_, __, ___) => marcador(),
                ),
              ),
            ),
            title: Text(
              item.tituloVisible,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (item.estado != EstadoResultado.concluyente) ...[
                  EstadoBadge(estado: item.estado),
                  const SizedBox(height: 4),
                ],
                Text(
                  'ID #${item.id}  •  ${formatoFechaHora.format(item.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (item.notes != null && item.notes!.isNotEmpty)
                  Text(
                    item.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorItem.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$pct%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorItem,
                ),
              ),
            ),
            onTap: () async {
              final eliminado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => DetailScreen(
                    registro: item,
                    repositorio: widget.repositorio,
                  ),
                ),
              );
              if (eliminado == true) {
                await _cargarDiagnosticos();
              }
            },
          ),
        );
      },
    );
  }
}

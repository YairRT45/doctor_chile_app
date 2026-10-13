import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/chili_classes.dart';
import '../../../core/database/local_database.dart';
import '../../diagnosis/domain/diagnosis_record.dart';
import 'detail_screen.dart';

/// Pantalla de Historial y Filtros de Diagnósticos (CU-02: Revisar diagnóstico).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _afeccionSeleccionada = 'TODAS';
  DateTimeRange? _rangoFechas;

  List<DiagnosisRecord> _diagnosticos = [];
  bool _cargando = true;
  String? _errorBaseDatos;

  @override
  void initState() {
    super.initState();
    _cargarDiagnosticos();
  }

  /// Consulta los diagnósticos en SQLite aplicando los filtros activos.
  Future<void> _cargarDiagnosticos() async {
    setState(() {
      _cargando = true;
      _errorBaseDatos = null;
    });

    try {
      final resultados = await LocalDatabase.instance.obtenerDiagnosticos(
        diseaseKey: _afeccionSeleccionada,
        fechaInicio: _rangoFechas?.start,
        fechaFin: _rangoFechas?.end,
      );

      if (!mounted) return;
      setState(() {
        _diagnosticos = resultados;
        _cargando = false;
      });
    } catch (e) {
      // FE.1: Error interno en la base de datos
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorBaseDatos = 'Hubo un error al consultar los datos: $e';
      });
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
      _rangoFechas = null;
    });
    _cargarDiagnosticos();
  }

  @override
  Widget build(BuildContext context) {
    final formatoCorto = DateFormat('dd/MM/yyyy');
    final tieneFiltrosActivos = _afeccionSeleccionada != 'TODAS' || _rangoFechas != null;

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
                    labelText: 'Filtrar por afección (FN.1)',
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

                // FA.1: Selector de rango de fechas
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _seleccionarRangoFechas,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          _rangoFechas == null
                              ? 'Filtrar por rango de fechas (FA.1)'
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
                _afeccionSeleccionada != 'TODAS' || _rangoFechas != null
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _diagnosticos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _diagnosticos[index];
        final claseInfo = ChiliClasses.porClave(item.diseaseKey);
        final pct = (item.confidence * 100).toStringAsFixed(1);
        final fotoFile = File(item.imagePath);

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
                child: fotoFile.existsSync()
                    ? Image.file(fotoFile, fit: BoxFit.cover)
                    : Container(
                        color: claseInfo.colorIndicador.withValues(alpha: 0.15),
                        child: Icon(claseInfo.icono, color: claseInfo.colorIndicador),
                      ),
              ),
            ),
            title: Text(
              item.diseaseName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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
                color: claseInfo.colorIndicador.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$pct%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: claseInfo.colorIndicador,
                ),
              ),
            ),
            onTap: () async {
              final eliminado = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => DetailScreen(registro: item),
                ),
              );
              if (eliminado == true) {
                _cargarDiagnosticos();
              }
            },
          ),
        );
      },
    );
  }
}

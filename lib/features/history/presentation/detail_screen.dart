import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/chili_classes.dart';
import '../../../core/database/local_database.dart';
import '../../../core/errors/app_errors.dart';
import '../../../core/widgets/descargo_responsabilidad.dart';
import '../../diagnosis/domain/diagnosis_record.dart';
import '../../diagnosis/domain/diagnosis_repository.dart';
import '../../diagnosis/domain/estado_resultado.dart';
import '../../diagnosis/presentation/estado_badge.dart';

/// Vista de detalle de un diagnóstico almacenado en la base de datos local.
class DetailScreen extends StatelessWidget {
  final DiagnosisRecord registro;

  /// Repositorio de persistencia. Por defecto SQLite; se puede inyectar un
  /// doble en pruebas.
  final DiagnosisRepository? repositorio;

  const DetailScreen({
    super.key,
    required this.registro,
    this.repositorio,
  });

  Future<void> _confirmarEliminacion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar diagnóstico'),
        content: Text(
          '¿Desea eliminar permanentemente el diagnóstico #${registro.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && registro.id != null) {
      try {
        await (repositorio ?? LocalDatabase.instance).eliminarDiagnostico(
          registro.id!,
          registro.imagePath,
        );
      } catch (e, st) {
        registrarError(e, st, 'Error al eliminar el diagnóstico');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(
                mensajeAmigable(
                  e,
                  porDefecto: 'No se pudo eliminar el diagnóstico. Intente de nuevo.',
                ),
              ),
            ),
          );
        }
        return;
      }
      if (context.mounted) {
        Navigator.of(context).pop(true); // Indica al historial que recargue la lista
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final claseInfo = ChiliClasses.porClaveODesconocida(registro.diseaseKey);
    // Un resultado dudoso usa color neutro para no parecer un diagnóstico firme.
    final color = registro.estado == EstadoResultado.concluyente
        ? claseInfo.colorIndicador
        : Colors.blueGrey.shade600;
    final fechaFormateada = DateFormat('dd/MM/yyyy • HH:mm').format(registro.createdAt);
    final certezaPct = (registro.confidence * 100).toStringAsFixed(1);
    final archivoFoto = File(registro.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text('Diagnóstico #${registro.id ?? "-"}'),
        actions: [
          IconButton(
            tooltip: 'Eliminar diagnóstico',
            onPressed: () => _confirmarEliminacion(context),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: archivoFoto.existsSync()
                    ? Image.file(archivoFoto, fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 64),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: color.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(
                            claseInfo.icono,
                            color: color,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ID de registro: #${registro.id}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (registro.estado != EstadoResultado.concluyente) ...[
                                EstadoBadge(estado: registro.estado),
                                const SizedBox(height: 4),
                              ],
                              Text(
                                registro.tituloVisible,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                fechaFormateada,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Icon(Icons.verified_rounded, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Nivel de certeza: $certezaPct%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (registro.estado != EstadoResultado.noEsHoja) ...[
                      const SizedBox(height: 14),
                      Text(
                        registro.estado == EstadoResultado.concluyente
                            ? 'Descripción de síntomas:'
                            : 'Síntomas de la posible afección:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        claseInfo.descripcionSintomas,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ],
                    if (registro.notes != null && registro.notes!.isNotEmpty) ...[
                      const Divider(height: 28),
                      const Text(
                        'Nota / Ubicación:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        registro.notes!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const DescargoResponsabilidad(),
          ],
        ),
      ),
    );
  }
}

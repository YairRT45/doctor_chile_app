import 'package:flutter/material.dart';

import '../domain/estado_resultado.dart';

/// Insignia que marca un resultado como no concluyente. No muestra nada si el
/// resultado es concluyente.
class EstadoBadge extends StatelessWidget {
  final EstadoResultado estado;

  const EstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    if (estado == EstadoResultado.concluyente) return const SizedBox.shrink();

    final color = estado == EstadoResultado.noEsHoja
        ? Colors.red.shade700
        : Colors.amber.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            estado.etiqueta,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

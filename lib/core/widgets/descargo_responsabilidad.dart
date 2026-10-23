import 'package:flutter/material.dart';

/// Aviso fijo de que el resultado es orientativo.
class DescargoResponsabilidad extends StatelessWidget {
  const DescargoResponsabilidad({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.blueGrey.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Resultado orientativo generado por un modelo automático. No sustituye '
              'el criterio de un técnico agrónomo; consulte a un especialista antes de '
              'tomar decisiones sobre su cultivo.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.blueGrey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

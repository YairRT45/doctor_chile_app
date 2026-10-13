import 'package:flutter/material.dart';

/// Información descriptiva de cada una de las 5 clases del modelo YOLO11.
/// Nota: Conforme a la limitante del SRS v1.0, solo describe los síntomas
/// detectados sin emitir sugerencias de tratamiento químico/agronómico.
class ChiliClassInfo {
  final int index;
  final String key;
  final String nombreEspanol;
  final String nombreCientificoOComun;
  final String descripcionSintomas;
  final Color colorIndicador;
  final IconData icono;
  final bool esSana;

  const ChiliClassInfo({
    required this.index,
    required this.key,
    required this.nombreEspanol,
    required this.nombreCientificoOComun,
    required this.descripcionSintomas,
    required this.colorIndicador,
    required this.icono,
    this.esSana = false,
  });
}

class ChiliClasses {
  /// Orden exacto exportado por YOLO11:
  /// {0: 'Curl', 1: 'Healthy', 2: 'Spot', 3: 'Whitefly', 4: 'Yellowish'}
  static const List<ChiliClassInfo> todas = [
    ChiliClassInfo(
      index: 0,
      key: 'Curl',
      nombreEspanol: 'Hoja Rizada (Virosis)',
      nombreCientificoOComun: 'Virus del rizado / Begomovirus',
      descripcionSintomas:
          'Deformación, arrugamiento y encrespamiento de la lámina foliar hacia arriba o hacia abajo, acompañado de engrosamiento de las nervaduras.',
      colorIndicador: Color(0xFFD97706), // Ámbar / Naranja
      icono: Icons.waves_rounded,
    ),
    ChiliClassInfo(
      index: 1,
      key: 'Healthy',
      nombreEspanol: 'Hoja Sana',
      nombreCientificoOComun: 'Capsicum annuum sin afección visible',
      descripcionSintomas:
          'Lámina foliar con coloración verde uniforme, superficie lisa, nervaduras simétricas y ausencia de lesiones necróticas o insectos.',
      colorIndicador: Color(0xFF16A34A), // Verde agrícola
      icono: Icons.check_circle_rounded,
      esSana: true,
    ),
    ChiliClassInfo(
      index: 2,
      key: 'Spot',
      nombreEspanol: 'Mancha Foliar',
      nombreCientificoOComun: 'Xanthomonas spp. / Cercospora',
      descripcionSintomas:
          'Presencia de lesiones circulares o irregulares de color café o blanquecino con bordes necróticos definidos sobre la superficie de la hoja.',
      colorIndicador: Color(0xFFDC2626), // Rojo alerta
      icono: Icons.blur_circular_rounded,
    ),
    ChiliClassInfo(
      index: 3,
      key: 'Whitefly',
      nombreEspanol: 'Mosquita Blanca',
      nombreCientificoOComun: 'Bemisia tabaci / Trialeurodes vaporariorum',
      descripcionSintomas:
          'Presencia de colonias de pequeños insectos blancos o huevecillos adheridos a la superficie foliar que succionan la savia de la planta.',
      colorIndicador: Color(0xFF7C3AED), // Morado / Violeta
      icono: Icons.bug_report_rounded,
    ),
    ChiliClassInfo(
      index: 4,
      key: 'Yellowish',
      nombreEspanol: 'Amarillamiento (Clorosis)',
      nombreCientificoOComun: 'Clorosis foliar',
      descripcionSintomas:
          'Pérdida generalizada o intervenal del pigmento verde (clorofila), tornando la hoja de color amarillo pálido o brillante.',
      colorIndicador: Color(0xFFCA8A04), // Amarillo oscuro / Dorado
      icono: Icons.wb_sunny_rounded,
    ),
  ];

  /// Busca la información de una clase por su índice numérico (0..4).
  static ChiliClassInfo porIndice(int index) {
    return todas.firstWhere(
      (c) => c.index == index,
      orElse: () => todas[1],
    );
  }

  /// Busca la información de una clase por su clave en inglés ('Curl', 'Spot', etc.).
  static ChiliClassInfo porClave(String key) {
    return todas.firstWhere(
      (c) => c.key.toLowerCase() == key.toLowerCase(),
      orElse: () => todas[1],
    );
  }
}

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

  /// Clase neutra para claves/índices que no pertenecen al modelo actual.
  /// Nunca se considera sana: no debe confundirse con un resultado favorable.
  static const ChiliClassInfo desconocida = ChiliClassInfo(
    index: -1,
    key: 'Unknown',
    nombreEspanol: 'Afección no reconocida',
    nombreCientificoOComun: 'Sin información disponible',
    descripcionSintomas:
        'Este registro corresponde a una clase que la versión actual de la aplicación no reconoce.',
    colorIndicador: Color(0xFF6B7280), // Gris neutro
    icono: Icons.help_outline_rounded,
  );

  /// Busca la información de una clase por su índice numérico (0..4).
  /// Devuelve `null` si el índice no existe (nunca asume una clase por defecto).
  static ChiliClassInfo? porIndice(int index) {
    for (final c in todas) {
      if (c.index == index) return c;
    }
    return null;
  }

  /// Busca la información de una clase por su clave en inglés ('Curl', 'Spot', etc.).
  /// Devuelve `null` si la clave no existe.
  static ChiliClassInfo? porClave(String key) {
    final buscada = key.toLowerCase();
    for (final c in todas) {
      if (c.key.toLowerCase() == buscada) return c;
    }
    return null;
  }

  /// Igual que [porClave], pero devuelve [desconocida] si no hay coincidencia.
  /// Pensado para pantallas que muestran registros guardados.
  static ChiliClassInfo porClaveODesconocida(String key) =>
      porClave(key) ?? desconocida;
}

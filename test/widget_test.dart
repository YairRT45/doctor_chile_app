import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_chile_app/main.dart';

void main() {
  testWidgets('DoctorChileApp muestra pantalla principal', (WidgetTester tester) async {
    await tester.pumpWidget(const DoctorChileApp());
    expect(find.text('Hacer Diagnóstico (Cámara)'), findsOneWidget);
    expect(find.text('Subir Foto desde Galería'), findsOneWidget);
  });
}

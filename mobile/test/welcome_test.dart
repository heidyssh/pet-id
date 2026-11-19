import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petid/welcome.dart';

void main() {
  testWidgets('la bienvenida anima su contenido sin errores', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Ya tengo cuenta'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Ya tengo cuenta'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ya tengo cuenta'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

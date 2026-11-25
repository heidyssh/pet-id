import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petid/api.dart';
import 'package:petid/entry_forms.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> openForm(
    WidgetTester tester,
    MockClient client, {
    bool register = false,
  }) async {
    tester.view.physicalSize = const Size(360, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Provider.value(
        value: PetIdApi(client),
        child: MaterialApp(
          home: AccountForm(
            register: register,
            initialEmail: 'prueba@example.com',
          ),
        ),
      ),
    );
  }

  Future<void> press(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, Finder target, String value) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.enterText(target, value);
    await tester.pump();
  }

  http.Response success() => http.Response(
    '{"success":true}',
    200,
    headers: {'content-type': 'application/json'},
  );

  testWidgets('registra un refugio y conserva los dos nombres sin números', (
    tester,
  ) async {
    http.Request? registration;
    final client = MockClient((request) async {
      registration = request;
      return success();
    });
    addTearDown(client.close);
    await openForm(tester, client, register: true);
    await press(tester, find.text('Veterinaria o refugio'));
    await press(tester, find.text('Seleccionar tipo'));
    await press(tester, find.text('Refugio'));
    final inputs = find.byType(TextFormField);
    await type(tester, inputs.at(0), 'Refugio PetID');
    await type(tester, inputs.at(1), 'María19  José');
    await type(tester, inputs.at(2), 'Pérez López');
    await type(tester, inputs.at(3), '9876-5432');
    await type(tester, inputs.at(5), 'PetId123!');
    await type(tester, inputs.at(6), 'PetId123!');
    await press(tester, find.text('Crear cuenta'));

    expect(registration?.url.path, '/api/auth/registro');
    expect(jsonDecode(registration!.body), {
      'nombre': 'María José',
      'apellido': 'Pérez López',
      'telefono': '+50498765432',
      'correo': 'prueba@example.com',
      'password': 'PetId123!',
      'organizacion': {
        'nombre': 'Refugio PetID',
        'tipo': 'refugio',
        'telefono': '+50498765432',
      },
    });
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('solicita un enlace y cambia la contraseña desde el formulario', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return success();
    });
    addTearDown(client.close);
    await openForm(tester, client);
    await press(tester, find.text('¿Olvidaste tu contraseña?'));
    await press(tester, find.text('Enviar enlace'));
    final token = 'a' * 64;
    final inputs = find.byType(TextFormField);
    await type(
      tester,
      inputs.first,
      'https://petid.example/cambio#token=$token',
    );
    await type(tester, inputs.last, 'Clave123!');
    await press(tester, find.text('Guardar contraseña'));
    expect(requests.map((request) => request.url.path), [
      '/api/auth/recuperar-contrasena',
      '/api/auth/restablecer-contrasena',
    ]);
    expect(jsonDecode(requests.first.body), {'correo': 'prueba@example.com'});
    expect(jsonDecode(requests.last.body), {
      'token': token,
      'password': 'Clave123!',
    });
    expect(find.text('¡Hola de nuevo!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('limita los nombres y exige un teléfono con prefijo válido', (
    tester,
  ) async {
    http.Request? registration;
    final client = MockClient((request) async {
      registration = request;
      return success();
    });
    addTearDown(client.close);
    await openForm(tester, client, register: true);
    final inputs = find.byType(TextFormField);
    final name = '${'Á' * 15} ${'a' * 15}';
    final surname = 'É' * 30;
    await type(tester, inputs.at(0), '${name}abc');
    await type(tester, inputs.at(1), '${surname}xyz');
    await type(tester, inputs.at(4), 'PetId123!');
    await type(tester, inputs.at(5), 'PetId123!');
    await press(tester, find.text('Crear cuenta'));
    expect(find.text('Escribe tu teléfono.'), findsOneWidget);
    expect(registration, isNull);

    // Los nombres muestran cuántas letras llevan.
    expect(find.text('30/30'), findsNWidgets(2));

    // Un teléfono que empieza con otro dígito no se escribe.
    await type(tester, inputs.at(2), '12345678');
    expect(
      tester.widget<TextFormField>(inputs.at(2)).controller!.text,
      isEmpty,
    );

    await type(tester, inputs.at(2), '9123');
    await press(tester, find.text('Crear cuenta'));
    expect(
      find.text('Escribe 8 dígitos que empiecen con 2, 3, 8 o 9.'),
      findsOneWidget,
    );
    expect(registration, isNull);

    await type(tester, inputs.at(2), '8x123-4567');
    await press(tester, find.text('Crear cuenta'));
    final body = jsonDecode(registration!.body);
    expect(body['nombre'], name);
    expect(body['apellido'], surname);
    expect(body['telefono'], '+50481234567');
    await tester.pump(const Duration(seconds: 5));
  });
}

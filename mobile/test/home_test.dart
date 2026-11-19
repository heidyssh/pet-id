import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petid/api.dart';
import 'package:petid/home.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> openHome(WidgetTester tester, MockClient client) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PetIdApi(client);
    await tester.pumpWidget(
      Provider.value(
        value: api,
        child: ChangeNotifierProvider(
          create: (_) => Session(api),
          child: const MaterialApp(home: CitizenHome(name: 'Ana Pérez')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  http.Response json(String body) =>
      http.Response(body, 200, headers: {'content-type': 'application/json'});

  testWidgets('muestra estados vacíos reales sin datos inventados', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/mascotas/mias')) {
        return json('{"success":true,"data":{"mascotas":[]}}');
      }
      return json(
        '{"success":true,"data":{"items":[],"paginacion":{"total":0}}}',
      );
    });
    await openHome(tester, client);

    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('Reportar mascota perdida'), findsOneWidget);
    expect(find.text('Todavía no registras mascotas.'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra las mascotas y los avisos sin leer de la API', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/mascotas/mias')) {
        return json('''
{"success":true,"data":{"mascotas":[
  {"nombre":"Canela","sexo":"Hembra","especie":{"nombre":"Perro"},
   "raza":{"nombre":"Mestizo"},"fotos":[]}
]}}''');
      }
      return json(
        '{"success":true,"data":{"items":[],"paginacion":{"total":2}}}',
      );
    });
    await openHome(tester, client);

    expect(find.text('Canela'), findsOneWidget);
    expect(find.text('Perra · Mestizo'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Ver todas'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Mis mascotas'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

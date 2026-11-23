import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'api.dart';
import 'home.dart';
import 'motion.dart';
import 'welcome.dart';

void main() => runApp(const PetIdApp());

class PetIdApp extends StatefulWidget {
  const PetIdApp({super.key});

  @override
  State<PetIdApp> createState() => _PetIdAppState();
}

class _PetIdAppState extends State<PetIdApp> {
  final _client = http.Client();
  late final _api = PetIdApi(_client);

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider.value(
      value: _api,
      child: ChangeNotifierProvider(
        create: (_) => Session(_api)..restore(),
        child: MaterialApp(
          title: 'PetID',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: petOrange,
              primary: petDarkOrange,
              onPrimary: Colors.white,
            ),
            scaffoldBackgroundColor: petCream,
            // Todas las pantallas, actuales y nuevas, entran con la misma
            // animación.
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: PetPageTransitions(),
                TargetPlatform.iOS: PetPageTransitions(),
              },
            ),
            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          home: const _Entry(),
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.loading) {
      return const _PetIdBootLoader();
    }
    if (session.user case final user?) {
      final givenName = user['nombre']?.toString().trim() ?? '';
      final familyName = user['apellido']?.toString().trim() ?? '';
      final fullName = [
        givenName,
        familyName,
      ].where((part) => part.isNotEmpty).join(' ');
      return CitizenHome(name: fullName);
    }
    return WelcomeScreen(restoreError: session.restoreError);
  }
}

class _PetIdBootLoader extends StatelessWidget {
  const _PetIdBootLoader();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Breathing(
              scale: 1.08,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFDCC5),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 82,
                  child: Icon(
                    Icons.pets_rounded,
                    color: petDarkOrange,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'PetID',
              style: TextStyle(
                color: petInk,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Preparando todo para ti',
              style: TextStyle(color: Color(0xFF5D686C), fontSize: 14),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  minHeight: 5,
                  color: petOrange,
                  backgroundColor: Color(0xFFFDE1D1),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

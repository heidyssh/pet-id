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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

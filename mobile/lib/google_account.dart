import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api.dart';

class GoogleAccount {
  static const _serverId = String.fromEnvironment('PETID_GOOGLE_CLIENT_ID');
  static const _iosId = String.fromEnvironment('PETID_GOOGLE_IOS_CLIENT_ID');
  static Future<void>? _initialization;

  static bool get available =>
      !kIsWeb &&
      _serverId.isNotEmpty &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS && _iosId.isNotEmpty));

  static Future<String?> idToken() async {
    final google = GoogleSignIn.instance;
    try {
      await (_initialization ??= google.initialize(
        serverClientId: _serverId,
        clientId: defaultTargetPlatform == TargetPlatform.iOS ? _iosId : null,
      ));
      final account = await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const ApiError('Google no pudo confirmar tu identidad.');
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ApiError(
        'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
      );
    }
  }
}

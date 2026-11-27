import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ApiError implements Exception {
  const ApiError(this.message, [this.status]);
  final String message;
  final int? status;
}

class PetIdApi {
  PetIdApi(this.client);
  final http.Client client;

  Uri _uri(String path) {
    const configured = String.fromEnvironment('PETID_API_URL');
    // En desarrollo, el celular (o emulador) llega al backend de la PC por
    // `adb reverse tcp:3000 tcp:3000`, así que basta con 127.0.0.1.
    final base = configured.isNotEmpty
        ? configured
        : kDebugMode
        ? 'http://127.0.0.1:3000/api'
        : '';
    final uri = Uri.tryParse(base);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.scheme == 'https' || (kDebugMode && uri.scheme == 'http'))) {
      throw const ApiError('Configura la dirección de la API de PetID.');
    }
    // La ruta puede traer parámetros, como /mascotas/mias?limite=20.
    final target = Uri.parse(path);
    return uri.replace(
      path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}${target.path}',
      query: target.hasQuery ? target.query : null,
    );
  }

  /// Convierte una ruta de imagen del backend en una URL completa.
  String? imageUrl(Object? value) {
    if (value is! String || value.isEmpty) return null;
    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }
    try {
      return _uri('').replace(path: value).toString();
    } on ApiError {
      return null;
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
    XFile? photo,
    String capture = 'desconocida',
    Map<String, String>? multipartFields,
  }) async {
    final uri = _uri(path);
    final http.BaseRequest request;
    if (photo == null) {
      final json = http.Request(method, uri);
      if (body != null) {
        json.headers['Content-Type'] = 'application/json';
        json.body = jsonEncode(body);
      }
      request = json;
    } else {
      final extension = photo.name.split('.').last.toLowerCase();
      final subtype = switch (extension) {
        'jpg' || 'jpeg' => 'jpeg',
        'png' => 'png',
        'webp' => 'webp',
        _ => throw const ApiError('Elige una foto JPG, PNG o WebP.'),
      };
      final length = await photo.length();
      if (length > 5 * 1024 * 1024) {
        throw const ApiError('La foto supera el límite de 5 MB.');
      }
      request = http.MultipartRequest(method, uri)
        ..fields['datos'] = jsonEncode(body)
        ..fields['tipo_captura'] = capture
        ..fields.addAll(multipartFields ?? const {})
        ..files.add(
          http.MultipartFile(
            'foto',
            photo.openRead(),
            length,
            filename: photo.name,
            contentType: MediaType('image', subtype),
          ),
        );
    }
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final response = await client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(Duration(seconds: photo == null ? 20 : 90));
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiError(
        'PetID devolvió una respuesta inesperada.',
        response.statusCode,
      );
    }
    if (decoded is Map<String, dynamic> &&
        decoded['success'] == true &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }
    final message = decoded is Map ? decoded['message'] : null;
    final issues = decoded is Map ? decoded['errors'] : null;
    if (issues is List) {
      if (issues.firstOrNull case {'mensaje': final String detail}) {
        throw ApiError(detail, response.statusCode);
      }
    }
    throw ApiError(
      message is String ? message : 'No se pudo completar la solicitud.',
      response.statusCode,
    );
  }
}

class Session extends ChangeNotifier {
  Session(this.api);
  final PetIdApi api;
  final _storage = const FlutterSecureStorage();
  static const _key = 'petid.session';
  Map<String, dynamic>? user;
  String? _access;
  bool loading = true;
  String? restoreError;

  String? get _mapLocationKey {
    final id = user?['id_usuario'] ?? user?['id'];
    return id == null ? null : 'petid.map-location.$id';
  }

  /// Conserva el último punto autorizado por la persona sin activar por sí
  /// solo las notificaciones de zona. Esto permite reconstruir el mapa al
  /// volver a iniciar sesión cuando Android no entrega una posición nueva.
  Future<void> saveLastMapLocation(double latitude, double longitude) async {
    final key = _mapLocationKey;
    if (key == null) return;
    try {
      await _storage.write(
        key: key,
        value: jsonEncode({'latitud': latitude, 'longitud': longitude}),
      );
    } catch (_) {
      // La ubicación actual sigue siendo utilizable aunque no pueda persistir.
    }
  }

  Future<Map<String, double>?> readLastMapLocation() async {
    final key = _mapLocationKey;
    if (key == null) return null;
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final latitude = decoded['latitud'];
      final longitude = decoded['longitud'];
      if (latitude is! num || longitude is! num) return null;
      return {'latitud': latitude.toDouble(), 'longitud': longitude.toDouble()};
    } catch (_) {
      return null;
    }
  }

  Future<void> restore() async {
    loading = true;
    restoreError = null;
    notifyListeners();
    String? saved;
    try {
      // En una instalación nueva el almacén seguro puede tardar en estar
      // disponible. Eso no es una sesión fallida y no debe alarmar al usuario.
      try {
        saved = await _storage.read(key: _key);
      } catch (_) {
        saved = null;
      }
      if (saved == null) return;
      final tokens = jsonDecode(saved) as Map<String, dynamic>;
      var access = tokens['access_token'] as String;
      Map<String, dynamic> profile;
      try {
        profile = (await api.request('GET', '/auth/me', token: access))['data'];
      } on ApiError catch (error) {
        if (error.status != 401) rethrow;
        final renewed =
            (await api.request(
                  'POST',
                  '/sesiones/renovar',
                  body: {'refresh_token': tokens['refresh_token']},
                ))['data']
                as Map<String, dynamic>;
        await _save(renewed);
        access = renewed['access_token'] as String;
        profile = (await api.request('GET', '/auth/me', token: access))['data'];
      }
      _access = access;
      user = profile;
    } on ApiError catch (error) {
      if (error.status == 401 || error.status == 403) {
        _access = null;
        user = null;
        try {
          await _storage.delete(key: _key);
        } catch (_) {
          restoreError = 'No se pudo borrar la sesión vencida.';
        }
      } else {
        restoreError = 'No se pudo recuperar tu sesión.';
      }
    } catch (_) {
      restoreError = 'No se pudo recuperar tu sesión.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _save(Map<String, dynamic> data) => _storage.write(
    key: _key,
    value: jsonEncode({
      'access_token': data['access_token'],
      'refresh_token': data['refresh_token'],
    }),
  );

  Future<void> login(Map<String, Object?> form) async {
    await _openSession('/auth/login', form);
  }

  Future<void> _openSession(String path, Map<String, Object?> form) async {
    final data =
        (await api.request('POST', path, body: form))['data']
            as Map<String, dynamic>;
    await _save(data);
    _access = data['access_token'] as String;
    user = data['usuario'] as Map<String, dynamic>;
    restoreError = null;
    notifyListeners();
  }

  /// Consulta privada. Si el token venció, lo renueva una vez y reintenta.
  Future<Map<String, dynamic>> authRequest(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    try {
      return await api.request(method, path, body: body, token: _access);
    } on ApiError catch (error) {
      if (error.status != 401) rethrow;
      await _renew();
      return api.request(method, path, body: body, token: _access);
    }
  }

  Future<void> updateProfile(Map<String, Object?> changes) async {
    final response = await authRequest('PATCH', '/auth/me', body: changes);
    user = Map<String, dynamic>.from(response['data'] as Map);
    notifyListeners();
  }

  Future<void> _renew() async {
    final saved = await _storage.read(key: _key);
    if (saved == null) throw const ApiError('Tu sesión venció.', 401);
    final tokens = jsonDecode(saved) as Map<String, dynamic>;
    try {
      final renewed =
          (await api.request(
                'POST',
                '/sesiones/renovar',
                body: {'refresh_token': tokens['refresh_token']},
              ))['data']
              as Map<String, dynamic>;
      await _save(renewed);
      _access = renewed['access_token'] as String;
    } on ApiError catch (error) {
      if (error.status == 401 || error.status == 403) {
        await _storage.delete(key: _key);
        _access = null;
        user = null;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> report(
    Map<String, Object?> data,
    XFile? photo,
    String capture,
  ) async {
    Future<Map<String, dynamic>> send() async {
      return api.request(
        'POST',
        photo == null
            ? '/avistamientos/registrado'
            : '/avistamientos/escanear/registrado',
        body: data,
        token: _access,
        photo: photo,
        capture: capture,
      );
    }

    try {
      return await send();
    } on ApiError catch (error) {
      if (error.status != 401) rethrow;
      await restore();
      if (user == null || _access == null || restoreError != null) rethrow;
      return send();
    }
  }

  Future<Map<String, dynamic>> uploadPetPhoto(
    Object petId,
    XFile photo, {
    required bool main,
    bool requireRecognition = false,
  }) async {
    Future<Map<String, dynamic>> send() => api.request(
      'POST',
      '/mascotas/$petId/fotos',
      token: _access,
      photo: photo,
      multipartFields: {
        'es_principal': '$main',
        'requiere_vector': '$requireRecognition',
      },
    );
    try {
      return await send();
    } on ApiError catch (error) {
      if (error.status != 401) rethrow;
      await _renew();
      return send();
    }
  }

  Future<void> logout() async {
    try {
      await api.request('POST', '/sesiones/cerrar', token: _access);
    } catch (_) {
      // Cerrar sesión localmente nunca debe depender de la red. El token
      // expirará en el servidor aunque el dispositivo esté sin conexión.
    } finally {
      await _storage.delete(key: _key);
      user = null;
      _access = null;
      notifyListeners();
    }
  }
}

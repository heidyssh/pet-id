import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'google_account.dart';
import 'motion.dart';
import 'welcome.dart';

String _errorMessage(Object error) => switch (error) {
  ApiError() => error.message,
  TimeoutException() => 'PetID tardó en responder. Verifica la conexión.',
  PlatformException() => 'No se pudo acceder a la cámara o galería.',
  _ =>
    'No se pudo completar la acción. Verifica la conexión e inténtalo de nuevo.',
};

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Completa este campo.' : null;

final _emailPattern = RegExp(
  r"""^(?:[A-Za-z0-9_'+\-]+\.)*[A-Za-z0-9_'+\-]*[A-Za-z0-9_+-]@(?:[A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$""",
);
final _phonePattern = RegExp(r'^[2389][0-9]{7}$');

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Escribe tu correo electrónico.';
  if (!_emailPattern.hasMatch(email)) {
    return 'Escribe un correo válido, como nombre@ejemplo.com.';
  }
  return null;
}

String? _validateNewPassword(String? value) {
  if (value == null || value.trim().isEmpty) return 'Escribe tu contraseña.';
  if (value.length < 8) return 'Escribe al menos 8 caracteres.';
  if (utf8.encode(value).length > 72) {
    return 'La contraseña es demasiado larga.';
  }
  return null;
}

abstract class _FormState<T extends StatefulWidget> extends State<T> {
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (exception) {
      if (mounted) setState(() => error = _errorMessage(exception));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget page(
    String title,
    List<Widget> fields,
    String submitLabel,
    VoidCallback submit,
  ) {
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    for (var i = 0; i < fields.length; i++)
                      Reveal(
                        order: i < 10 ? i : 10,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: fields[i],
                        ),
                      ),
                    if (error case final message?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    Reveal(
                      order: fields.length < 10 ? fields.length : 10,
                      child: Pressable(
                        child: FilledButton(
                          onPressed: busy
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  if (!form.currentState!.validate()) return;
                                  FocusScope.of(context).unfocus();
                                  submit();
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(busy ? 'Un momento…' : submitLabel),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccountForm extends StatefulWidget {
  const AccountForm({
    super.key,
    this.register = false,
    this.initialEmail = '',
    this.offerVerification = false,
  });
  final bool register;
  final String initialEmail;
  final bool offerVerification;

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends _FormState<AccountForm> {
  static const _maxNameLetters = 30;
  static final _letterPattern = RegExp(r'\p{L}', unicode: true);
  static final _namePattern = RegExp(
    r'^(?:\p{L}\p{M}*)+(?: (?:\p{L}\p{M}*)+)?$',
    unicode: true,
  );
  static final _nameInputTokens = RegExp(r'\p{L}\p{M}*|\s', unicode: true);
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _phone = TextEditingController();
  final _organizationName = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _hide = true;
  late bool _verificationNeeded = widget.offerVerification;
  bool _organization = false;
  String _organizationType = 'veterinaria';
  bool _locationAlerts = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _surname,
      _phone,
      _organizationName,
      _email,
      _password,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() => perform(() async {
    final email = _email.text.trim();
    final credentials = {'correo': email, 'password': _password.text};
    if (widget.register) {
      final api = context.read<PetIdApi>();
      final phone = '+504${_phone.text}';
      final location = _locationAlerts ? await _readAlertLocation() : null;
      if (!mounted) return;
      final response = await api.request(
        'POST',
        '/auth/registro',
        body: {
          ...credentials,
          'nombre': _name.text.trim(),
          'apellido': _surname.text.trim(),
          'telefono': phone,
          if (_organization)
            'organizacion': {
              'nombre': _organizationName.text.trim(),
              'tipo': _organizationType,
              'telefono': phone,
            },
          if (location != null) 'alertas_ubicacion': {'ubicacion': location},
        },
      );
      if (!mounted) return;
      final result = response['data'];
      final verify = await _showRegistrationConfirmation(
        email,
        sent: result is! Map || result['verificacion_enviada'] != false,
      );
      if (!mounted) return;
      final verified = verify == true && await _openHelp(verify: true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              AccountForm(initialEmail: email, offerVerification: !verified),
        ),
      );
    } else {
      try {
        await context.read<Session>().login(credentials);
      } on ApiError catch (exception) {
        if (mounted) {
          setState(
            () => _verificationNeeded =
                exception.status == 403 &&
                exception.message.toLowerCase().contains('verific'),
          );
        }
        rethrow;
      }
      if (mounted) Navigator.of(context).pop();
    }
  });

  Future<Map<String, double>> _readAlertLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiError(
        'Activa la ubicación del celular o desmarca las alertas para continuar.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const ApiError(
        'Permite el acceso a tu ubicación en los ajustes del celular o desmarca las alertas.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return {'latitud': position.latitude, 'longitud': position.longitude};
    } on TimeoutException {
      throw const ApiError(
        'No se pudo obtener tu ubicación. Intenta de nuevo o desmarca las alertas.',
      );
    } on LocationServiceDisabledException {
      throw const ApiError(
        'Activa la ubicación del celular o desmarca las alertas para continuar.',
      );
    }
  }

  Future<void> _loginWithGoogle() => perform(() async {
    final session = context.read<Session>();
    final token = await GoogleAccount.idToken();
    if (!mounted || token == null) return;
    await session.loginWithGoogle(token);
    if (mounted) Navigator.of(context).pop();
  });

  void _changeMode({required bool register}) {
    final email = _email.text.trim();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AccountForm(register: register, initialEmail: email),
      ),
    );
  }

  Future<bool> _openHelp({bool verify = false}) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AccountHelp(email: _email.text.trim(), verify: verify),
      ),
    );
    if (mounted && completed == true) {
      setState(() {
        error = null;
        _verificationNeeded = false;
      });
    }
    return completed == true;
  }

  Future<bool?> _showRegistrationConfirmation(
    String email, {
    required bool sent,
  }) => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: petCream,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: petOrange),
      ),
      icon: const CircleAvatar(
        backgroundColor: petOrange,
        foregroundColor: petInk,
        radius: 26,
        child: Icon(Icons.check_rounded, size: 30),
      ),
      title: const Text(
        '¡Cuenta creada!',
        textAlign: TextAlign.center,
        style: TextStyle(color: petInk, fontWeight: FontWeight.bold),
      ),
      content: Text(
        [
          if (sent)
            'Revisa $email y copia el enlace de verificación.'
          else
            'No pudimos enviar el correo. Puedes solicitar otro desde el inicio de sesión.',
          if (_organization) 'La organización quedó pendiente de revisión.',
        ].join('\n\n'),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (sent)
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Verificar mi correo'),
          ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Ir a iniciar sesión'),
        ),
      ],
    ),
  );

  Future<void> _resend() => perform(() async {
    await context.read<PetIdApi>().request(
      'POST',
      '/auth/reenviar-verificacion',
      body: {'correo': _email.text.trim()},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si tu cuenta está pendiente, recibirás un correo de verificación.',
          ),
        ),
      );
    }
  });

  static String _sanitizeNameInput(String text) {
    final result = StringBuffer();
    var letters = 0;
    var hasSpace = false;
    for (final token in _nameInputTokens.allMatches(text)) {
      final value = token[0]!;
      if (_letterPattern.hasMatch(value)) {
        if (letters == _maxNameLetters) break;
        result.write(value);
        letters++;
      } else if (letters > 0 && letters < _maxNameLetters && !hasSpace) {
        result.write(' ');
        hasSpace = true;
      }
    }
    return result.toString();
  }

  static TextEditingValue _formatNameInput(
    TextEditingValue previous,
    TextEditingValue next,
  ) {
    if (!next.composing.isCollapsed) return next;
    final text = _sanitizeNameInput(next.text);
    if (text == next.text) return next;

    int offset(int index) => index < 0
        ? text.length
        : _sanitizeNameInput(next.text.substring(0, index)).length;

    return next.copyWith(
      text: text,
      selection: next.selection.copyWith(
        baseOffset: offset(next.selection.baseOffset),
        extentOffset: offset(next.selection.extentOffset),
      ),
      composing: TextRange.empty,
    );
  }

  Widget _nameField(
    TextEditingController controller,
    String label,
    String hint,
  ) => AccountField(
    label,
    ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextFormField(
        controller: controller,
        enabled: !busy,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        inputFormatters: [TextInputFormatter.withFunction(_formatNameInput)],
        decoration: accountInput(hint).copyWith(
          counterText:
              '${_letterPattern.allMatches(value.text).length}/$_maxNameLetters',
          counterStyle: const TextStyle(color: accountMuted),
        ),
        validator: (value) {
          final name = value?.trim() ?? '';
          if (name.isEmpty) return 'Completa este campo.';
          if (!_namePattern.hasMatch(name)) {
            return 'Usa solo letras y un espacio entre palabras.';
          }
          final letters = _letterPattern.allMatches(name).length;
          if (letters < 2) return 'Escribe al menos dos letras.';
          if (letters > _maxNameLetters) {
            return 'Escribe un máximo de $_maxNameLetters letras.';
          }
          return null;
        },
      ),
    ),
  );

  Widget _accountType(String label, {required bool organization}) {
    final selected = _organization == organization;
    return OutlinedButton(
      onPressed: busy
          ? null
          : () => setState(() => _organization = organization),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        foregroundColor: selected ? petInk : accountMuted,
        backgroundColor: selected ? const Color(0xFFFFF1E8) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        side: BorderSide(color: selected ? petOrange : accountBorder, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Semantics(
        selected: selected,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    final submitLabel = register ? 'Crear cuenta' : 'Iniciar sesión';
    return AccountLayout(
      title: register ? 'Crea tu cuenta' : '¡Hola de nuevo!',
      subtitle: register
          ? 'Así podrás registrar mascotas y recibir alertas cerca de ti.'
          : 'Inicia sesión para ver a tus mascotas y las alertas de tu zona.',
      busy: busy,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            register ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?',
            style: const TextStyle(color: accountMuted),
          ),
          accountLink(
            register ? 'Inicia sesión' : 'Regístrate',
            busy ? null : () => _changeMode(register: !register),
          ),
        ],
      ),
      children: [
        AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (register) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _accountType(
                          'Dueño o ciudadano',
                          organization: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _accountType(
                          'Veterinaria o refugio',
                          organization: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _nameField(_name, 'Nombres', 'Ej. María José'),
                  _nameField(_surname, 'Apellidos', 'Ej. Pérez López'),
                  if (_organization) ...[
                    AccountField(
                      'Tipo de organización',
                      DropdownButtonFormField<String>(
                        value: _organizationType,
                        isExpanded: true,
                        decoration: accountInput('Selecciona el tipo'),
                        items: const [
                          DropdownMenuItem(
                            value: 'veterinaria',
                            child: Text('Veterinaria'),
                          ),
                          DropdownMenuItem(
                            value: 'refugio',
                            child: Text('Refugio'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _organizationType = value);
                                }
                              },
                      ),
                    ),
                    AccountField(
                      'Nombre de la organización',
                      TextFormField(
                        controller: _organizationName,
                        enabled: !busy,
                        maxLength: 150,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: accountInput(
                          'Nombre de tu veterinaria o refugio',
                        ),
                        validator: (value) => (value?.trim().length ?? 0) < 2
                            ? 'Escribe el nombre de la organización.'
                            : null,
                      ),
                    ),
                  ],
                  AccountField(
                    'Teléfono',
                    TextFormField(
                      controller: _phone,
                      enabled: !busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        // El primer dígito solo puede ser 2, 3, 8 o 9.
                        TextInputFormatter.withFunction(
                          (previous, next) =>
                              next.text.isEmpty || '2389'.contains(next.text[0])
                              ? next
                              : previous,
                        ),
                        LengthLimitingTextInputFormatter(8),
                      ],
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      decoration: accountInput('Ej. 98765432'),
                      validator: (value) {
                        final phone = value ?? '';
                        if (phone.isEmpty) return 'Escribe tu teléfono.';
                        if (!_phonePattern.hasMatch(phone)) {
                          return 'Escribe 8 dígitos que empiecen con 2, 3, 8 o 9.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
                AccountField(
                  'Correo electrónico',
                  TextFormField(
                    controller: _email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    maxLength: 150,
                    decoration: accountInput(
                      'tucorreo@ejemplo.com',
                      icon: register ? null : Icons.mail_outline_rounded,
                    ),
                    onChanged: (_) {
                      if (_verificationNeeded) {
                        setState(() {
                          _verificationNeeded = false;
                          error = null;
                        });
                      }
                    },
                    validator: _validateEmail,
                  ),
                ),
                AccountField(
                  'Contraseña',
                  TextFormField(
                    controller: _password,
                    enabled: !busy,
                    obscureText: _hide,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: accountInput(
                      register ? 'Mínimo 8 caracteres' : '••••••••',
                      icon: register ? null : Icons.lock_outline_rounded,
                      suffix: IconButton(
                        tooltip: _hide
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: busy
                            ? null
                            : () => setState(() => _hide = !_hide),
                        icon: Icon(
                          _hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: register
                        ? _validateNewPassword
                        : (value) => value == null || value.isEmpty
                              ? 'Escribe tu contraseña.'
                              : null,
                    onFieldSubmitted: (_) => _submitValidated(),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (register)
          CheckboxListTile(
            value: _locationAlerts,
            onChanged: busy
                ? null
                : (value) => setState(() {
                    _locationAlerts = value ?? false;
                    error = null;
                  }),
            contentPadding: EdgeInsets.zero,
            activeColor: petOrange,
            checkColor: petInk,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Permitir ubicación para recibir alertas de mi zona',
              style: TextStyle(color: accountMuted),
            ),
          ),
        if (!register)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: accountLink(
              '¿Olvidaste tu contraseña?',
              busy ? null : () => _openHelp(),
            ),
          ),
        if (error case final message?) accountError(context, message),
        if (_verificationNeeded) ...[
          accountLink(
            'Verificar mi correo',
            busy ? null : () => _openHelp(verify: true),
          ),
          accountLink('Reenviar correo de verificación', busy ? null : _resend),
        ],
        const SizedBox(height: 12),
        AccountButton(
          busy ? 'Un momento…' : submitLabel,
          onPressed: busy ? null : _submitValidated,
        ),
        if (!register) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Row(
              children: [
                Expanded(child: Divider(color: accountBorder, thickness: 2)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o continúa con',
                    style: TextStyle(color: accountMuted),
                  ),
                ),
                Expanded(child: Divider(color: accountBorder, thickness: 2)),
              ],
            ),
          ),
          AccountButton(
            'Google',
            primary: false,
            onPressed: busy || !GoogleAccount.available
                ? null
                : _loginWithGoogle,
          ),
          if (!GoogleAccount.available)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Google aún no está disponible.',
                textAlign: TextAlign.center,
                style: TextStyle(color: accountMuted),
              ),
            ),
        ],
      ],
    );
  }

  void _submitValidated() {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _submit();
  }
}

class _AccountHelp extends StatefulWidget {
  const _AccountHelp({required this.email, required this.verify});
  final String email;
  final bool verify;

  @override
  State<_AccountHelp> createState() => _AccountHelpState();
}

class _AccountHelpState extends _FormState<_AccountHelp> {
  late final _email = TextEditingController(text: widget.email);
  final _link = TextEditingController();
  final _password = TextEditingController();
  bool _hasLink = false;
  bool _hidePassword = true;
  String? _notice;

  bool get _usingLink => widget.verify || _hasLink;

  @override
  void dispose() {
    _email.dispose();
    _link.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _token(String value) {
    final text = value.trim();
    final token = RegExp(r'^[0-9a-f]{64}$');
    if (token.hasMatch(text)) return text;
    final linkToken = RegExp(
      r'[#?&]token=([0-9a-f]{64})(?=&|$)',
    ).firstMatch(text)?.group(1);
    return linkToken;
  }

  Future<void> _submit() => perform(() async {
    final api = context.read<PetIdApi>();
    if (!_usingLink) {
      await api.request(
        'POST',
        '/auth/recuperar-contrasena',
        body: {'correo': _email.text.trim()},
      );
      if (!mounted) return;
      setState(() {
        _hasLink = true;
        _notice = 'Si la cuenta existe, recibirás un correo con instrucciones.';
      });
      return;
    }
    await api.request(
      'POST',
      widget.verify ? '/auth/verificar-correo' : '/auth/restablecer-contrasena',
      body: {
        'token': _token(_link.text),
        if (!widget.verify) 'password': _password.text,
      },
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.verify
              ? 'Correo verificado. Ya puedes iniciar sesión.'
              : 'Contraseña actualizada. Ya puedes iniciar sesión.',
        ),
      ),
    );
    Navigator.of(context).pop(true);
  });

  @override
  Widget build(BuildContext context) => AccountLayout(
    title: widget.verify ? 'Verifica tu correo' : 'Recupera tu contraseña',
    subtitle: _usingLink
        ? 'Copia y pega el enlace del correo de PetID.'
        : 'Te enviaremos un enlace para cambiar tu contraseña.',
    busy: busy,
    children: [
      if (_notice case final notice?)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(notice, style: const TextStyle(color: accountMuted)),
        ),
      Form(
        key: form,
        child: Column(
          children: [
            if (!_usingLink)
              AccountField(
                'Correo electrónico',
                TextFormField(
                  key: const ValueKey('recovery-email'),
                  controller: _email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: accountInput('tucorreo@ejemplo.com'),
                  validator: _validateEmail,
                ),
              ),
            if (_usingLink)
              AccountField(
                'Enlace de PetID',
                TextFormField(
                  key: const ValueKey('recovery-link'),
                  controller: _link,
                  enabled: !busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  decoration: accountInput('Pega el enlace aquí'),
                  validator: (value) => _token(value ?? '') == null
                      ? 'Pega el enlace completo que recibiste.'
                      : null,
                ),
              ),
            if (_usingLink && !widget.verify)
              AccountField(
                'Nueva contraseña',
                TextFormField(
                  controller: _password,
                  enabled: !busy,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: accountInput(
                    'Mínimo 8 caracteres',
                    suffix: IconButton(
                      tooltip: _hidePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                      onPressed: busy
                          ? null
                          : () =>
                                setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: _validateNewPassword,
                ),
              ),
          ],
        ),
      ),
      if (error case final message?) accountError(context, message),
      AccountButton(
        busy
            ? 'Un momento…'
            : widget.verify
            ? 'Verificar correo'
            : _usingLink
            ? 'Guardar contraseña'
            : 'Enviar enlace',
        onPressed: busy
            ? null
            : () {
                if (!form.currentState!.validate()) return;
                FocusScope.of(context).unfocus();
                _submit();
              },
      ),
      if (!widget.verify)
        accountLink(
          _usingLink ? 'Solicitar otro enlace' : 'Ya tengo el enlace',
          busy
              ? null
              : () => setState(() {
                  _hasLink = !_hasLink;
                  error = null;
                  _notice = null;
                }),
        ),
    ],
  );
}

class SightingForm extends StatefulWidget {
  const SightingForm({super.key, this.signedIn = false});
  final bool signedIn;

  @override
  State<SightingForm> createState() => _SightingFormState();
}

class _SightingFormState extends _FormState<SightingForm> {
  final _place = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  String _capture = 'desconocida';

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        perform(() async {
          final lost = await _picker.retrieveLostData();
          if (lost.exception case final exception?) throw exception;
          final restored = lost.files?.firstOrNull;
          if (mounted && restored != null) {
            setState(() => _photo = restored);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _place.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) => perform(() async {
    final photo = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (mounted && photo != null) setState(() => _photo = photo);
  });

  Future<void> _report() => perform(() async {
    final data = {
      'referencia_lugar': _place.text.trim(),
      'descripcion': _description.text.trim(),
      'fecha_avistamiento': DateTime.now().toUtc().toIso8601String(),
    };
    final photo = _photo;
    if (widget.signedIn) {
      await context.read<Session>().report(data, photo, _capture);
    } else {
      await context.read<PetIdApi>().request(
        'POST',
        photo == null ? '/avistamientos' : '/avistamientos/escanear',
        body: data,
        photo: photo,
        capture: _capture,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Avistamiento registrado. Gracias por reportarlo.'),
      ),
    );
    Navigator.of(context).pop();
  });

  @override
  Widget build(BuildContext context) => page(
    'Reportar avistamiento',
    [
      TextFormField(
        controller: _place,
        enabled: !busy,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: '¿Dónde viste a la mascota?',
          helperText: 'Escribe el barrio, calle o un punto de referencia.',
          helperMaxLines: 2,
        ),
        validator: _required,
      ),
      TextFormField(
        controller: _description,
        enabled: !busy,
        maxLines: 4,
        maxLength: 3000,
        decoration: const InputDecoration(labelText: 'Describe a la mascota'),
        validator: _required,
      ),
      const Text('Foto opcional'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: busy ? null : () => _pick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Tomar foto'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galería'),
          ),
        ],
      ),
      if (_photo case final photo?) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.image_outlined),
          title: Text(photo.name),
          trailing: IconButton(
            tooltip: 'Quitar foto',
            onPressed: busy
                ? null
                : () => setState(() {
                    _photo = null;
                    _capture = 'desconocida';
                  }),
            icon: const Icon(Icons.close),
          ),
        ),
        DropdownButtonFormField<String>(
          value: _capture,
          decoration: const InputDecoration(labelText: 'Distancia de la foto'),
          items: const [
            DropdownMenuItem(
              value: 'desconocida',
              child: Text('No estoy segura/o'),
            ),
            DropdownMenuItem(value: 'cerca', child: Text('De cerca')),
            DropdownMenuItem(value: 'lejos', child: Text('De lejos')),
          ],
          onChanged: busy ? null : (value) => setState(() => _capture = value!),
        ),
      ],
    ],
    'Enviar reporte',
    _report,
  );
}

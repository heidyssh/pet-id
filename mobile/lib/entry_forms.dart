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
import 'motion.dart';
import 'pet_camera.dart';
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
  if (!RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[a-z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value)) {
    return 'Cumple todos los requisitos de la contraseña.';
  }
  if (utf8.encode(value).length > 72) {
    return 'La contraseña es demasiado larga.';
  }
  return null;
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final password = value.text;
          final started = password.isNotEmpty;
          final requirements = <(String, bool)>[
            ('8 caracteres', password.length >= 8),
            ('Una mayúscula', RegExp(r'[A-Z]').hasMatch(password)),
            ('Una minúscula', RegExp(r'[a-z]').hasMatch(password)),
            ('Un número', RegExp(r'[0-9]').hasMatch(password)),
          ];
          return Semantics(
            liveRegion: true,
            label: 'Requisitos de contraseña',
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final requirement in requirements)
                    _PasswordRequirementChip(
                      label: requirement.$1,
                      valid: requirement.$2,
                      started: started,
                    ),
                ],
              ),
            ),
          );
        },
      );
}

class _PasswordRequirementChip extends StatelessWidget {
  const _PasswordRequirementChip({
    required this.label,
    required this.valid,
    required this.started,
  });

  final String label;
  final bool valid;
  final bool started;

  @override
  Widget build(BuildContext context) {
    final foreground = !started
        ? accountMuted
        : valid
        ? const Color(0xFF176D61)
        : const Color(0xFFB42318);
    final background = !started
        ? const Color(0xFFF5F2EF)
        : valid
        ? const Color(0xFFDDF5EE)
        : const Color(0xFFFFE8E5);
    final border = !started
        ? accountBorder
        : valid
        ? const Color(0xFF8BD8C5)
        : const Color(0xFFFFB4AB);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              !started
                  ? Icons.circle_outlined
                  : valid
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              key: ValueKey((started, valid)),
              color: foreground,
              size: 15,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
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
  const AccountForm({super.key, this.register = false, this.initialEmail = ''});
  final bool register;
  final String initialEmail;

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
      await api.request(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _organization
                ? 'Cuenta creada. Tu organización quedó pendiente de revisión.'
                : '¡Cuenta creada! Ya puedes usar PetID.',
          ),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AccountForm(initialEmail: email),
        ),
      );
    } else {
      await context.read<Session>().login(credentials);
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

  void _changeMode({required bool register}) {
    final email = _email.text.trim();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AccountForm(register: register, initialEmail: email),
      ),
    );
  }

  Future<void> _openHelp() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AccountHelp(email: _email.text.trim()),
      ),
    );
  }

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
                if (register)
                  Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 14),
                    child: _PasswordRequirements(controller: _password),
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
        const SizedBox(height: 12),
        AccountButton(
          busy ? 'Un momento…' : submitLabel,
          loading: busy,
          onPressed: busy ? null : _submitValidated,
        ),
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
  const _AccountHelp({required this.email});
  final String email;

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

  bool get _usingLink => _hasLink;

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
      '/auth/restablecer-contrasena',
      body: {'token': _token(_link.text), 'password': _password.text},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
      ),
    );
    Navigator.of(context).pop(true);
  });

  @override
  Widget build(BuildContext context) => AccountLayout(
    title: 'Recupera tu contraseña',
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
            if (_usingLink)
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
            if (_usingLink)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _PasswordRequirements(controller: _password),
              ),
          ],
        ),
      ),
      if (error case final message?) accountError(context, message),
      AccountButton(
        busy
            ? 'Un momento…'
            : _usingLink
            ? 'Guardar contraseña'
            : 'Enviar enlace',
        loading: busy,
        onPressed: busy
            ? null
            : () {
                if (!form.currentState!.validate()) return;
                FocusScope.of(context).unfocus();
                _submit();
              },
      ),
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
  const SightingForm({
    super.key,
    this.signedIn = false,
    this.startWithCamera = false,
  });
  final bool signedIn;
  final bool startWithCamera;

  @override
  State<SightingForm> createState() => _SightingFormState();
}

class _SightingFormState extends _FormState<SightingForm> {
  final _place = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  String _capture = 'desconocida';
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _takePhoto();
      });
    }
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
    if (mounted && photo != null) {
      setState(() {
        _photo = photo;
        _latitude = null;
        _longitude = null;
      });
    }
  });

  Future<void> _takePhoto() async {
    if (busy) return;
    final capture = await Navigator.of(context).push<PetCaptureResult>(
      MaterialPageRoute<PetCaptureResult>(
        builder: (_) => const PetCameraPage(attachLocation: true),
      ),
    );
    if (mounted && capture != null) {
      setState(() {
        _photo = capture.photo;
        _capture = 'desconocida';
        _latitude = capture.latitude;
        _longitude = capture.longitude;
      });
    }
  }

  Future<void> _report() => perform(() async {
    final data = {
      'referencia_lugar': _place.text.trim(),
      'descripcion': _description.text.trim(),
      'fecha_avistamiento': DateTime.now().toUtc().toIso8601String(),
      if (_latitude != null && _longitude != null)
        'ubicacion': {'latitud': _latitude, 'longitud': _longitude},
    };
    final photo = _photo;
    final Map<String, dynamic> response;
    if (widget.signedIn) {
      response = await context.read<Session>().report(data, photo, _capture);
    } else {
      response = await context.read<PetIdApi>().request(
        'POST',
        photo == null ? '/avistamientos' : '/avistamientos/escanear',
        body: data,
        photo: photo,
        capture: _capture,
      );
    }
    if (!mounted) return;
    if (photo != null) {
      final result = response['data'] is Map
          ? (response['data'] as Map)['resultado']
          : null;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: petCream,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _ScanResultSheet(result: result),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avistamiento registrado. Gracias por reportarlo.'),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  });

  void _submitValidated() {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _report();
  }

  @override
  Widget build(BuildContext context) => AccountLayout(
    title: 'Reportar avistamiento',
    subtitle:
        'Comparte lo que viste. Una foto clara puede ayudar a encontrar a su familia.',
    busy: busy,
    children: [
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AccountField(
              '¿Dónde viste a la mascota?',
              TextFormField(
                controller: _place,
                enabled: !busy,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: accountInput(
                  'Barrio, calle o punto de referencia',
                  icon: Icons.location_on_outlined,
                ),
                validator: _required,
              ),
            ),
            AccountField(
              'Describe a la mascota',
              TextFormField(
                controller: _description,
                enabled: !busy,
                minLines: 4,
                maxLines: 6,
                maxLength: 3000,
                textCapitalization: TextCapitalization.sentences,
                decoration: accountInput(
                  'Color, tamaño, collar, señas particulares...',
                ).copyWith(alignLabelWithHint: true),
                validator: _required,
              ),
            ),
            const Text(
              'Foto de la mascota',
              style: TextStyle(color: petInk, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            const Text(
              'Opcional, pero ayuda a buscar coincidencias.',
              style: TextStyle(color: accountMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MediaActionButton(
                    icon: Icons.photo_camera_outlined,
                    label: 'Tomar foto',
                    onPressed: busy ? null : _takePhoto,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MediaActionButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Galería',
                    onPressed: busy ? null : () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            if (_photo case final photo?) ...[
              const SizedBox(height: 14),
              _SelectedPhotoCard(
                photo: photo,
                enabled: !busy,
                onRemove: () => setState(() {
                  _photo = null;
                  _capture = 'desconocida';
                  _latitude = null;
                  _longitude = null;
                }),
              ),
              if (_latitude != null && _longitude != null) ...[
                const SizedBox(height: 10),
                const _LocationAttachedBadge(),
              ],
              const SizedBox(height: 16),
              const Text(
                '¿A qué distancia tomaste la foto?',
                style: TextStyle(color: petInk, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 9),
              _CaptureDistance(
                value: _capture,
                enabled: !busy,
                onChanged: (value) => setState(() => _capture = value),
              ),
            ],
            if (error case final message?) ...[
              const SizedBox(height: 16),
              accountError(context, message),
            ],
            const SizedBox(height: 22),
            AccountButton(
              busy ? 'Enviando reporte...' : 'Enviar reporte',
              loading: busy,
              onPressed: busy ? null : _submitValidated,
            ),
          ],
        ),
      ),
    ],
  );
}

class _ScanResultSheet extends StatelessWidget {
  const _ScanResultSheet({required this.result});

  final Object? result;

  @override
  Widget build(BuildContext context) {
    final data = result is Map
        ? Map<String, dynamic>.from(result! as Map)
        : const <String, dynamic>{};
    final matches = data['coincidencias'] is List
        ? (data['coincidencias'] as List)
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList()
        : const <Map<String, dynamic>>[];
    final completed = data['procesamiento'] == 'visual_completado';

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: matches.isEmpty ? .58 : .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accountBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: completed
                          ? const Color(0xFFDDF5EE)
                          : const Color(0xFFFFE8D8),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      completed
                          ? Icons.center_focus_strong_rounded
                          : Icons.info_outline_rounded,
                      color: completed
                          ? const Color(0xFF176D61)
                          : petDarkOrange,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completed ? 'Escaneo completado' : 'Reporte guardado',
                          style: const TextStyle(
                            color: petInk,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          completed
                              ? matches.isEmpty
                                    ? 'No encontramos una coincidencia visual por ahora.'
                                    : 'Estas son las mascotas visualmente más parecidas.'
                              : 'El reconocimiento visual no pudo completarse en este intento.',
                          style: const TextStyle(
                            color: accountMuted,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (matches.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: matches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => Reveal(
                      order: index,
                      child: _VisualMatchCard(match: matches[index]),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accountBorder, width: 2),
                      ),
                      child: Text(
                        completed
                            ? 'La foto sí fue analizada. Puedes continuar con el reporte; si aparece una coincidencia después, el propietario deberá confirmarla.'
                            : 'Comprueba que Roboflow esté configurado y que la foto muestre claramente el rostro o cuerpo de un perro o gato.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: accountMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: petDarkOrange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'La similitud orienta la búsqueda; nunca confirma por sí sola la identidad. El propietario debe verificarla.',
                        style: TextStyle(
                          color: accountMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AccountButton(
                'Finalizar reporte',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisualMatchCard extends StatelessWidget {
  const _VisualMatchCard({required this.match});

  final Map<String, dynamic> match;

  @override
  Widget build(BuildContext context) {
    final photo = context.read<PetIdApi>().imageUrl(match['foto']);
    final score = (match['puntuacion_visual'] as num?)?.toDouble();
    final percentage = score == null ? null : (score * 100).round();
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: accountBorder, width: 2),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.square(
              dimension: 64,
              child: photo == null
                  ? const ColoredBox(
                      color: Color(0xFFFFE8D8),
                      child: Icon(Icons.pets_rounded, color: petDarkOrange),
                    )
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFFFE8D8),
                        child: Icon(Icons.pets_rounded, color: petDarkOrange),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${match['nombre'] ?? 'Mascota sin nombre'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: petInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Posible coincidencia',
                  style: TextStyle(color: accountMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (percentage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDDF5EE),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$percentage%',
                style: const TextStyle(
                  color: Color(0xFF176D61),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaActionButton extends StatelessWidget {
  const _MediaActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 21),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      foregroundColor: petDarkOrange,
      backgroundColor: Colors.white,
      disabledForegroundColor: accountMuted.withValues(alpha: .45),
      side: const BorderSide(color: accountBorder, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

class _SelectedPhotoCard extends StatelessWidget {
  const _SelectedPhotoCard({
    required this.photo,
    required this.enabled,
    required this.onRemove,
  });

  final XFile photo;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accountBorder, width: 2),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 66,
            child: FutureBuilder(
              future: photo.readAsBytes(),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) {
                  return const ColoredBox(
                    color: Color(0xFFFFE8D8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Image.memory(bytes, fit: BoxFit.cover);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Foto lista para escanear',
                style: TextStyle(color: petInk, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                photo.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: accountMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Quitar foto',
          onPressed: enabled ? onRemove : null,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _CaptureDistance extends StatelessWidget {
  const _CaptureDistance({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in const [
        ('desconocida', 'No sé'),
        ('cerca', 'De cerca'),
        ('lejos', 'De lejos'),
      ])
        ChoiceChip(
          label: Text(option.$2),
          selected: value == option.$1,
          onSelected: enabled ? (_) => onChanged(option.$1) : null,
          showCheckmark: false,
          selectedColor: const Color(0xFFFFDCC5),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: value == option.$1 ? petOrange : accountBorder,
            width: 1.7,
          ),
          shape: const StadiumBorder(),
          labelStyle: TextStyle(
            color: value == option.$1 ? petDarkOrange : accountMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );
}

class _LocationAttachedBadge extends StatelessWidget {
  const _LocationAttachedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFDDF5EE),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF98D8C9)),
    ),
    child: const Row(
      children: [
        Icon(Icons.location_on_rounded, color: Color(0xFF16816D), size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Ubicación agregada al reporte',
            style: TextStyle(
              color: Color(0xFF166A5B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Icon(Icons.check_circle_rounded, color: Color(0xFF16816D), size: 19),
      ],
    ),
  );
}

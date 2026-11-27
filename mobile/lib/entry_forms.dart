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
import 'app_select.dart';
import 'location_picker.dart';
import 'motion.dart';
import 'pet_camera.dart';
import 'welcome.dart';

String _errorMessage(Object error) => switch (error) {
  ApiError() => error.message,
  TimeoutException() =>
    'No pudimos conectar con PetID. Comprueba que el celular y la computadora estén en la misma red.',
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
      !RegExp(r'[0-9]').hasMatch(value) ||
      !RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(value)) {
    return 'Cumple todos los requisitos de la contraseña.';
  }
  if (utf8.encode(value).length > 72) {
    return 'La contraseña es demasiado larga.';
  }
  return null;
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({
    required this.controller,
    this.confirmController,
  });

  final TextEditingController controller;
  final TextEditingController? confirmController;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final password = value.text;
          final confirmation = confirmController?.text ?? '';
          final started = password.isNotEmpty;
          final requirements = <(String, bool)>[
            ('Al menos 8 caracteres', password.length >= 8),
            ('Una mayúscula', RegExp(r'[A-Z]').hasMatch(password)),
            ('Una minúscula', RegExp(r'[a-z]').hasMatch(password)),
            ('Un número', RegExp(r'[0-9]').hasMatch(password)),
            (
              'Al menos un símbolo: #, \$, -, @ o !',
              RegExp(r'[^\p{L}\p{N}\s]', unicode: true).hasMatch(password),
            ),
            if (confirmController != null)
              (
                'Escrita igual en Confirmar contraseña',
                confirmation.isNotEmpty && confirmation == password,
              ),
          ];
          return Semantics(
            liveRegion: true,
            label: 'Requisitos de contraseña',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationSectionHeader extends StatelessWidget {
  const _RegistrationSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0E5),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: petDarkOrange, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: petInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: accountMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
      if (mounted) {
        final message = _errorMessage(exception);
        setState(() => error = null);
        showPetToast(
          context,
          message,
          type: exception is TimeoutException
              ? PetToastType.warning
              : PetToastType.error,
        );
      }
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
  final _confirmPassword = TextEditingController();
  bool _hide = true;
  bool _hideConfirmation = true;
  bool _organization = false;
  String? _organizationType;
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
      _confirmPassword,
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
              'tipo': _organizationType!,
              'telefono': phone,
            },
          if (location != null)
            'alertas_ubicacion': {'ubicacion': location, 'radio_km': 2},
        },
      );
      if (!mounted) return;
      showPetToast(
        context,
        _organization
            ? 'Cuenta creada. Tu organización quedó pendiente de revisión.'
            : '¡Cuenta creada! Ya puedes iniciar sesión.',
        type: PetToastType.success,
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
                  if (_organization) ...[
                    const _RegistrationSectionHeader(
                      icon: Icons.business_rounded,
                      title: 'Datos de la organización',
                      subtitle: 'Información de la veterinaria o refugio',
                    ),
                    const SizedBox(height: 16),
                    AccountField(
                      'Tipo de organización',
                      AppSelectField<String>(
                        value: _organizationType,
                        title: 'Tipo de organización',
                        hint: 'Seleccionar tipo',
                        options: const [
                          AppSelectOption(
                            'veterinaria',
                            'Veterinaria',
                            icon: Icons.local_hospital_outlined,
                          ),
                          AppSelectOption(
                            'refugio',
                            'Refugio',
                            icon: Icons.home_outlined,
                          ),
                        ],
                        enabled: !busy,
                        onChanged: (value) =>
                            setState(() => _organizationType = value),
                        validator: (value) => value == null
                            ? 'Selecciona el tipo de organización.'
                            : null,
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
                    const _RegistrationSectionHeader(
                      icon: Icons.badge_outlined,
                      title: 'Persona encargada',
                      subtitle: 'Responsable de administrar esta cuenta',
                    ),
                  ] else
                    const _RegistrationSectionHeader(
                      icon: Icons.person_outline_rounded,
                      title: 'Datos personales',
                      subtitle: 'Información de quien crea la cuenta',
                    ),
                  const SizedBox(height: 16),
                  _nameField(
                    _name,
                    _organization ? 'Nombres del encargado' : 'Nombres',
                    'Ej. María José',
                  ),
                  _nameField(
                    _surname,
                    _organization ? 'Apellidos del encargado' : 'Apellidos',
                    'Ej. Pérez López',
                  ),
                  AccountField(
                    _organization ? 'Teléfono del encargado' : 'Teléfono',
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
                  const _RegistrationSectionHeader(
                    icon: Icons.lock_person_outlined,
                    title: 'Acceso a la cuenta',
                    subtitle: 'Correo y contraseña para iniciar sesión',
                  ),
                  const SizedBox(height: 16),
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
                    scrollPadding: const EdgeInsets.only(bottom: 280),
                    onFieldSubmitted: register
                        ? null
                        : (_) => _submitValidated(),
                  ),
                ),
                if (register) ...[
                  AccountField(
                    'Confirmar contraseña',
                    TextFormField(
                      controller: _confirmPassword,
                      enabled: !busy,
                      obscureText: _hideConfirmation,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      scrollPadding: const EdgeInsets.only(bottom: 300),
                      decoration: accountInput(
                        'Escribe la contraseña otra vez',
                        suffix: IconButton(
                          tooltip: _hideConfirmation
                              ? 'Mostrar confirmación'
                              : 'Ocultar confirmación',
                          onPressed: busy
                              ? null
                              : () => setState(
                                  () => _hideConfirmation = !_hideConfirmation,
                                ),
                          icon: Icon(
                            _hideConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirma tu contraseña.';
                        }
                        if (value != _password.text) {
                          return 'Las contraseñas no coinciden.';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _submitValidated(),
                    ),
                  ),
                  _PasswordRequirements(
                    controller: _password,
                    confirmController: _confirmPassword,
                  ),
                ],
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
    if (busy) return;
    if (!form.currentState!.validate()) {
      showPetToast(
        context,
        'Revisa los campos marcados antes de continuar.',
        type: PetToastType.warning,
      );
      return;
    }
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
    this.suggestedLostReport,
  });
  final bool signedIn;
  final bool startWithCamera;
  final Map<String, dynamic>? suggestedLostReport;

  @override
  State<SightingForm> createState() => _SightingFormState();
}

class _SightingFormState extends _FormState<SightingForm> {
  final _description = TextEditingController();
  final _picker = ImagePicker();
  XFile? _photo;
  String _capture = 'desconocida';
  double? _latitude;
  double? _longitude;
  String? _locationLabel;
  String? _locationError;

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
      setState(() => _photo = photo);
    }
  });

  Future<void> _chooseLocation() async {
    if (busy) return;
    final selected = await Navigator.of(context).push<LocationSelection>(
      MaterialPageRoute<LocationSelection>(
        builder: (_) => LocationPickerPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialLabel: _locationLabel,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _latitude = selected.latitude;
      _longitude = selected.longitude;
      _locationLabel = selected.label;
      _locationError = null;
    });
  }

  Future<void> _resolveCapturedLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await context.read<PetIdApi>().request(
        'GET',
        '/mapas/geocodificar-reversa?latitud=$latitude&longitud=$longitude',
      );
      final items = (response['data'] as Map?)?['items'];
      final first = items is List && items.isNotEmpty ? items.first : null;
      final address = first is Map ? first['direccion'] : null;
      if (!mounted || address is! String || address.trim().isEmpty) return;
      if (_latitude == latitude && _longitude == longitude) {
        setState(() => _locationLabel = address.trim());
      }
    } catch (_) {
      // Las coordenadas siguen siendo válidas sin una dirección legible.
    }
  }

  Future<void> _takePhoto() async {
    if (busy) return;
    final capture = await Navigator.of(context).push<PetCaptureResult>(
      MaterialPageRoute<PetCaptureResult>(
        builder: (_) => const PetCameraPage(attachLocation: true),
      ),
    );
    if (mounted && capture != null) {
      final latitude = capture.latitude;
      final longitude = capture.longitude;
      setState(() {
        _photo = capture.photo;
        _capture = 'desconocida';
        _latitude = latitude;
        _longitude = longitude;
        _locationLabel = latitude != null && longitude != null
            ? 'Ubicación tomada con la foto'
            : _locationLabel;
        _locationError = null;
      });
      if (latitude != null && longitude != null) {
        unawaited(_resolveCapturedLocation(latitude, longitude));
      }
    }
  }

  Future<void> _report() => perform(() async {
    final data = {
      if (widget.suggestedLostReport?['id_reporte'] case final Object reportId)
        'id_reporte_sugerido': int.tryParse('$reportId') ?? reportId,
      if (_locationLabel?.trim().isNotEmpty == true)
        'referencia_lugar': _locationLabel!.trim(),
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
        useSafeArea: true,
        backgroundColor: Colors.transparent,
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
    if (busy) return;
    if (_latitude == null || _longitude == null) {
      setState(() => _locationError = 'Selecciona el punto en el mapa.');
      return;
    }
    setState(() => _locationError = null);
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final suggested = widget.suggestedLostReport;
    final petName = '${suggested?['nombre_mascota'] ?? ''}'.trim();
    return AccountLayout(
      title: suggested == null
          ? 'Reportar avistamiento'
          : 'Posible avistamiento',
      subtitle: suggested == null
          ? 'Comparte lo que viste. Una foto clara puede ayudar a encontrar a su familia.'
          : 'Comparte lo que viste para que la familia pueda comprobar si es ${petName.isEmpty ? 'su mascota' : petName}.',
      busy: busy,
      children: [
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (suggested != null) ...[
                _SuggestedLostPetCard(item: suggested),
                const SizedBox(height: 18),
              ],
              _ReportLocationCard(
                label: _locationLabel,
                error: _locationError,
                enabled: !busy,
                onTap: _chooseLocation,
              ),
              const SizedBox(height: 18),
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
                  }),
                ),
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
              const SizedBox(height: 22),
              _ReportSubmitButton(
                label: busy
                    ? 'Enviando reporte...'
                    : _photo == null
                    ? 'Enviar avistamiento'
                    : 'Buscar coincidencias y reportar',
                loading: busy,
                onPressed: busy ? null : _submitValidated,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestedLostPetCard extends StatelessWidget {
  const _SuggestedLostPetCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final photo = context.read<PetIdApi>().imageUrl(item['foto']);
    final name = '${item['nombre_mascota'] ?? 'Mascota perdida'}';
    final detail = [
      item['raza'],
      item['especie'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFB5CC), width: 2),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.square(
              dimension: 62,
              child: photo == null
                  ? const ColoredBox(
                      color: Color(0xFFFFD9E5),
                      child: Icon(Icons.pets_rounded, color: Color(0xFFD93A6E)),
                    )
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFFFD9E5),
                        child: Icon(
                          Icons.pets_rounded,
                          color: Color(0xFFD93A6E),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CREES QUE PODRÍA SER',
                  style: TextStyle(
                    color: Color(0xFFD93A6E),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: const TextStyle(
                    color: petInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail ?? 'La familia confirmará la identidad',
                  style: const TextStyle(color: accountMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.link_rounded, color: Color(0xFFD93A6E)),
        ],
      ),
    );
  }
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

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.only(bottom: petSheetBottomInset(context)),
      child: Container(
        decoration: const BoxDecoration(
          color: petCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .86,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF5EE),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.check_rounded,
                          color: Color(0xFF176D61),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Avistamiento publicado',
                              style: TextStyle(
                                color: petInk,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              completed
                                  ? matches.isEmpty
                                        ? 'La foto fue analizada sin una coincidencia clara.'
                                        : 'Encontramos candidatos para que sus familias los revisen.'
                                  : 'La foto quedó guardada, aunque no pudimos compararla ahora.',
                              style: const TextStyle(
                                color: Color(0xFF176D61),
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (matches.isNotEmpty)
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: accountBorder, width: 2),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.visibility_outlined, color: petDarkOrange),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Se mostrará en el mapa como un avistamiento: una mascota vista cuya identidad todavía no está confirmada.',
                            style: TextStyle(color: accountMuted, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: petDarkOrange),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El reconocimiento solo propone posibles coincidencias. La familia siempre debe verificarlas.',
                          style: TextStyle(
                            color: accountMuted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AccountButton(
                  'Entendido',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder(
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
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB8000000)],
                stops: [.48, 1],
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 62,
            bottom: 15,
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD064)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Foto lista para buscar coincidencias',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filled(
              tooltip: 'Quitar foto',
              onPressed: enabled ? onRemove : null,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xDDFFFFFF),
                foregroundColor: petInk,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReportLocationCard extends StatelessWidget {
  const _ReportLocationCard({
    required this.label,
    required this.error,
    required this.enabled,
    required this.onTap,
  });

  final String? label;
  final String? error;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = label?.trim().isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Dónde viste a la mascota?',
          style: TextStyle(color: petInk, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Material(
          color: selected ? const Color(0xFFF1FBF8) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: error != null
                  ? const Color(0xFFE05A67)
                  : selected
                  ? const Color(0xFF7EDCC8)
                  : accountBorder,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFCCF3E9)
                          : const Color(0xFFFFE7D5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      selected ? Icons.location_on_rounded : Icons.map_outlined,
                      color: selected ? const Color(0xFF087460) : petDarkOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected ? label! : 'Elegir en el mapa',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: petInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          selected
                              ? 'Toca para ajustar el punto'
                              : 'Marca el lugar exacto o usa tu GPS',
                          style: const TextStyle(
                            color: accountMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.edit_location_alt_outlined
                        : Icons.chevron_right_rounded,
                    color: selected ? const Color(0xFF087460) : petDarkOrange,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDF0),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFB9254F),
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFF92203F),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportSubmitButton extends StatelessWidget {
  const _ReportSubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFFC85B0A), petDarkOrange],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2EAE4B04),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.send_rounded),
      label: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text(label, key: ValueKey(label)),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
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

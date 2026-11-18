import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'api.dart';
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
                    for (final field in fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: field,
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
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () {
                              if (!form.currentState!.validate()) return;
                              FocusScope.of(context).unfocus();
                              submit();
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(busy ? 'Un momento…' : submitLabel),
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
  static const _maxNameLetters = 50;
  static final _letterPattern = RegExp(r'\p{L}', unicode: true);
  static final _namePattern = RegExp(
    r'^(?:\p{L}\p{M}*)+(?: (?:\p{L}\p{M}*)+)?$',
    unicode: true,
  );
  static final _nameInputTokens = RegExp(r'\p{L}\p{M}*|\s', unicode: true);
  static final _emailPattern = RegExp(
    r"""^(?:[A-Za-z0-9_'+\-]+\.)*[A-Za-z0-9_'+\-]*[A-Za-z0-9_+-]@(?:[A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$""",
  );

  final _name = TextEditingController();
  final _surname = TextEditingController();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _hide = true;
  bool _verificationNeeded = false;

  @override
  void dispose() {
    for (final controller in [_name, _surname, _email, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() => perform(() async {
    final email = _email.text.trim();
    final credentials = {'correo': email, 'password': _password.text};
    if (widget.register) {
      await context.read<PetIdApi>().request(
        'POST',
        '/auth/registro',
        body: {
          ...credentials,
          'nombre': _name.text.trim(),
          'apellido': _surname.text.trim(),
        },
      );
      if (!mounted) return;
      await _showRegistrationConfirmation(email);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AccountForm(initialEmail: email),
        ),
      );
    } else {
      try {
        await context.read<Session>().login(credentials);
      } on ApiError catch (exception) {
        if (mounted)
          setState(
            () => _verificationNeeded =
                exception.status == 403 &&
                exception.message.toLowerCase().contains('verific'),
          );
        rethrow;
      }
      if (mounted) Navigator.of(context).pop();
    }
  });

  Future<void> _showRegistrationConfirmation(String email) => showDialog<void>(
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
        'Revisa $email y abre el enlace de verificación para activar tu cuenta.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si tu cuenta está pendiente, recibirás un correo de verificación.',
          ),
        ),
      );
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

  Widget _nameField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        enabled: !busy,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [
          TextInputFormatter.withFunction(_formatNameInput),
        ],
        decoration: InputDecoration(
          labelText: label,
          helperText: 'Hasta 50 letras y un espacio opcional.',
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
            return 'Escribe un máximo de 50 letras.';
          }
          return null;
        },
      );

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    final label = register ? 'Crear cuenta' : 'Iniciar sesión';
    return page(
      label,
      [
        if (register) _nameField(_name, 'Nombre'),
        if (register) _nameField(_surname, 'Apellido'),
        TextFormField(
          controller: _email,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          maxLength: 150,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            counterText: '',
          ),
          onChanged: (_) {
            if (_verificationNeeded)
              setState(() => _verificationNeeded = false);
          },
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Escribe tu correo electrónico.';
            if (!_emailPattern.hasMatch(email)) {
              return 'Escribe un correo válido, como nombre@ejemplo.com.';
            }
            return null;
          },
        ),
        TextFormField(
          controller: _password,
          enabled: !busy,
          obscureText: _hide,
          autofillHints: [
            register ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: InputDecoration(
            labelText: 'Contraseña',
            helperText: register ? 'Mínimo 8 caracteres' : null,
            suffixIcon: IconButton(
              tooltip: _hide ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: () => setState(() => _hide = !_hide),
              icon: Icon(
                _hide
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) {
            if (value == null ||
                value.isEmpty ||
                (register && value.trim().isEmpty)) {
              return 'Escribe tu contraseña.';
            }
            if (register && value.length < 8) {
              return 'Escribe al menos 8 caracteres.';
            }
            if (register && utf8.encode(value).length > 72)
              return 'La contraseña es demasiado larga.';
            return null;
          },
        ),
        if (_verificationNeeded)
          TextButton(
            onPressed: busy ? null : _resend,
            child: const Text('Reenviar correo de verificación'),
          ),
      ],
      label,
      _submit,
    );
  }
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

class CitizenHome extends StatefulWidget {
  const CitizenHome({super.key, required this.name});
  final String name;

  @override
  State<CitizenHome> createState() => _CitizenHomeState();
}

class _CitizenHomeState extends State<CitizenHome> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await context.read<Session>().logout();
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(exception))));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PetID'),
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: _loggingOut ? null : _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            widget.name.isEmpty ? 'Bienvenido a PetID' : 'Hola, ${widget.name}',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: petInk),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loggingOut
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SightingForm(signedIn: true),
                    ),
                  ),
            icon: const Icon(Icons.pets),
            label: const Text('Reportar avistamiento'),
          ),
        ],
      ),
    ),
  );
}

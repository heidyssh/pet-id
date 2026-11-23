import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'motion.dart';
import 'pet_camera.dart';
import 'welcome.dart';

class PetRegistrationPage extends StatefulWidget {
  const PetRegistrationPage({super.key});

  @override
  State<PetRegistrationPage> createState() => _PetRegistrationPageState();
}

class _PetRegistrationPageState extends State<PetRegistrationPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _color = TextEditingController();
  final _marks = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile?> _photos = List.filled(4, null);
  final Set<int> _uploaded = {};
  List<Map<String, dynamic>> _species = const [];
  List<Map<String, dynamic>> _breeds = const [];
  int _step = 0;
  int? _speciesId;
  String? _breedId;
  String _sex = 'hembra';
  String _size = 'mediano';
  DateTime? _birthDate;
  Object? _createdId;
  bool _loadingCatalog = true;
  bool _busy = false;
  String? _error;

  static const _photoLabels = [
    'Cara de frente',
    'Perfil',
    'Cuerpo completo',
    'Señas particulares',
  ];

  @override
  void initState() {
    super.initState();
    _loadSpecies();
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _marks.dispose();
    super.dispose();
  }

  Future<void> _loadSpecies() async {
    try {
      final response = await context.read<PetIdApi>().request(
        'GET',
        '/catalogos/especies',
      );
      final items = _maps(response['data']);
      if (!mounted) return;
      setState(() {
        _species = items;
        _speciesId = items.isEmpty
            ? null
            : (items.first['id_especie'] as num).toInt();
      });
      await _loadBreeds();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  Future<void> _loadBreeds() async {
    final id = _speciesId;
    if (id == null) return;
    try {
      final response = await context.read<PetIdApi>().request(
        'GET',
        '/catalogos/razas?id_especie=$id',
      );
      if (mounted) {
        setState(() {
          _breeds = _maps(response['data']);
          _breedId = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _choosePhoto(int index) async {
    if (_busy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: petCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cámara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || source == null) return;
    XFile? photo;
    if (source == ImageSource.camera) {
      final capture = await Navigator.of(context).push<PetCaptureResult>(
        MaterialPageRoute(builder: (_) => const PetCameraPage()),
      );
      photo = capture?.photo;
    } else {
      photo = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    }
    if (mounted && photo != null) setState(() => _photos[index] = photo);
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: 'Fecha de nacimiento',
    );
    if (selected != null && mounted) setState(() => _birthDate = selected);
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 0 && !_form.currentState!.validate()) return;
    if (_step == 1 && _photos.any((photo) => photo == null)) {
      setState(
        () =>
            _error = 'Agrega las cuatro fotos para mejorar el reconocimiento.',
      );
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = context.read<Session>();
      if (_createdId == null) {
        final response = await session.authRequest(
          'POST',
          '/mascotas',
          body: {
            'nombre': _name.text.trim(),
            'id_especie': _speciesId,
            'id_raza': _breedId,
            'sexo': _sex,
            'color_principal': _color.text.trim(),
            'tamano': _size,
            'senas_particulares': _marks.text.trim().isEmpty
                ? null
                : _marks.text.trim(),
            'fecha_nacimiento': _birthDate == null
                ? null
                : _isoDate(_birthDate!),
          },
        );
        _createdId = (response['data'] as Map)['id_mascota'];
      }
      for (var i = 0; i < _photos.length; i++) {
        if (_uploaded.contains(i)) continue;
        await session.uploadPetPhoto(_createdId!, _photos[i]!, main: i == 0);
        _uploaded.add(i);
        if (mounted) setState(() {});
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${_name.text.trim()} ya forma parte de PetID!'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${_message(error)} Puedes reintentar sin perder los datos.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: petCream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  IconButton.outlined(
                    onPressed: _busy
                        ? null
                        : () => _step == 0
                              ? Navigator.pop(context)
                              : setState(() => _step--),
                    icon: const Icon(Icons.chevron_left_rounded, size: 30),
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(50),
                      side: const BorderSide(color: accountBorder, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Nueva mascota',
                    style: TextStyle(
                      color: petInk,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Progress(step: _step),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: _step == 0
                      ? _details()
                      : _step == 1
                      ? _recognitionPhotos()
                      : _review(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: AccountButton(
                        'Atrás',
                        primary: false,
                        onPressed: _busy ? null : () => setState(() => _step--),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AccountButton(
                      _step == 2
                          ? (_busy ? 'Registrando...' : 'Registrar mascota')
                          : 'Continuar',
                      loading: _busy,
                      onPressed: _busy || _loadingCatalog
                          ? null
                          : (_step == 2 ? _save : _next),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _details() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Datos de tu mascota',
          style: TextStyle(
            color: petInk,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Esta información ayudará a identificarla.',
          style: TextStyle(color: accountMuted),
        ),
        const SizedBox(height: 20),
        AccountField(
          'Nombre',
          TextFormField(
            controller: _name,
            decoration: accountInput('Nombre de la mascota'),
            textCapitalization: TextCapitalization.words,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Escribe su nombre.'
                : null,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: AccountField(
                'Especie',
                DropdownButtonFormField<int>(
                  value: _speciesId,
                  decoration: accountInput('Especie'),
                  items: _species
                      .map(
                        (item) => DropdownMenuItem(
                          value: (item['id_especie'] as num).toInt(),
                          child: Text('${item['nombre']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingCatalog
                      ? null
                      : (value) {
                          setState(() => _speciesId = value);
                          _loadBreeds();
                        },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AccountField(
                'Sexo',
                DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: accountInput('Sexo'),
                  items: const [
                    DropdownMenuItem(value: 'hembra', child: Text('Hembra')),
                    DropdownMenuItem(value: 'macho', child: Text('Macho')),
                  ],
                  onChanged: (value) => setState(() => _sex = value!),
                ),
              ),
            ),
          ],
        ),
        AccountField(
          'Raza',
          DropdownButtonFormField<String?>(
            value: _breedId,
            isExpanded: true,
            decoration: accountInput('Selecciona la raza'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Mestiza / sin especificar'),
              ),
              ..._breeds.map(
                (item) => DropdownMenuItem<String?>(
                  value: '${item['id_raza']}',
                  child: Text('${item['nombre']}'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _breedId = value),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: AccountField(
                'Color',
                TextFormField(
                  controller: _color,
                  decoration: accountInput('Ej. Canela'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el color.'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AccountField(
                'Tamaño',
                DropdownButtonFormField<String>(
                  value: _size,
                  decoration: accountInput('Tamaño'),
                  items: const [
                    DropdownMenuItem(value: 'pequeno', child: Text('Pequeño')),
                    DropdownMenuItem(value: 'mediano', child: Text('Mediano')),
                    DropdownMenuItem(value: 'grande', child: Text('Grande')),
                  ],
                  onChanged: (value) => setState(() => _size = value!),
                ),
              ),
            ),
          ],
        ),
        AccountField(
          'Fecha de nacimiento',
          InkWell(
            onTap: _selectBirthDate,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: accountInput('Opcional'),
              child: Text(
                _birthDate == null
                    ? 'Seleccionar fecha'
                    : _isoDate(_birthDate!),
                style: TextStyle(
                  color: _birthDate == null ? accountMuted : petInk,
                ),
              ),
            ),
          ),
        ),
        AccountField(
          'Señas particulares',
          TextFormField(
            controller: _marks,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: accountInput('Manchas, cicatrices, collar...'),
          ),
        ),
        if (_error != null) accountError(context, _error!),
      ],
    ),
  );

  Widget _recognitionPhotos() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accountBorder, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toma 4 fotos claras',
              style: TextStyle(
                color: petInk,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Con buena luz y sin filtros. Servirán para reconocer a tu mascota si se pierde.',
              style: TextStyle(color: accountMuted, height: 1.35),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (_, index) => _PhotoSlot(
                label: _photoLabels[index],
                photo: _photos[index],
                onTap: () => _choosePhoto(index),
              ),
            ),
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        accountError(context, _error!),
      ],
    ],
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Revisa antes de registrar',
        style: TextStyle(
          color: petInk,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Crearemos su ficha y procesaremos las cuatro fotos para el reconocimiento visual.',
        style: TextStyle(color: accountMuted, height: 1.4),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accountBorder, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _name.text.trim(),
              style: const TextStyle(
                color: petInk,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_speciesName()} · ${_color.text.trim()} · ${_sizeLabel()}',
              style: const TextStyle(color: accountMuted),
            ),
            if (_createdId != null) ...[
              const SizedBox(height: 12),
              Text(
                'Fotos procesadas: ${_uploaded.length}/4',
                style: const TextStyle(
                  color: Color(0xFF08735F),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        accountError(context, _error!),
      ],
    ],
  );

  String _speciesName() =>
      '${_species.firstWhere((item) => item['id_especie'] == _speciesId, orElse: () => {'nombre': 'Mascota'})['nombre']}';
  String _sizeLabel() =>
      {'pequeno': 'Pequeña', 'mediano': 'Mediana', 'grande': 'Grande'}[_size]!;
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 8,
                  decoration: BoxDecoration(
                    color: i <= step ? petOrange : accountBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Paso ${step + 1} de 3 · ${['Datos principales', 'Fotos para reconocimiento', 'Confirmación'][step]}',
          style: const TextStyle(
            color: accountMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.photo,
    required this.onTap,
  });
  final String label;
  final XFile? photo;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: photo == null ? petCream : const Color(0xFFFFDDC5),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: photo == null ? const Color(0xFFFFC5A3) : accountBorder,
              width: 2,
              style: photo == null ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      photo == null
                          ? Icons.photo_camera_outlined
                          : Icons.image_outlined,
                      color: petDarkOrange,
                      size: 31,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: petDarkOrange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (photo != null)
                const Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: Color(0xFF12CFA5),
                    child: Icon(
                      Icons.check_rounded,
                      color: Color(0xFF063D33),
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];
String _isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _message(Object error) =>
    error is ApiError ? error.message : 'No se pudo completar la acción.';

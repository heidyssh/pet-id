import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'app_select.dart';
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
  bool _breedChosen = false;
  String? _sex;
  String? _size;
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
      });
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
          _breedChosen = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _selectBreed() async {
    if (_speciesId == null || _loadingCatalog) return;
    final search = TextEditingController();
    var query = '';
    final selected = await showModalBottomSheet<_BreedOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: petCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final options =
              [
                const _BreedOption(null, 'Mestiza / sin especificar'),
                ..._breeds.map(
                  (item) =>
                      _BreedOption('${item['id_raza']}', '${item['nombre']}'),
                ),
              ].where((option) {
                return query.isEmpty ||
                    option.name.toLowerCase().contains(query.toLowerCase());
              }).toList();
          return FractionallySizedBox(
            heightFactor: .78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accountBorder,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Selecciona la raza',
                    style: TextStyle(
                      color: petInk,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: accountInput(
                      'Buscar raza',
                    ).copyWith(prefixIcon: const Icon(Icons.search_rounded)),
                    onChanged: (value) =>
                        setSheetState(() => query = value.trim()),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: options.isEmpty
                        ? const Center(child: Text('No encontramos esa raza.'))
                        : ListView.separated(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: options.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final option = options[index];
                              final active =
                                  _breedChosen && option.id == _breedId;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                title: Text(option.name),
                                trailing: active
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: Color(0xFF00A985),
                                      )
                                    : null,
                                onTap: () =>
                                    Navigator.pop(sheetContext, option),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    search.dispose();
    if (selected != null && mounted) {
      setState(() {
        _breedId = selected.id;
        _breedChosen = true;
      });
    }
  }

  void _removePhoto(int index) {
    if (_busy) return;
    setState(() {
      _photos[index] = null;
      _uploaded.remove(index);
      _error = null;
    });
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
        await session.uploadPetPhoto(
          _createdId!,
          _photos[i]!,
          main: i == 0,
          requireRecognition: true,
        );
        _uploaded.add(i);
        if (mounted) setState(() {});
      }
      if (!mounted) return;
      showPetToast(
        context,
        '¡${_name.text.trim()} ya forma parte de PetID!',
        type: PetToastType.success,
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
                AppSelectField<int>(
                  value: _speciesId,
                  title: 'Especie',
                  hint: 'Seleccionar',
                  options: _species
                      .map(
                        (item) => AppSelectOption(
                          (item['id_especie'] as num).toInt(),
                          '${item['nombre']}',
                          icon: Icons.pets_outlined,
                        ),
                      )
                      .toList(),
                  enabled: !_loadingCatalog,
                  onChanged: (value) {
                    setState(() {
                      _speciesId = value;
                      _breedId = null;
                      _breedChosen = false;
                      _breeds = const [];
                    });
                    _loadBreeds();
                  },
                  validator: (value) =>
                      value == null ? 'Selecciona la especie.' : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AccountField(
                'Sexo',
                AppSelectField<String>(
                  value: _sex,
                  title: 'Sexo',
                  hint: 'Seleccionar',
                  options: const [
                    AppSelectOption('hembra', 'Hembra'),
                    AppSelectOption('macho', 'Macho'),
                  ],
                  onChanged: (value) => setState(() => _sex = value),
                  validator: (value) =>
                      value == null ? 'Selecciona el sexo.' : null,
                ),
              ),
            ),
          ],
        ),
        AccountField(
          'Raza',
          InkWell(
            onTap: _speciesId == null ? null : _selectBreed,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: accountInput('Seleccionar raza').copyWith(
                suffixIcon: Icon(
                  _speciesId == null
                      ? Icons.lock_outline_rounded
                      : Icons.keyboard_arrow_down_rounded,
                ),
              ),
              child: Text(
                _breedChosen
                    ? _breedName()
                    : _speciesId == null
                    ? 'Selecciona primero la especie'
                    : 'Seleccionar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _breedChosen ? petInk : accountMuted),
              ),
            ),
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
                AppSelectField<String>(
                  value: _size,
                  title: 'Tamaño',
                  hint: 'Seleccionar',
                  options: const [
                    AppSelectOption('pequeno', 'Pequeño'),
                    AppSelectOption('mediano', 'Mediano'),
                    AppSelectOption('grande', 'Grande'),
                  ],
                  onChanged: (value) => setState(() => _size = value),
                  validator: (value) =>
                      value == null ? 'Selecciona el tamaño.' : null,
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
                onRemove: () => _removePhoto(index),
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
      const Text(
        'Fotos para reconocimiento',
        style: TextStyle(
          color: petInk,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _photos.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (_, index) =>
            _ReviewPhoto(photo: _photos[index]!, label: _photoLabels[index]),
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
            const SizedBox(height: 16),
            _ReviewPair(
              firstLabel: 'Especie',
              firstValue: _speciesName(),
              secondLabel: 'Sexo',
              secondValue: _sexLabel(),
            ),
            const SizedBox(height: 14),
            _ReviewPair(
              firstLabel: 'Raza',
              firstValue: _breedName(),
              secondLabel: 'Tamaño',
              secondValue: _sizeLabel(),
            ),
            const SizedBox(height: 14),
            _ReviewPair(
              firstLabel: 'Color',
              firstValue: _color.text.trim(),
              secondLabel: 'Nacimiento',
              secondValue: _birthDate == null
                  ? 'No especificada'
                  : _isoDate(_birthDate!),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            const Text(
              'Señas particulares',
              style: TextStyle(
                color: accountMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _marks.text.trim().isEmpty
                  ? 'Sin señas particulares registradas'
                  : _marks.text.trim(),
              style: const TextStyle(color: petInk, height: 1.35),
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
  String _breedName() {
    if (!_breedChosen || _breedId == null) return 'Mestiza / sin especificar';
    return '${_breeds.firstWhere((item) => '${item['id_raza']}' == _breedId, orElse: () => {'nombre': 'Sin especificar'})['nombre']}';
  }

  String _sexLabel() => _sex == 'macho' ? 'Macho' : 'Hembra';
  String _sizeLabel() =>
      {'pequeno': 'Pequeña', 'mediano': 'Mediana', 'grande': 'Grande'}[_size]!;
}

class _ReviewPair extends StatelessWidget {
  const _ReviewPair({
    required this.firstLabel,
    required this.firstValue,
    required this.secondLabel,
    required this.secondValue,
  });

  final String firstLabel;
  final String firstValue;
  final String secondLabel;
  final String secondValue;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: _ReviewValue(label: firstLabel, value: firstValue),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: _ReviewValue(label: secondLabel, value: secondValue),
      ),
    ],
  );
}

class _ReviewValue extends StatelessWidget {
  const _ReviewValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: accountMuted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(color: petInk, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _ReviewPhoto extends StatelessWidget {
  const _ReviewPhoto({required this.photo, required this.label});
  final XFile photo;
  final String label;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Stack(
      fit: StackFit.expand,
      children: [
        _LocalPhoto(photo: photo),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(7, 18, 7, 7),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB8000000)],
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
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
    required this.onRemove,
  });
  final String label;
  final XFile? photo;
  final VoidCallback onTap;
  final VoidCallback onRemove;
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
              if (photo != null)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _LocalPhoto(photo: photo!),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 20, 8, 9),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xB8000000)],
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (photo != null)
                Positioned(
                  top: 7,
                  right: 7,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          color: petInk,
                          size: 18,
                        ),
                      ),
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

class _LocalPhoto extends StatelessWidget {
  const _LocalPhoto({required this.photo});
  final XFile photo;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: photo.readAsBytes(),
    builder: (_, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(snapshot.data!, fit: BoxFit.cover);
      }
      return const ColoredBox(
        color: Color(0xFFFFDDC5),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    },
  );
}

class _BreedOption {
  const _BreedOption(this.id, this.name);
  final String? id;
  final String name;
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];
String _isoDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _message(Object error) =>
    error is ApiError ? error.message : 'No se pudo completar la acción.';

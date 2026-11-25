import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'app_select.dart';
import 'lost_report.dart';
import 'motion.dart';
import 'welcome.dart';

const _mint = Color(0xFF12CFA5);
const _mintDark = Color(0xFF08735F);
const _pink = Color(0xFFFF6B98);
const _peach = Color(0xFFFFDDC5);

class PetDetailPage extends StatefulWidget {
  const PetDetailPage({super.key, required this.initialPet});

  final Map<String, dynamic> initialPet;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  static const _storage = FlutterSecureStorage();
  late Map<String, dynamic> _pet = widget.initialPet;
  List<Map<String, dynamic>> _history = const [];
  bool _loading = true;
  bool _offlineReady = false;
  bool _changed = false;
  String? _error;
  String? _historyError;
  Map<String, dynamic>? _activeReport;
  int _photoIndex = 0;

  String get _id => '${_pet['id_mascota']}';
  String get _cacheKey => 'petid.pet.$_id';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<Session>();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final cached = await _storage.read(key: _cacheKey);
      if (cached != null && mounted) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        setState(() {
          _pet = Map<String, dynamic>.from(data['pet'] as Map);
          _history = _maps(data['history']);
          _offlineReady = true;
        });
      }
    } catch (_) {
      // La caché es una ayuda; la API sigue siendo la fuente oficial.
    }

    try {
      final response = await session.authRequest('GET', '/mascotas/$_id');
      final pet = Map<String, dynamic>.from(response['data'] as Map);
      if (!mounted) return;
      setState(() {
        _pet = pet;
        _offlineReady = true;
      });
    } catch (_) {
      if (mounted && !_offlineReady) {
        setState(() => _error = 'No pudimos actualizar la ficha.');
      }
    }

    try {
      final response = await session.authRequest(
        'GET',
        '/historial-clinico/mascotas/$_id',
      );
      final historyData = response['data'] as Map;
      if (mounted) {
        setState(() {
          _history = _maps(historyData['items']);
          _historyError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _historyError = 'No pudimos actualizar el historial.');
      }
    }

    try {
      final response = await session.authRequest(
        'GET',
        '/extravios/mios?pagina=1&limite=50',
      );
      final reports = _maps((response['data'] as Map?)?['reportes']);
      if (mounted) {
        Map<String, dynamic>? active;
        for (final item in reports) {
          if ('${item['id_mascota']}' == _id && item['estado'] == 'activo') {
            active = item;
            break;
          }
        }
        setState(() {
          _activeReport = active;
        });
      }
    } catch (_) {
      // La ficha sigue siendo utilizable aunque no se pueda consultar el reporte.
    }

    if (mounted && _offlineReady) {
      try {
        await _storage.write(
          key: _cacheKey,
          value: jsonEncode({'pet': _pet, 'history': _history}),
        );
      } catch (_) {
        // La ficha en línea sigue disponible aunque falle la caché.
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reportLost() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => LostReportPage(pet: _pet)));
    if (created != true || !mounted) return;
    _changed = true;
    setState(() => _pet = {..._pet, 'estado': 'perdido'});
    await _load();
    if (!mounted) return;
    showPetToast(
      context,
      'Alerta de ${_pet['nombre']} enviada.',
      type: PetToastType.success,
    );
  }

  Future<void> _resolveLost() async {
    final report = _activeReport;
    if (report == null) {
      showPetToast(
        context,
        'No pudimos localizar el reporte activo. Actualiza la ficha e inténtalo de nuevo.',
        type: PetToastType.warning,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Ya está en casa?'),
        content: Text(
          'Cerraremos la alerta de ${_pet['nombre']} y dejará de aparecer como perdida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, está en casa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<Session>().authRequest(
        'PATCH',
        '/extravios/${report['id_reporte']}/resolver',
      );
      if (!mounted) return;
      _changed = true;
      setState(() {
        _pet = {..._pet, 'estado': 'a_salvo'};
        _activeReport = null;
      });
      showPetToast(
        context,
        '¡Qué alegría! La alerta fue cerrada.',
        type: PetToastType.success,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      showPetToast(context, _message(error), type: PetToastType.error);
    }
  }

  Future<void> _showMatches() async {
    final report = _activeReport;
    if (report == null) {
      showPetToast(
        context,
        'Actualiza la ficha para consultar las coincidencias.',
        type: PetToastType.warning,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MatchesSheet(reportId: '${report['id_reporte']}'),
    );
  }

  Future<void> _addClinicalRecord() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HealthRecordSheet(petId: _id),
    );
    if (created != true || !mounted) return;
    _changed = true;
    await _load();
    if (!mounted) return;
    showPetToast(
      context,
      'Registro de salud guardado.',
      type: PetToastType.success,
    );
  }

  Future<void> _editPet() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPetSheet(pet: _pet),
    );
    if (updated != true || !mounted) return;
    _changed = true;
    await _load();
    if (!mounted) return;
    showPetToast(
      context,
      'Ficha de ${_pet['nombre']} actualizada.',
      type: PetToastType.success,
    );
  }

  void _close() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final photos = _galleryOf(context, _pet);
    final lost = _pet['estado'] == 'perdido';
    return Scaffold(
      backgroundColor: _peach,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: petOrange,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _hero(photos)),
              SliverToBoxAdapter(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height - 310,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    28,
                    20,
                    30 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: petCream,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(38),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(child: _identity(lost)),
                      if (_loading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          minHeight: 4,
                          color: petOrange,
                          backgroundColor: accountBorder,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _InfoBox(
                          text: _error!,
                          action: 'Reintentar',
                          onAction: _load,
                        ),
                      ],
                      const SizedBox(height: 22),
                      Reveal(order: 1, child: _facts()),
                      const SizedBox(height: 10),
                      Reveal(order: 2, child: _marks()),
                      const SizedBox(height: 26),
                      Reveal(order: 3, child: _clinical()),
                      const SizedBox(height: 24),
                      Reveal(
                        order: 4,
                        child: _LostButton(
                          name: '${_pet['nombre'] ?? 'esta mascota'}',
                          lost: lost,
                          onReport: lost ? null : _reportLost,
                          onMatches: lost ? _showMatches : null,
                          onResolved: lost ? _resolveLost : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(List<String> photos) => SizedBox(
    height: 330,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isEmpty)
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, color: petDarkOrange, size: 62),
              SizedBox(height: 12),
              Text(
                'Foto de la mascota',
                style: TextStyle(
                  color: petDarkOrange,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          )
        else
          PageView.builder(
            physics: const BouncingScrollPhysics(),
            pageSnapping: true,
            itemCount: photos.length,
            onPageChanged: (index) {
              HapticFeedback.selectionClick();
              setState(() => _photoIndex = index);
            },
            itemBuilder: (_, index) => AnimatedScale(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              scale: index == _photoIndex ? 1 : .97,
              child: Image.network(
                photos[index],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: _peach,
                  child: Center(
                    child: Icon(
                      Icons.pets_rounded,
                      color: petDarkOrange,
                      size: 70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 18,
          left: 18,
          right: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TopButton(icon: Icons.chevron_left_rounded, onPressed: _close),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _OfflineBadge(
                  key: ValueKey((_offlineReady, _loading)),
                  ready: _offlineReady,
                  loading: _loading,
                ),
              ),
            ],
          ),
        ),
        if (photos.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < photos.length; index++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: index == _photoIndex ? 22 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: index == _photoIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _identity(bool lost) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${_pet['nombre'] ?? 'Mascota'}',
              style: const TextStyle(
                color: petInk,
                fontSize: 31,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _StatusBadge(lost: lost),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        '${_petId(_pet['id_mascota'])}  ·  ${_registered(_pet['fecha_registro'])}',
        style: const TextStyle(color: accountMuted, fontSize: 14),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _editPet,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar ficha'),
          style: OutlinedButton.styleFrom(
            foregroundColor: petDarkOrange,
            side: const BorderSide(color: accountBorder, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _facts() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 2.1,
    children: [
      _Fact(label: 'Especie', value: _species(_pet)),
      _Fact(
        label: 'Raza',
        value: _pet['raza']?['nombre']?.toString() ?? 'Sin especificar',
      ),
      _Fact(label: 'Edad', value: _age(_pet['fecha_nacimiento'])),
      _Fact(label: 'Color', value: '${_pet['color_principal'] ?? 'Sin dato'}'),
    ],
  );

  Widget _marks() => Container(
    padding: const EdgeInsets.all(17),
    decoration: _box(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Señas particulares',
          style: TextStyle(
            color: petInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          (_pet['senas_particulares'] as String?)?.trim().isNotEmpty == true
              ? _pet['senas_particulares']
              : 'No se registraron señas particulares.',
          style: const TextStyle(color: accountMuted, height: 1.4),
        ),
      ],
    ),
  );

  Widget _clinical() {
    final items = _history
        .where(
          (item) =>
              item['tipo_registro'] == 'vacuna' ||
              item['tipo_registro'] == 'desparasitacion',
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Vacunas y desparasitación',
                style: TextStyle(
                  color: petInk,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _addClinicalRecord,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Registrar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: petDarkOrange,
                side: const BorderSide(color: petOrange, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        if (_historyError != null) ...[
          _InfoBox(text: _historyError!, action: 'Reintentar', onAction: _load),
          if (items.isNotEmpty) const SizedBox(height: 10),
        ],
        if (items.isEmpty && _historyError == null)
          const _InfoBox(
            text: 'Aún no hay vacunas ni desparasitaciones registradas.',
          )
        else
          for (var i = 0; i < items.length; i++) ...[
            _ClinicalCard(item: items[i]),
            if (i < items.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _EditPetSheet extends StatefulWidget {
  const _EditPetSheet({required this.pet});
  final Map<String, dynamic> pet;

  @override
  State<_EditPetSheet> createState() => _EditPetSheetState();
}

class _EditPetSheetState extends State<_EditPetSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _color;
  late final TextEditingController _marks;
  String? _sex;
  String? _size;
  DateTime? _birthDate;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.pet['nombre'] ?? ''}');
    _color = TextEditingController(
      text: '${widget.pet['color_principal'] ?? ''}',
    );
    _marks = TextEditingController(
      text: '${widget.pet['senas_particulares'] ?? ''}',
    );
    _sex = widget.pet['sexo']?.toString();
    _size = widget.pet['tamano']?.toString();
    _birthDate = DateTime.tryParse('${widget.pet['fecha_nacimiento']}');
  }

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _marks.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
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

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().authRequest(
        'PATCH',
        '/mascotas/${widget.pet['id_mascota']}',
        body: {
          'nombre': _name.text.trim(),
          'sexo': _sex,
          'color_principal': _color.text.trim(),
          'tamano': _size,
          'senas_particulares': _marks.text.trim().isEmpty
              ? null
              : _marks.text.trim(),
          'fecha_nacimiento': _birthDate == null
              ? null
              : _dateOnly(_birthDate!),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiError
              ? error.message
              : 'No se pudo actualizar la ficha.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 220),
    padding: EdgeInsets.only(bottom: petSheetBottomInset(context)),
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: petCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
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
                'Editar ficha',
                style: TextStyle(
                  color: petInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_species(widget.pet)} · ${widget.pet['raza']?['nombre'] ?? 'Sin raza especificada'}',
                style: const TextStyle(color: accountMuted),
              ),
              const SizedBox(height: 18),
              AccountField(
                'Nombre',
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: accountInput('Nombre de la mascota'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe su nombre.'
                      : null,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: AccountField(
                      'Sexo',
                      AppSelectField<String>(
                        value: _sex,
                        title: 'Sexo',
                        options: const [
                          AppSelectOption('hembra', 'Hembra'),
                          AppSelectOption('macho', 'Macho'),
                        ],
                        enabled: !_busy,
                        onChanged: (value) => setState(() => _sex = value),
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
                        options: const [
                          AppSelectOption('pequeno', 'Pequeño'),
                          AppSelectOption('mediano', 'Mediano'),
                          AppSelectOption('grande', 'Grande'),
                        ],
                        enabled: !_busy,
                        onChanged: (value) => setState(() => _size = value),
                      ),
                    ),
                  ),
                ],
              ),
              AccountField(
                'Color',
                TextFormField(
                  controller: _color,
                  enabled: !_busy,
                  decoration: accountInput('Color principal'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el color.'
                      : null,
                ),
              ),
              AccountField(
                'Fecha de nacimiento',
                _DateField(
                  value: _birthDate == null
                      ? 'Seleccionar fecha'
                      : _date(_birthDate!),
                  muted: _birthDate == null,
                  onTap: _pickBirthDate,
                  onClear: _birthDate == null
                      ? null
                      : () => setState(() => _birthDate = null),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'La edad se calcula automáticamente a partir de esta fecha.',
                  style: TextStyle(color: accountMuted, fontSize: 12),
                ),
              ),
              AccountField(
                'Señas particulares',
                TextFormField(
                  controller: _marks,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: accountInput(
                    'Manchas, cicatrices, comportamiento...',
                  ),
                ),
              ),
              if (_error != null) accountError(context, _error!),
              const SizedBox(height: 14),
              AccountButton(
                _busy ? 'Guardando...' : 'Guardar cambios',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HealthRecordSheet extends StatefulWidget {
  const _HealthRecordSheet({required this.petId});
  final String petId;

  @override
  State<_HealthRecordSheet> createState() => _HealthRecordSheetState();
}

class _HealthRecordSheetState extends State<_HealthRecordSheet> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _type = 'vacuna';
  DateTime _applied = DateTime.now();
  DateTime? _next;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickApplied() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _applied,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: 'Fecha de aplicación',
    );
    if (value != null && mounted) {
      setState(() {
        _applied = value;
        if (_next != null && _next!.isBefore(value)) _next = null;
      });
    }
  }

  Future<void> _pickNext() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _next ?? _applied.add(const Duration(days: 365)),
      firstDate: _applied,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Próxima aplicación',
    );
    if (value != null && mounted) setState(() => _next = value);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().authRequest(
        'POST',
        '/historial-clinico/mascotas/${widget.petId}',
        body: {
          'tipo_registro': _type,
          'descripcion': _description.text.trim(),
          'fecha_aplicacion': _dateOnly(_applied),
          'proxima_fecha': _next == null ? null : _dateOnly(_next!),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiError
              ? error.message
              : 'No se pudo guardar el registro.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 220),
    padding: EdgeInsets.only(bottom: petSheetBottomInset(context)),
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: petCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
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
                'Registrar vacuna o desparasitación',
                style: TextStyle(
                  color: petInk,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Este registro será marcado como ingresado por el propietario.',
                style: TextStyle(color: accountMuted, height: 1.35),
              ),
              const SizedBox(height: 18),
              AccountField(
                'Tipo de registro',
                AppSelectField<String>(
                  value: _type,
                  title: 'Tipo de registro',
                  options: const [
                    AppSelectOption(
                      'vacuna',
                      'Vacuna',
                      icon: Icons.vaccines_outlined,
                    ),
                    AppSelectOption(
                      'desparasitacion',
                      'Desparasitación',
                      icon: Icons.medication_outlined,
                    ),
                  ],
                  enabled: !_busy,
                  onChanged: (value) {
                    if (value != null) setState(() => _type = value);
                  },
                ),
              ),
              AccountField(
                _type == 'vacuna' ? 'Vacuna aplicada' : 'Producto aplicado',
                TextFormField(
                  controller: _description,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 200,
                  decoration: accountInput(
                    _type == 'vacuna'
                        ? 'Ej. Antirrábica'
                        : 'Ej. Desparasitante interno',
                  ).copyWith(counterText: ''),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Escribe qué se aplicó.'
                      : null,
                ),
              ),
              AccountField(
                'Fecha de aplicación',
                _DateField(value: _date(_applied), onTap: _pickApplied),
              ),
              AccountField(
                'Próxima fecha (opcional)',
                _DateField(
                  value: _next == null ? 'Sin próxima fecha' : _date(_next!),
                  muted: _next == null,
                  onTap: _pickNext,
                  onClear: _next == null
                      ? null
                      : () => setState(() => _next = null),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                accountError(context, _error!),
              ],
              const SizedBox(height: 16),
              AccountButton(
                _busy ? 'Guardando...' : 'Guardar registro',
                loading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onTap,
    this.onClear,
    this.muted = false,
  });
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool muted;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InputDecorator(
      decoration: accountInput('Fecha').copyWith(
        prefixIcon: const Icon(Icons.calendar_month_outlined),
        suffixIcon: onClear == null
            ? const Icon(Icons.chevron_right_rounded)
            : IconButton(
                tooltip: 'Quitar fecha',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
      child: Text(
        value,
        style: TextStyle(color: muted ? accountMuted : petInk),
      ),
    ),
  );
}

class _LostReportSheet extends StatefulWidget {
  const _LostReportSheet({required this.pet});
  final Map<String, dynamic> pet;

  @override
  State<_LostReportSheet> createState() => _LostReportSheetState();
}

class _LostReportSheetState extends State<_LostReportSheet> {
  final _place = TextEditingController();
  bool _busy = false;
  bool _locating = true;
  double? _latitude;
  double? _longitude;
  double _radius = 5;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!await Geolocator.isLocationServiceEnabled() ||
          (permission != LocationPermission.always &&
              permission != LocationPermission.whileInUse)) {
        throw const ApiError('Escribe el lugar o permite la ubicación.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No obtuvimos el GPS. Puedes escribir el lugar.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    final place = _place.text.trim();
    if (place.isEmpty && _latitude == null) {
      setState(
        () =>
            _error = 'Escribe el lugar donde se perdió o agrega tu ubicación.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().authRequest(
        'POST',
        '/extravios',
        body: {
          'id_mascota': '${widget.pet['id_mascota']}',
          'fecha_perdida': DateTime.now().toUtc().toIso8601String(),
          if (place.isNotEmpty) 'referencia_lugar': place,
          if (_latitude != null && _longitude != null)
            'ubicacion': {'latitud': _latitude, 'longitud': _longitude},
          'radio_km': _radius,
        },
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiError
              ? error.message
              : 'No se pudo enviar la alerta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(22, 12, 22, 20 + petSheetBottomInset(context)),
    child: SingleChildScrollView(
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
          const SizedBox(height: 20),
          Text(
            'Reportar a ${widget.pet['nombre']} como perdida',
            style: const TextStyle(
              color: petInk,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Usaremos este punto para avisar a las personas cercanas.',
            style: TextStyle(color: accountMuted),
          ),
          const SizedBox(height: 20),
          AccountField(
            'Lugar o punto de referencia',
            TextField(
              controller: _place,
              enabled: !_busy,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: accountInput(
                'Barrio, calle o lugar cercano',
                icon: Icons.location_on_outlined,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _busy || _locating ? null : _locate,
            icon: _locating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _latitude == null
                        ? Icons.my_location_rounded
                        : Icons.check_circle_rounded,
                  ),
            label: Text(
              _locating
                  ? 'Obteniendo ubicación...'
                  : _latitude == null
                  ? 'Agregar mi ubicación'
                  : 'Ubicación agregada',
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Avisar en un radio de',
            style: TextStyle(color: petInk, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final radius in const [1.0, 3.0, 5.0, 10.0])
                ChoiceChip(
                  label: Text('${radius.toInt()} km'),
                  selected: _radius == radius,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _radius = radius),
                  selectedColor: const Color(0xFFFFDCC5),
                  side: BorderSide(
                    color: _radius == radius ? petOrange : accountBorder,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            accountError(context, _error!),
          ],
          const SizedBox(height: 18),
          AccountButton(
            _busy ? 'Enviando alerta...' : 'Enviar alerta',
            loading: _busy,
            onPressed: _busy ? null : _submit,
          ),
        ],
      ),
    ),
  );
}

class _TopButton extends StatelessWidget {
  const _TopButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 30),
    style: IconButton.styleFrom(
      fixedSize: const Size.square(52),
      foregroundColor: petInk,
      backgroundColor: Colors.white,
      side: const BorderSide(color: accountBorder, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
    ),
  );
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({super.key, required this.ready, required this.loading});
  final bool ready;
  final bool loading;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: ready ? const Color(0xFF6EDFC8) : accountBorder,
        width: 2,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading && !ready)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: petOrange),
          )
        else
          Icon(
            ready ? Icons.check_rounded : Icons.cloud_off_outlined,
            color: ready ? _mintDark : accountMuted,
            size: 19,
          ),
        const SizedBox(width: 7),
        Text(
          ready ? 'Datos guardados' : 'Sincronizando',
          style: TextStyle(
            color: ready ? _mintDark : accountMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.lost});
  final bool lost;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: lost ? const Color(0xFFFFE3EC) : const Color(0xFFDDF5EE),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: lost ? _pink : const Color(0xFF6EDFC8),
        width: 2,
      ),
    ),
    child: Text(
      lost ? 'Perdida' : 'En casa',
      style: TextStyle(
        color: lost ? const Color(0xFFB71952) : _mintDark,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: _box(),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: accountMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: petInk,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ClinicalCard extends StatelessWidget {
  const _ClinicalCard({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final deworming = item['tipo_registro'] == 'desparasitacion';
    final organization = item['organizacion'] as Map?;
    final applied = DateTime.tryParse('${item['fecha_aplicacion']}');
    final next = DateTime.tryParse('${item['proxima_fecha']}');
    final days = next?.difference(DateTime.now()).inDays;
    final expired = days != null && days < 0;
    final soon = days != null && days >= 0 && days <= 30;
    final status = expired
        ? 'Vencida'
        : soon
        ? 'Pendiente'
        : 'Al día';
    final statusColor = expired || soon ? const Color(0xFF966400) : _mintDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: expired || soon ? const Color(0xFFFFD36B) : _mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.vaccines_outlined,
              color: expired || soon ? const Color(0xFF6D4B00) : _mintDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deworming ? 'Desparasitación' : 'Vacuna',
                  style: const TextStyle(
                    color: petInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${item['descripcion'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: accountMuted, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  organization == null
                      ? 'Registrada por ti${applied == null ? '' : ' · ${_date(applied)}'}'
                      : 'Veterinaria: ${organization['nombre'] ?? 'Certificada'}${applied == null ? '' : ' · ${_date(applied)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: organization == null ? accountMuted : _mintDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (next != null)
                  Text(
                    'Próxima: ${_date(next)}',
                    style: const TextStyle(color: accountMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _LostButton extends StatelessWidget {
  const _LostButton({
    required this.name,
    required this.lost,
    required this.onReport,
    required this.onMatches,
    required this.onResolved,
  });
  final String name;
  final bool lost;
  final VoidCallback? onReport;
  final VoidCallback? onMatches;
  final VoidCallback? onResolved;
  @override
  Widget build(BuildContext context) => lost
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: onMatches,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Revisar posibles coincidencias'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58),
                foregroundColor: petInk,
                backgroundColor: _pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onResolved,
              icon: const Icon(Icons.home_rounded),
              label: Text('Marcar a $name como encontrada'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                foregroundColor: _mintDark,
                side: const BorderSide(color: _mint, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        )
      : Pressable(
          child: FilledButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.warning_amber_rounded),
            label: Text('Reportar a $name como perdida'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(62),
              foregroundColor: petInk,
              backgroundColor: _pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
}

class _MatchesSheet extends StatefulWidget {
  const _MatchesSheet({required this.reportId});
  final String reportId;

  @override
  State<_MatchesSheet> createState() => _MatchesSheetState();
}

class _MatchesSheetState extends State<_MatchesSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<Session>().authRequest(
        'GET',
        '/coincidencias/reportes/${widget.reportId}',
      );
      if (!mounted) return;
      setState(() => _items = _maps((response['data'] as Map?)?['items']));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Map<String, dynamic> item, String status) async {
    final id = '${item['id_coincidencia']}';
    setState(() => _updating.add(id));
    try {
      await context.read<Session>().authRequest(
        'PATCH',
        '/coincidencias/$id/revision',
        body: {'estado_revision': status},
      );
      if (!mounted) return;
      setState(() => item['estado_revision'] = status);
      showPetToast(
        context,
        status == 'confirmada'
            ? 'Coincidencia confirmada. Ya puedes contactar usando el reporte.'
            : 'Coincidencia descartada.',
        type: status == 'confirmada' ? PetToastType.success : PetToastType.info,
      );
    } catch (error) {
      if (mounted) {
        showPetToast(context, _message(error), type: PetToastType.error);
      }
    } finally {
      if (mounted) setState(() => _updating.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    duration: const Duration(milliseconds: 220),
    padding: EdgeInsets.only(bottom: petSheetBottomInset(context)),
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      decoration: const BoxDecoration(
        color: petCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: accountBorder,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Posibles coincidencias',
                style: TextStyle(
                  color: petInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              'El reconocimiento orienta la búsqueda. Confirma personalmente antes de dar por encontrada a tu mascota.',
              style: TextStyle(color: accountMuted, height: 1.35),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: petOrange),
                  )
                : _error != null
                ? Center(
                    child: _MapLikeMessage(message: _error!, onRetry: _load),
                  )
                : _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Todavía no hay avistamientos compatibles. Puedes volver a revisar más tarde.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: accountMuted, height: 1.4),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) => _MatchCard(
                      item: _items[index],
                      busy: _updating.contains(
                        '${_items[index]['id_coincidencia']}',
                      ),
                      onConfirm: () => _review(_items[index], 'confirmada'),
                      onDiscard: () => _review(_items[index], 'descartada'),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.item,
    required this.busy,
    required this.onConfirm,
    required this.onDiscard,
  });
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final sighting = item['avistamiento'] as Map? ?? const {};
    final photos = _maps(sighting['fotos']);
    final rawPhoto =
        photos.firstOrNull?['url_recorte'] ??
        photos.firstOrNull?['url_original'];
    final photo = context.read<PetIdApi>().imageUrl(rawPhoto);
    final score = ((item['puntuacion'] as num?)?.toDouble() ?? 0) * 100;
    final status = '${item['estado_revision'] ?? 'pendiente'}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox.square(
                  dimension: 78,
                  child: photo == null
                      ? const ColoredBox(
                          color: Color(0xFFFFE5D2),
                          child: Icon(Icons.pets_rounded, color: petDarkOrange),
                        )
                      : Image.network(photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${sighting['especie']?['nombre'] ?? 'Mascota avistada'}',
                      style: const TextStyle(
                        color: petInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sighting['referencia_lugar'] ?? 'Ubicación compartida'}',
                      style: const TextStyle(color: accountMuted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${score.round()}% de compatibilidad',
                      style: const TextStyle(
                        color: petDarkOrange,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ('${sighting['descripcion'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${sighting['descripcion']}',
              style: const TextStyle(color: accountMuted, height: 1.35),
            ),
          ],
          const SizedBox(height: 13),
          if (status == 'pendiente')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDiscard,
                    child: const Text('Descartar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onConfirm,
                    child: Text(busy ? 'Guardando...' : 'Confirmar'),
                  ),
                ),
              ],
            )
          else
            Text(
              status == 'confirmada' ? 'Coincidencia confirmada' : 'Descartada',
              style: TextStyle(
                color: status == 'confirmada' ? _mintDark : accountMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _MapLikeMessage extends StatelessWidget {
  const _MapLikeMessage({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: _box(),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: const TextStyle(color: accountMuted)),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

BoxDecoration _box() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: accountBorder, width: 2),
);

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

List<String> _galleryOf(BuildContext context, Map<String, dynamic> pet) {
  final photos = _maps(pet['fotos']);
  photos.sort((a, b) {
    if (a['es_principal'] == b['es_principal']) return 0;
    return a['es_principal'] == true ? -1 : 1;
  });
  return photos
      .map((photo) => photo['url_original'] ?? photo['url_recorte'])
      .map(context.read<PetIdApi>().imageUrl)
      .whereType<String>()
      .toList();
}

String _petId(Object? value) => 'ID PET-${value.toString().padLeft(4, '0')}';

String _registered(Object? value) {
  final date = DateTime.tryParse('$value');
  return date == null
      ? 'Registro sin fecha'
      : 'Registrada ${_date(date.toLocal())}';
}

String _species(Map<String, dynamic> pet) {
  final species = pet['especie']?['nombre']?.toString() ?? 'Sin especificar';
  final female = '${pet['sexo']}'.toLowerCase().startsWith(RegExp(r'[hf]'));
  if (species.toLowerCase() == 'perro' && female) return 'Perra';
  if (species.toLowerCase() == 'gato' && female) return 'Gata';
  return species;
}

String _age(Object? value) {
  final birth = DateTime.tryParse('$value');
  if (birth == null) return 'Sin dato';
  final now = DateTime.now();
  var years = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    years--;
  }
  if (years <= 0) {
    final months = (now.year - birth.year) * 12 + now.month - birth.month;
    return '${months.clamp(0, 11)} meses';
  }
  return '$years ${years == 1 ? 'año' : 'años'}';
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _dateOnly(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _message(Object error) => switch (error) {
  ApiError() => error.message,
  _ => 'No se pudo completar la acción. Inténtalo de nuevo.',
};

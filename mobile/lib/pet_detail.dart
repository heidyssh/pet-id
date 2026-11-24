import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
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
      final responses = await Future.wait([
        session.authRequest('GET', '/mascotas/$_id'),
        session.authRequest('GET', '/historial-clinico/mascotas/$_id'),
      ]);
      final pet = Map<String, dynamic>.from(responses[0]['data'] as Map);
      final historyData = responses[1]['data'] as Map;
      final history = _maps(historyData['items']);
      if (!mounted) return;
      setState(() {
        _pet = pet;
        _history = history;
        _offlineReady = true;
      });
      try {
        await _storage.write(
          key: _cacheKey,
          value: jsonEncode({'pet': pet, 'history': history}),
        );
      } catch (_) {
        if (mounted) setState(() => _offlineReady = false);
      }
    } catch (_) {
      if (mounted && !_offlineReady) {
        setState(() => _error = 'No pudimos actualizar la ficha.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  void _close() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final photo = context.read<PetIdApi>().imageUrl(_photoOf(_pet));
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
              SliverToBoxAdapter(child: _hero(photo)),
              SliverToBoxAdapter(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height - 310,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
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
                      const SizedBox(height: 18),
                      Reveal(order: 2, child: _marks()),
                      const SizedBox(height: 26),
                      Reveal(order: 3, child: _clinical()),
                      const SizedBox(height: 24),
                      Reveal(
                        order: 4,
                        child: _LostButton(
                          name: '${_pet['nombre'] ?? 'esta mascota'}',
                          lost: lost,
                          onPressed: lost ? null : _reportLost,
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

  Widget _hero(String? photo) => SizedBox(
    height: 300,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (photo == null)
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
          Image.network(
            photo,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.pets_rounded, color: petDarkOrange, size: 70),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x55000000), Colors.transparent],
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
        if (items.isEmpty)
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
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: accountInput('Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'vacuna', child: Text('Vacuna')),
                    DropdownMenuItem(
                      value: 'desparasitacion',
                      child: Text('Desparasitación'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _type = value!),
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
    padding: EdgeInsets.fromLTRB(
      22,
      12,
      22,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
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
          ready ? 'Disponible sin conexión' : 'Sincronizando',
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
    required this.onPressed,
  });
  final String name;
  final bool lost;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Pressable(
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(
        lost ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
      ),
      label: Text(
        lost
            ? '$name ya está reportada como perdida'
            : 'Reportar a $name como perdida',
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(62),
        foregroundColor: petInk,
        backgroundColor: lost ? accountBorder : _pink,
        disabledBackgroundColor: accountBorder,
        disabledForegroundColor: accountMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
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

String? _photoOf(Map<String, dynamic> pet) {
  final photos = _maps(pet['fotos']);
  if (photos.isEmpty) return null;
  final main = photos.firstWhere(
    (photo) => photo['es_principal'] == true,
    orElse: () => photos.first,
  );
  return (main['url_recorte'] ?? main['url_original']) as String?;
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

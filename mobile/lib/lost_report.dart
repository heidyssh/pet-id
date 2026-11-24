import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'motion.dart';
import 'welcome.dart';

const _pink = Color(0xFFFF6395);
const _pinkSoft = Color(0xFFFFE5EE);
const _peach = Color(0xFFFFDDC5);

class LostReportPage extends StatefulWidget {
  const LostReportPage({super.key, required this.pet});

  final Map<String, dynamic> pet;

  @override
  State<LostReportPage> createState() => _LostReportPageState();
}

class _LostReportPageState extends State<LostReportPage> {
  static const _fallback = LatLng(15.7835, -86.7918);
  final _map = MapController();
  final _search = TextEditingController();
  final _details = TextEditingController();
  final _searchFocus = FocusNode();

  LatLng _point = _fallback;
  double _radiusKm = 1;
  bool _pointConfirmed = false;
  bool _locating = true;
  bool _searching = false;
  bool _sending = false;
  String? _reference;
  String? _error;
  List<Map<String, dynamic>> _results = const [];
  Timer? _searchTimer;
  Timer? _reverseTimer;

  @override
  void initState() {
    super.initState();
    _search.addListener(_scheduleSearch);
    _searchFocus.addListener(_onSearchFocusChanged);
    _locate();
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _reverseTimer?.cancel();
    _search.removeListener(_scheduleSearch);
    _searchFocus.removeListener(_onSearchFocusChanged);
    _search.dispose();
    _details.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    if (mounted) {
      setState(() {
        _locating = true;
        _error = null;
      });
    }
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!await Geolocator.isLocationServiceEnabled() ||
          (permission != LocationPermission.always &&
              permission != LocationPermission.whileInUse)) {
        throw const ApiError('Activa la ubicación o busca el lugar.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _point = point;
        _pointConfirmed = true;
      });
      _map.move(point, 16);
      await _reverse(point);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No obtuvimos el GPS. Busca el lugar o mueve el mapa.';
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    final query = _search.text.trim();
    if (query.length < 3) {
      if (_results.isNotEmpty) setState(() => _results = const []);
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 450), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _search.text.trim();
    if (query.length < 3) return;
    setState(() => _searching = true);
    try {
      final response = await context.read<PetIdApi>().request(
        'GET',
        '/mapas/geocodificar?direccion=${Uri.encodeQueryComponent(query)}',
      );
      if (!mounted || query != _search.text.trim()) return;
      final data = response['data'] as Map?;
      setState(() => _results = _maps(data?['items']));
    } catch (error) {
      if (mounted) {
        setState(() {
          _results = const [];
          _error = error is ApiError
              ? error.message
              : 'No pudimos buscar ese lugar.';
        });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(Map<String, dynamic> result) {
    final location = result['ubicacion'] as Map?;
    final lat = (location?['latitud'] as num?)?.toDouble();
    final lon = (location?['longitud'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    final point = LatLng(lat, lon);
    setState(() {
      _point = point;
      _pointConfirmed = true;
      _reference = '${result['direccion'] ?? _search.text.trim()}';
      _results = const [];
      _error = null;
    });
    _searchFocus.unfocus();
    _map.move(point, 16);
  }

  void _mapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    setState(() {
      _point = camera.center;
      _pointConfirmed = true;
      _reference = null;
      _results = const [];
      _error = null;
    });
    _reverseTimer?.cancel();
    _reverseTimer = Timer(
      const Duration(milliseconds: 700),
      () => _reverse(camera.center),
    );
  }

  Future<void> _reverse(LatLng point) async {
    try {
      final response = await context.read<PetIdApi>().request(
        'GET',
        '/mapas/geocodificar-reversa?latitud=${point.latitude}&longitud=${point.longitude}',
      );
      if (!mounted || _point != point) return;
      final data = response['data'] as Map?;
      final items = _maps(data?['items']);
      if (items.isNotEmpty) {
        setState(() => _reference = '${items.first['direccion']}');
      }
    } catch (_) {
      // La coordenada sigue siendo válida aunque la dirección no esté disponible.
    }
  }

  Future<void> _submit() async {
    if (!_pointConfirmed) {
      setState(
        () => _error = 'Busca el lugar o mueve el mapa para confirmarlo.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final details = _details.text.trim();
      final baseReference = (_reference ?? _search.text.trim()).trim();
      final reference = [
        if (baseReference.isNotEmpty) baseReference,
        if (details.isNotEmpty) details,
      ].join(' · ');
      await context.read<Session>().authRequest(
        'POST',
        '/extravios',
        body: {
          'id_mascota': '${widget.pet['id_mascota']}',
          'fecha_perdida': DateTime.now().toUtc().toIso8601String(),
          'ubicacion': {
            'latitud': _point.latitude,
            'longitud': _point.longitude,
          },
          if (reference.isNotEmpty)
            'referencia_lugar': reference.length > 500
                ? reference.substring(0, 500)
                : reference,
          'radio_km': _radiusKm,
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiError
              ? error.message
              : 'No se pudo enviar la alerta.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final searchingPlace = _searchFocus.hasFocus;
    return Scaffold(
      backgroundColor: petCream,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(bottom: 420, child: _mapView()),
          SafeArea(child: _mapControls()),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              offset: searchingPlace ? const Offset(0, 1.06) : Offset.zero,
              child: IgnorePointer(
                ignoring: searchingPlace,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: searchingPlace ? 0 : keyboard,
                  ),
                  child: _panel(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapView() => FlutterMap(
    mapController: _map,
    options: MapOptions(
      initialCenter: _point,
      initialZoom: 15,
      minZoom: 6,
      maxZoom: 19,
      onPositionChanged: _mapMoved,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.petid.app',
      ),
      if (_pointConfirmed)
        CircleLayer(
          circles: [
            CircleMarker(
              point: _point,
              radius: _radiusKm * 1000,
              useRadiusInMeter: true,
              color: _pink.withValues(alpha: .14),
              borderColor: _pink,
              borderStrokeWidth: 3,
            ),
          ],
        ),
      const RichAttributionWidget(
        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
      ),
    ],
  );

  Widget _mapControls() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SquareButton(
              icon: Icons.chevron_left_rounded,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accountBorder, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x16000000),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: 'Buscar dirección o lugar',
                        prefixIcon: const Icon(Icons.search_rounded, size: 29),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(15),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 17,
                        ),
                      ),
                    ),
                  ),
                  if (_results.isNotEmpty) _searchResults(),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _pink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 8,
                    offset: Offset(3, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.pets_rounded, color: petInk, size: 30),
            ),
            Positioned(
              bottom: -10,
              child: Transform.rotate(
                angle: .785,
                child: Container(width: 20, height: 20, color: _pink),
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: accountBorder, width: 2),
          ),
          child: Text(
            _locating
                ? 'Buscando tu ubicación...'
                : 'Mueve el mapa para ajustar el punto',
            style: const TextStyle(color: petInk, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 420),
      ],
    ),
  );

  Widget _searchResults() => Container(
    margin: const EdgeInsets.only(top: 5),
    constraints: const BoxConstraints(maxHeight: 220),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24000000),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      shrinkWrap: true,
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final item = _results[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.location_on_outlined, color: _pink),
          title: Text(
            '${item['direccion'] ?? 'Lugar encontrado'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _selectResult(item),
        );
      },
    ),
  );

  Widget _panel() {
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final bottomPadding = systemBottom < 14 ? 14.0 : systemBottom + 8;

    return Container(
      height: 440,
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPadding),
      decoration: const BoxDecoration(
        color: petCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
        boxShadow: [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '¿Dónde se perdió?',
                    style: TextStyle(
                      color: petInk,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _petCard(),
                  const SizedBox(height: 16),
                  const Text(
                    'Avisar a usuarios en un radio de',
                    style: TextStyle(
                      color: petInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      for (final radius in const [0.5, 1.0, 3.0]) ...[
                        Expanded(child: _radiusButton(radius)),
                        if (radius != 3) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Detalles para quien la vea',
                    style: TextStyle(
                      color: petInk,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _details,
                    enabled: !_sending,
                    maxLength: 300,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: accountInput(
                      'Ej.: se asustó con los cohetes, lleva collar rojo',
                    ).copyWith(counterText: ''),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 9),
                    accountError(context, _error!),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Pressable(
            child: FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.notifications_none_rounded),
              label: Text(_sending ? 'Enviando alerta...' : 'Enviar alerta'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: _pink,
                foregroundColor: petInk,
                disabledBackgroundColor: _pinkSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _petCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _pink, width: 2.5),
    ),
    child: Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _peach,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.pets_rounded, color: petDarkOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.pet['nombre'] ?? 'Mascota'}',
                style: const TextStyle(
                  color: petInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _reference ??
                    (_pointConfirmed
                        ? 'Punto seleccionado'
                        : 'Selecciona el lugar'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: accountMuted, fontSize: 13),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _sending ? null : () => _searchFocus.requestFocus(),
          child: const Text('Cambiar'),
        ),
      ],
    ),
  );

  Widget _radiusButton(double radius) {
    final selected = _radiusKm == radius;
    final label = radius < 1 ? '500 m' : '${radius.toInt()} km';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? _pinkSoft : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected ? _pink : accountBorder,
          width: selected ? 2.5 : 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: _sending ? null : () => setState(() => _radiusKm = radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: petInk, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: 30),
    style: IconButton.styleFrom(
      fixedSize: const Size.square(56),
      foregroundColor: petInk,
      backgroundColor: Colors.white,
      side: const BorderSide(color: accountBorder, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

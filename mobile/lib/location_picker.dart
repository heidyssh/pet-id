import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'welcome.dart';

class LocationSelection {
  const LocationSelection({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLabel,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLabel;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _fallback = LatLng(15.7835, -86.7918);
  final _map = MapController();
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _searchTimer;
  Timer? _reverseTimer;
  late LatLng _point;
  String _label = 'Mueve el mapa para elegir el punto';
  bool _loadingLocation = false;
  bool _searching = false;
  List<Map<String, dynamic>> _results = const [];

  @override
  void initState() {
    super.initState();
    final hasInitial =
        widget.initialLatitude != null && widget.initialLongitude != null;
    _point = hasInitial
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : _fallback;
    _label = widget.initialLabel?.trim().isNotEmpty == true
        ? widget.initialLabel!.trim()
        : _label;
    _search.addListener(_scheduleSearch);
    if (!hasInitial) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _reverseTimer?.cancel();
    _search.removeListener(_scheduleSearch);
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _loadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _point = point);
      _map.move(point, 16);
      await _reverse(point);
    } catch (_) {
      // El usuario todavía puede elegir el punto moviendo el mapa.
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _scheduleSearch() {
    _searchTimer?.cancel();
    if (_search.text.trim().length < 3) {
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
        '/mapas/geocodificar?direccion=${Uri.encodeQueryComponent(query)}'
            '&cerca_latitud=${_point.latitude}'
            '&cerca_longitud=${_point.longitude}',
      );
      if (!mounted || query != _search.text.trim()) return;
      setState(() => _results = _maps((response['data'] as Map?)?['items']));
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(Map<String, dynamic> item) {
    final location = item['ubicacion'] as Map?;
    final latitude = (location?['latitud'] as num?)?.toDouble();
    final longitude = (location?['longitud'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;
    final point = LatLng(latitude, longitude);
    setState(() {
      _point = point;
      _label = '${item['direccion'] ?? _search.text.trim()}';
      _results = const [];
    });
    _focus.unfocus();
    _map.move(point, 16);
  }

  void _mapMoved(MapCamera camera, bool gesture) {
    if (!gesture) return;
    setState(() {
      _point = camera.center;
      _label = 'Buscando dirección...';
      _results = const [];
    });
    _reverseTimer?.cancel();
    _reverseTimer = Timer(
      const Duration(milliseconds: 650),
      () => _reverse(camera.center),
    );
  }

  Future<void> _reverse(LatLng point) async {
    try {
      final response = await context.read<PetIdApi>().request(
        'GET',
        '/mapas/geocodificar-reversa?latitud=${point.latitude}'
            '&longitud=${point.longitude}',
      );
      final items = _maps((response['data'] as Map?)?['items']);
      if (!mounted || point != _point || items.isEmpty) return;
      setState(() => _label = '${items.first['direccion']}');
    } catch (_) {
      if (mounted && point == _point) {
        setState(() => _label = 'Punto seleccionado en el mapa');
      }
    }
  }

  void _confirm() => Navigator.pop(
    context,
    LocationSelection(
      latitude: _point.latitude,
      longitude: _point.longitude,
      label: _label == 'Buscando dirección...'
          ? 'Punto seleccionado en el mapa'
          : _label,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: petCream,
    body: Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _point,
              initialZoom: 16,
              minZoom: 6,
              maxZoom: 19,
              onPositionChanged: _mapMoved,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.petid.app',
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 42),
            child: Icon(
              Icons.location_on_rounded,
              color: Color(0xFFFF6395),
              size: 58,
              shadows: [Shadow(color: Color(0x55000000), blurRadius: 6)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: petInk,
                    fixedSize: const Size.square(52),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 30),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: TextField(
                          controller: _search,
                          focusNode: _focus,
                          onSubmitted: (_) => _runSearch(),
                          decoration: InputDecoration(
                            hintText: 'Buscar dirección o lugar',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searching
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _results.isEmpty
                            ? const SizedBox.shrink()
                            : Container(
                                key: const ValueKey('search-results'),
                                constraints: const BoxConstraints(
                                  maxHeight: 220,
                                ),
                                margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 18,
                                      offset: Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        14,
                                        11,
                                        14,
                                        5,
                                      ),
                                      child: Text(
                                        'LUGARES CERCA DEL MAPA',
                                        style: TextStyle(
                                          color: accountMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .7,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.only(
                                          bottom: 5,
                                        ),
                                        itemCount: _results.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(height: 1),
                                        itemBuilder: (_, index) => ListTile(
                                          leading: const Icon(
                                            Icons.location_on_outlined,
                                            color: petDarkOrange,
                                          ),
                                          title: Text(
                                            '${_results[index]['direccion'] ?? 'Lugar encontrado'}',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onTap: () =>
                                              _selectResult(_results[index]),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: petCream,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: petDarkOrange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadingLocation
                              ? 'Obteniendo tu ubicación...'
                              : _label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: petInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Usar mi ubicación',
                        onPressed: _loadingLocation ? null : _locate,
                        icon: const Icon(Icons.my_location_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Confirmar ubicación'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: petDarkOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

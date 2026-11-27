import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'entry_forms.dart';
import 'motion.dart';
import 'welcome.dart';

const _pink = Color(0xFFFF6395);
const _yellow = Color(0xFFFFCF62);

enum _Filter { all, lost, sighted }

enum _LoadState { loading, ready, noLocation, error }

class NearbyMapPage extends StatefulWidget {
  const NearbyMapPage({
    super.key,
    this.ownPetIds = const <String>{},
    this.ownPetsLoaded = true,
    this.onOpenOwnPet,
  });

  final Set<String> ownPetIds;
  final bool ownPetsLoaded;
  final Future<void> Function(Map<String, dynamic> pet)? onOpenOwnPet;

  @override
  State<NearbyMapPage> createState() => _NearbyMapPageState();
}

class _NearbyMapPageState extends State<NearbyMapPage>
    with AutomaticKeepAliveClientMixin {
  static const _fallback = LatLng(15.7835, -86.7918);
  final _map = MapController();
  _LoadState _state = _LoadState.loading;
  _Filter _filter = _Filter.all;
  LatLng? _userPoint;
  List<Map<String, dynamic>> _lost = const [];
  List<Map<String, dynamic>> _sighted = const [];
  String? _selected;

  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> get _items {
    final values = switch (_filter) {
      _Filter.all => [..._lost, ..._sighted],
      _Filter.lost => [..._lost],
      _Filter.sighted => [..._sighted],
    };
    values.sort(
      (a, b) => (_apiDouble(a['distancia_km']) ?? 999).compareTo(
        _apiDouble(b['distancia_km']) ?? 999,
      ),
    );
    return values;
  }

  @override
  void initState() {
    super.initState();
    _load(askPermission: false);
  }

  Future<void> _load({required bool askPermission}) async {
    setState(() => _state = _LoadState.loading);
    try {
      final point = await _resolveMapPoint(askPermission: askPermission);
      if (point == null) {
        if (mounted) setState(() => _state = _LoadState.noLocation);
        return;
      }
      if (!mounted) return;
      final api = context.read<PetIdApi>();
      final query =
          'latitud=${point.latitude}&longitud=${point.longitude}'
          '&radio_km=10&limite=50';
      final responses = await Future.wait([
        api.request('GET', '/extravios/cercanos?$query'),
        api.request('GET', '/avistamientos/cercanos?$query'),
      ]);
      if (!mounted) return;
      setState(() {
        _userPoint = point;
        _lost = _maps((responses[0]['data'] as Map?)?['items']);
        _sighted = _maps((responses[1]['data'] as Map?)?['items']);
        _state = _LoadState.ready;
      });
      _map.move(point, 14.5);
    } on TimeoutException {
      if (mounted) setState(() => _state = _LoadState.error);
    } catch (_) {
      if (mounted) setState(() => _state = _LoadState.error);
    }
  }

  Future<LatLng?> _resolveMapPoint({required bool askPermission}) async {
    final session = context.read<Session>();
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied && askPermission) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15),
            ),
          );
          unawaited(
            session.saveLastMapLocation(position.latitude, position.longitude),
          );
          return LatLng(position.latitude, position.longitude);
        }
      }
    } catch (_) {
      // Si el GPS falla, se intenta usar la ubicación guardada.
    }

    try {
      final response = await session.authRequest(
        'GET',
        '/notificaciones/ubicacion-alertas',
      );
      final data = response['data'] as Map?;
      final location = data?['ubicacion'] as Map?;
      final latitude = _apiDouble(location?['latitud']);
      final longitude = _apiDouble(location?['longitud']);
      if (latitude != null && longitude != null) {
        unawaited(session.saveLastMapLocation(latitude, longitude));
        return LatLng(latitude, longitude);
      }
    } catch (_) {
      // Solo se pide ubicación otra vez si tampoco hay una guardada.
    }
    final saved = await session.readLastMapLocation();
    final latitude = saved?['latitud'];
    final longitude = saved?['longitud'];
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
  }

  void _select(Map<String, dynamic> item) {
    setState(() => _selected = _keyOf(item));
    final point = _pointOf(item);
    if (point != null) _map.move(point, 16);
  }

  Future<void> _openAlert(Map<String, dynamic> item) async {
    _select(item);
    final sighted = item['tipo_alerta'] == 'avistado';
    final ownPet =
        !sighted && widget.ownPetIds.contains('${item['id_mascota']}');
    final ownershipReady = sighted || widget.ownPetsLoaded;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AlertDetailSheet(
        item: item,
        ownPet: ownPet,
        onOpenOwnPet: ownPet && widget.onOpenOwnPet != null
            ? () async {
                Navigator.pop(sheetContext);
                await widget.onOpenOwnPet!(item);
                if (mounted) await _load(askPermission: false);
              }
            : null,
        onReportSighting: sighted || ownPet || !ownershipReady
            ? null
            : () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SightingForm(
                      signedIn: true,
                      startWithCamera: true,
                      suggestedLostReport: item,
                    ),
                  ),
                );
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (_, constraints) {
        final collapsedPanel = constraints.maxHeight * .24;
        return Stack(
          children: [
            Positioned.fill(child: _mapView()),
            Positioned(left: 20, top: 18, child: _title()),
            Positioned(left: 20, right: 20, top: 88, child: _filters()),
            Positioned(
              right: 18,
              bottom: collapsedPanel + 12,
              child: FloatingActionButton.small(
                heroTag: 'nearby-location',
                backgroundColor: Colors.white,
                foregroundColor: petDarkOrange,
                onPressed: _state == _LoadState.loading
                    ? null
                    : () {
                        if (_userPoint case final point?) {
                          _map.move(point, 15);
                        } else {
                          _load(askPermission: true);
                        }
                      },
                child: _state == _LoadState.loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
              ),
            ),
            DraggableScrollableSheet(
              minChildSize: .24,
              initialChildSize: .45,
              maxChildSize: .82,
              snap: true,
              snapSizes: const [.24, .45, .82],
              builder: (_, scrollController) => _panel(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _mapView() => FlutterMap(
    mapController: _map,
    options: const MapOptions(
      initialCenter: _fallback,
      initialZoom: 12,
      minZoom: 6,
      maxZoom: 19,
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.petid.app',
      ),
      MarkerLayer(markers: _markers()),
      const RichAttributionWidget(
        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
      ),
    ],
  );

  List<Marker> _markers() {
    final result = <Marker>[];
    if (_userPoint case final point?) {
      result.add(
        Marker(point: point, width: 52, height: 52, child: const _UserMarker()),
      );
    }
    for (final item in _items) {
      final point = _pointOf(item);
      if (point == null) continue;
      final sighted = item['tipo_alerta'] == 'avistado';
      result.add(
        Marker(
          point: point,
          width: 62,
          height: 72,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _select(item),
            child: _PetMarker(
              color: sighted ? _yellow : _pink,
              selected: _selected == _keyOf(item),
            ),
          ),
        ),
      );
    }
    return result;
  }

  Widget _title() => _FloatingBox(
    child: const Text(
      'Alertas cerca de ti',
      style: TextStyle(
        color: petInk,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _filters() => Row(
    children: [
      Expanded(child: _filterButton(_Filter.all, 'Todas', petInk)),
      const SizedBox(width: 7),
      Expanded(child: _filterButton(_Filter.lost, 'Perdidas', _pink)),
      const SizedBox(width: 7),
      Expanded(child: _filterButton(_Filter.sighted, 'Vistas', _yellow)),
    ],
  );

  Widget _filterButton(_Filter value, String label, Color color) {
    final active = _filter == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: active && value == _Filter.all ? petInk : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: active ? color : Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => setState(() {
          _filter = value;
          _selected = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (value != _Filter.all) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active && value == _Filter.all
                        ? Colors.white
                        : petInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panel(ScrollController scrollController) => Container(
    decoration: const BoxDecoration(
      color: petCream,
      borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      boxShadow: [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 20,
          offset: Offset(0, -5),
        ),
      ],
    ),
    child: ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                _state == _LoadState.ready
                    ? '${_items.length} ${_items.length == 1 ? 'alerta' : 'alertas'} en 10 km · actualizado ahora'
                    : 'Buscando alertas cercanas',
                style: const TextStyle(
                  color: accountMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_state == _LoadState.ready)
              IconButton(
                tooltip: 'Actualizar',
                onPressed: () => _load(askPermission: false),
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_state == _LoadState.ready) ...[
          const _MapLegend(),
          const SizedBox(height: 12),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _panelBody(),
        ),
      ],
    ),
  );

  Widget _panelBody() => switch (_state) {
    _LoadState.loading => const SizedBox(
      height: 250,
      child: _MapLoading(key: ValueKey('loading')),
    ),
    _LoadState.noLocation => SizedBox(
      height: 210,
      child: _MapMessage(
        key: const ValueKey('location'),
        icon: Icons.location_off_outlined,
        message:
            'Activa y permite la ubicación para mostrar alertas realmente cercanas.',
        action: 'Usar mi ubicación',
        onAction: () => _load(askPermission: true),
      ),
    ),
    _LoadState.error => SizedBox(
      height: 210,
      child: _MapMessage(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_outlined,
        message: 'No pudimos actualizar el mapa en este momento.',
        action: 'Reintentar',
        onAction: () => _load(askPermission: false),
      ),
    ),
    _LoadState.ready when _items.isEmpty => const SizedBox(
      height: 210,
      child: _MapMessage(
        key: ValueKey('empty'),
        icon: Icons.pets_outlined,
        message: 'No hay alertas de este tipo cerca de ti.',
      ),
    ),
    _LoadState.ready => Column(
      key: ValueKey(_filter),
      children: [
        for (var index = 0; index < _items.length; index++) ...[
          Reveal(
            order: index,
            child: _AlertCard(
              item: _items[index],
              selected: _selected == _keyOf(_items[index]),
              onTap: () => _openAlert(_items[index]),
            ),
          ),
          if (index != _items.length - 1) const SizedBox(height: 10),
        ],
      ],
    ),
  };
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sighted = item['tipo_alerta'] == 'avistado';
    final color = sighted ? _yellow : _pink;
    final photo = context.read<PetIdApi>().imageUrl(item['foto']);
    final title = sighted
        ? 'Mascota avistada'
        : [
            item['nombre_mascota'],
            item['raza'] ?? item['especie'],
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    final place = [
      sighted ? 'Avistamiento sin identificar' : 'Perdida',
      item['referencia_lugar'],
      _distance(item['distancia_km']),
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? color : accountBorder,
          width: selected ? 3 : 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox.square(
                  dimension: 64,
                  child: photo == null
                      ? _PhotoFallback(color: color)
                      : Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _PhotoFallback(color: color),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Mascota sin identificar' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: petInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: accountMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _ago(item[sighted ? 'fecha_avistamiento' : 'fecha_reporte']),
                  style: const TextStyle(
                    color: petInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: accountBorder),
    ),
    child: const Row(
      children: [
        _LegendItem(color: _pink, label: 'Familias buscando'),
        SizedBox(width: 14),
        _LegendItem(color: _yellow, label: 'Mascotas vistas'),
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: accountMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AlertDetailSheet extends StatelessWidget {
  const _AlertDetailSheet({
    required this.item,
    required this.ownPet,
    this.onReportSighting,
    this.onOpenOwnPet,
  });
  final Map<String, dynamic> item;
  final bool ownPet;
  final VoidCallback? onReportSighting;
  final VoidCallback? onOpenOwnPet;

  @override
  Widget build(BuildContext context) {
    final sighted = item['tipo_alerta'] == 'avistado';
    final photo = context.read<PetIdApi>().imageUrl(item['foto']);
    final title = sighted
        ? 'Mascota avistada'
        : [
            item['nombre_mascota'],
            item['raza'] ?? item['especie'],
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.only(bottom: petSheetBottomInset(context)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: petCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: photo == null
                      ? _PhotoFallback(color: sighted ? _yellow : _pink)
                      : Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _PhotoFallback(color: sighted ? _yellow : _pink),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: (sighted ? _yellow : _pink).withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    sighted
                        ? 'REPORTE DE AVISTAMIENTO'
                        : 'ALERTA DE MASCOTA PERDIDA',
                    style: const TextStyle(
                      color: petInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title.isEmpty ? 'Mascota sin identificar' : title,
                style: const TextStyle(
                  color: petInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  sighted
                      ? 'Alguien vio este animal; todavía no se sabe a qué familia pertenece'
                      : 'Es una mascota identificada y su familia la está buscando',
                  item['referencia_lugar'],
                  _distance(item['distancia_km']),
                ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
                style: const TextStyle(color: accountMuted, height: 1.35),
              ),
              if ('${item['senas_particulares'] ?? item['descripcion'] ?? ''}'
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '${item['senas_particulares'] ?? item['descripcion']}',
                  style: const TextStyle(color: accountMuted, height: 1.4),
                ),
              ],
              if (onReportSighting != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onReportSighting,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    '${item['nombre_mascota'] ?? ''}'.toString().trim().isEmpty
                        ? 'Creo que vi a esta mascota'
                        : 'Creo que vi a ${item['nombre_mascota']}',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    backgroundColor: petOrange,
                    foregroundColor: petInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
              if (ownPet) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF5EE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Esta alerta pertenece a tu mascota. No puedes reportar un avistamiento contra tu propia alerta. Si ya regresó, abre su ficha y márcala como encontrada.',
                    style: TextStyle(
                      color: Color(0xFF176D61),
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onOpenOwnPet,
                  icon: const Icon(Icons.pets_rounded),
                  label: const Text('Abrir ficha de mi mascota'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    backgroundColor: const Color(0xFF0ACAA5),
                    foregroundColor: petInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingBox extends StatelessWidget {
  const _FloatingBox({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
    decoration: BoxDecoration(
      color: petCream,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: accountBorder, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _PetMarker extends StatelessWidget {
  const _PetMarker({required this.color, required this.selected});
  final Color color;
  final bool selected;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    duration: const Duration(milliseconds: 180),
    scale: selected ? 1.18 : 1,
    child: Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.location_on_rounded,
          color: color,
          size: 61,
          shadows: const [
            Shadow(
              color: Color(0x55000000),
              blurRadius: 4,
              offset: Offset(3, 4),
            ),
          ],
        ),
        const Positioned(
          top: 12,
          child: Icon(Icons.pets_rounded, color: petInk, size: 22),
        ),
      ],
    ),
  );
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0x553C91F5),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
    padding: const EdgeInsets.all(10),
    child: const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFF4C97F2),
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _MapLoading extends StatelessWidget {
  const _MapLoading({super.key});
  @override
  Widget build(BuildContext context) => Shimmer(
    child: Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          if (index != 2) const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({
    super.key,
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: petDarkOrange, size: 36),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: accountMuted, height: 1.35),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color.withValues(alpha: .2),
    child: Icon(Icons.pets_rounded, color: petInk.withValues(alpha: .7)),
  );
}

LatLng? _pointOf(Map<String, dynamic> item) {
  final lat = _apiDouble(item['latitud_aproximada']);
  final lon = _apiDouble(item['longitud_aproximada']);
  return lat == null || lon == null ? null : LatLng(lat, lon);
}

String _keyOf(Map<String, dynamic> item) => item['tipo_alerta'] == 'avistado'
    ? 'a:${item['id_avistamiento']}'
    : 'p:${item['id_reporte']}';

String? _distance(Object? value) {
  final distance = _apiDouble(value);
  if (distance == null) return null;
  return distance < 1
      ? '${(distance * 1000).round()} m'
      : '${distance.toStringAsFixed(1)} km';
}

double? _apiDouble(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value),
  _ => null,
};

String _ago(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '';
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Ahora';
  if (difference.inHours < 1) return '${difference.inMinutes} min';
  if (difference.inDays < 1) return '${difference.inHours} h';
  return '${difference.inDays} d';
}

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

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
const _yellow = Color(0xFFFFCF62);

enum _Filter { all, lost, sighted }

enum _LoadState { loading, ready, noLocation, error }

class NearbyMapPage extends StatefulWidget {
  const NearbyMapPage({super.key});

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
      (a, b) => ((a['distancia_km'] as num?) ?? 999).compareTo(
        (b['distancia_km'] as num?) ?? 999,
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
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _state = _LoadState.noLocation);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _state = _LoadState.noLocation);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
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

  void _select(Map<String, dynamic> item) {
    setState(() => _selected = _keyOf(item));
    final point = _pointOf(item);
    if (point != null) _map.move(point, 16);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (_, constraints) {
        final panelHeight = (constraints.maxHeight * .45).clamp(310.0, 430.0);
        return Stack(
          children: [
            Positioned.fill(bottom: panelHeight - 24, child: _mapView()),
            Positioned(left: 20, top: 18, child: _title()),
            Positioned(left: 20, right: 20, top: 88, child: _filters()),
            Positioned(
              right: 18,
              bottom: panelHeight + 12,
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
            Align(
              alignment: Alignment.bottomCenter,
              child: _panel(panelHeight),
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
      Expanded(child: _filterButton(_Filter.sighted, 'Avistadas', _yellow)),
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

  Widget _panel(double height) => Container(
    height: height,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
    child: Column(
      children: [
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: accountBorder,
            borderRadius: BorderRadius.circular(99),
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
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _panelBody(),
          ),
        ),
      ],
    ),
  );

  Widget _panelBody() => switch (_state) {
    _LoadState.loading => const _MapLoading(key: ValueKey('loading')),
    _LoadState.noLocation => _MapMessage(
      key: const ValueKey('location'),
      icon: Icons.location_off_outlined,
      message:
          'Activa y permite la ubicación para mostrar alertas realmente cercanas.',
      action: 'Usar mi ubicación',
      onAction: () => _load(askPermission: true),
    ),
    _LoadState.error => _MapMessage(
      key: const ValueKey('error'),
      icon: Icons.cloud_off_outlined,
      message: 'No pudimos actualizar el mapa en este momento.',
      action: 'Reintentar',
      onAction: () => _load(askPermission: false),
    ),
    _LoadState.ready when _items.isEmpty => const _MapMessage(
      key: ValueKey('empty'),
      icon: Icons.pets_outlined,
      message: 'No hay alertas de este tipo cerca de ti.',
    ),
    _LoadState.ready => ListView.separated(
      key: ValueKey(_filter),
      physics: const BouncingScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final item = _items[index];
        return Reveal(
          order: index,
          child: _AlertCard(
            item: item,
            selected: _selected == _keyOf(item),
            onTap: () => _select(item),
          ),
        );
      },
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
        ? [
            item['especie'],
            item['color_principal'],
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · ')
        : [
            item['nombre_mascota'],
            item['raza'] ?? item['especie'],
          ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    final place = [
      sighted ? 'Avistada' : 'Perdida',
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
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
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
  final lat = (item['latitud_aproximada'] as num?)?.toDouble();
  final lon = (item['longitud_aproximada'] as num?)?.toDouble();
  return lat == null || lon == null ? null : LatLng(lat, lon);
}

String _keyOf(Map<String, dynamic> item) => item['tipo_alerta'] == 'avistado'
    ? 'a:${item['id_avistamiento']}'
    : 'p:${item['id_reporte']}';

String? _distance(Object? value) {
  final distance = (value as num?)?.toDouble();
  if (distance == null) return null;
  return distance < 1
      ? '${(distance * 1000).round()} m'
      : '${distance.toStringAsFixed(1)} km';
}

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

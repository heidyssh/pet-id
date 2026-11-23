import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'account_layout.dart';
import 'api.dart';
import 'entry_forms.dart';
import 'motion.dart';
import 'nearby_map.dart';
import 'pet_detail.dart';
import 'pet_registration.dart';
import 'welcome.dart';

const _pink = Color(0xFFFF6B98);
const _pinkDark = Color(0xFFD93A6E);
const _pinkShadow = Color(0xFFE0457A);
const _peach = Color(0xFFFDE1D1);
const _yellow = Color(0xFFFFE08A);
const _mint = Color(0xFFBDEFD8);
const _lilac = Color(0xFFE7DDFB);
const _purple = Color(0xFF7B5CC4);
const _muted = Color(0xFF8A9497);

/// Pantalla principal del ciudadano, con la barra inferior de navegación.
class CitizenHome extends StatefulWidget {
  const CitizenHome({super.key, required this.name});
  final String name;

  @override
  State<CitizenHome> createState() => _CitizenHomeState();
}

class _CitizenHomeState extends State<CitizenHome> {
  int _tab = 0;
  List<Map<String, dynamic>> _pets = const [];
  bool _petsLoading = true;
  String? _petsError;
  int _unread = 0;
  List<Map<String, dynamic>> _nearby = const [];
  _NearbyState _nearbyState = _NearbyState.loading;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => Future.wait([
    _loadPets(),
    _loadUnread(),
    _loadNearby(askPermission: false),
  ]);

  Future<void> _loadPets() async {
    setState(() {
      _petsLoading = true;
      _petsError = null;
    });
    try {
      final data = (await context.read<Session>().authRequest(
        'GET',
        '/mascotas/mias?limite=20',
      ))['data'];
      if (!mounted) return;
      setState(() => _pets = _list(data['mascotas']));
    } catch (_) {
      if (mounted) setState(() => _petsError = 'No se pudieron cargar.');
    } finally {
      if (mounted) setState(() => _petsLoading = false);
    }
  }

  Future<void> _loadUnread() async {
    try {
      final data = (await context.read<Session>().authRequest(
        'GET',
        '/notificaciones?solo_no_leidas=true&limite=1',
      ))['data'];
      if (!mounted) return;
      setState(
        () => _unread = (data['paginacion']?['total'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      // El número de avisos es secundario: si falla, no se muestra.
    }
  }

  Future<void> _loadNearby({required bool askPermission}) async {
    setState(() => _nearbyState = _NearbyState.loading);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _nearbyState = _NearbyState.noLocation);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _nearbyState = _NearbyState.noLocation);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final data = (await context.read<PetIdApi>().request(
        'GET',
        '/extravios/cercanos?latitud=${position.latitude}'
            '&longitud=${position.longitude}&radio_km=10&limite=5',
      ))['data'];
      if (!mounted) return;
      setState(() {
        _nearby = _list(data['items']);
        _nearbyState = _NearbyState.ready;
      });
    } catch (_) {
      if (mounted) setState(() => _nearbyState = _NearbyState.error);
    }
  }

  void _soon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature estará disponible pronto.')),
      );
  }

  Future<void> _openSighting() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            const SightingForm(signedIn: true, startWithCamera: true),
      ),
    );
    if (created == true && mounted) unawaited(_refresh());
  }

  Future<void> _openPet(Map<String, dynamic> pet) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => PetDetailPage(initialPet: pet)),
    );
    if (mounted) unawaited(_loadPets());
  }

  Future<void> _openPetRegistration() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const PetRegistrationPage()),
    );
    if (created == true && mounted) unawaited(_loadPets());
  }

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: petCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _NotificationsSheet(),
    );
    if (mounted) unawaited(_loadUnread());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _homePage(),
      const NearbyMapPage(),
      _petsPage(),
      _ProfilePage(name: widget.name),
    ];
    return Scaffold(
      backgroundColor: petCream,
      body: SafeArea(
        // Al cambiar de pestaña, la nueva aparece con un fundido suave.
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_tab),
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: IndexedStack(index: _tab, children: pages),
          builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 14),
              child: child,
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        onTap: (index) => setState(() => _tab = index),
      ),
    );
  }

  Widget _homePage() => RefreshIndicator(
    color: petOrange,
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Reveal(child: _header()),
        const SizedBox(height: 22),
        Reveal(
          order: 1,
          child: _LostPetCard(
            onTap: () => _soon('El reporte de mascota perdida'),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          order: 2,
          child: Row(
            children: [
              Expanded(
                child: _ActionCard(
                  color: _yellow,
                  icon: Icons.photo_camera_outlined,
                  label: 'Encontré una mascota',
                  onTap: _openSighting,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ActionCard(
                  color: _mint,
                  icon: Icons.add_rounded,
                  label: 'Registrar mascota',
                  onTap: _openPetRegistration,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Reveal(
          order: 3,
          child: _SectionTitle(
            'Mis mascotas',
            action: 'Ver todas',
            onAction: () => setState(() => _tab = 2),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(order: 4, child: _swap(_petsPreview())),
        const SizedBox(height: 26),
        Reveal(
          order: 5,
          child: _SectionTitle(
            'Perdidos cerca de ti',
            action: 'Ver mapa',
            onAction: () => setState(() => _tab = 1),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(order: 6, child: _swap(_nearbySection())),
      ],
    ),
  );

  /// Cambia con un fundido entre "cargando", "vacío" y los datos.
  Widget _swap(Widget child) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    child: KeyedSubtree(key: ValueKey(child.runtimeType), child: child),
  );

  Widget _header() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos días,'
        : hour < 19
        ? 'Buenas tardes,'
        : 'Buenas noches,';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                  const SizedBox(width: 6),
                  const Wiggle(
                    angle: 0.45,
                    every: Duration(milliseconds: 4000),
                    child: Icon(Icons.pets_rounded, color: petOrange, size: 17),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.name.isEmpty ? 'Bienvenido' : widget.name,
                style: const TextStyle(
                  color: petInk,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _BellButton(count: _unread, onTap: _openNotifications),
      ],
    );
  }

  Widget _petsPreview() {
    if (_petsLoading && _pets.isEmpty) return const _LoadingCard();
    if (_petsError != null && _pets.isEmpty) {
      return _MessageCard(
        text: _petsError!,
        action: 'Reintentar',
        onAction: _loadPets,
      );
    }
    if (_pets.isEmpty) {
      return _MessageCard(
        text: 'Todavía no registras mascotas.',
        action: 'Registrar',
        onAction: _openPetRegistration,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(
            child: i < _pets.length
                ? Reveal(
                    order: i,
                    child: _PetCard(
                      pet: _pets[i],
                      index: i,
                      onTap: () => _openPet(_pets[i]),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _nearbySection() => switch (_nearbyState) {
    _NearbyState.loading => const _LoadingCard(),
    _NearbyState.noLocation => _MessageCard(
      text: 'Activa tu ubicación para ver mascotas perdidas cerca de ti.',
      action: 'Activar',
      onAction: () => _loadNearby(askPermission: true),
    ),
    _NearbyState.error => _MessageCard(
      text: 'No se pudieron cargar los reportes cercanos.',
      action: 'Reintentar',
      onAction: () => _loadNearby(askPermission: false),
    ),
    _NearbyState.ready when _nearby.isEmpty => const _MessageCard(
      text: 'No hay mascotas perdidas reportadas cerca de ti.',
    ),
    _NearbyState.ready => Column(
      children: [
        for (var i = 0; i < _nearby.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Reveal(
              order: i,
              child: _NearbyCard(item: _nearby[i]),
            ),
          ),
      ],
    ),
  };

  Widget _petsPage() => RefreshIndicator(
    color: petOrange,
    onRefresh: _loadPets,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Mis mascotas',
          style: TextStyle(
            color: petInk,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        if (_petsLoading && _pets.isEmpty)
          const _LoadingCard()
        else if (_pets.isEmpty)
          _MessageCard(
            text: _petsError ?? 'Todavía no registras mascotas.',
            action: _petsError == null ? null : 'Reintentar',
            onAction: _petsError == null ? null : _loadPets,
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.95,
            children: [
              for (var i = 0; i < _pets.length; i++)
                Reveal(
                  order: i,
                  child: _PetCard(
                    pet: _pets[i],
                    index: i,
                    onTap: () => _openPet(_pets[i]),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

enum _NearbyState { loading, noLocation, error, ready }

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

String? _photoOf(Map<String, dynamic> pet) {
  final photos = _list(pet['fotos']);
  if (photos.isEmpty) return null;
  final main = photos.firstWhere(
    (photo) => photo['es_principal'] == true,
    orElse: () => photos.first,
  );
  return (main['url_recorte'] ?? main['url_original']) as String?;
}

String _speciesLabel(Map<String, dynamic> pet) {
  final species = (pet['especie']?['nombre'] as String?) ?? '';
  final sex = (pet['sexo'] as String?)?.toLowerCase() ?? '';
  final female = sex.startsWith('h') || sex.startsWith('f');
  final label = switch ((species, female)) {
    ('Perro', true) => 'Perra',
    ('Gato', true) => 'Gata',
    _ => species,
  };
  final breed = pet['raza']?['nombre'] as String?;
  return [
    label,
    breed,
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
}

String _distance(Object? km) {
  final value = double.tryParse('$km');
  if (value == null) return '';
  if (value < 1) return 'a ${(value * 1000).round()} m';
  return 'a ${value.toStringAsFixed(1)} km';
}

String _ago(Object? date) {
  final parsed = DateTime.tryParse('$date');
  if (parsed == null) return '';
  final diff = DateTime.now().difference(parsed.toLocal());
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
  return 'Hace ${diff.inDays} d';
}

/// Reportado en las últimas 24 horas.
bool _isRecent(Object? date) {
  final parsed = DateTime.tryParse('$date');
  return parsed != null &&
      DateTime.now().difference(parsed.toLocal()) < const Duration(days: 1);
}

BoxDecoration _cardDecoration({
  Color color = Colors.white,
  Color edge = _peach,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: edge, width: 2),
  boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 4))],
);

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: count > 0 ? 'Notificaciones, $count sin leer' : 'Notificaciones',
    child: GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Pressable(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: _cardDecoration(),
              // La campana se mueve sola si hay avisos sin leer.
              child: Wiggle(
                active: count > 0,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: petInk,
                ),
              ),
            ),
            Positioned(
              right: -4,
              top: -4,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                    reverseCurve: Curves.easeIn,
                  ),
                  child: child,
                ),
                child: count <= 0
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(count),
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _pink,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: petCream, width: 2),
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LostPetCard extends StatelessWidget {
  const _LostPetCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    child: Sheen(
      radius: 26,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(26),
          splashColor: Colors.white24,
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF7BA4), _pink],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(color: _pinkShadow, offset: Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Breathing(
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: _pinkDark,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reportar mascota perdida',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Avisamos a los vecinos de tu zona',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        splashColor: color.withValues(alpha: 0.5),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: petInk, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: const TextStyle(
                  color: petInk,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
    this.title, {
    required this.action,
    required this.onAction,
  });
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: petInk,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      TextButton(
        onPressed: onAction,
        style: TextButton.styleFrom(
          foregroundColor: petDarkOrange,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(
          action,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: petDarkOrange,
          ),
        ),
      ),
    ],
  );
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet, required this.index, required this.onTap});
  final Map<String, dynamic> pet;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = index.isEven
        ? (_peach, petOrange)
        : (_lilac, _purple);
    final photo = context.read<PetIdApi>().imageUrl(_photoOf(pet));
    return Pressable(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: background,
                    child: photo == null
                        ? Icon(Icons.pets_rounded, color: foreground, size: 28)
                        : Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.pets_rounded,
                              color: foreground,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${pet['nombre'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: petInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _speciesLabel(pet),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: accountMuted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final photo = context.read<PetIdApi>().imageUrl(item['foto']);
    final title = [
      item['nombre_mascota'],
      item['raza'] ?? item['especie'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final place = [
      item['referencia_lugar'],
      _distance(item['distancia_km']),
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final ago = _ago(item['fecha_reporte']);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 72,
              height: 72,
              child: photo == null
                  ? const _PhotoPlaceholder()
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: petInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  place,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: accountMuted, fontSize: 13),
                ),
                if (ago.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE3EC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRecent(item['fecha_reporte'])) ...[
                          const PulseDot(color: _pinkDark),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          ago,
                          style: const TextStyle(
                            color: _pinkDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedBorder(),
    child: const Center(
      child: Text(
        'Foto',
        style: TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5C4A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(16),
        ).deflate(1),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return Semantics(
      label: 'Cargando',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Shimmer(
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(140, 14),
                    const SizedBox(height: 10),
                    bar(double.infinity, 11),
                    const SizedBox(height: 8),
                    bar(70, 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: accountMuted, fontSize: 14),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: petDarkOrange),
            child: Text(
              action!,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.location_on_outlined, 'Mapa'),
    (Icons.pets_rounded, 'Mascotas'),
    (Icons.person_outline_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _peach, width: 2)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  child: InkWell(
                    onTap: () {
                      if (i != index) HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Una píldora durazno se desliza a la pestaña activa.
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutBack,
                          padding: EdgeInsets.symmetric(
                            horizontal: i == index ? 18 : 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: i == index ? _peach : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AnimatedScale(
                            scale: i == index ? 1.12 : 1,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutBack,
                            child: Icon(
                              _items[i].$1,
                              color: i == index ? petOrange : _muted,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: i == index ? petOrange : _muted,
                            fontSize: 12,
                            fontWeight: i == index
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                          child: Text(_items[i].$2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.name});
  final String name;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await context.read<Session>().logout();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cerrar la sesión. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user ?? const {};
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Perfil',
          style: TextStyle(
            color: petInk,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _peach,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: petOrange,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: petInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (user['correo'] case final String email)
                      Text(email, style: const TextStyle(color: accountMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AccountButton(
          _loggingOut ? 'Cerrando sesión...' : 'Cerrar sesión',
          loading: _loggingOut,
          onPressed: _loggingOut ? null : _logout,
        ),
      ],
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = (await context.read<Session>().authRequest(
        'GET',
        '/notificaciones?limite=30',
      ))['data'];
      if (mounted) setState(() => _items = _list(data['items']));
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los avisos.');
    }
  }

  Future<void> _read(Map<String, dynamic> item) async {
    if (item['leida'] == true) return;
    try {
      await context.read<Session>().authRequest(
        'PATCH',
        '/notificaciones/${item['id_notificacion']}/leer',
      );
      if (mounted) setState(() => item['leida'] = true);
    } catch (_) {
      // Si no se pudo marcar, sigue apareciendo como nueva.
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notificaciones',
                style: TextStyle(
                  color: petInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              if (_error != null)
                _MessageCard(text: _error!)
              else if (items == null)
                const _LoadingCard()
              else if (items.isEmpty)
                const _MessageCard(text: 'No tienes notificaciones.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final unread = item['leida'] != true;
                      return InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _read(item),
                        child: Ink(
                          padding: const EdgeInsets.all(14),
                          decoration: _cardDecoration(
                            color: unread
                                ? const Color(0xFFFFF1E8)
                                : Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['titulo'] ?? ''}',
                                style: TextStyle(
                                  color: petInk,
                                  fontWeight: unread
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item['mensaje'] ?? ''}',
                                style: const TextStyle(color: accountMuted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _ago(item['fecha_creacion']),
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

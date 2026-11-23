import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import 'account_layout.dart';
import 'motion.dart';
import 'welcome.dart';

class PetCaptureResult {
  const PetCaptureResult({required this.photo, this.latitude, this.longitude});

  final XFile photo;
  final double? latitude;
  final double? longitude;
}

class PetCameraPage extends StatefulWidget {
  const PetCameraPage({super.key, this.attachLocation = false});

  final bool attachLocation;

  @override
  State<PetCameraPage> createState() => _PetCameraPageState();
}

class _PetCameraPageState extends State<PetCameraPage>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();
  CameraController? _controller;
  String? _cameraError;
  bool _takingPhoto = false;
  bool _locating = false;
  bool _autoLocationRequested = false;
  double? _latitude;
  double? _longitude;

  bool get _hasLocation => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('not-found', '');
      final selected = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
      if (widget.attachLocation && !_autoLocationRequested) {
        _autoLocationRequested = true;
        unawaited(_requestLocation());
      }
    } on CameraException {
      if (mounted) {
        setState(() => _cameraError = 'No pudimos abrir la cámara de PetID.');
      }
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  PetCaptureResult _result(XFile photo) => PetCaptureResult(
    photo: photo,
    latitude: _latitude,
    longitude: _longitude,
  );

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _takingPhoto) {
      return;
    }
    setState(() => _takingPhoto = true);
    HapticFeedback.mediumImpact();
    try {
      final photo = await controller.takePicture();
      if (mounted) Navigator.of(context).pop(_result(photo));
    } on CameraException {
      if (mounted) {
        setState(() {
          _takingPhoto = false;
          _cameraError = 'No se pudo tomar la foto. Inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> _openSystemCamera() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (mounted && photo != null) Navigator.of(context).pop(_result(photo));
  }

  Future<void> _openGallery() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (mounted && photo != null) Navigator.of(context).pop(_result(photo));
  }

  Future<void> _requestLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw const PermissionDeniedException('location');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locating = false;
      });
    } on LocationServiceDisabledException {
      _showLocationError('Activa la ubicación del celular para agregarla.');
    } on PermissionDeniedException {
      _showLocationError('Permite la ubicación para guardarla en el reporte.');
    } on TimeoutException {
      _showLocationError('No logramos obtener tu ubicación. Intenta otra vez.');
    } catch (_) {
      _showLocationError('No pudimos agregar la ubicación en este momento.');
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    setState(() {
      _locating = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF343D3F),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ready) _CameraSurface(controller: controller!) else _loading(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                    Color(0x55000000),
                  ],
                  stops: [0, .45, 1],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundCameraButton(
                    tooltip: 'Cerrar',
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF176D61),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF55D6C3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.attachLocation
                              ? _hasLocation
                                    ? Icons.location_on_rounded
                                    : Icons.location_searching_rounded
                              : Icons.center_focus_strong_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.attachLocation
                              ? _locating
                                    ? 'Buscando GPS...'
                                    : _hasLocation
                                    ? 'GPS listo'
                                    : 'Agregar GPS'
                              : 'Encuadre asistido',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (ready)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 110),
                  child: SizedBox(
                    width: 270,
                    height: 310,
                    child: _AnimatedScanFrame(),
                  ),
                ),
              ),
            Positioned(
              left: 34,
              right: 34,
              bottom: _cameraError == null ? 190 : 244,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: Text(
                  _cameraError ??
                      'Centra el rostro o el cuerpo de la mascota dentro del marco.',
                  key: ValueKey(_cameraError),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 480),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Transform.translate(
                  offset: Offset(0, 36 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                ),
                child: _CameraDock(
                  ready: ready,
                  takingPhoto: _takingPhoto,
                  hasLocation: _hasLocation,
                  locating: _locating,
                  onGallery: _openGallery,
                  onCapture: _capture,
                  onLocation: _requestLocation,
                ),
              ),
            ),
            if (_cameraError != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 182,
                child: OutlinedButton.icon(
                  onPressed: _openSystemCamera,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Abrir cámara del sistema'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _loading() => const Center(
    child: Padding(
      padding: EdgeInsets.only(bottom: 120),
      child: CircularProgressIndicator(color: Color(0xFFFFC45B)),
    ),
  );
}

class _CameraDock extends StatelessWidget {
  const _CameraDock({
    required this.ready,
    required this.takingPhoto,
    required this.hasLocation,
    required this.locating,
    required this.onGallery,
    required this.onCapture,
    required this.onLocation,
  });

  final bool ready;
  final bool takingPhoto;
  final bool hasLocation;
  final bool locating;
  final VoidCallback onGallery;
  final VoidCallback onCapture;
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) => Container(
    height: 164,
    padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
    decoration: const BoxDecoration(
      color: petCream,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _RoundCameraButton(
              tooltip: 'Elegir de la galería',
              icon: Icons.photo_library_outlined,
              light: true,
              onPressed: onGallery,
            ),
            Breathing(
              scale: 1.04,
              child: Semantics(
                button: true,
                label: 'Tomar foto',
                child: GestureDetector(
                  onTap: ready && !takingPhoto ? onCapture : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: takingPhoto
                          ? accountBorder
                          : const Color(0xFFFFC45B),
                      shape: BoxShape.circle,
                      border: Border.all(color: petOrange, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x44FF8D42),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: takingPhoto ? .82 : 1,
                      child: const Icon(
                        Icons.pets_rounded,
                        color: petInk,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _RoundCameraButton(
              tooltip: hasLocation
                  ? 'Ubicación agregada'
                  : 'Agregar ubicación al reporte',
              icon: hasLocation
                  ? Icons.location_on_rounded
                  : Icons.location_on_outlined,
              light: true,
              active: hasLocation,
              loading: locating,
              onPressed: locating ? null : onLocation,
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            locating
                ? 'Obteniendo tu ubicación...'
                : hasLocation
                ? 'Ubicación agregada · Toca la huella para capturar'
                : ready
                ? 'Toca la huella para capturar'
                : 'Preparando cámara...',
            key: ValueKey((ready, locating, hasLocation)),
            style: TextStyle(
              color: hasLocation ? const Color(0xFF176D61) : accountMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoundCameraButton extends StatelessWidget {
  const _RoundCameraButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.light = false,
    this.active = false,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool light;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(48),
      foregroundColor: active
          ? const Color(0xFF176D61)
          : light
          ? petInk
          : Colors.white,
      disabledForegroundColor: active
          ? const Color(0xFF176D61)
          : light
          ? petInk
          : Colors.white,
      backgroundColor: active
          ? const Color(0xFFDDF5EE)
          : light
          ? Colors.white
          : const Color(0xAA263033),
      disabledBackgroundColor: active
          ? const Color(0xFFDDF5EE)
          : light
          ? Colors.white
          : const Color(0xAA263033),
      side: BorderSide(
        color: active
            ? const Color(0xFF55D6C3)
            : light
            ? accountBorder
            : Colors.white24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    icon: loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.3,
              color: Color(0xFF176D61),
            ),
          )
        : Icon(icon),
  );
}

class _CameraSurface extends StatelessWidget {
  const _CameraSurface({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _AnimatedScanFrame extends StatefulWidget {
  const _AnimatedScanFrame();

  @override
  State<_AnimatedScanFrame> createState() => _AnimatedScanFrameState();
}

class _AnimatedScanFrameState extends State<_AnimatedScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.value = .5;
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) =>
        CustomPaint(painter: _ScanFramePainter(_controller.value)),
  );
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = const Color(0xFFFFD35A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const length = 34.0;

    final corners = [
      Path()
        ..moveTo(0, length)
        ..lineTo(0, 0)
        ..lineTo(length, 0),
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, length),
      Path()
        ..moveTo(size.width, size.height - length)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width - length, size.height),
      Path()
        ..moveTo(length, size.height)
        ..lineTo(0, size.height)
        ..lineTo(0, size.height - length),
    ];
    for (final corner in corners) {
      canvas.drawPath(corner, cornerPaint);
    }

    final y = 24 + (size.height - 48) * progress;
    final scanPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x00FFD35A), Color(0xAAFFD35A), Color(0x00FFD35A)],
      ).createShader(Rect.fromLTWH(20, y - 1, size.width - 40, 2))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), scanPaint);
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

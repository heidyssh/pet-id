import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import 'account_layout.dart';
import 'welcome.dart';

class PetCameraPage extends StatefulWidget {
  const PetCameraPage({super.key});

  @override
  State<PetCameraPage> createState() => _PetCameraPageState();
}

class _PetCameraPageState extends State<PetCameraPage>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();
  CameraController? _controller;
  String? _error;
  bool _takingPhoto = false;

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
        _error = null;
      });
    } on CameraException {
      if (mounted) {
        setState(() => _error = 'No pudimos abrir la cámara de PetID.');
      }
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

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
      if (mounted) Navigator.of(context).pop(photo);
    } on CameraException {
      if (mounted) {
        setState(() {
          _takingPhoto = false;
          _error = 'No se pudo tomar la foto. Inténtalo de nuevo.';
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
    if (mounted && photo != null) Navigator.of(context).pop(photo);
  }

  Future<void> _openGallery() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (mounted && photo != null) Navigator.of(context).pop(photo);
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.center_focus_strong_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Encuadre asistido',
                          style: TextStyle(
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 110),
                  child: SizedBox(
                    width: 270,
                    height: 310,
                    child: CustomPaint(painter: const _ScanFramePainter()),
                  ),
                ),
              ),
            Positioned(
              left: 34,
              right: 34,
              bottom: _error == null ? 190 : 244,
              child: Text(
                _error ??
                    'Centra el rostro o el cuerpo de la mascota dentro del marco.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
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
                          onPressed: _openGallery,
                        ),
                        Semantics(
                          button: true,
                          label: 'Tomar foto',
                          child: GestureDetector(
                            onTap: ready && !_takingPhoto ? _capture : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: _takingPhoto
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
                              child: const Icon(
                                Icons.pets_rounded,
                                color: petInk,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const _RoundCameraButton(
                          tooltip: 'La ubicación se agrega al reporte',
                          icon: Icons.location_on_outlined,
                          light: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ready
                          ? 'Toca el botón para capturar'
                          : 'Preparando cámara...',
                      style: const TextStyle(
                        color: accountMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
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

class _RoundCameraButton extends StatelessWidget {
  const _RoundCameraButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.light = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      fixedSize: const Size.square(48),
      foregroundColor: light ? petInk : Colors.white,
      disabledForegroundColor: light ? petInk : Colors.white,
      backgroundColor: light ? Colors.white : const Color(0xAA263033),
      disabledBackgroundColor: light ? Colors.white : const Color(0xAA263033),
      side: BorderSide(color: light ? accountBorder : Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    icon: Icon(icon),
  );
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
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
      canvas.drawPath(corner, paint);
    }
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) => false;
}

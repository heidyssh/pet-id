import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'api.dart';
import 'entry_forms.dart';
import 'motion.dart';

const petCream = Color(0xFFFCF7F2);
const petOrange = Color(0xFFFF8D42);
const petDarkOrange = Color(0xFFAE4B04);
const petInk = Color(0xFF293234);
const _edge = Color(0xFFFDE1D1);

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.restoreError});
  final String? restoreError;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 460.0);
            final scale = width / 390;
            return SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: width,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        top: 50 * scale,
                        right: -30 * scale,
                        child: Float(
                          distance: 14 * scale,
                          child: _circle(160 * scale, const Color(0xFFFFEAC1)),
                        ),
                      ),
                      Positioned(
                        top: 310 * scale,
                        left: -50 * scale,
                        child: Float(
                          distance: 18 * scale,
                          period: const Duration(milliseconds: 4200),
                          child: _circle(180 * scale, const Color(0xFFFFE0E4)),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24 * scale,
                          36 * scale,
                          24 * scale,
                          28 * scale,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Reveal(
                              child: Row(
                                children: [
                                  Container(
                                    width: 53 * scale,
                                    height: 53 * scale,
                                    decoration: BoxDecoration(
                                      color: petOrange,
                                      borderRadius: BorderRadius.circular(
                                        16 * scale,
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFFE87D35),
                                        width: 2.4 * scale,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x3DD96B22),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Wiggle(
                                      angle: 0.35,
                                      child: _paw(25 * scale, petInk),
                                    ),
                                  ),
                                  SizedBox(width: 10 * scale),
                                  Text(
                                    'PetID',
                                    style: TextStyle(
                                      color: petInk,
                                      fontSize: 27 * scale,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 36 * scale),
                            Reveal(order: 1, child: _HeroPanel(scale: scale)),
                            SizedBox(height: 38 * scale),
                            Reveal(
                              order: 2,
                              child: Text.rich(
                                const TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          'Que toda mascota encuentre el camino ',
                                    ),
                                    TextSpan(
                                      text: 'de vuelta a casa',
                                      style: TextStyle(
                                        color: Color(0xFFC75308),
                                      ),
                                    ),
                                  ],
                                ),
                                style: TextStyle(
                                  color: petInk,
                                  fontSize: 32 * scale,
                                  height: 1.14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            SizedBox(height: 16 * scale),
                            Reveal(
                              order: 3,
                              child: Text(
                                'Registra a tu mascota, recibe alertas de tu zona en La Ceiba y reporta avistamientos en segundos.',
                                style: TextStyle(
                                  color: const Color(0xFF5D686C),
                                  fontSize: 16 * scale,
                                  height: 1.48,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: 6 * scale),
                            Reveal(
                              order: 4,
                              child: _button(
                                context,
                                'Crear cuenta',
                                const AccountForm(register: true),
                                scale,
                                primary: true,
                              ),
                            ),
                            SizedBox(height: 15 * scale),
                            Reveal(
                              order: 5,
                              child: _button(
                                context,
                                'Ya tengo cuenta',
                                const AccountForm(),
                                scale,
                              ),
                            ),
                            SizedBox(height: 12 * scale),
                            Reveal(
                              order: 6,
                              child: _guestReportButton(context, scale),
                            ),
                            if (restoreError != null)
                              TextButton(
                                onPressed: context.read<Session>().restore,
                                child: Text('$restoreError Reintentar'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _button(
    BuildContext context,
    String label,
    Widget page,
    double scale, {
    bool primary = false,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16 * scale),
    );
    return Pressable(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          shadows: const [
            BoxShadow(
              color: Color(0x33AE4B04),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: OutlinedButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            _open(context, page);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: primary ? Colors.white : petDarkOrange,
            backgroundColor: primary ? petDarkOrange : Colors.white,
            side: BorderSide(
              color: primary ? const Color(0xFFE27935) : petOrange,
              width: 2.4 * scale,
            ),
            minimumSize: Size(0, 60 * scale),
            shape: shape,
            textStyle: TextStyle(
              fontSize: 17 * scale,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _guestReportButton(BuildContext context, double scale) {
    return Align(
      child: Pressable(
        child: TextButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _open(context, const SightingForm());
          },
          style: TextButton.styleFrom(
            foregroundColor: petDarkOrange,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: const Color(0xFFFDE1D1),
              width: 1.6 * scale,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 17 * scale,
              vertical: 11 * scale,
            ),
            shape: const StadiumBorder(),
            textStyle: TextStyle(
              fontSize: 13.5 * scale,
              fontWeight: FontWeight.w800,
            ),
          ),
          icon: Icon(Icons.pets_outlined, size: 19 * scale),
          label: const Text('Reportar una mascota sin cuenta'),
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

Widget _circle(double size, Color color) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);

Widget _paw(double size, Color color) =>
    CustomPaint(size: Size.square(size), painter: _PawPainter(color));

class _PawPainter extends CustomPainter {
  const _PawPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72, size.height / 72);
    final ink = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(33, 11), 6, ink);
    canvas.drawCircle(const Offset(54, 23), 6, ink);
    canvas.drawCircle(const Offset(60, 47), 6, ink);
    canvas.drawPath(
      Path()
        ..moveTo(7, 37)
        ..cubicTo(11, 27, 34, 27, 39, 39)
        ..cubicTo(44, 48, 43, 66, 33, 66)
        ..cubicTo(20, 67, 23, 55, 15, 52)
        ..cubicTo(8, 50, 4, 44, 7, 37)
        ..close(),
      ink,
    );
  }

  @override
  bool shouldRepaint(_PawPainter oldDelegate) => oldDelegate.color != color;
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 250 * scale,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEFE),
          borderRadius: BorderRadius.circular(27 * scale),
          border: Border.all(color: _edge, width: 2.4 * scale),
          boxShadow: const [
            BoxShadow(color: Color(0xFFEEEDEC), offset: Offset(0, 4)),
            BoxShadow(color: Color(0x55FFBC94), offset: Offset(8, 10)),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: CustomPaint(
                size: Size.square(154 * scale),
                painter: const _DashedCircle(),
                child: SizedBox.square(
                  dimension: 154 * scale,
                  child: Center(
                    child: Breathing(
                      scale: 1.08,
                      child: _paw(73 * scale, petOrange),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18 * scale,
              top: 22 * scale,
              child: Float(
                distance: 6 * scale,
                child: _label(
                  'Alertas por zona',
                  Icons.location_on_outlined,
                  const Color(0xFF00CF9C),
                ),
              ),
            ),
            Positioned(
              right: 18 * scale,
              bottom: 20 * scale,
              child: Float(
                distance: 6 * scale,
                period: const Duration(milliseconds: 2700),
                child: _label(
                  'Escanea y reporta',
                  Icons.photo_camera_outlined,
                  const Color(0xFFFFD063),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _edge, width: 2.4 * scale),
        borderRadius: BorderRadius.circular(16 * scale),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F2F2C),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28 * scale,
            height: 28 * scale,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: Icon(icon, color: petInk, size: 17 * scale),
          ),
          SizedBox(width: 7 * scale),
          Text(
            text,
            style: TextStyle(
              color: petInk,
              fontWeight: FontWeight.w700,
              fontSize: 13.5 * scale,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  const _DashedCircle();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(rect, Paint()..color = const Color(0xFFFFF3EA));
    final stroke = Paint()
      ..color = const Color(0xFFFFC39F)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 67; i++) {
      canvas.drawArc(rect, i * 2 * math.pi / 67, .061, false, stroke);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle oldDelegate) => false;
}

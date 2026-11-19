import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animaciones reutilizables de PetID. Todas respetan la opción del teléfono
/// de reducir movimiento.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Hace aparecer el contenido desde abajo, en orden, al abrir la pantalla.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  static const _step = 70;
  static const _length = 520;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _length + widget.order * _step),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.order * _step / (_length + widget.order * _step),
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (_, child) => Opacity(
      opacity: _progress.value,
      child: Transform.translate(
        offset: Offset(0, (1 - _progress.value) * 28),
        child: child,
      ),
    ),
  );
}

/// Encoge un poco la tarjeta mientras se mantiene presionada.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child});
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? 0.96 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Base para animaciones que se repiten mientras la vista existe.
abstract class _LoopState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  Duration get period;
  bool get reverse => false;
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      controller.stop();
    } else if (!controller.isAnimating) {
      controller.repeat(reverse: reverse);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// Late suavemente, como si respirara.
class Breathing extends StatefulWidget {
  const Breathing({super.key, required this.child, this.scale = 1.1});
  final Widget child;
  final double scale;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends _LoopState<Breathing> {
  @override
  Duration get period => const Duration(milliseconds: 1100);
  @override
  bool get reverse => true;

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// Se balancea de vez en cuando, como una campana o una patita saludando.
class Wiggle extends StatefulWidget {
  const Wiggle({
    super.key,
    required this.child,
    this.active = true,
    this.angle = 0.28,
    this.every = const Duration(milliseconds: 3200),
  });
  final Widget child;
  final bool active;
  final double angle;
  final Duration every;

  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends _LoopState<Wiggle> {
  @override
  Duration get period => widget.every;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (_, child) {
      // Solo se mueve durante el primer 25 % de cada ciclo.
      final t = controller.value / 0.25;
      final angle = !widget.active || t >= 1
          ? 0.0
          : math.sin(t * math.pi * 4) * widget.angle * (1 - t);
      return Transform.rotate(angle: angle, child: child);
    },
  );
}

/// Un brillo que cruza la tarjeta en diagonal cada cierto tiempo.
class Sheen extends StatefulWidget {
  const Sheen({super.key, required this.child, required this.radius});
  final Widget child;
  final double radius;

  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends _LoopState<Sheen> {
  @override
  Duration get period => const Duration(milliseconds: 4200);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: AnimatedBuilder(
              animation: controller,
              builder: (_, _) {
                // Cruza durante el primer 30 % del ciclo y luego descansa.
                final t = (controller.value / 0.3).clamp(0.0, 1.0);
                final x = -1.6 + t * 3.2;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(x - 0.5, -1),
                      end: Alignment(x + 0.5, 1),
                      colors: const [
                        Color(0x00FFFFFF),
                        Color(0x40FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ],
  );
}

/// Bloques de carga con un brillo que se desplaza.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends _LoopState<Shimmer> {
  @override
  Duration get period => const Duration(milliseconds: 1300);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (_, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        final x = -1.5 + controller.value * 3;
        return LinearGradient(
          begin: Alignment(x - 0.6, 0),
          end: Alignment(x + 0.6, 0),
          colors: const [
            Color(0xFFFBEADF),
            Color(0xFFFFF7F1),
            Color(0xFFFBEADF),
          ],
        ).createShader(bounds);
      },
      child: child,
    ),
  );
}

/// Punto que late para señalar algo reciente.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color});
  final Color color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends _LoopState<PulseDot> {
  @override
  Duration get period => const Duration(milliseconds: 1400);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: AnimatedBuilder(
      animation: controller,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 6 + controller.value * 8,
            height: 6 + controller.value * 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(
                alpha: 0.35 * (1 - controller.value),
              ),
            ),
          ),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Sube y baja despacio, como si flotara.
class Float extends StatefulWidget {
  const Float({
    super.key,
    required this.child,
    this.distance = 8,
    this.period = const Duration(milliseconds: 3200),
  });
  final Widget child;
  final double distance;
  final Duration period;

  @override
  State<Float> createState() => _FloatState();
}

class _FloatState extends _LoopState<Float> {
  @override
  Duration get period => widget.period;
  @override
  bool get reverse => true;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: widget.child,
    builder: (_, child) => Transform.translate(
      offset: Offset(
        0,
        (Curves.easeInOut.transform(controller.value) - 0.5) * widget.distance,
      ),
      child: child,
    ),
  );
}

/// Transición entre pantallas de PetID: la nueva sube y aparece con un
/// fundido. Se aplica en el tema, así que vale para todas las pantallas.
class PetPageTransitions extends PageTransitionsBuilder {
  const PetPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final behind = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.6).animate(behind),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

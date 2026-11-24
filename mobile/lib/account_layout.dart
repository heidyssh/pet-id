import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'motion.dart';
import 'welcome.dart';

const accountBorder = Color(0xFFFDE1D1);
const accountMuted = Color(0xFF5D686C);

enum PetToastType { success, error, warning, info }

OverlayEntry? _activePetToast;

void showPetToast(
  BuildContext context,
  String message, {
  PetToastType type = PetToastType.info,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  if (_activePetToast?.mounted ?? false) _activePetToast!.remove();
  final (color, icon) = switch (type) {
    PetToastType.success => (
      const Color(0xFF08735F),
      Icons.check_circle_rounded,
    ),
    PetToastType.error => (const Color(0xFFB42318), Icons.error_rounded),
    PetToastType.warning => (
      const Color(0xFF8A5A00),
      Icons.warning_amber_rounded,
    ),
    PetToastType.info => (const Color(0xFF2E5F87), Icons.info_rounded),
  };
  late final OverlayEntry entry;
  void dismiss() {
    if (entry.mounted) entry.remove();
    if (identical(_activePetToast, entry)) _activePetToast = null;
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 18,
      right: 18,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        builder: (_, value, child) => Transform.translate(
          offset: Offset(0, -18 * (1 - value)),
          child: Opacity(opacity: value.clamp(0, 1), child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 23),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    visualDensity: VisualDensity.compact,
                    onPressed: dismiss,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _activePetToast = entry;
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 4), () {
    dismiss();
  });
}

class AccountLayout extends StatelessWidget {
  const AccountLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.busy = false,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool busy;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                28 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: (viewport.maxHeight - 44)
                        .clamp(0, double.infinity)
                        .toDouble(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Reveal(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: IconButton.outlined(
                                tooltip: 'Volver',
                                onPressed: busy
                                    ? null
                                    : () => Navigator.maybePop(context),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size.square(48),
                                  foregroundColor: petInk,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: accountBorder,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.chevron_left_rounded,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Reveal(
                            order: 1,
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 31,
                                height: 1.1,
                                color: petInk,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Reveal(
                            order: 2,
                            child: Text(
                              subtitle,
                              style: const TextStyle(
                                color: accountMuted,
                                fontSize: 16,
                                height: 1.28,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Cada campo entra después del anterior.
                          for (var i = 0; i < children.length; i++)
                            Reveal(
                              order: math.min(3 + i, 10),
                              child: children[i],
                            ),
                        ],
                      ),
                      if (footer != null)
                        Reveal(
                          order: math.min(3 + children.length, 11),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: footer,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration accountInput(String hint, {IconData? icon, Widget? suffix}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: 2),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF747475)),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: border(accountBorder),
    disabledBorder: border(accountBorder),
    focusedBorder: border(petOrange),
    errorBorder: border(const Color(0xFFBA1A1A)),
    focusedErrorBorder: border(const Color(0xFFBA1A1A)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: icon == null ? null : Icon(icon, color: accountMuted),
    suffixIcon: suffix,
    errorMaxLines: 3,
    counterText: '',
  );
}

class AccountField extends StatelessWidget {
  const AccountField(this.label, this.field, {super.key});

  final String label;
  final Widget field;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: petInk, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        field,
      ],
    ),
  );
}

class AccountButton extends StatelessWidget {
  const AccountButton(
    this.label, {
    super.key,
    this.onPressed,
    this.primary = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x44FF8D42), offset: Offset(4, 4)),
        ],
      ),
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          foregroundColor: petInk,
          backgroundColor: primary ? petOrange : Colors.white,
          disabledBackgroundColor: accountBorder,
          side: BorderSide(
            color: primary ? const Color(0xFFE27935) : accountBorder,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        // El texto cambia con un fundido, por ejemplo al pasar a "Enviando...".
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Row(
            key: ValueKey((label, loading)),
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: primary ? petInk : petDarkOrange,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        ),
      ),
    );
    return Pressable(child: button);
  }
}

Widget accountLink(String label, VoidCallback? onPressed) => TextButton(
  onPressed: onPressed,
  child: Text(
    label,
    style: const TextStyle(
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w700,
    ),
  ),
);

Widget accountError(BuildContext context, String message) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  ),
);

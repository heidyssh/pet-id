import 'package:flutter/material.dart';

import 'account_layout.dart';
import 'welcome.dart';

class AppSelectOption<T> {
  const AppSelectOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.title,
    required this.options,
    required this.onChanged,
    this.hint = 'Seleccionar',
    this.enabled = true,
    this.validator,
  });

  final T? value;
  final String title;
  final String hint;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final FormFieldValidator<T>? validator;

  Future<T?> _open(BuildContext context) => showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        decoration: const BoxDecoration(
          color: petCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: accountBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: petInk,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Elige una opción para continuar.',
              style: TextStyle(color: accountMuted),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option.value == value;
                  return Material(
                    color: selected ? const Color(0xFFFFE9D9) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: selected ? petOrange : accountBorder,
                        width: selected ? 2 : 1.5,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, option.value),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            if (option.icon case final icon?) ...[
                              Icon(icon, color: petDarkOrange, size: 22),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                option.label,
                                style: const TextStyle(
                                  color: petInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: selected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      key: ValueKey(true),
                                      color: petDarkOrange,
                                    )
                                  : const Icon(
                                      Icons.circle_outlined,
                                      key: ValueKey(false),
                                      color: accountBorder,
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
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FormField<T>(
    key: ValueKey((title, value)),
    initialValue: value,
    enabled: enabled,
    validator: validator,
    builder: (field) {
      final selected = options.where((option) => option.value == field.value);
      final option = selected.isEmpty ? null : selected.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: enabled ? Colors.white : const Color(0xFFF5F1EE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(
                color: field.hasError
                    ? Theme.of(context).colorScheme.error
                    : accountBorder,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: !enabled
                  ? null
                  : () async {
                      final selected = await _open(context);
                      if (selected == null || !context.mounted) return;
                      field.didChange(selected);
                      onChanged(selected);
                    },
              borderRadius: BorderRadius.circular(17),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    if (option?.icon case final icon?) ...[
                      Icon(icon, color: petDarkOrange, size: 21),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        option?.label ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: option == null ? accountMuted : petInk,
                          fontWeight: option == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: petDarkOrange,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (field.errorText case final error?) ...[
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

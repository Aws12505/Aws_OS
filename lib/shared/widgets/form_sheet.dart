import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';

/// Colored icon chip + bold title shown at the top of every finance form
/// sheet, so each one reads at a glance which action/domain it belongs to
/// instead of a bare title string.
class FormSheetHeader extends StatelessWidget {
  const FormSheetHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: tt.titleLarge?.weight(FontWeight.w800),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small uppercase kicker label used to group fields within a form sheet
/// ("LINES", "REPEAT", "LINKED TRANSACTIONS"...). Same recipe as the private
/// `_SectionLabel` that already existed in `transaction_filter_sheet.dart`,
/// promoted here so every sheet can share it.
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            letterSpacing: 1.2,
      ),
    );
  }
}

/// Rounded, bordered row that opens a date (or date+time) picker on tap —
/// replaces the bare `ListTile` date rows previously duplicated across every
/// form sheet. Purely presentational: callers keep using the shared
/// `pickDate`/`pickDateTime` helpers from `date_time_picker.dart` and pass the
/// already-formatted value in.
class SheetDateTile extends StatelessWidget {
  const SheetDateTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.event_rounded,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      value,
                      style: tt.bodyLarge?.weight(FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amount input with a visually prominent style — the number the user cares
/// about most in every finance form gets bigger, bolder treatment than a
/// plain `TextFormField`, while keeping the same numeric keyboard/formatter/
/// validator plumbing every caller already used.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.label = 'Amount',
    this.currencySymbol,
    this.helperText,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? currencySymbol;
  final String? helperText;
  final String? Function(String?)? validator;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      style: Theme.of(context).textTheme.headlineSmall?.weight(FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        suffixText: currencySymbol,
        helperText: helperText,
      ),
      validator: validator,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
    );
  }
}

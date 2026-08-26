import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';

/// Numeric field with a minus and a plus flanking the value.
///
/// The keyboard still works for a big jump, but the common case on a gym floor
/// is nudging last session's number by one, one-handed, and that should not
/// require opening a keyboard and re-typing. Both buttons are full 48dp
/// targets and fire a selection haptic.
///
/// Holding either button keeps stepping, so going from 60 to 80 is one press
/// rather than twenty.
class AppStepper extends StatefulWidget {
  const AppStepper({
    super.key,
    required this.controller,
    required this.label,
    this.step = 1,
    this.min = 0,
    this.max = 9999,
    this.decimal = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;

  /// Sits above the field. Never a placeholder: placeholder-as-label
  /// disappears exactly when the user needs it.
  final String label;

  final double step;
  final double min;
  final double max;

  /// Whether the field accepts a fractional value. Reps are whole; weight is
  /// not.
  final bool decimal;

  /// Unit shown after the value, for example `kg`.
  final String? suffix;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<AppStepper> createState() => _AppStepperState();
}

class _AppStepperState extends State<AppStepper> {
  double? _parse() {
    final raw = widget.controller.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String _format(double v) {
    if (!widget.decimal || v == v.roundToDouble()) {
      return v.toStringAsFixed(0);
    }
    return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
      RegExp(r'\.$'),
      '',
    );
  }

  void _nudge(int direction) {
    final current = _parse() ?? 0;
    final next = (current + widget.step * direction).clamp(
      widget.min,
      widget.max,
    );
    if (next == current) return;
    HapticFeedback.selectionClick();
    final text = _format(next);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onChanged?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.md);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: tt.labelMedium?.copyWith(color: surfaces.textSecondary),
        ),
        const SizedBox(height: 4),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: surfaces.sunken.withValues(alpha: 0.5),
            borderRadius: radius,
            border: Border.all(color: surfaces.hairlineStrong),
          ),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                tooltip: 'Decrease ${widget.label.toLowerCase()}',
                onStep: widget.enabled ? () => _nudge(-1) : null,
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: widget.decimal,
                  ),
                  inputFormatters: [
                    widget.decimal
                        ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                        : FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: context.type.numeric,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0',
                    suffixText: widget.suffix,
                    suffixStyle: tt.bodySmall?.copyWith(
                      color: surfaces.textTertiary,
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                tooltip: 'Increase ${widget.label.toLowerCase()}',
                onStep: widget.enabled ? () => _nudge(1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onStep,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _repeat;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  /// Press and hold to keep stepping, so going from 60 to 80 is one gesture
  /// rather than twenty taps. The initial delay means a plain tap steps once:
  /// `onTap` already fired it.
  void _startRepeating() {
    final step = widget.onStep;
    if (step == null) return;
    _stopRepeating();
    _repeat = Timer(const Duration(milliseconds: 450), () {
      _repeat = Timer.periodic(
        const Duration(milliseconds: 90),
        (_) => step(),
      );
    });
  }

  void _stopRepeating() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final enabled = widget.onStep != null;
    return Tooltip(
      message: widget.tooltip,
      child: InkResponse(
        onTap: widget.onStep,
        onTapDown: enabled ? (_) => _startRepeating() : null,
        onTapUp: (_) => _stopRepeating(),
        onTapCancel: _stopRepeating,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 48,
          child: Icon(
            widget.icon,
            size: 20,
            color: enabled ? surfaces.textSecondary : surfaces.textQuaternary,
          ),
        ),
      ),
    );
  }
}

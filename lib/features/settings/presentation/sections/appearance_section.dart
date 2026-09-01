part of '../settings_screen.dart';

// Colour, theme, typeface and text size.


class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: context.surfaces.hairlineStrong,
          width: AppSurfaces.hairlineWidth,
        ),
      ),
    );
  }
}

/// Colour picker used by the two accent swatches.
void _pickColor(
  BuildContext context, {
  required String title,
  required Color initial,
  required ValueChanged<Color> onPicked,
}) {
  Color current = initial;
  showAppDialog<void>(
    context,
    builder: (dCtx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: initial,
          onColorChanged: (c) => current = c,
          enableAlpha: false,
          labelTypes: const [],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            onPicked(current);
            Navigator.pop(dCtx);
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}

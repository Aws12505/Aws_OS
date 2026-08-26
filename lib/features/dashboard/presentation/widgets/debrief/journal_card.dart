part of '../../debrief_screen.dart';

// Mood, energy and the four written prompts.

class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.mood,
    required this.energy,
    required this.wins,
    required this.improve,
    required this.gratitude,
    required this.reflection,
    required this.saving,
    required this.onMood,
    required this.onEnergy,
    required this.onSave,
  });

  final int? mood;
  final int? energy;
  final TextEditingController wins;
  final TextEditingController improve;
  final TextEditingController gratitude;
  final TextEditingController reflection;
  final bool saving;
  final ValueChanged<int> onMood;
  final ValueChanged<int> onEnergy;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was your day?',
            style: tt.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _ScalePicker(
            label: 'Mood',
            value: mood,
            onChanged: onMood,
            colorFor: MoodColors.forScore,
          ),
          const SizedBox(height: AppSpacing.md),
          _ScalePicker(
            label: 'Energy',
            value: energy,
            onChanged: onEnergy,
            colorFor: (s) => Color.lerp(cs.primary, cs.tertiary, (s - 1) / 4)!,
          ),
          const SizedBox(height: AppSpacing.lg),
          _JournalField(
            controller: wins,
            label: 'Wins',
            hint: 'What went well?',
          ),
          _JournalField(
            controller: improve,
            label: 'To improve',
            hint: 'What could be better?',
          ),
          _JournalField(
            controller: gratitude,
            label: 'Gratitude',
            hint: "What you're thankful for",
          ),
          _JournalField(
            controller: reflection,
            label: 'Reflection',
            hint: 'Anything else on your mind',
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'Save debrief',
            icon: Icons.check_rounded,
            expand: true,
            loading: saving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

class _ScalePicker extends StatelessWidget {
  const _ScalePicker({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.colorFor,
  });

  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  final Color Function(int) colorFor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
              // The ramp runs red to green, which is unreadable with
              // deuteranopia. The word carries the meaning; the colour only
              // reinforces it.
              if (value != null)
                Text(
                  MoodColors.labelForScore(value!),
                  style: tt.labelSmall?.copyWith(
                    color: colorFor(value!),
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 36,
                      decoration: BoxDecoration(
                        color: value != null && i <= value!
                            ? colorFor(value!).withValues(alpha: 0.9)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: value == i
                              ? colorFor(i)
                              : cs.outlineVariant.withValues(alpha: 0.4),
                          width: value == i ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$i',
                          style: tt.labelMedium?.copyWith(
                            // The mood ramp runs red to green, so the fill
                            // under this number changes lightness across the
                            // scale and white does not stay readable on it.
                            color: value != null && i <= value!
                                ? bestForegroundOn(colorFor(value!))
                                : cs.onSurfaceVariant,
                          ).weight(FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JournalField extends StatelessWidget {
  const _JournalField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 2,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: maxLines,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }
}

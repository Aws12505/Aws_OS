part of '../../screens/day_detail_screen.dart';

/// One set: its number, reps, weight, and the tick that logs it.
class _SetRow extends ConsumerStatefulWidget {
  const _SetRow({
    required this.dayId,
    required this.exerciseId,
    required this.setIndex,
    required this.current,
    required this.previous,
  });

  final String dayId;
  final String exerciseId;
  final int setIndex;
  final ExerciseSetPrescription? current;
  final ExerciseSetPrescription? previous;

  @override
  ConsumerState<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<_SetRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: widget.current?.reps.toString() ?? '');
    _weight = TextEditingController(text: _weightText);
  }

  String get _weightText =>
      widget.current == null ? '' : _fmtSetWeight(widget.current!.weight);

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current?.id != widget.current?.id) {
      _reps.text = widget.current?.reps.toString() ?? '';
      _weight.text = _weightText;
    }
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  String get _checkKey => '${widget.exerciseId}#${widget.setIndex}';

  /// Parses the fields and, if they are usable, persists them as a new
  /// prescription row unless nothing changed. Returns false, with a snackbar
  /// saying why, when they are not, so a tick press is never a silent no-op.
  Future<bool> _trySave() async {
    final reps = int.tryParse(_reps.text.trim());
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (reps == null || weight == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter reps and weight before ticking this set.'),
          ),
        );
      }
      return false;
    }
    final unchanged =
        widget.current != null &&
        widget.current!.reps == reps &&
        (widget.current!.weight - weight).abs() < 1e-9;
    if (!unchanged) {
      await ref
          .read(gymDaoProvider)
          .insertPrescription(
            dayExerciseId: widget.exerciseId,
            setIndex: widget.setIndex,
            reps: reps,
            weight: weight,
          );
    }
    return true;
  }

  Future<void> _onCheckPressed() async {
    final notifier = ref.read(dayCheckedSetsProvider(widget.dayId).notifier);
    final isChecked = ref
        .read(dayCheckedSetsProvider(widget.dayId))
        .contains(_checkKey);
    if (isChecked) {
      HapticFeedback.selectionClick();
      notifier.uncheck(_checkKey);
      return;
    }
    if (await _trySave()) {
      HapticFeedback.lightImpact();
      notifier.check(_checkKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = ref
        .watch(dayCheckedSetsProvider(widget.dayId))
        .contains(_checkKey);
    final previous = widget.previous;
    final surfaces = context.surfaces;
    final motion = context.motion;
    final positive = context.sem.positive;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SizedBox(
                  width: 18,
                  child: Text(
                    '${widget.setIndex}',
                    style: context.type.numericSmall.copyWith(
                      color: surfaces.textTertiary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppStepper(
                  controller: _reps,
                  label: 'Reps',
                  max: 200,
                  onSubmitted: (_) => _trySave(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppStepper(
                  controller: _weight,
                  label: 'Weight',
                  decimal: true,
                  step: 2.5,
                  onSubmitted: (_) => _trySave(),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Tooltip(
                  message: isChecked
                      ? 'Untick set ${widget.setIndex}'
                      : 'Tick set ${widget.setIndex} off',
                  child: InkResponse(
                    onTap: _onCheckPressed,
                    radius: 26,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: AnimatedSwitcher(
                        duration: motion.quick,
                        child: Icon(
                          isChecked
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          key: ValueKey(isChecked),
                          size: 27,
                          color: isChecked
                              ? positive.base
                              : surfaces.textQuaternary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (previous != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                'last ${previous.reps} x ${_fmtSetWeight(previous.weight)} '
                'on ${DateFormat.MMMd().format(previous.effectiveFrom)}',
                style: context.type.numericSmall.copyWith(
                  color: surfaces.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

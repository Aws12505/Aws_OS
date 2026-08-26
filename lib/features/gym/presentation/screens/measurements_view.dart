import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/db/app_database.dart';
import '../../../../shared/design/app_theme.dart';
import '../../../../shared/utils/date_preset.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_chip.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../shared/widgets/app_modal_sheet.dart';
import '../../../../shared/widgets/date_time_picker.dart';
import '../../../../shared/widgets/metric_grid.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/sparkline.dart';
import '../providers.dart';

part '../widgets/measurements/manage_types_card.dart';
part '../widgets/measurements/type_trend_card.dart';
part '../widgets/measurements/entry_tile.dart';
part '../widgets/measurements/types_sheet.dart';
part '../widgets/measurements/entry_sheet.dart';

class MeasurementsView extends ConsumerStatefulWidget {
  const MeasurementsView({super.key});

  @override
  ConsumerState<MeasurementsView> createState() => _MeasurementsViewState();
}

class _MeasurementsViewState extends ConsumerState<MeasurementsView> {
  DatePreset _datePreset = DatePreset.all;
  DateTime? _customFrom;
  DateTime? _customTo;

  bool _inRange(DateTime d) {
    final range = datePresetRange(
      _datePreset,
      customFrom: _customFrom,
      customTo: _customTo,
    );
    if (range == null) return true;
    return !d.isBefore(range.$1) && !d.isAfter(range.$2);
  }

  Future<void> _pickCustomRange() async {
    final from = await pickDate(
      context,
      initial: _customFrom ?? DateTime.now(),
    );
    if (from == null || !mounted) return;
    final to = await pickDate(
      context,
      initial: _customTo ?? from,
      firstDate: from,
    );
    if (to == null) return;
    setState(() {
      _datePreset = DatePreset.custom;
      _customFrom = from;
      _customTo = to;
    });
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(measurementTypesStreamProvider);
    final entriesAsync = ref.watch(measurementEntriesStreamProvider);
    final valuesAsync = ref.watch(measurementValuesStreamProvider);
    final accent = context.sem.gym;

    return typesAsync.when(
      loading: () => const AppLoading(message: 'Loading measurements'),
      error: (e, _) => AppErrorView(error: e),
      data: (types) {
        if (types.isEmpty) {
          return AppEmptyState(
            icon: Icons.straighten_rounded,
            title: 'No measurement types',
            message:
                'Decide what you want to track first, such as weight, chest '
                'or waist. Then you can record entries against them.',
            accent: accent.base,
            action: FilledButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Set up types'),
              onPressed: () => showMeasurementTypesSheet(context),
            ),
          );
        }

        return entriesAsync.when(
          loading: () => const AppLoading(message: 'Loading measurements'),
          error: (e, _) => AppErrorView(error: e),
          data: (allEntries) {
            final byEntry = <String, List<MeasurementValue>>{};
            for (final v in (valuesAsync.value ?? const <MeasurementValue>[])) {
              byEntry.putIfAbsent(v.entryId, () => []).add(v);
            }
            final typesById = {for (final t in types) t.id: t};

            // Entries the current filter selects, newest first.
            final entries = allEntries
                .where((e) => _inRange(e.takenAt))
                .toList();

            // Chronological series per type, built from the same filtered
            // entries. Previously the trend cards read every entry ever while
            // the history list below them was filtered, so the two halves of
            // the screen quietly disagreed about what period you were looking
            // at.
            final ascending = entries.reversed.toList();
            final seriesByType = <String, List<double>>{};
            for (final e in ascending) {
              for (final v in (byEntry[e.id] ?? const <MeasurementValue>[])) {
                seriesByType.putIfAbsent(v.typeId, () => []).add(v.value);
              }
            }
            final trendTypes = types
                .where((t) => (seriesByType[t.id] ?? const []).isNotEmpty)
                .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppInsets.listBottom,
              ),
              children: [
                _ManageTypesCard(
                  count: types.length,
                  onTap: () => showMeasurementTypesSheet(context),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    children: [
                      for (final preset in DatePreset.values)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: preset == DatePreset.custom
                              ? AppChip(
                                  label:
                                      _datePreset == DatePreset.custom &&
                                          _customFrom != null
                                      ? '${DateFormat.MMMd().format(_customFrom!)} to ${DateFormat.MMMd().format(_customTo ?? _customFrom!)}'
                                      : 'Custom',
                                  icon: Icons.date_range_rounded,
                                  color: accent.base,
                                  selected: _datePreset == DatePreset.custom,
                                  onTap: _pickCustomRange,
                                )
                              : AppChip(
                                  label: preset.label,
                                  color: accent.base,
                                  selected: _datePreset == preset,
                                  onTap: () => setState(() {
                                    _datePreset = preset;
                                    _customFrom = null;
                                    _customTo = null;
                                  }),
                                ),
                        ),
                    ],
                  ),
                ),
                if (trendTypes.isNotEmpty) ...[
                  SectionLabel(
                    _datePreset == DatePreset.all
                        ? 'Trends, all time'
                        : 'Trends, ${_datePreset.label.toLowerCase()}',
                  ),
                  // Wrapped, not a rail: what you track is a short list, and
                  // hiding half of it behind a swipe defeats the point of a
                  // summary.
                  MetricGrid(
                    minTileWidth: 152,
                    maxPerRow: 3,
                    tiles: [
                      for (final t in trendTypes)
                        _TypeTrendCard(type: t, series: seriesByType[t.id]!),
                    ],
                  ),
                ],
                SectionLabel(
                  'History',
                  trailing: entries.isEmpty
                      ? null
                      : Text(
                          '${entries.length}',
                          style: context.type.numericSmall.copyWith(
                            color: context.surfaces.textTertiary,
                          ),
                        ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxl),
                    child: AppEmptyState(
                      compact: true,
                      icon: Icons.monitor_weight_outlined,
                      title: _datePreset == DatePreset.all
                          ? 'Nothing recorded yet'
                          : 'Nothing in this period',
                      message: _datePreset == DatePreset.all
                          ? 'Use the add button to record your first reading.'
                          : 'Try a wider date range.',
                      accent: accent.base,
                    ),
                  ),
                for (final e in entries)
                  _EntryTile(
                    entry: e,
                    values: byEntry[e.id] ?? const [],
                    typesById: typesById,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

String _fmtValue(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

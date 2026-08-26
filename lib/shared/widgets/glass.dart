import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import 'app_card.dart';
import 'section_header.dart';

export 'app_card.dart' show AppCard, PressableSurface;
export 'section_header.dart' show SectionHeader;

/// Kept so existing call sites keep compiling while they migrate to [AppCard],
/// which resolves glass or flat from the surrounding `SurfaceScope` instead of
/// always being frosted.
typedef GlassCard = AppCard;

/// Small pill for inline metadata: tags, counts, dates.
///
/// The fill is pre-blended against a known surface rather than laid over the
/// card at 12% alpha, so the label's contrast is guaranteed instead of
/// depending on whatever the aurora happens to be doing behind it.
class MiniPill extends StatelessWidget {
  const MiniPill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;

  /// A semantic color. Defaults to the theme primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final role = SemanticRole.derive(color ?? cs.primary, cs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: role.container,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: role.onContainer),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: role.onContainer,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kicker-over-title header.
///
/// Superseded by [SectionHeader], which spends that line on live status rather
/// than repeating the nav label the user just tapped. This forwards so existing
/// call sites keep working; the kicker is dropped rather than rendered.
class EditorialHeader extends StatelessWidget {
  const EditorialHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 16, 4),
  });

  final String kicker;
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SectionHeader(title: title, trailing: trailing, padding: padding);
  }
}

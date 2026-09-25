import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The surfaces and headings every screen is assembled from.
///
/// The instrument has one line weight, one lit colour and no rounded corners,
/// and these are the three places that fact is written down. A screen that
/// draws its own container with its own border has left the instrument; if
/// something is missing here, add it here.

/// A legend over a group of readings — "BERKITME USULY", "ENJAM SAÝLAŇ".
///
/// Lettered like the silkscreen on an instrument's face: mono, uppercase,
/// tracked wide, with a lit tick at the head and a hairline running out to the
/// end of the row. The rule is what makes a section a section — there is no
/// box around it and no heavier type.
class SectionHeading extends StatelessWidget {
  final String label;

  /// A short note under the legend — what this section is for, when that is
  /// not obvious from the controls themselves. Prose, not legend.
  final String? note;

  /// Runs the hairline out from the legend to the end of the row. On by
  /// default; off where the section already sits inside a framed panel and a
  /// second line would be noise.
  final bool rule;

  /// Shown at the end of the row — a count, a status, a citation chip.
  final Widget? trailing;

  /// Lights the head tick and the legend. Used where the section is the one
  /// the trainee is working in.
  final bool live;

  const SectionHeading(
    this.label, {
    super.key,
    this.note,
    this.rule = true,
    this.trailing,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: AppText.sectionTitle,
              color: live ? AppColors.instrument : AppColors.hairlineBright,
            ),
            const SizedBox(width: AppSpace.sm),
            // Flexible, not fixed: several of these legends are long Turkmen
            // phrases and some of them sit in a 340-pixel column, where an
            // unbounded heading overflowed its row.
            // The legend gets the lion's share of the row and the rule takes
            // what is left. Sharing it evenly squeezed a long Turkmen legend in
            // a 340-pixel side column until it broke in the middle of a word.
            Flexible(
              flex: 5,
              child: Text(
                label.toUpperCase(),
                style: AppText.legend(
                  color: live ? AppColors.instrumentGlow : AppColors.label,
                ),
              ),
            ),
            if (rule)
              const Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.only(left: AppSpace.md, right: AppSpace.md),
                  child: Divider(height: 1, thickness: AppStroke.hair, color: AppColors.hairline),
                ),
              )
            else
              const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        if (note != null) ...[
          AppSpace.gapSm,
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(note!, style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary)),
          ),
        ],
        AppSpace.gapMd,
      ],
    );
  }
}

/// A region of the field set aside for one group of readings.
///
/// A hairline frame with a tick cut into each corner, the way a measured plate
/// is cropped. [tone] lights the corner ticks and the frame: a verdict is read
/// off the frame of the thing it is about, so a failing arrangement is legible
/// before a word of it has been read.
class AppPanel extends StatelessWidget {
  final Widget child;
  final AppTone tone;
  final EdgeInsets padding;

  /// A legend drawn inside the panel, above [child].
  final String? heading;

  const AppPanel({
    super.key,
    required this.child,
    this.tone = AppTone.neutral,
    this.padding = AppSpace.panel,
    this.heading,
  });

  @override
  Widget build(BuildContext context) {
    final accented = tone != AppTone.neutral;
    return CustomPaint(
      painter: _FramePainter(
        edge: accented ? tone.accent.withValues(alpha: 0.45) : AppColors.hairline,
        tick: accented ? tone.accent : AppColors.hairlineBright,
        fill: AppColors.panel,
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heading != null) SectionHeading(heading!, rule: false),
            child,
          ],
        ),
      ),
    );
  }
}

/// The frame: a hairline rectangle with the corners struck brighter, cut in
/// from each corner by [AppStroke.tick]. It is the only container shape in the
/// design, and it is drawn rather than assembled from borders so the corner
/// ticks can be a different colour from the edge without Flutter objecting.
class _FramePainter extends CustomPainter {
  final Color edge;
  final Color tick;
  final Color fill;

  const _FramePainter({required this.edge, required this.tick, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = fill);

    final edgePaint = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.hair;
    canvas.drawRect(rect.deflate(0.5), edgePaint);

    final tickPaint = Paint()
      ..color = tick
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.lit;
    const t = AppStroke.tick;
    final w = size.width;
    final h = size.height;
    // Four corners, two strokes each: the crop marks on a measured plate.
    for (final (Offset o, double dx, double dy) in [
      (Offset.zero, 1.0, 1.0),
      (Offset(w, 0), -1.0, 1.0),
      (Offset(0, h), 1.0, -1.0),
      (Offset(w, h), -1.0, -1.0),
    ]) {
      final ox = o.dx + dx * 1;
      final oy = o.dy + dy * 1;
      canvas.drawLine(Offset(ox, oy), Offset(ox + dx * t, oy), tickPaint);
      canvas.drawLine(Offset(ox, oy), Offset(ox, oy + dy * t), tickPaint);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.edge != edge || old.tick != tick || old.fill != fill;
}

/// What a verdict looks like, everywhere it is shown.
enum AppTone {
  neutral,
  pass,
  warn,
  fail;

  Color get accent => switch (this) {
        AppTone.neutral => AppColors.hairlineBright,
        AppTone.pass => AppColors.inTolerance,
        AppTone.warn => AppColors.offNominal,
        AppTone.fail => AppColors.outOfTolerance,
      };

  IconData get icon => switch (this) {
        // An outcome that has not been decided is its own state and must never
        // be drawn as a pass — the same rule the verdict dot already followed.
        AppTone.neutral => Icons.remove_circle_outline,
        AppTone.pass => Icons.check_circle_outline,
        AppTone.warn => Icons.error_outline,
        AppTone.fail => Icons.highlight_off,
      };
}

/// A verdict as a struck chip: mark, tone and word together.
///
/// Colour alone would fail anyone reading this printed or with a colour vision
/// deficiency — and "unconfirmed" and "in tolerance" are the exact pair most
/// often confused. The mark and the word carry it too. The shape is a bracket,
/// not a pill: this is a reading taken off an instrument, and it is squared.
class VerdictChip extends StatelessWidget {
  final AppTone tone;
  final String label;
  final bool dense;

  const VerdictChip({
    super.key,
    required this.tone,
    required this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tone.accent;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpace.sm : AppSpace.md,
        vertical: dense ? AppSpace.xs : AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: AppStroke.hair),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tone.icon, size: dense ? 15 : 18, color: accent),
          SizedBox(width: dense ? AppSpace.xs : AppSpace.sm),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: AppText.legend(
                size: dense ? AppText.caption : AppText.label,
                color: accent,
                tracking: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

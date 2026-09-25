import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';

/// The instrument's chrome: the frame every screen is mounted in, the scale a
/// reading is taken against, and the one authored moment of motion.
///
/// The rule this file exists to hold: the trainee is always looking at a
/// measured field with the instrument's own lettering around it. The stage
/// index down the left says where in the operation they are; the strip across
/// the top names the reading being taken; the field itself is theirs.

// ---------------------------------------------------------------------------
// The frame
// ---------------------------------------------------------------------------

/// One step of the loading operation, as the stage index draws it.
class Stage {
  final String label;
  final String route;
  const Stage(this.label, this.route);
}

/// The operation, in order. The same five steps the flow has always had — this
/// is the breadcrumb the screens used to carry, stood on its end and lettered
/// as a scale, so the trainee reads their position off it the way they read a
/// value off any other scale in the program.
const kStages = <Stage>[
  Stage(AppStrings.breadcrumbWagons, '/consist'),
  Stage(AppStrings.breadcrumbTehnika, '/vehicles'),
  Stage(AppStrings.breadcrumbWagonType, '/wagon-type'),
  Stage(AppStrings.breadcrumbPlacement, '/placement'),
  Stage(AppStrings.breadcrumbEquipment, '/equipment'),
  Stage(AppStrings.breadcrumbFastening, '/securing'),
];

/// The chassis every screen in the flow is mounted in.
///
/// Left: the stage index. Top: the title strip, lettered like the legend on an
/// instrument's face, with whatever readings that screen wants beside it.
/// Bottom right: the one control that advances the operation. Everything else
/// is field.
class InstrumentScaffold extends StatelessWidget {
  /// What this screen is for, in the instrument's own lettering.
  final String title;

  /// A short line under the title — what the trainee is being asked to do.
  final String? subtitle;

  /// 0-based index into [kStages]; [kStages.length] for a screen the trainee
  /// reaches once the operation is over — the analysis, the result sheet —
  /// which draws every stage as done and none as live; or null for a screen
  /// outside the flow entirely (the reference browser).
  final int? step;

  /// Readings and controls that belong to the title strip.
  final List<Widget> actions;

  /// The field.
  final Widget body;

  /// The bar across the foot: the advance control, and anything that has to be
  /// read immediately before it is pressed.
  final Widget? footer;

  /// Drawn over everything — a drag layer, a dialog scrim.
  final Widget? overlay;

  /// Where "back" goes, when this screen has somewhere to go that the stage
  /// index does not already offer.
  final VoidCallback? onBack;

  /// A row of selectors under the title strip — the reference browser's
  /// sections, say.
  final Widget? tabs;

  /// A screen outside the loading operation (the handbook browser) keeps the
  /// rail but drops the five steps from it: an index showing five steps nobody
  /// is on says the trainee is nowhere, while dropping the rail entirely takes
  /// the program's mark and its citation off the screen with it.
  final bool showRail;

  const InstrumentScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.step,
    this.actions = const [],
    this.footer,
    this.overlay,
    this.onBack,
    this.tabs,
    this.showRail = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StageIndex(step: step, showStages: showRail),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TitleStrip(title: title, subtitle: subtitle, actions: actions, onBack: onBack),
                if (tabs != null) tabs!,
                Expanded(
                  child: overlay == null
                      ? body
                      : Stack(children: [Positioned.fill(child: body), overlay!]),
                ),
                if (footer != null) _FooterBar(child: footer!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleStrip extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;

  const _TitleStrip({required this.title, this.subtitle, required this.actions, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xl, AppSpace.xxl, AppSpace.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onBack != null) ...[
                  _RailLink(
                    label: AppStrings.backButtonLabel,
                    icon: Icons.arrow_back,
                    onTap: onBack!,
                    compact: true,
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
                Text(
                  title.toUpperCase(),
                  style: AppText.legend(
                    size: AppText.screenTitle,
                    color: AppColors.textPrimary,
                    tracking: AppText.trackTitle,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    subtitle!,
                    style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: AppSpace.lg), a],
        ],
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  final Widget child;
  const _FooterBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl, vertical: AppSpace.lg),
      decoration: const BoxDecoration(
        color: AppColors.ground,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: child,
    );
  }
}

/// The stage index: the operation drawn down the left edge as a scale.
///
/// Each step is a tick on a vertical rule. Steps behind the trainee are struck
/// and tappable, the live step is lit and carries its number in the
/// instrument's light, steps ahead are dim ticks with no lettering weight —
/// present, so the trainee can see how far the operation runs, but plainly not
/// theirs yet.
class StageIndex extends StatelessWidget {
  final int? step;

  /// Whether the operation's steps are listed.
  ///
  /// Off for a screen outside the operation — the handbook browser. That
  /// screen still gets the rail, because the mark, the program's name and the
  /// citation belong on every screen and a page without them stops looking
  /// like part of the instrument; what it does not get is five steps with
  /// nobody standing on any of them, which would say the trainee is nowhere.
  final bool showStages;

  const StageIndex({super.key, this.step, this.showStages = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      decoration: const BoxDecoration(
        color: AppColors.well,
        border: Border(right: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _RailHead(),
          const SizedBox(height: AppSpace.xl),
          if (showStages)
            for (var i = 0; i < kStages.length; i++)
            _StageRow(
              index: i,
              stage: kStages[i],
              state: step == null
                  ? _StageState.pending
                  : i == step
                      ? _StageState.live
                      : i < step!
                          ? _StageState.done
                          : _StageState.pending,
            ),
          const Spacer(),
          const _RailFoot(),
        ],
      ),
    );
  }
}

class _RailHead extends StatelessWidget {
  const _RailHead();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.lg, AppSpace.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _RailMark(),
              const SizedBox(width: AppSpace.sm),
              Text('RAILSIM', style: AppText.legend(size: AppText.label, color: AppColors.textPrimary, tracking: 3.0)),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            AppStrings.appTitle,
            style: AppText.prose(size: AppText.caption, color: AppColors.labelDim, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// The program's mark: a flatcar in section, drawn with the same hairline the
/// rest of the instrument is drawn with — deck, two axles, and the load's
/// centre line. Fifteen logical pixels of the actual subject, rather than a
/// stock glyph borrowed from a font.
class _RailMark extends StatelessWidget {
  const _RailMark();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(22, 16), painter: _RailMarkPainter());
}

class _RailMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.instrument
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final w = size.width;
    final h = size.height;
    // Deck.
    canvas.drawLine(Offset(0, h * 0.62), Offset(w, h * 0.62), line);
    // Load, in section.
    canvas.drawRect(Rect.fromLTRB(w * 0.18, h * 0.20, w * 0.82, h * 0.62), line);
    // Axles.
    canvas.drawCircle(Offset(w * 0.24, h * 0.82), 2.2, line);
    canvas.drawCircle(Offset(w * 0.76, h * 0.82), 2.2, line);
    // Centre line, the way a plate marks one.
    final dash = Paint()
      ..color = AppColors.instrumentDeep
      ..strokeWidth = 1;
    for (double y = 0; y < h; y += 4) {
      canvas.drawLine(Offset(w / 2, y), Offset(w / 2, y + 2), dash);
    }
  }

  @override
  bool shouldRepaint(_RailMarkPainter oldDelegate) => false;
}

class _RailFoot extends StatelessWidget {
  const _RailFoot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.lg, AppSpace.xl),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RailLink(
            label: AppStrings.referenceBrowserButton,
            icon: Icons.menu_book_outlined,
            onTap: () => context.push('/reference'),
          ),
          const SizedBox(height: AppSpace.sm),
          _RailLink(
            label: AppStrings.mainMenuButton,
            icon: Icons.power_settings_new,
            onTap: () => context.go('/'),
          ),
          const SizedBox(height: AppSpace.lg),
          // The citation is the program's whole claim to be believed, so it is
          // set at reading size in the second text rank, not as fine print in
          // the dimmest colour the palette has.
          Text(
            AppStrings.mainMenuSource,
            style: AppText.prose(
              size: AppText.caption,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailLink extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Shrinks to its label instead of filling the row — for the title strip,
  /// where the link sits above a heading rather than in a column of its own.
  final bool compact;

  const _RailLink({
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_RailLink> createState() => _RailLinkState();
}

class _RailLinkState extends State<_RailLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? AppColors.instrument : AppColors.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.touch,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: Row(
            mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(widget.icon, size: 15, color: color),
              const SizedBox(width: AppSpace.sm),
              if (widget.compact)
                Text(
                  widget.label.toUpperCase(),
                  style: AppText.legend(size: AppText.tick, color: color, tracking: 1.4),
                )
              else
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 2,
                    style: AppText.legend(size: AppText.tick, color: color, tracking: 1.0),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StageState { done, live, pending }

class _StageRow extends StatefulWidget {
  final int index;
  final Stage stage;
  final _StageState state;

  const _StageRow({required this.index, required this.stage, required this.state});

  @override
  State<_StageRow> createState() => _StageRowState();
}

class _StageRowState extends State<_StageRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final live = widget.state == _StageState.live;
    final done = widget.state == _StageState.done;
    final tappable = done;

    final tickColor = live
        ? AppColors.instrument
        : done
            ? AppColors.hairlineBright
            : AppColors.hairline;
    final labelColor = live
        ? AppColors.instrumentGlow
        : done
            ? (_hover ? AppColors.instrument : AppColors.textPrimary)
            : AppColors.labelDim;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: 11),
      child: Row(
        children: [
          // The tick. Live is a filled square on the rule; done is a struck
          // one; pending is a bare rule crossing.
          SizedBox(
            width: 18,
            child: CustomPaint(
              size: const Size(18, 18),
              painter: _StageTickPainter(state: widget.state),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Text(
            (widget.index + 1).toString().padLeft(2, '0'),
            style: AppText.value(size: AppText.tick, color: tickColor, weight: FontWeight.w700),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              widget.stage.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.legend(
                size: AppText.caption,
                color: labelColor,
                weight: live ? FontWeight.w700 : FontWeight.w400,
                tracking: 1.2,
              ),
            ),
          ),
        ],
      ),
    );

    if (!tappable) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: () => context.go(widget.stage.route), child: row),
    );
  }
}

class _StageTickPainter extends CustomPainter {
  final _StageState state;
  const _StageTickPainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    // The rule the whole index hangs on, drawn per row so the scale is
    // continuous from the first step to the last.
    canvas.drawLine(
      Offset(size.width / 2, -11),
      Offset(size.width / 2, size.height + 11),
      Paint()
        ..color = AppColors.hairline
        ..strokeWidth = AppStroke.hair,
    );

    final cx = size.width / 2;
    switch (state) {
      case _StageState.live:
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: 9, height: 9),
          Paint()..color = AppColors.instrument,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: 15, height: 15),
          Paint()
            ..color = AppColors.instrumentDeep
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppStroke.hair,
        );
      case _StageState.done:
        canvas.drawRect(
          Rect.fromCenter(center: Offset(cx, cy), width: 8, height: 8),
          Paint()
            ..color = AppColors.hairlineBright
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      case _StageState.pending:
        canvas.drawLine(
          Offset(cx - 4, cy),
          Offset(cx + 4, cy),
          Paint()
            ..color = AppColors.hairline
            ..strokeWidth = AppStroke.hair,
        );
    }
  }

  @override
  bool shouldRepaint(_StageTickPainter old) => old.state != state;
}

// ---------------------------------------------------------------------------
// Readings
// ---------------------------------------------------------------------------

/// One line of the instrument's readout: what was measured, and what it came
/// to. The leader between them is dotted, the way a parts list on a plate runs
/// its entry out to the number, so a column of readings is scannable without
/// any of them being boxed.
///
/// A reading on its own cannot know how wide the other readings beside it are,
/// so a single [Readout] does not try to align to anything: it sizes to its
/// own value. **A group of readings that must share a right edge is built with
/// [ReadoutTable], not with a column of these.** Reserving a guessed width
/// here is what broke `çeşmede ýok` across two lines in the middle of a word.
class Readout extends StatelessWidget {
  final String label;
  final String value;

  /// The unit, set apart from the number so the number is what the eye lands
  /// on: "2,40" reads first, "m" second.
  final String? unit;

  /// Lights the value. Use for a reading the trainee has just produced.
  final Color valueColor;

  /// Shown after the unit — a citation chip, a verdict mark.
  final Widget? trailing;

  final bool dense;

  const Readout({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor = AppColors.textPrimary,
    this.trailing,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 3 : AppSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          // The label yields before the value does. Some of these labels are a
          // whole grouped record's designation — fourteen object numbers on one
          // line — and a reading whose name pushes its own number off the row
          // has stopped being a reading.
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _labelStyle,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          const Expanded(child: _DottedLeader()),
          const SizedBox(width: AppSpace.sm),
          Text(value, softWrap: false, style: _valueStyle(dense, valueColor)),
          if (unit != null) ...[
            const SizedBox(width: 5),
            Text(unit!, softWrap: false, style: _unitStyle),
          ],
          if (trailing != null) ...[const SizedBox(width: AppSpace.sm), trailing!],
        ],
      ),
    );
  }
}

TextStyle get _labelStyle => AppText.legend(
      size: AppText.caption,
      color: AppColors.labelDim,
      weight: FontWeight.w400,
      tracking: 1.0,
    );

TextStyle _valueStyle(bool dense, Color color) => AppText.value(
      size: dense ? AppText.readoutSmall : AppText.readout,
      color: color,
    );

TextStyle get _unitStyle => AppText.legend(
      size: AppText.caption,
      color: AppColors.textSecondary,
      weight: FontWeight.w400,
      tracking: 0.5,
    );

/// One row of a [ReadoutTable].
class ReadoutRow {
  final String label;
  final String value;
  final String? unit;
  final Color valueColor;

  const ReadoutRow({
    required this.label,
    required this.value,
    this.unit,
    this.valueColor = AppColors.textPrimary,
  });
}

/// A group of readings that share one right edge.
///
/// This is a [Table], and that is the whole point: the value column is sized
/// to the widest value in the group and every row is given that same width, so
/// the numbers line up under each other by construction rather than by a
/// number somebody guessed. Nothing wraps — a value that will not fit makes
/// the column wider, because in a measuring instrument a value broken across
/// two lines is worse than a column that is wide.
class ReadoutTable extends StatelessWidget {
  final List<ReadoutRow> rows;
  final bool dense;

  const ReadoutTable({super.key, required this.rows, this.dense = false});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(),
        1: IntrinsicColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: dense ? 3 : AppSpace.xs),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.label.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle,
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    const Expanded(child: _DottedLeader()),
                    const SizedBox(width: AppSpace.sm),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: dense ? 3 : AppSpace.xs),
                child: Text(
                  row.value,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: _valueStyle(dense, row.valueColor),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: row.unit == null ? 0 : 5,
                  top: dense ? 3 : AppSpace.xs,
                  bottom: dense ? 3 : AppSpace.xs,
                ),
                child: Text(row.unit ?? '', softWrap: false, style: _unitStyle),
              ),
            ],
          ),
      ],
    );
  }
}

class _DottedLeader extends StatelessWidget {
  const _DottedLeader();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(double.infinity, 1), painter: _DottedLeaderPainter());
}

class _DottedLeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x + 1, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLeaderPainter oldDelegate) => false;
}

/// The signature of this instrument: a measured value drawn against the range
/// the handbook allows.
///
/// The track is the whole span the reading could plausibly take. The lit band
/// is what the handbook permits. The needle is where the trainee's own
/// placement actually landed, and it runs to its reading on a damped curve
/// rather than appearing at it, so a value that changes as they drag is
/// followed rather than noticed. Out of the band, the needle turns red and the
/// band stays lit: the trainee sees both where they are and where they should
/// have been, which is the whole lesson.
class ToleranceScale extends StatelessWidget {
  /// The reading. Null means not taken yet — the scale draws its band and no
  /// needle, which is an honest empty state rather than a zero.
  final double? value;

  /// The handbook's permitted range.
  final double min;
  final double max;

  /// The span drawn. Defaults to the band plus a quarter of its width at each
  /// end, so a value just outside is still on the scale.
  final double? spanMin;
  final double? spanMax;

  /// How a number is lettered under the scale.
  final String Function(double) format;

  final String? unit;

  const ToleranceScale({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    this.spanMin,
    this.spanMax,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final pad = math.max((max - min) * 0.35, 0.001);
    final lo = spanMin ?? (min - pad);
    final hi = spanMax ?? (max + pad);
    final inBand = value != null && value! >= min && value! <= max;
    // A scale does not rescale itself to swallow an absurd reading. Stretching
    // the span to include a value ten times the permitted range would shrink
    // the band to a sliver and quietly make a wild placement look like a near
    // miss. The needle pegs at the end of the scale instead, drawn as a
    // chevron, and the figure underneath still says what was actually
    // measured.
    final offScale = value != null && (value! < lo || value! > hi);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 34,
          child: TweenAnimationBuilder<double>(
            // Begin at the band's lower limit so the needle is seen running
            // to its first reading; afterwards TweenAnimationBuilder carries
            // it from wherever it currently stands to the new value.
            tween: Tween<double>(begin: min, end: value ?? min),
            duration: AppMotion.reading,
            curve: AppMotion.needle,
            builder: (context, needle, _) => CustomPaint(
              size: const Size(double.infinity, 34),
              painter: _ScalePainter(
                lo: lo,
                hi: hi,
                bandMin: min,
                bandMax: max,
                needle: value == null ? null : needle,
                inBand: inBand,
                offScale: offScale,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            Text(format(min), style: AppText.value(size: AppText.tick, color: AppColors.instrumentDeep)),
            const Spacer(),
            if (value != null)
              Text(
                unit == null ? format(value!) : '${format(value!)} $unit',
                style: AppText.value(
                  size: AppText.readoutSmall,
                  color: inBand ? AppColors.instrumentGlow : AppColors.outOfTolerance,
                ),
              ),
            const Spacer(),
            Text(format(max), style: AppText.value(size: AppText.tick, color: AppColors.instrumentDeep)),
          ],
        ),
      ],
    );
  }
}

class _ScalePainter extends CustomPainter {
  final double lo;
  final double hi;
  final double bandMin;
  final double bandMax;
  final double? needle;
  final bool inBand;

  /// The reading is past an end of the scale: the needle pegs there and is
  /// drawn as a chevron pointing off the scale rather than as a mark on it.
  final bool offScale;

  const _ScalePainter({
    required this.lo,
    required this.hi,
    required this.bandMin,
    required this.bandMax,
    required this.needle,
    required this.inBand,
    required this.offScale,
  });

  double _x(double v, double w) => ((v - lo) / (hi - lo)).clamp(0.0, 1.0) * w;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final baseline = size.height - 10;

    // The track.
    canvas.drawLine(
      Offset(0, baseline),
      Offset(w, baseline),
      Paint()
        ..color = AppColors.hairline
        ..strokeWidth = AppStroke.hair,
    );

    // Minor ticks, every twentieth of the span: what makes it a scale and not
    // a progress bar.
    final tickPaint = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = AppStroke.hair;
    for (var i = 0; i <= 20; i++) {
      final x = w * i / 20;
      final long = i % 5 == 0;
      canvas.drawLine(Offset(x, baseline), Offset(x, baseline + (long ? 5 : 3)), tickPaint);
    }

    // The permitted band.
    final x1 = _x(bandMin, w);
    final x2 = _x(bandMax, w);
    final band = Rect.fromLTRB(x1, baseline - 9, x2, baseline);
    canvas.drawRect(band, Paint()..color = AppColors.instrumentDeep.withValues(alpha: 0.55));
    canvas.drawRect(
      band,
      Paint()
        ..color = AppColors.instrument.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.hair,
    );

    if (needle == null) return;

    // The needle: a full-height stroke with a solid head, drawn over the band
    // so an in-tolerance reading reads as a struck line on a lit field.
    final nx = _x(needle!, w);
    final color = inBand ? AppColors.instrumentGlow : AppColors.outOfTolerance;

    if (offScale) {
      // Pegged: a double chevron at the end it ran past, and no needle on the
      // scale, because there is nothing on the scale to point at.
      final atRight = needle! > hi;
      final x = atRight ? w - 2 : 2;
      final dir = atRight ? 1.0 : -1.0;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppStroke.lit;
      for (var i = 0; i < 2; i++) {
        final base = x - dir * i * 6;
        canvas.drawLine(Offset(base - dir * 6, baseline - 11), Offset(base, baseline - 4), paint);
        canvas.drawLine(Offset(base, baseline - 4), Offset(base - dir * 6, baseline + 3), paint);
      }
      return;
    }

    canvas.drawLine(
      Offset(nx, 0),
      Offset(nx, baseline + 6),
      Paint()
        ..color = color
        ..strokeWidth = AppStroke.lit,
    );
    final head = Path()
      ..moveTo(nx, 9)
      ..lineTo(nx - 5, 0)
      ..lineTo(nx + 5, 0)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScalePainter old) =>
      old.lo != lo ||
      old.hi != hi ||
      old.bandMin != bandMin ||
      old.bandMax != bandMax ||
      old.needle != needle ||
      old.inBand != inBand ||
      old.offScale != offScale;
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

/// The one authored moment: a screen settling into place.
///
/// Children are already visible in the tree and rise the last few pixels into
/// position on an exponential ease-out, staggered down the column so the eye
/// is led from the first reading to the last. Nothing else in the program
/// animates on arrival.
class FieldEntrance extends StatefulWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final Duration stagger;

  const FieldEntrance({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.stagger = const Duration(milliseconds: 55),
  });

  @override
  State<FieldEntrance> createState() => _FieldEntranceState();
}

class _FieldEntranceState extends State<FieldEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.settle +
        widget.stagger * math.max(widget.children.length - 1, 0),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _c.duration!.inMilliseconds;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: widget.crossAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _settled(i, total, widget.children[i]),
          ],
        );
      },
    );
  }

  Widget _settled(int i, int total, Widget child) {
    final start = (widget.stagger.inMilliseconds * i) / total;
    final end = math.min(1.0, start + AppMotion.settle.inMilliseconds / total);
    final t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: AppMotion.needle),
    ).value;
    return Opacity(
      opacity: 0.35 + 0.65 * t,
      child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty
// ---------------------------------------------------------------------------

/// A reading that has not been taken yet.
///
/// Every screen in the flow can be arrived at before the step that fills it,
/// and a bare sentence floating in the middle of a black field says only that
/// something is wrong. This says the same thing the way the instrument says
/// everything else: a legend, a dashed frame where the content will go, the
/// sentence inside it, and — when there is one — the control that fills it.
class EmptyField extends StatelessWidget {
  final String legend;
  final String message;

  /// The way out: the step that produces what is missing.
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyField({
    super.key,
    required this.legend,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CustomPaint(
          painter: _EmptyFramePainter(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  legend.toUpperCase(),
                  style: AppText.legend(size: AppText.caption, color: AppColors.labelDim, tracking: 2.0),
                ),
                const SizedBox(height: AppSpace.md),
                Text(message, style: AppText.prose(color: AppColors.textSecondary)),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpace.xl),
                  OutlinedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(actionLabel!.toUpperCase()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.hair;
    // A dashed frame: the region is reserved, not filled.
    const dash = 6.0;
    const gap = 6.0;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset((x + dash).clamp(0, size.width), 0), paint);
      canvas.drawLine(
        Offset(x, size.height),
        Offset((x + dash).clamp(0, size.width), size.height),
        paint,
      );
    }
    for (double y = 0; y < size.height; y += dash + gap) {
      canvas.drawLine(Offset(0, y), Offset(0, (y + dash).clamp(0, size.height)), paint);
      canvas.drawLine(
        Offset(size.width, y),
        Offset(size.width, (y + dash).clamp(0, size.height)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyFramePainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

/// The control that advances the operation.
///
/// One per screen, at the foot on the right, lit in the instrument's colour
/// because pressing it is the only thing on the screen that changes what the
/// program is doing. Disabled it goes dark and says, in the strip beside it,
/// what is still missing — a dead button that will not say why is the single
/// most common way a step-based program wastes a trainee's time.
class AdvanceButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// Why the control is dark, when it is.
  final String? blockedReason;

  final IconData icon;

  const AdvanceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.blockedReason,
    this.icon = Icons.arrow_forward,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!enabled && blockedReason != null)
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppColors.offNominal),
                const SizedBox(width: AppSpace.sm),
                Flexible(
                  child: Text(
                    blockedReason!,
                    style: AppText.prose(size: AppText.bodySmall, color: AppColors.offNominal),
                  ),
                ),
              ],
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpace.lg),
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label.toUpperCase()),
        ),
      ],
    );
  }
}

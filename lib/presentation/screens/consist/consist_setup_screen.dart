import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/consist_providers.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/instrument.dart';

/// Step 1 of the loading flow: how many wagons the echelon needs.
///
/// The customer brief (HGM.pptx, slide 2) asks for this to be chosen by
/// spinning a wheel that adds one wagon per turn until the user stops it, and
/// ships the artwork for it — so that is the primary control here, with plain
/// +/- buttons and a typed figure alongside so a count can also just be
/// entered directly.
///
/// The wagon *type* is deliberately not chosen here. It comes in step 3, once
/// the vehicles are known, because which flatcars are permitted depends on
/// what is being loaded onto them.
class ConsistSetupScreen extends ConsumerStatefulWidget {
  const ConsistSetupScreen({super.key});

  @override
  ConsumerState<ConsistSetupScreen> createState() => _ConsistSetupScreenState();
}

class _ConsistSetupScreenState extends ConsumerState<ConsistSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wheel;

  /// Full turns already counted, so the wagon total only rises when the wheel
  /// actually completes a revolution rather than on every animation frame.
  int _turnsCounted = 0;

  @override
  void initState() {
    super.initState();
    _wheel = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addListener(_onWheelTick);
  }

  @override
  void dispose() {
    _wheel.removeListener(_onWheelTick);
    _wheel.dispose();
    super.dispose();
  }

  void _onWheelTick() {
    if (!_wheel.isAnimating) return;
    final turns = _wheel.lastElapsedDuration == null
        ? 0
        : _wheel.lastElapsedDuration!.inMilliseconds ~/ _wheel.duration!.inMilliseconds;
    if (turns > _turnsCounted) {
      _turnsCounted = turns;
      _addWagons(1);
    }
  }

  void _toggleSpin() {
    if (_wheel.isAnimating) {
      _wheel.stop();
    } else {
      _turnsCounted = 0;
      _wheel.repeat();
    }
    setState(() {});
  }

  void _addWagons(int delta) {
    final next = (ref.read(wagonCountProvider) + delta).clamp(0, 99);
    ref.read(wagonCountProvider.notifier).state = next;
    // Keep the consist itself in step with the count as soon as a wagon type
    // is known; before step 3 there is nothing to build wagons out of yet.
    final platformId = ref.read(selectedWagonTypeProvider);
    if (platformId != null) {
      ref.read(consistProvider.notifier).setWagons(count: next, platformId: platformId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(wagonCountProvider);

    return InstrumentScaffold(
      title: AppStrings.consistSetupTitle,
      subtitle: AppStrings.consistSetupSubtitle,
      step: 0,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 980;
          final wheel = _WagonCounterWheel(
            controller: _wheel,
            spinning: _wheel.isAnimating,
            onToggle: _toggleSpin,
            count: count,
          );
          final controls = _CountControls(
            count: count,
            onAdd: () => _addWagons(1),
            onRemove: () => _addWagons(-1),
          );

          return SingleChildScrollView(
            padding: AppSpace.screen,
            child: stacked
                ? Column(children: [controls, const SizedBox(height: AppSpace.xxl), wheel])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: controls),
                      const SizedBox(width: AppSpace.xxl),
                      Expanded(flex: 4, child: wheel),
                    ],
                  ),
          );
        },
      ),
      footer: AdvanceButton(
        label: AppStrings.consistNextButton,
        onPressed: count > 0 ? () => context.go('/vehicles') : null,
        blockedReason: count > 0 ? null : AppStrings.consistNoWagonsYet,
      ),
    );
  }
}

/// The counting dial the customer brief asks for — one wagon added per turn,
/// spun until the trainee stops it.
///
/// It is drawn, not photographed. The brief ships a photograph of a ship's
/// helm for this control, and a pasted object with wooden spokes and aircraft
/// decals is the one thing on any screen in this program that is neither
/// measured nor drawn in the instrument's own stroke. The interaction the
/// brief actually specifies — turn it, count the turns, stop it — is kept
/// exactly; what changes is that the thing turning is a graduated dial with a
/// pointer and an index mark, in the same hairline the rest of the instrument
/// is built from.
class _WagonCounterWheel extends StatelessWidget {
  final AnimationController controller;
  final bool spinning;
  final VoidCallback onToggle;
  final int count;

  const _WagonCounterWheel({
    required this.controller,
    required this.spinning,
    required this.onToggle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              onTap: onToggle,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => CustomPaint(
                      painter: _DialPainter(
                        turns: controller.value,
                        spinning: spinning,
                        count: count,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AppSpace.gapLg,
          OutlinedButton.icon(
            onPressed: onToggle,
            icon: Icon(spinning ? Icons.stop : Icons.rotate_right, size: 18),
            label: Text(
              (spinning ? AppStrings.consistSpinStop : AppStrings.consistSpinStart).toUpperCase(),
            ),
          ),
          AppSpace.gapSm,
          Text(
            AppStrings.consistSpinHint,
            textAlign: TextAlign.center,
            style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  /// Fraction of a full revolution, 0 to 1.
  final double turns;
  final bool spinning;
  final int count;

  const _DialPainter({
    required this.turns,
    required this.spinning,
    required this.count,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 10;
    final angle = turns * 2 * math.pi;

    final hair = Paint()
      ..color = AppColors.hairline
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.hair;
    final bright = Paint()
      ..color = AppColors.hairlineBright
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.hair;
    final lit = Paint()
      ..color = spinning ? AppColors.instrument : AppColors.instrumentDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppStroke.lit;

    // The face: two rings and the well they sit on.
    canvas.drawCircle(centre, r, Paint()..color = AppColors.well);
    canvas.drawCircle(centre, r, bright);
    canvas.drawCircle(centre, r * 0.72, hair);
    canvas.drawCircle(centre, r * 0.24, hair);

    // The graduations turn with the dial: twenty-four of them, every sixth one
    // long, so a revolution is countable rather than just visibly spinning.
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);
    for (var i = 0; i < 24; i++) {
      final a = i * 2 * math.pi / 24;
      final long = i % 6 == 0;
      final outer = r * 0.98;
      final inner = r * (long ? 0.80 : 0.88);
      canvas.drawLine(
        Offset(math.cos(a) * inner, math.sin(a) * inner),
        Offset(math.cos(a) * outer, math.sin(a) * outer),
        long ? bright : hair,
      );
    }
    // The pointer: one arm from the hub out to the graduations, and a stub
    // opposite it so the dial reads as balanced rather than as a hand.
    canvas.drawLine(Offset(r * 0.24, 0), Offset(r * 0.80, 0), lit);
    canvas.drawLine(Offset(-r * 0.24, 0), Offset(-r * 0.44, 0), hair);
    canvas.drawCircle(
      Offset(r * 0.80, 0),
      3.5,
      Paint()..color = spinning ? AppColors.instrument : AppColors.instrumentDeep,
    );
    canvas.restore();

    // The index mark stays still at the top: the pointer passing it is what
    // one wagon is.
    final index = Path()
      ..moveTo(centre.dx, centre.dy - r - 1)
      ..lineTo(centre.dx - 5, centre.dy - r - 10)
      ..lineTo(centre.dx + 5, centre.dy - r - 10)
      ..close();
    canvas.drawPath(index, Paint()..color = AppColors.instrumentGlow);

    // The count, read off the middle of the face.
    final tp = TextPainter(
      text: TextSpan(
        text: count.toString().padLeft(2, '0'),
        style: AppText.value(
          size: 30,
          color: count > 0 ? AppColors.instrumentGlow : AppColors.labelDim,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.turns != turns || old.spinning != spinning || old.count != count;
}

class _CountControls extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CountControls({
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return FieldEntrance(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(AppStrings.consistWagonCountLabel, live: true),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CountKey(icon: Icons.remove, onTap: count > 0 ? onRemove : null, tooltip: AppStrings.consistRemoveWagon),
            const SizedBox(width: AppSpace.lg),
            // The count itself, lettered at the size a figure read across a
            // desk wants to be, in the instrument's light because it is the
            // one value this screen exists to produce.
            Text(
              count.toString().padLeft(2, '0'),
              style: AppText.value(
                size: AppText.counter,
                color: count > 0 ? AppColors.instrumentGlow : AppColors.labelDim,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'WAGON',
                style: AppText.legend(size: AppText.caption, color: AppColors.textSecondary, tracking: 2.0),
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            _CountKey(icon: Icons.add, onTap: onAdd, tooltip: AppStrings.consistAddWagon),
          ],
        ),
        AppSpace.gapLg,
        // The consist as it stands: one plan symbol per wagon, so the number
        // above is also a train the trainee can see the length of.
        _ConsistStrip(count: count),
        AppSpace.gapMd,
        // The footer already says what is missing when the count is zero, so
        // this line only speaks once there is something to report.
        if (count > 0)
          Text(
            AppStrings.consistWagonCountValue(count),
            style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

/// A square key on the instrument's face. Not a Material icon button: those
/// arrive round, tinted and elevated, and none of the three belong here.
class _CountKey extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  const _CountKey({required this.icon, required this.onTap, required this.tooltip});

  @override
  State<_CountKey> createState() => _CountKeyState();
}

class _CountKeyState extends State<_CountKey> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = !enabled
        ? AppColors.labelDim
        : _hover
            ? AppColors.instrumentGlow
            : AppColors.label;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.touch,
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled && _hover ? AppColors.instrument.withValues(alpha: 0.10) : AppColors.well,
              border: Border.all(
                color: enabled && _hover ? AppColors.instrument : AppColors.hairlineBright,
              ),
            ),
            child: Icon(widget.icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

/// The echelon drawn as it is counted: a locomotive tick and one flatcar plan
/// symbol per wagon, on the track rule.
class _ConsistStrip extends StatelessWidget {
  final int count;
  const _ConsistStrip({required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: CustomPaint(
        size: const Size(double.infinity, 58),
        painter: _ConsistStripPainter(count: count),
      ),
    );
  }
}

class _ConsistStripPainter extends CustomPainter {
  final int count;
  const _ConsistStripPainter({required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    final rail = size.height - 14;
    final track = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, rail), Offset(size.width, rail), track);
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, rail), Offset(x, rail + 3), track);
    }

    if (count == 0) return;

    const gap = 4.0;
    // Wagons shrink to fit rather than running off the edge: the strip is a
    // reading of the whole consist, so all of it has to be on the scale.
    final unit = ((size.width - 30) / count).clamp(6.0, 56.0);
    final w = unit - gap;

    final loco = Paint()..color = AppColors.instrumentDeep;
    canvas.drawRect(Rect.fromLTWH(0, rail - 24, 24, 24), loco);

    final body = Paint()
      ..color = AppColors.instrument
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final deck = Paint()..color = AppColors.instrument.withValues(alpha: 0.18);

    for (var i = 0; i < count; i++) {
      final x = 30 + i * unit;
      if (x > size.width) break;
      final r = Rect.fromLTWH(x, rail - 18, w, 18);
      canvas.drawRect(r, deck);
      canvas.drawRect(r, body);
      canvas.drawLine(Offset(x + w * 0.2, rail), Offset(x + w * 0.2, rail + 4), body);
      canvas.drawLine(Offset(x + w * 0.8, rail), Offset(x + w * 0.8, rail + 4), body);
    }
  }

  @override
  bool shouldRepaint(_ConsistStripPainter old) => old.count != count;
}

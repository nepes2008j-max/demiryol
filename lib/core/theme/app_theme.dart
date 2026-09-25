import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The instrument's palette.
///
/// RailSim is not a dashboard and not a game: it is the readout of a measured
/// field. The trainee puts a real vehicle and real securing hardware on a real
/// flatcar, in metres, and the handbook answers back. So the interface is lit
/// the way a measuring instrument is lit — a near-black field, one instrument
/// light, and two alarm colours that are never spent on anything decorative.
///
/// The rules that keep it one instrument rather than a colour scheme:
///
/// * [instrument] means *measured*. A value the app has actually computed, a
///   thing the trainee has actually placed, the step they are actually on, the
///   control that will actually act. Nothing inert is ever lit with it.
/// * [offNominal] and [outOfTolerance] are alarm colours and belong to
///   verdicts only. A heading, a border or a decoration may never use them.
/// * Everything else is the field and its lettering: four greys for ground and
///   rules, four for type. If a new colour seems necessary, the answer is
///   almost always a different weight, size or rule instead.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------- the field

  /// The measured field itself — the ground the whole instrument sits on.
  static const Color ground = Color(0xFF070A0E);

  /// A region of the field set aside for one group of readings. One step up
  /// from [ground]; a panel is told apart by its hairline and its corner
  /// ticks, not by being a lighter box.
  static const Color panel = Color(0xFF0D1219);

  /// The one surface above a panel — a selected row, a menu, a dialog.
  static const Color panelRaised = Color(0xFF141C25);

  /// Below the field: the inside of an input, an inset well, a track.
  static const Color well = Color(0xFF04070A);

  // ---------------------------------------------------------------- the rules

  /// The hairline every division in the interface is drawn with. There is one
  /// line weight in this design — 1 logical pixel — and this is its colour.
  static const Color hairline = Color(0xFF1D2732);

  /// The same line where it has to be read rather than felt: a panel's frame,
  /// a scale's baseline, the edge of a control.
  static const Color hairlineBright = Color(0xFF33424F);

  // ----------------------------------------------------------- the instrument

  /// The instrument light. One hue, and it always means the same thing:
  /// measured, live, confirmed, actionable.
  static const Color instrument = Color(0xFF5FD8F5);

  /// The instrument light at rest — a scale's lit band, an idle tick, the
  /// ghost of a value that has not been taken yet.
  static const Color instrumentDeep = Color(0xFF11566B);

  /// The filament: the brightest point of the light, for the needle itself and
  /// for the single character a reading turns on.
  static const Color instrumentGlow = Color(0xFFB6EFFF);

  // ------------------------------------------------------------ the machine

  /// Vehicle paintwork, in the flat elevations and plans.
  ///
  /// The machine is not lit with [instrument]: the instrument's light means a
  /// reading, and a vehicle is the thing being read. It is drawn in the
  /// service green the three-dimensional view already paints it in — the
  /// handbook's own plates colour it that way — desaturated enough to sit on
  /// the near-black field without competing with the securing gear on top of
  /// it, which is what the trainee is actually placing.
  static const Color vehicleBody = Color(0xFF313A1F);
  static const Color vehicleEdge = Color(0xFF8E9C66);
  static const Color vehicleAccent = Color(0xFF48532A);

  // ------------------------------------------------------------ the verdicts

  /// Inside the handbook's stated range. Deliberately the same light as
  /// [instrument]: an in-tolerance reading is the instrument agreeing with
  /// itself, not a third colour arriving to say so.
  static const Color inTolerance = instrument;

  /// The handbook does not confirm this — an unconfirmed option, a missing
  /// dimension, a check that could not be computed. Never a failure.
  static const Color offNominal = Color(0xFFF2B23C);

  /// Outside the handbook's stated range. The only red in the interface.
  static const Color outOfTolerance = Color(0xFFFF5C4D);

  // ------------------------------------------------------------- the type

  /// Prose, values, anything meant to be read.
  static const Color textPrimary = Color(0xFFE6EDF3);

  /// The second rank: a hint under a control, a unit after a value, a caption.
  static const Color textSecondary = Color(0xFF8FA1B1);

  /// Lettering on the instrument's own chrome — section headings, scale
  /// legends, column heads. Set in mono and tracked, never in prose.
  static const Color label = Color(0xFFB4C5D3);

  /// Chrome lettering that is present but not addressed: a step not reached
  /// yet, a disabled control's word, a tick that is only there for scale.
  ///
  /// Dim is a rank, not an excuse to be unreadable. This is measured at 5.1:1
  /// against [ground] — it was 3.9:1, which failed at the caption and tick
  /// sizes it is mostly used at, and those sizes carry the readout labels and
  /// the handbook citation, which is the one thing in this program that may
  /// never be hard to read.
  static const Color labelDim = Color(0xFF74838F);
}

/// The type scale.
///
/// Two families, both bundled in `assets/fonts/` — the machine this runs on is
/// offline, so nothing is fetched — and both covering the Turkmen letters the
/// whole interface is written in:
///
/// * [sans] — Noto Sans, for prose: descriptions, notes, instructions.
/// * [mono] — Noto Sans Mono, for everything the instrument itself says:
///   headings, labels, units, citations, counts and every measured value.
///
/// The split is the design. In this world the chrome is lettered like an
/// instrument's silkscreen — mono, uppercase, tracked wide — and prose is set
/// in a humanist sans so a paragraph is still a paragraph. Mono is used here
/// for measurement and legend, which is what mono is for, and never as a
/// costume for the word "technical".
///
/// Sizes are the *displayed* sizes; nothing scales them further. The interface
/// is read for a long stretch by one person at a desk, so nothing is lettered
/// small to fit more in — raising the whole scale for a larger screen is one
/// edit here.
class AppText {
  AppText._();

  static const sans = 'NotoSans';
  static const mono = 'NotoSansMono';

  /// The instrument's own name, on the opening screen.
  static const display = 40.0;

  /// A single number read across the desk — the wagon count on the consist
  /// step, a score on the result.
  static const counter = 66.0;

  /// Screen titles, set in mono and tracked.
  static const screenTitle = 22.0;

  /// A measured value: a dimension, a load, an angle. Mono, always.
  static const readout = 22.0;

  /// Card headings — a vehicle designation, a wagon name.
  static const cardTitle = 21.0;

  /// A measured value inside a dense row.
  static const readoutSmall = 16.0;

  /// Section headings ("BERKITME USULY"). Mono, uppercase, tracked.
  static const sectionTitle = 16.0;

  /// Default reading size for prose.
  static const body = 17.0;

  /// Secondary prose: hints, notes, captions under a control.
  static const bodySmall = 15.0;

  /// Data values and short labels beside them.
  static const label = 16.0;

  /// The smallest lettering in the interface — badges, citation chips, the
  /// caption under a figure. Nothing may be smaller than this.
  static const caption = 13.5;

  /// The legend under a scale's tick marks. The one thing allowed below
  /// [caption], because it is part of a drawn scale rather than of the prose.
  static const tick = 12.0;

  /// Tracking for mono chrome lettering. Silkscreen on an instrument is set
  /// wide; this is what makes a mono label read as a legend rather than as
  /// code.
  static const double trackWide = 1.6;
  static const double trackTitle = 2.4;

  // Labels lettered into a diagram by a CustomPainter deliberately do NOT come
  // from this scale: they sit inside the drawing, where a name at interface
  // size covers the thing it names, and each painter sizes its own against the
  // geometry around it.

  /// Chrome lettering: mono, uppercase, tracked. Every legend, column head and
  /// section title in the interface comes from here.
  static TextStyle legend({
    double size = sectionTitle,
    Color color = AppColors.label,
    FontWeight weight = FontWeight.w700,
    double? tracking,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: tracking ?? trackWide,
        color: color,
        height: 1.2,
      );

  /// A measured value. Mono, tabular by construction, never tracked — a number
  /// is read as a quantity, not as a legend.
  static TextStyle value({
    double size = readout,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0,
        color: color,
        height: 1.15,
      );

  /// Prose.
  static TextStyle prose({
    double size = body,
    Color color = AppColors.textPrimary,
    FontWeight weight = FontWeight.w400,
    double height = 1.45,
  }) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );
}

/// The spacing scale. Everything is a multiple of four, and a gap means a
/// relationship: [xs] inside a line, [sm] between lines of one thought, [md]
/// between thoughts, [lg] between blocks, [xl] between sections, [xxl] between
/// a section and an unrelated one.
class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// The gutter a screen's own content is inset by.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: xxl, vertical: xl);

  /// The padding inside a panel.
  static const EdgeInsets panel = EdgeInsets.all(lg);

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);
}

/// Corners, in a world that has none.
///
/// An instrument's face is cut square. A panel is told apart from the field by
/// a hairline and by the ticks at its corners, so there is nothing left for a
/// radius to do, and a rounded rectangle here would read as consumer software
/// pretending to be a measuring device. These constants stay because forty
/// widgets name them; they are all zero, and they should stay zero.
class AppRadius {
  AppRadius._();

  static const double panel = 0;
  static const double card = 0;
  static const double chip = 0;
}

/// The one line weight in the design.
class AppStroke {
  AppStroke._();

  static const double hair = 1.0;

  /// The lit edge of something selected or measured — still a hairline, drawn
  /// twice as heavy so it reads as struck rather than as a second weight.
  static const double lit = 2.0;

  /// The length of a corner tick on a panel frame.
  static const double tick = 9.0;
}

/// Motion, as a material.
///
/// The instrument has exactly one authored moment: a needle taking a reading.
/// Screens settle in from an already-visible state, values run to their mark
/// on an exponential ease-out, and nothing else moves. Anything that would
/// animate for its own sake is not part of this design.
class AppMotion {
  AppMotion._();

  /// A needle running to its reading, a scale lighting its band.
  static const Duration reading = Duration(milliseconds: 620);

  /// A control answering a pointer.
  static const Duration touch = Duration(milliseconds: 140);

  /// A screen settling.
  static const Duration settle = Duration(milliseconds: 420);

  /// Exponential ease-out: fast off the mark, long tail into rest. What a
  /// damped needle actually does.
  static const Curve needle = Curves.easeOutExpo;
  static const Curve ease = Curves.easeOutCubic;
}

class AppTheme {
  AppTheme._();

  /// The instrument is read at a desk, indoors, for a long stretch, and the
  /// thing being read is a dark field with light drawn on it — the vehicle,
  /// the deck, the lashings, the dimension lines. A light interface around a
  /// dark field would make the field a hole in the page. So: dark, and only
  /// dark.
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = base.colorScheme.copyWith(
      primary: AppColors.instrument,
      onPrimary: AppColors.ground,
      primaryContainer: AppColors.instrumentDeep,
      onPrimaryContainer: AppColors.instrumentGlow,
      secondary: AppColors.label,
      onSecondary: AppColors.ground,
      secondaryContainer: AppColors.panelRaised,
      onSecondaryContainer: AppColors.textPrimary,
      surface: AppColors.panel,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.panelRaised,
      outline: AppColors.hairline,
      outlineVariant: AppColors.hairline,
      error: AppColors.outOfTolerance,
      onError: AppColors.ground,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ground,
      canvasColor: AppColors.ground,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.instrument.withValues(alpha: 0.06),
      hoverColor: AppColors.instrument.withValues(alpha: 0.05),
      focusColor: AppColors.instrument.withValues(alpha: 0.12),
      cardTheme: const CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: AppSpace.xs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.legend(
          size: AppText.screenTitle,
          color: AppColors.textPrimary,
          tracking: AppText.trackTitle,
        ),
        toolbarHeight: 68,
      ),
      textTheme: _textTheme(base.textTheme),
      dividerColor: AppColors.hairline,
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: AppStroke.hair,
        space: AppSpace.xl,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.instrument,
          foregroundColor: AppColors.ground,
          disabledBackgroundColor: AppColors.panelRaised,
          disabledForegroundColor: AppColors.labelDim,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          textStyle: AppText.legend(
            size: AppText.label,
            color: AppColors.ground,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.instrument,
          disabledForegroundColor: AppColors.labelDim,
          side: const BorderSide(color: AppColors.hairlineBright),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          textStyle: AppText.legend(size: AppText.label),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.instrument,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: AppText.legend(size: AppText.label, color: AppColors.instrument),
        ),
      ),
      iconTheme: const IconThemeData(size: 24, color: AppColors.label),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.label,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle: AppText.prose(),
        subtitleTextStyle: AppText.prose(
          size: AppText.bodySmall,
          color: AppColors.textSecondary,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.panelRaised,
          border: Border.fromBorderSide(BorderSide(color: AppColors.hairlineBright)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        waitDuration: const Duration(milliseconds: 400),
        textStyle: AppText.prose(size: AppText.bodySmall),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.hairlineBright),
        ),
        titleTextStyle: AppText.legend(
          size: AppText.cardTitle,
          color: AppColors.textPrimary,
          tracking: AppText.trackTitle,
        ),
        contentTextStyle: AppText.prose(),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.panelRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.hairlineBright),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.well,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: AppText.prose(color: AppColors.labelDim),
        labelStyle: AppText.legend(size: AppText.caption, color: AppColors.labelDim),
        floatingLabelStyle: AppText.legend(size: AppText.caption, color: AppColors.instrument),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.instrument, width: AppStroke.lit),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.outOfTolerance),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.panelRaised,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: AppColors.instrumentDeep),
        ),
        contentTextStyle: AppText.prose(),
      ),
      // The surfaces nobody designs. A scrollbar, a caret, a selection and a
      // focus ring all ship with defaults that belong to no design system, and
      // they are the cheapest tell that a program was assembled rather than
      // built. They are part of the instrument here.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? AppColors.instrumentDeep
              : AppColors.hairlineBright,
        ),
        trackColor: const WidgetStatePropertyAll(AppColors.well),
        trackBorderColor: const WidgetStatePropertyAll(AppColors.hairline),
        thickness: const WidgetStatePropertyAll(9),
        radius: Radius.zero,
        crossAxisMargin: 0,
        mainAxisMargin: 0,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.instrument,
        selectionColor: AppColors.instrument.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.instrument,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.instrument,
        linearTrackColor: AppColors.well,
        circularTrackColor: AppColors.well,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.instrument,
        inactiveTrackColor: AppColors.hairline,
        thumbColor: AppColors.instrumentGlow,
        overlayColor: Colors.transparent,
        trackHeight: 2,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: const BorderSide(color: AppColors.hairlineBright),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.instrument
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.ground),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.panel,
        side: const BorderSide(color: AppColors.hairline),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        labelStyle: AppText.legend(size: AppText.caption),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
      ),
    );
  }

  /// The window's own chrome, on the platforms that let a program set it.
  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarColor: AppColors.ground,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.ground,
  );

  static TextTheme _textTheme(TextTheme base) {
    return base
        .copyWith(
          // Display and title ranks are the instrument's silkscreen: mono,
          // tracked. Body ranks are prose: sans, untracked.
          displayLarge: AppText.legend(size: AppText.display, color: AppColors.textPrimary, tracking: AppText.trackTitle),
          displayMedium: AppText.legend(size: AppText.display, color: AppColors.textPrimary, tracking: AppText.trackTitle),
          displaySmall: AppText.legend(size: AppText.display, color: AppColors.textPrimary, tracking: AppText.trackTitle),
          headlineLarge: AppText.legend(size: AppText.screenTitle, color: AppColors.textPrimary, tracking: AppText.trackTitle),
          headlineMedium: AppText.legend(size: AppText.screenTitle, color: AppColors.textPrimary, tracking: AppText.trackTitle),
          headlineSmall: AppText.legend(size: AppText.cardTitle, color: AppColors.textPrimary),
          titleLarge: AppText.legend(size: AppText.cardTitle, color: AppColors.textPrimary),
          titleMedium: AppText.legend(size: AppText.sectionTitle),
          titleSmall: AppText.legend(size: AppText.label),
          bodyLarge: AppText.prose(),
          bodyMedium: AppText.prose(),
          bodySmall: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary),
          labelLarge: AppText.legend(size: AppText.label),
          labelMedium: AppText.legend(size: AppText.caption),
          labelSmall: AppText.legend(size: AppText.tick, color: AppColors.labelDim),
        )
        .apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);
  }
}

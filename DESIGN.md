---
name: RailSim
description: A measured field read against the handbook — near-black ground, one instrument light, hairline rules, no cards.
colors:
  ground: "#070A0E"
  panel: "#0D1219"
  panel-raised: "#141C25"
  well: "#04070A"
  hairline: "#1D2732"
  hairline-bright: "#33424F"
  instrument: "#5FD8F5"
  instrument-deep: "#11566B"
  instrument-glow: "#B6EFFF"
  off-nominal: "#F2B23C"
  out-of-tolerance: "#FF5C4D"
  vehicle-body: "#313A1F"
  vehicle-edge: "#8E9C66"
  vehicle-accent: "#48532A"
  scene-wagon-frame: "#8E3D30"
  scene-deck-plank: "#8A7048"
  text-primary: "#E6EDF3"
  text-secondary: "#8FA1B1"
  label: "#B4C5D3"
  label-dim: "#74838F"
typography:
  display:
    fontFamily: "NotoSansMono"
    fontSize: "40px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "2.4px"
  counter:
    fontFamily: "NotoSansMono"
    fontSize: "66px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "0"
  screen-title:
    fontFamily: "NotoSansMono"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "2.4px"
  readout:
    fontFamily: "NotoSansMono"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "0"
  card-title:
    fontFamily: "NotoSansMono"
    fontSize: "21px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "1.6px"
  readout-small:
    fontFamily: "NotoSansMono"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "0"
  section-label:
    fontFamily: "NotoSansMono"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "1.6px"
  body:
    fontFamily: "NotoSans"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "normal"
  body-small:
    fontFamily: "NotoSans"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "normal"
  caption:
    fontFamily: "NotoSansMono"
    fontSize: "13.5px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "1.6px"
  tick:
    fontFamily: "NotoSansMono"
    fontSize: "12px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "0"
rounded:
  panel: "0px"
  card: "0px"
  chip: "0px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  advance-button:
    backgroundColor: "{colors.instrument}"
    textColor: "{colors.ground}"
    typography: "{typography.section-label}"
    rounded: "{rounded.chip}"
    padding: "20px 28px"
  advance-button-disabled:
    backgroundColor: "{colors.panel-raised}"
    textColor: "{colors.label-dim}"
    typography: "{typography.section-label}"
    rounded: "{rounded.chip}"
    padding: "20px 28px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.instrument}"
    typography: "{typography.section-label}"
    rounded: "{rounded.chip}"
    padding: "18px 22px"
  panel:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.panel}"
    padding: "16px"
  stage-index:
    backgroundColor: "{colors.well}"
    textColor: "{colors.label}"
    rounded: "{rounded.panel}"
    width: "244px"
  verdict-chip-pass:
    backgroundColor: "transparent"
    textColor: "{colors.instrument}"
    typography: "{typography.section-label}"
    rounded: "{rounded.chip}"
    padding: "8px 12px"
  verdict-chip-warn:
    backgroundColor: "transparent"
    textColor: "{colors.off-nominal}"
    typography: "{typography.section-label}"
    rounded: "{rounded.chip}"
    padding: "8px 12px"
  verdict-chip-fail:
    backgroundColor: "transparent"
    textColor: "{colors.out-of-tolerance}"
    typography: "{typography.section-label}"
    rounded: "{rounded.chip}"
    padding: "8px 12px"
  citation-chip:
    backgroundColor: "{colors.panel}"
    textColor: "{colors.label}"
    typography: "{typography.body-small}"
    rounded: "{rounded.chip}"
    padding: "4px 8px"
  input-field:
    backgroundColor: "{colors.well}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.chip}"
    padding: "18px 16px"
  input-field-focus:
    backgroundColor: "{colors.well}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.chip}"
    padding: "18px 16px"
---

# Design System: RailSim

## Overview

**Creative North Star: "The Measured Field"**

RailSim is not a dashboard and not a game. It is the readout of a measured field: the trainee puts a real vehicle and real securing hardware on a real flatcar, in metres, and the handbook answers back. Every surface in the program is lit the way a measuring instrument is lit — a near-black ground, one instrument light, and two alarm colours that are never spent on anything decorative. The interface's own lettering is the silkscreen on the instrument's face; the field in the middle belongs to the trainee.

The system is flat by construction. There is no elevation, no shadow, no rounded chrome, and — as the shipped screens confirm — no cards used as page scaffold. A group of readings is told apart from the field by a hairline frame with a tick cut into each corner, the way a measured plate is cropped. A list of choices is a ruled row: a rule, the content, the value. Where a card grid once tiled the vehicle screen, the shipped build carries ruled entries that take the height their content needs, because the border around each tile carried nothing and the designation a trainee scans for sat a different distance down every cell.

The visual anti-references are named and confirmed by the build: the dark-Material-card dashboard, the rounded consumer surface, and mono-as-costume. Mono is used here for measurement and legend, which is what mono is for. The palette is a Turkmen-language technical instrument for military engineering; the tone is never playful.

**Key Characteristics:**
- Near-black measured ground (`#070A0E`) with one cyan instrument light and two reserved alarm colours.
- One line weight (1px hairline), struck to 2px for something measured or selected. Nothing else.
- Square corners everywhere; all three radius tokens are zero and are meant to stay zero.
- Mono for every measured value and every legend; humanist sans for prose. Nothing in between.
- Motion is one authored moment on arrival plus the needle running to its reading.

## Colors

A near-black field, one instrument light in three intensities, two alarm colours, four greys for ground and rules and four for type — and a separate machine palette that is deliberately not lit at all.

### Primary
- **Instrument Cyan** (`#5FD8F5`): The one lit hue, and it always means the same thing — measured, live, confirmed, actionable. A computed value, a thing the trainee placed, the live step on the stage index, the control that advances the operation. The advance button is a solid fill of it with ground-coloured lettering; it is the only solid fill of an accent anywhere.
- **Instrument Deep** (`#11566B`): The light at rest — the permitted band on a tolerance scale, an idle tick, the ghost of a value not taken yet, a hovered scrollbar thumb.
- **Instrument Filament** (`#B6EFFF`): The brightest point — the needle itself, a lit section legend, the single reading a scale turns on.

### Secondary
- **Off-Nominal Amber** (`#F2B23C`): The handbook does not confirm this. An unconfirmed option, a missing dimension, a check that could not be computed, a dimension whose value the source does not state (lettered with the handbook's own `çeşmede ýok`), the blocked-reason line beside a dark advance button. Never a failure.
- **Out-of-Tolerance Red** (`#FF5C4D`): Outside a stated range. The only red in the interface, and the only thing that turns a needle away from cyan.

### Tertiary
- **Service Green** (`#313A1F` body, `#8E9C66` edge, `#48532A` accent): Vehicle paintwork in the flat elevations and plans, following the handbook's own plates. The 3-D scene extends the same family across hull, turret, track link, fender and tilt, on an **oxblood wagon frame** (`#8E3D30`) with a **timber deck** (`#8A7048`). A trainee moving between the plate and the view is looking at the same object.

### Neutral
- **Field Black** (`#070A0E`): The measured ground the whole instrument sits on; every screen's scaffold colour.
- **Panel** (`#0D1219`): One step up from ground, for a region set aside for one group of readings.
- **Panel Raised** (`#141C25`): The one surface above a panel — a selected row, a menu, a dialog, a tooltip.
- **Well** (`#04070A`): Below the field — the inside of an input, a scrollbar track, the stage-index rail.
- **Hairline** (`#1D2732`): The colour of every division that is felt rather than read.
- **Hairline Bright** (`#33424F`): The same line where it has to be read — a panel's frame, a scale's baseline, the edge of a control.
- **Read Text** (`#E6EDF3`) / **Second Rank** (`#8FA1B1`): Prose and its captions and units.
- **Legend** (`#B4C5D3`): Chrome lettering — section headings, scale legends, column heads. Mono and tracked, never prose.
- **Legend Dim** (`#74838F`): Chrome lettering present but not addressed — a step not reached, a disabled word, a tick there only for scale. Measured at 5.1:1 against ground; dim is a rank, not permission to be unreadable.

### Named Rules
**The One Instrument Light Rule.** Instrument cyan means *measured*. Nothing inert is ever lit with it. In-tolerance is deliberately the same cyan, not a third colour: an in-tolerance reading is the instrument agreeing with itself.

**The Alarm-Only Rule.** Amber and red belong to verdicts alone. They may never be a heading, a border, a decoration or an emphasis. Audit test: if the amber in a screenshot is not stating "the handbook does not confirm this", it is a bug.

**The Unconfirmed-Is-Not-Failed Rule.** Missing data is amber, never red, and below its threshold the data-completeness badge goes *dimmer* rather than redder. Nothing in this program renders absent evidence as a failing grade.

**The Machine Is Not Lit Rule.** Vehicles are never drawn in instrument cyan — not in the flat elevations, not in the 3-D scene. The light means a reading; a vehicle is the thing being read.

## Typography

**Display / Label / Mono Font:** NotoSansMono (bundled, `assets/fonts/`)
**Body Font:** NotoSans (bundled, `assets/fonts/`)

**Character:** Two bundled Noto families, both covering the Turkmen letters the whole interface is written in. The split is the design: the chrome is lettered like an instrument's silkscreen — mono, uppercase, tracked wide — and prose is set in a humanist sans so a paragraph is still a paragraph. NotoSansMono Bold with wide tracking is also the display voice, which is a consequence of the offline constraint: type comes only from what is bundled, and there is no second display face to source.

### Hierarchy
- **Display** (mono 700, 40px, tracking 2.4): The program's name on the opening screen. In the shipped `menu.png` it sets three lines in the right-hand column beside a full-bleed field.
- **Counter** (mono 700, 66px, tracking 0): One number read across the desk — a wagon count, a score.
- **Screen Title / Readout** (mono 700, 22px; title tracked 2.4, value untracked 0): Title strips are tracked and uppercased; a measured value at the same size is never tracked, because a number is read as a quantity, not as a legend.
- **Card Title** (mono 700, 21px, tracking 1.6): A vehicle designation, a wagon name, at the head of a ruled row.
- **Section Label / Readout Small / Label** (mono 700, 16px): Section legends (`ÖLÇEGLER`, `BERKITME USULY`), column heads, and values inside a dense row.
- **Body** (sans 400, 17px, line-height 1.45): Prose. **Body Small** (sans 400, 15px) for hints, notes and captions under a control.
- **Caption** (mono 700, 13.5px, tracking 1.6): Badges, citation chips, figure captions. Nothing in the interface is lettered smaller than this.
- **Tick** (mono 700, 12px): The legend under a scale's tick marks — the one thing below caption, because it is part of a drawn scale rather than of the prose.

### Named Rules
**The Mono-for-Measurement Rule.** Mono carries measurement and legend; sans carries prose. Never mono because a thing should look technical, and never sans for a number.

**The Nothing-Shrinks-To-Fit Rule.** These are displayed sizes and nothing scales them further. The interface is read for a long stretch by one person at a desk, so a value is never lettered small to fit more in; if it does not fit, the container widens. Raising the whole scale for a larger screen is one edit in `AppText`.

**The Painter Sizes Its Own Rule.** Labels lettered into a diagram by a `CustomPainter` deliberately do not come from this scale. A name at interface size covers the thing it names, so each painter sizes its lettering against the geometry around it.

## Layout

Every screen in the loading operation is mounted in the same chassis (`InstrumentScaffold`): a 244px stage-index rail down the left on the well colour with a hairline right edge; a title strip across the top, hairline-ruled at the bottom, carrying the uppercased mono title, an optional prose subtitle and any readings that belong to the strip; the field filling the rest; and a hairline-ruled footer bar holding one advance control at the right. A screen outside the operation — the handbook browser — keeps the rail but drops the five steps, because an index showing five steps nobody stands on says the trainee is nowhere.

Inside the field the recurring split is a wide left field and a narrow right value rail (roughly 380px in the 1440×900 captures), the rail holding mono readings, each with its handbook limit, its tolerance bar and its citation chip. Screen content is inset 32px horizontally and 24px vertically; a panel's own padding is 16px.

Spacing is a four-multiple scale, and a gap states a relationship: 4px inside a line, 8px between lines of one thought, 12px between thoughts, 16px between blocks, 24px between sections, 32px between a section and an unrelated one.

Density is a desk instrument at a fixed window, not a responsive page. The one measured breakpoint in the build is inside the ruled row: below 620px of row width the entry stacks its citation and its control under the details rather than squeezing the designation.

### Named Rules
**The Shared Right Edge Rule.** A group of readings that must align is built as a real table with intrinsic-width value and unit columns and no wrapping — the column sizes to the widest value and every row inherits it. A single readout never reserves a guessed width; that is what once broke `çeşmede ýok` across two lines mid-word. A value that will not fit widens the column; a value broken across two lines in a measuring instrument is worse than a wide column.

**The Long Legend Rule.** Section legends are long Turkmen phrases. The legend takes five parts of the heading row and the trailing rule takes two, never an even split, and value columns never reserve fixed widths.

## Elevation & Depth

There are no shadows in this system, and no tonal elevation in the Material sense. Card elevation, dialog elevation, app-bar elevation, snackbar elevation and popup elevation are all explicitly zero, and Material's surface tint is set transparent so nothing drifts toward the primary hue as it "rises". Depth is carried by three things instead: a four-step ground scale (well below the field, ground, panel, panel-raised), the hairline itself, and the corner ticks that crop a panel out of the field. In the 3-D scene, depth is real geometry with a directional shading term multiplied into each material colour — that is lighting a model, not elevating a surface.

### Named Rules
**The No-Shadow Rule.** An instrument's face has no drop shadows. A surface is separated by its ground step and its hairline, never by a shadow, a glow or a blur. There is no shadow vocabulary in this project and adding one would leave the world.

**The Ghost-of-a-Box Rule.** If a container seems to need emphasis, the answer is the corner ticks or the lit hairline, not a fill, a radius or a lift.

## Shapes

Square, everywhere. All three radius tokens are zero, and the comment in `AppRadius` is explicit that they should stay zero: an instrument's face is cut square, a panel is told apart by its hairline and its corner ticks, and a rounded rectangle here would read as consumer software pretending to be a measuring device. Buttons, chips, inputs, dialogs, menus, checkboxes, the scrollbar thumb and its track are all squared.

The one container shape in the design is the framed panel: a hairline rectangle with a 2px tick struck 9px in along both edges at each of the four corners — the crop marks on a measured plate. It is drawn by a painter rather than assembled from borders so the ticks can carry a verdict tone while the edge stays quieter (the edge takes the tone at 45% alpha, the ticks at full). A verdict read off the frame of the thing it concerns is legible before a word of it has been read.

The second recurring silhouette is the drawn scale: a hairline track with minor ticks every twentieth of its span, a lit band for the permitted range, and a needle stroke with a solid triangular head.

## Components

### Buttons
- **Shape:** Square (0px), every variant.
- **Advance (primary):** Solid instrument cyan with ground-coloured mono uppercase lettering at 16px, 28px/20px padding, elevation zero, a 18px leading arrow. One per screen, at the foot on the right, because pressing it is the only thing on the screen that changes what the program is doing.
- **Disabled:** Panel-raised fill with dim lettering, *and* an amber line in the strip beside it saying what is still missing. A dead control that will not say why is not shipped in this system.
- **Outlined:** Bright-hairline border, cyan mono label, 22px/18px padding. For anything that does not advance the operation.
- **Text:** Cyan mono label, 14px/12px padding.
- **Hover / Focus:** No splash anywhere (`NoSplash`). Hover and highlight are instrument cyan at 5–6% alpha, focus at 12%, over 140ms.

### Chips
- **Verdict chip:** A struck bracket, not a pill — squared, 1px border of the tone at 55% alpha over the tone at 10% fill, with the tone's mark and the uppercased word in the tone's colour. Four tones: neutral, pass (instrument cyan), warn (amber), fail (red). Colour never carries a verdict alone; the mark and the word carry it too, because "unconfirmed" and "in tolerance" are the exact pair most often confused.
- **Citation chip:** Panel fill, dim-label 1px border, book mark and the reference label at body-small. It is the traceability apparatus, and it sits under every reading the app takes.
- **Data completeness badge:** The same chip geometry in cyan at or above 80% and amber below; below 30% it drops to 75% alpha rather than changing hue.

### Cards / Containers
- **There are no cards as page scaffold.** A list is ruled rows: a rule, the content, the value, at whatever height the content needs. The framed panel is reserved for field views and for a group of readings.
- **Framed panel:** Panel fill, hairline edge, corner ticks, 16px padding, square. Takes a verdict tone on its edge and ticks.
- **Ruled row:** No border by default. Hovered or selected it lights its control's border to instrument cyan and fills it at 10% (hover) or 16% (selected), over 140ms. Selection is a struck edge, never a lift.

### Inputs / Fields
- **Style:** Well-coloured fill, 1px hairline border, square, 16px/18px padding, prose at 17px.
- **Focus:** Border shifts to instrument cyan at 2px — the struck hairline, not a glow. Caret and selection are cyan; selection at 28% alpha.
- **Error:** Border shifts to out-of-tolerance red. Labels are mono caption, dim at rest and cyan when floating.

### Navigation
The stage index is the navigation: the five steps of the loading operation stood on end down the left edge and lettered as a scale. Each step is a tick on a vertical rule with a two-digit mono number and an uppercased mono label. Steps behind the trainee are struck and tappable; the live step is lit in instrument cyan; steps ahead are dim ticks with no lettering weight — present so the trainee can see how far the operation runs, plainly not theirs yet. Above the steps sits the program's mark: a flatcar in section drawn with the same hairline as everything else — 15 logical pixels of the actual subject, not a stock glyph. Below them sit the reference-browser and main-menu links and the handbook citation, which belongs on every screen.

### Tolerance Scale (signature component)
A measured value drawn against the range the handbook allows: a 34px-tall hairline track with minor ticks every twentieth of the span (long at every fifth — what makes it a scale and not a progress bar), a lit band showing the permitted range in instrument-deep at 55% with a cyan hairline edge, and a needle running to the reading on a 620ms exponential ease-out. In the band the needle is filament cyan; out of it the needle turns red and the band stays lit, so the trainee sees both where they are and where they should have been. A null value draws the band and no needle — an honest empty state, not a zero. The figure beneath carries the reading between the band's two limits, lettered in tick-size mono.

**The Scale Does Not Rescale Rule.** A scale keeps its declared span. It never stretches to swallow an absurd reading, because that would shrink the band to a sliver and make a wild placement look like a near miss. A reading past either end pegs as a double chevron at the end it ran past, with no needle drawn on the scale at all, and the figure beneath still reports what was actually measured. This is the failure mode the whole world exists to refuse.

### Readout
One line of the instrument's readout: the legend, a dotted leader running out to the number the way a parts list on a plate does, then the value in mono with its unit set apart so the number is what the eye lands on. Lit when the trainee has just produced it. A trailing slot carries a citation chip or a verdict mark.

### Empty Field
A legend, a dashed frame where the content will go, one sentence naming the single condition that is missing, and — when there is one — the control that resolves it. Every screen in the flow can be arrived at before the step that fills it, and a bare sentence floating in a black field says only that something is wrong.

### Dimension Chrome (drawn views)
The side elevation letters its dimensions with witness lines and arrows in the legend grey. **Only horizontal extents are dimensioned:** every horizontal position in that painter comes from the handbook diagram, while every vertical one is a drawing convention chosen in the file, so a height dimension would be measuring a decision rather than a fact. A dimension whose value the source does not state is still drawn, lettered with the handbook's own `çeşmede ýok` in amber.

### Motion
Three durations and two curves, and that is the whole vocabulary: 620ms on `easeOutExpo` for a needle running to its reading (what a damped needle actually does), 140ms for a control answering a pointer, 420ms for a screen settling. The one authored arrival is `FieldEntrance`: children are already visible and rise the last few pixels into place, staggered 55ms down the column so the eye is led from the first reading to the last. Nothing else animates on arrival.

## Do's and Don'ts

### Do:
- **Do** light with instrument cyan (`#5FD8F5`) only what has been measured, placed, computed or is about to act.
- **Do** reach for a different weight, size or rule before reaching for a new colour; the palette is closed.
- **Do** set every measured value and every legend in NotoSansMono, and every paragraph in NotoSans.
- **Do** build a group of aligned readings as a table with intrinsic value and unit columns and no wrapping, so the right edge is shared by construction.
- **Do** keep a scale's declared span and peg an out-of-range reading as a chevron at the end it ran past, with the measured figure still printed beneath.
- **Do** draw a container as a hairline frame with corner ticks and reserve it for field views and reading groups; make lists ruled rows.
- **Do** give every empty state one named condition and the control that resolves it.
- **Do** state a missing value as `çeşmede ýok` in amber, with its citation chip, rather than omitting the dimension.
- **Do** carry a verdict with tone, mark and word together, never tone alone.
- **Do** render screens with `RAILSIM_SHOTS=<dir> flutter test test/screenshot_harness_test.dart` before judging a visual change; its header explains why the captures are taken the way they are (providers warmed inside `runAsync` before the tree is built, both the real and the fake clock run out before the shutter).

### Don't:
- **Don't** use amber or red for a heading, a border, a decoration or an emphasis; they are verdict colours only, and missing data is amber, never red.
- **Don't** paint a vehicle, in any view, with the instrument colour.
- **Don't** introduce a radius. All three radius tokens are zero and are named by forty widgets so they can stay zero.
- **Don't** add a shadow, a glow, a blur or a Material elevation; there is no shadow vocabulary here and a surface separates by ground step and hairline.
- **Don't** use a card grid as page scaffold, or fix a row's height so the designation lands at a different distance down each entry.
- **Don't** introduce a second line weight. There is one hairline, struck to 2px when something is measured or selected.
- **Don't** reserve a guessed width for a value, or let one wrap; widen the column instead.
- **Don't** animate anything on arrival beyond `FieldEntrance` and the needle running to its reading.
- **Don't** add a fetched font, a network call or a remote asset. The program is offline by construction and type comes only from the two families bundled in `assets/fonts/`; `assets/images/ui/` is deliberately absent from the asset manifest and must not be "restored".
- **Don't** let an aesthetic rule override the traceability apparatus. Citation chips, `çeşmede ýok`, the `ŞERTLI SURAT` badge on illustrative photography, amber-unconfirmed as a first-class verdict and the opening screen's real mesh with the record's real dimensions printed under it are product truth and outrank every rule above.

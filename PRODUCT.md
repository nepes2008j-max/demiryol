# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

<!-- Recorded as `web` because the schema has no desktop value. The real
runtime is Flutter Desktop (Linux and Windows embedders in `linux/` and
`windows/`); no mobile design language applies. See Capabilities. -->

## Users

Trainees — soldiers and cadets learning to secure armoured vehicles on
railway flatcars — working alone at a desk with a mouse and keyboard, one
person per monitor. Sessions are practice, not an examination of record: the
app scores an attempt so the trainee sees where they were wrong, and the
score is feedback rather than a grade filed against them. Instructors are a
secondary audience who read the result report and the reference browser.

## Product Purpose

RailSim walks a trainee through one loading attempt end to end — compose the
echelon, choose the wagon type, pick the vehicle, place it on the deck,
choose and place the securing gear, then read the engineering verdict. It
exists so a trainee can make the mistakes on screen, with the handbook's own
rules checking them, instead of on a flatcar. Success is a trainee who can
name the right chock, spur or lashing for a given vehicle and weight bracket
and say which paragraph of the handbook says so.

## Positioning

Every number the app states is traceable to one document: *Rules for
transporting troops by rail, water, and air transport*, Türkmenistan Ministry
of Defense / Ministry of Industry & Communications, Joint Order No.
145/175-ö, 03 July 2019. Where that extract is silent, the app says so —
`HandbookField` holds either a cited number or the literal
`"TODO: Fill from Handbook Page XX"`, and the validator reports
`CheckStatus.unknown` with a reason rather than a false pass. Nothing in the
interface may present an invented engineering value as fact; that honesty is
the product.

## Operating Context

A single desktop window, mouse and keyboard, offline. No network, no backend:
the handbook database ships as JSON under `assets/data/`, figures as PNGs
under `assets/images/`, vehicle meshes as Wavefront `.obj` under
`assets/models/`. The flow is linear and step-based
(main menu → consist → wagon type → vehicle category → vehicle → placement →
securing → engineering analysis → result), navigated with GoRouter, and the
trainee can go back to revise a step. The interface is written in Turkmen.

## Capabilities and Constraints

- Flutter 3.38 desktop, Material 3, Riverpod for state, GoRouter for the
  flow. Must build and look right on both Linux and Windows.
- Offline by construction: no pub.dev fetches at build time beyond the
  committed `pubspec.lock`, no network calls at runtime, no downloaded fonts.
  Type must come from the families bundled in `assets/fonts/`, which cover
  the Turkmen letters the whole interface is written in.
- The trainee places and drags securing gear directly on a 3-D deck scene
  drawn by the app's own painters (`scene3d_*`, `*_painter.dart`) from real
  metres; there is no 3-D engine and no model download.
- Nothing may be pre-placed or pre-filled for the trainee, and a decision
  they have already expressed by placing something must not be re-asked as a
  test question later.
- Data completeness is visible, not hidden: cards carry a `DATA %` badge and
  unconfirmed options are offered with an explicit "unconfirmed" marker
  rather than being removed.
- Vehicle dimensions exist for the T-72, T-90S, ZIL-131, KamAZ-43114 and
  Ural-4320; every other catalogue entry has `TODO` dimensions and falls back
  to flat, explicitly illustrative views.

## Brand Commitments

- The interface language is Turkmen; all user-facing strings live in
  `lib/core/localization/app_strings.dart`.
- Handbook citations are shown, not paraphrased away — reference chips link
  the number on screen to the paragraph, table or figure it came from.
- The subject matter is military engineering, and the tone is a technical
  instrument, never a game.

## Evidence on Hand

- `assets/data/*.json` — the handbook-derived database: vehicles, platforms,
  attachment types, measurements, rules, references, photos.
- `assets/images/*.png` — 21 figures extracted from the handbook itself.
- `assets/models/*.obj` + `assets/data/vehicle_models.json` — real sourced
  vehicle meshes with author, source and licence recorded.
- `docs/` — extraction and mapping reports, including
  `wagon-types-and-securing-methods.md` and
  `three-dimensional-loading-view.md`.
- Not on hand and never to be fabricated: per-vehicle spec sheets,
  centre-of-gravity heights, tie-down point counts, a named flatcar-model
  catalogue, vehicle photographs beyond the handbook's own figures.

## Product Principles

1. Cite or say nothing — an unknown is displayed as unknown, never rounded
   into a plausible number.
2. The trainee acts; the app does not act for them. Placement is direct
   manipulation from an empty deck.
3. One question is asked once. What the trainee has already decided by doing
   is never re-asked.
4. Readability at a desk beats density. The interface is read for a long
   time by one person; nothing is lettered small to fit more in.
5. Every screen belongs to the same instrument — one type scale, one spacing
   scale, one set of surfaces.

## Accessibility & Inclusion

Verdicts must never be carried by colour alone: tone, icon and word together
(the existing `VerdictChip` pattern). Text must hold contrast on the dark
ground at desk viewing distance.

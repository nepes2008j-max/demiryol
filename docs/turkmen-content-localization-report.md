# Turkmen technical-content localization — mapping report

Source of truth for this phase. Covers every English prose field in
`assets/data/*.json`, whether it is user-visible, whether it was translated,
and — where it was — the proposed Turkmen text. This document is generated
once as an audit trail; the actual translations live in
`assets/data/localization/*_tk.json` (see "Architecture" below), not in this
file, so this report does not need to be kept byte-for-byte in sync with the
JSON going forward — it records the state as of this phase.

## Architecture chosen

**Separate companion `*_tk.json` files** under `assets/data/localization/`,
one per source file, keyed by the same `id`s as their English counterpart:

- `principles_tk.json` ← `principles.json`
- `rules_tk.json` ← `rules.json`
- `attachments_tk.json` ← `attachments.json`
- `references_tk.json` ← `references.json`
- `photos_tk.json` ← `photos.json`
- `vehicles_tk.json` ← `vehicles.json`
- `platforms_tk.json` ← `platforms.json`

Why this over inline `fooTk` fields in the original files or a generic
`LocalizedText{en, tk}` wrapper type:

- **Original stays byte-for-byte untouched.** None of the 8 authoritative
  extraction files is modified. Full recoverability and 1:1 diff-based
  auditing (a reviewer can open the English and Turkmen file side by side
  and match rows by `id`) come for free.
- **No engineering-logic risk.** The engineering/numeric files
  (`measurements.json`, and the numeric/condition fields of
  `rules.json`/`vehicles.json`/`platforms.json`) are never touched, so
  there is no way this phase could have altered a validation outcome.
- **Fits the existing Repository pattern.** `HandbookRepository` already is
  "the only place that knows where data comes from" (per its own doc
  comment from Phase 1). Each `get*()` method gained one extra step: load
  the matching `_tk.json` (if present) and merge it onto the already-parsed
  English models via a small `withTurkmen(...)` method added to each model.
  No other layer changed shape.
- **No breaking change to existing models.** Every new field is a nullable
  addition (`String? xTk`) with a `displayX` getter that falls back to the
  English text when no translation exists yet — so partially-translated
  data (e.g. a future new vehicle added before its translation is written)
  degrades to English instead of crashing or showing a blank string.
- Rejected: a generic `LocalizedText` value type would have required
  changing the type of every existing `String` field touched by five prior
  phases' worth of call sites and tests — far more invasive than necessary
  for content that is 1:1 with existing fields.

## Legend

- **Visible**: is this field ever rendered on screen today (checked against
  every current screen/widget/dialog)?
- **Translate?**: Y = translated this phase: Turkmen text now lives in the
  matching `*_tk.json`. N = intentionally left English/untouched, with a
  reason.

---

## `principles.json` — 6 principles × 6 fields = 36 translated entries

All fields are visible (rendered by `PrincipleCard`, used on the Engineering
Analysis screen and the Reference Browser's Principles tab). All 36 were
translated. `id` and `handbookReferenceId` are untouched (structural/citation
keys).

| Principle id | Field | Translate? |
|---|---|---|
| principle-symmetry | title, principle, purpose, physics, engineeringReason, militaryRequirement | Y (all 6) |
| principle-braking-transfer | same 6 | Y (all 6) |
| principle-chock-placement | same 6 | Y (all 6) |
| principle-wire-angle | same 6 | Y (all 6) |
| principle-vehicle-specific-hardware | same 6 | Y (all 6) |
| principle-weight-class-method-count | same 6 | Y (all 6) |

Full English → Turkmen text for all 36 fields is in
`assets/data/localization/principles_tk.json`, one Turkmen field per English
field, same key names with a `Tk` suffix.

---

## `rules.json` — 21 translated entries

| Rule/method id | Field | Visible | Translate? | Reason if N |
|---|---|---|---|---|
| rule-axle-load-wheeled-ramp | description, failMessage | Y | Y (both) | |
| rule-ground-pressure-tracked-ramp | description, failMessage | Y | Y (both) | |
| rule-tracked-special-case-max | description, failMessage | Y | Y (both) | |
| rule-cog-height-method-eligibility | description, failMessage | Y | Y (both) | failMessage's embedded English "TODO: Fill from Handbook Page XX" fragment was itself prose (not a machine-detected marker — this field isn't a `HandbookField`), so it was translated as ordinary prose describing the same gap, not converted into the app's TODO-detection mechanism. |
| rule-symmetry-tolerance | description, failMessage | Y | Y (both) | |
| rule-wheeled-lashing-count | description | Y | Y | no `failMessage` (lookup rule) |
| rule-reusable-chock-tracked-selection | description | Y | Y | no `failMessage` |
| rule-reusable-chock-wheeled-selection | description | Y | Y | no `failMessage` |
| rule-wire-strand-count | description | Y | Y | no `failMessage` |
| rule-vehicle-specific-hardware-lookup | description | Y | Y | no `failMessage` |
| every rule's `condition` | e.g. `"axleLoadT <= 10.0"` | Y (shown in rule detail dialog) | **N** | This is the engineering condition itself — explicitly excluded ("engineering rules/conditions themselves"). Translating it would risk being mistaken for a change to validation logic. |
| every rule's `appliesTo` | `"wheeled"` / `"tracked"` / `"tracked_or_wheeled"` | Y | **N** | Already mapped to Turkmen in Dart (`AppStrings.appliesToLabelFor`) since Phase 3 — translating it in JSON too would create two sources of truth. |
| `lookup` / `lookupTable` fields | machine-readable | N (raw values never rendered) | **N** | Engineering data. |
| sixApprovedTrackedMethods[1..6] | `name` | Y | Y (all 6) | Descriptive method names, not product designations — the embedded hardware codes (KGUUB-1G/2G, Ş-series, MK-765/S-765) are preserved verbatim inside the translated string. |

---

## `attachments.json` — 10 translated entries (`notes`)

| Attachment id | `notes` present | Translate? |
|---|---|---|
| att-wire-lashing | Y | Y |
| att-wood-chock | Y | Y |
| att-wood-packing | Y | Y |
| att-nail | Y | Y |
| att-staple | Y | Y |
| att-kguub-1g | Y | Y |
| att-kguub-2g | N | — (no notes field) |
| att-kguub-1k | N | — |
| att-kguub-2k | N | — |
| att-iron-spur | Y | Y |
| att-iron-chock-boot | Y | Y |
| att-clamp-tensioner | Y | Y |
| att-clamp | Y | Y |

**Left untranslated (all attachments):** `name` (e.g. "Steel wire lashing (sim
çekme)") — treated as a hardware designation/label, not explanatory prose;
several already carry the handbook's own Turkmen term in parentheses, and
translating just the English half would produce an inconsistent mixed name.
`category`, `material`, `sizingRule`, `diametersAvailableMm`,
`minThicknessMm`, `combatWeightRangeT` — technical specification fields, not
narrative explanation. `category` is already Turkmen-labeled in the UI via
`AppStrings.attachmentCategoryLabel`. **Flagged for future review:**
`material` (e.g. "Sound dry hardwood or softwood timber; aspen/alder/linden
prohibited") reads more like descriptive prose than a rigid spec and could
arguably be translated in a future pass — left in English this time since it
wasn't in the requested category list ("attachment notes") and to keep this
phase's scope bounded to what was explicitly asked for.

---

## `references.json` — 16 translated entries (`summary`)

All 16 entries in the flat `references` list have a `summary`, all visible
(citation-chip tooltip, reference detail dialog, Reference Browser's
Paragraphs/Tables tabs). All 16 translated: para-51, para-19, para-20,
para-21, para-24, para-25, para-26, para-29, para-30, para-31, para-32,
para-33, para-34, para-40, table-7, para-55, table-16 (17 listed — table-16
included, for 17 actual reference entries; see note below).

**Note on count:** the file has 17 reference entries, not 16 — corrected
during translation; all 17 were translated (para-51, para-19, para-20,
para-21, para-24, para-25, para-26, para-29, para-30, para-31, para-32,
para-33, para-34, para-40, table-7, para-55, table-16).

**Left untranslated:** the `chapters` array's `title` fields (2 chapter
titles, 5 section titles) — traced through the codebase and confirmed **not
currently rendered by any screen or provider** (`HandbookRepository
.getChapters()` exists but nothing calls it). Not translated this phase per
the instruction to prioritize fields the application actually displays;
flagged as ready-to-translate the moment a "table of contents" browsing
feature is built. The top-level `_comment` (translation-license caveat) is
developer documentation, never parsed into any model, left in English.

---

## `photos.json` — 20 translated entries (`caption`)

`photos.json` holds 20 figure entries (21 image files exist in
`assets/images/`, but `image62.png` has no corresponding JSON entry — a
pre-existing orphaned asset noted back in Phase 2, unrelated to this phase).
All 20 captions are visible (figure tiles, the enlarged photo dialog,
thumbnail tooltips) and were translated: fig-15.8, fig-15.10, fig-15.11,
fig-15.12, fig-15.13a, fig-15.13b, fig-15.14, fig-15.15, fig-15.16ab,
fig-15.16cde, fig-15.16ae, fig-15.17ab, fig-15.17cd, fig-15.18, fig-15.26,
fig-15.27, fig-15.28, fig-15.29, fig-15.30, fig-15.31. `figureNumber`,
`file` (asset path), and `id` are untouched. The top-level `_comment` is
developer documentation, not translated.

---

## `vehicles.json` — 15 translated entries

Two different situations, both handled without touching the "never invent a
value" `TODO:` marker mechanism:

**A. `class` field's English parenthetical annotation (10 vehicles).** Ten
vehicles have a `class` value like `"TODO: Fill from Handbook Page XX (Main
Battle Tank / historical medium tank - not stated in this extract)"`. The
app's existing `presentHandbookText()` already extracts and displays that
parenthetical verbatim after the Turkmen "not available" message — meaning
this English fragment was actually leaking into an otherwise fully-Turkmen
sentence before this phase. Fix: a new `classDisplayTk` field per affected
vehicle holds the complete, correctly-Turkmen replacement sentence; `Vehicle`
gained a `displayClass` getter that uses it when present. `presentHandbookText`
itself is unchanged — no engineering/TODO-detection logic was touched.
Affected: veh-t34, veh-btr50p, veh-2s1, veh-2s3, veh-2s4, veh-2s5, veh-2s7,
veh-pts2, veh-obj429, veh-obj-family-137.

**B. `notes` field (5 vehicles).** veh-is4, veh-pts2, veh-ptsm,
veh-obj-family-137, veh-obj118 — all visible in the vehicle detail dialog,
all translated.

**Left untranslated:** `handbookDesignation` (24, official designation),
`ironSpurType`/`ironChockBootType` (official hardware type codes),
`manufacturer`/`country`/remaining dimension fields (still bare `"TODO: Fill
from Handbook Page XX"` with no annotation — already renders cleanly in
Turkmen via the existing mechanism, nothing to add), `category` (enum,
already Turkmen-mapped in Dart), the top-level `_comment`.

---

## `platforms.json` — 2 translated entries (`notes`)

Only `plat-generic-open-flatcar` and `plat-echelon-class-40wagon` have a
`notes` field (`plat-echelon-class-57wagon` has none); both translated and
visible in the platform detail dialog. `name` values (e.g. "Generic open
flatcar (açyk wagon)", "Military echelon class: 40 conditional wagons") are
left untranslated — treated as platform identifiers/classification labels,
the same treatment as vehicle designations, not narrative explanation.

---

## `measurements.json` — 0 translated entries this phase

Every `note`/`substitutionRule` field in this file (wheelChockByWheelDiameterTable,
trackChockByWeightTable, nailSubstitutionTable, wireLashingAngleTable,
staplesTable, ironChockBootTable, reusableChockWheeledTable) was checked
against every screen, provider, and widget in `lib/presentation/` — **none
of them is currently rendered anywhere.** The engineering validator reads
only the numeric `rows` from this file, never the prose notes. Per the
instruction to translate only "prose that is actually displayed," nothing
in this file was translated this phase. This is the only source file with
zero translated entries.

---

## Totals

| File | Translated entries | Untranslated (intentional) |
|---|---|---|
| principles.json | 36 | 0 (all fields translatable) |
| rules.json | 21 | conditions (10), appliesTo (10), lookup/lookupTable (4) — categories, not a count of individual "entries" |
| attachments.json | 10 | name (12), category/material/sizingRule/spec fields (12) |
| references.json | 17 | chapters/sections titles (7), `_comment` (1) |
| photos.json | 20 | `_comment` (1) |
| vehicles.json | 15 | handbookDesignation (24), ironSpurType/ironChockBootType (per vehicle), manufacturer/country/dimensions (still bare TODO, 24 each), `_comment` (1) |
| platforms.json | 2 | name (3), `_comment` (1) |
| measurements.json | 0 | all note/substitutionRule fields (7) — not currently displayed |
| **Total translated** | **121** | |

## Ambiguous terminology flagged for native-speaker review

- **"Bogie"** (principle-symmetry, purpose) — rendered as *"tigir toplumy"*
  (wheel assembly) rather than a specific Turkmen railway-engineering loan
  term, since I'm not confident of the standard term used in Turkmen railway
  literature.
- **"Bridging plates"** (rule-tracked-special-case-max) — rendered as
  *"köpürjik plitalar"*; a plausible literal rendering, worth checking
  against actual Turkmen military-transport terminology.
- **"Spacer board" / "support wedge"** — rendered as *"aralyk tagta"* /
  *"paz-agaç"* respectively; reasonable but not verified against a Turkmen
  technical glossary.
- General note (unchanged from Phase 3): this is machine-produced
  professional-register Turkmen, translating an already-once-removed English
  paraphrase of the original Turkmen handbook — not a verified translation.
  It should not be treated as authoritative until reviewed by a native
  technical speaker, ideally checked against the original handbook text
  directly rather than through this English intermediate.

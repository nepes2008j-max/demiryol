# Handbook Photo / Visual Reference Mapping Report

Produced before implementing the photo-correction phase, per the explicit
requirement to build an entity→figure mapping from evidence before changing
any code. All facts below come directly from reading `assets/data/photos.json`,
`assets/data/references.json`, `assets/data/vehicles.json`,
`assets/data/attachments.json`, `assets/data/rules.json`,
`assets/data/principles.json`, and `assets/data/measurements.json` in full —
nothing here is inferred from topic similarity or "closest match."

## Headline finding

**No photograph in the extracted handbook depicts a specific named vehicle.**
All 20 figures (`assets/data/photos.json`) are photographs of generic
securing *equipment* (spurs, chock-boots, KGUUB chocks, clamps, wood
stop-blocks, wire/chain lashings) or *procedure diagrams* (a securing
sequence, a chock/spur pair arrangement) — confirmed by reading every
caption. None names a tank/self-propelled-gun/etc. designation as its
subject.

The reported "same photo reused for different vehicles" bug is real, and
this is its root cause: `Vehicle.referenceId` cites the handbook paragraph
that documents *why that vehicle's mandatory hardware assignment holds*
(e.g. "para-31" = "Table 13 says this vehicle needs an iron spur"), **not**
"this photo depicts this vehicle." The pre-existing code
(`linker.photosFor(vehicle.referenceId)`) then displayed whatever generic
equipment figure happens to share that paragraph as if it were "the
vehicle's own photo." Since 16 of the 23 vehicles share `para-31` and 7
share `para-32`, all 16 showed the same two iron-spur figures and all 7
showed the same chock-boot figure.

**Fix applied:** vehicle cards/dialogs no longer treat a shared-paragraph
equipment figure as the vehicle's photo. They show "Surat: çeşmede ýok"
for the vehicle photograph (true for every vehicle today), and show those
same equipment/procedure figures — unchanged, still real, still correctly
cited — under a separate, explicitly-labeled heading ("BERKITME ÜÇIN
GATNAŞYKLY FIGURALAR" / securing-related figures), never presented as an
identification photo.

## Photo classification (from caption text alone)

| Figure ID | Caption (as extracted) | Kind |
|---|---|---|
| fig-15.8 | Single-use longitudinal/side wood stop-blocks | equipment |
| fig-15.10 | Reusable lashings: wire/rope, chain | equipment |
| fig-15.11 | KGUUB-1G reusable universal chock | equipment |
| fig-15.12 | Reusable universal chocks, wheeled (KGUUB-1K etc.) | equipment |
| fig-15.13a | Iron spurs, view 1 | equipment |
| fig-15.13b | Iron spurs (labeled parts) | equipment |
| fig-15.14 | Iron chock-boots: KTT/KT-137/KT-34 | equipment |
| fig-15.15 | MK-765 clamp-tensioner, S-765 clamp | equipment |
| fig-15.16ab | KGUUB-2G securing sequence (positioning) | procedure |
| fig-15.16cde | KGUUB-2G securing sequence (continued) | procedure |
| fig-15.16ae | KGUUB-2G chock-pair minimum spacing | procedure |
| fig-15.17ab | Iron spur securing sequence (start) | procedure |
| fig-15.17cd | Iron spur securing sequence (continued) | procedure |
| fig-15.18 | Securing tracked vehicle w/ wire + stop-blocks | procedure |
| fig-15.26 – fig-15.31 (6 figures) | Securing wheeled vehicles, various axle patterns | procedure |

## Vehicle → figure mapping

No vehicle has an identification photo. Every vehicle's "related figures"
are the equipment/procedure figures tied to its *mandatory hardware*
citation — legitimate to show, but only as securing-context, never as the
vehicle's own picture.

| Entity | Entity ID(s) | Primary (identification) figure | Related (securing-context) figures | Evidence | Confidence |
|---|---|---|---|---|---|
| Iron-spur vehicles (16) | veh-2s1, veh-2s3, veh-2s4, veh-2s5, veh-2s7, veh-2a6, veh-pts2, veh-ptsm, veh-obj429, veh-obj-family-137, veh-obj434, veh-obj219, veh-obj78, veh-obj256, veh-obj118, veh-obj915 | **NONE** | fig-15.13a, fig-15.13b | `vehicle.referenceId == 'para-31'`; both figures cite `para-31`; captions say "Iron spurs" (generic), not any vehicle name | Confirmed (no vehicle photo); UNCONFIRMED that these figures show *this specific* vehicle's own spur variant (Ş-303 vs Ş-350 etc. look different but the two figures aren't type-specific) |
| Iron-chock-boot vehicles (7) | veh-t34, veh-is4, veh-t10, veh-t54, veh-t55, veh-pt76, veh-btr50p | **NONE** | fig-15.14 | `vehicle.referenceId == 'para-32'`; fig-15.14 cites `para-32`; caption explicitly names T-34/IS-4/T-10/T-54/T-55/PT-76/BTR-50P as the vehicles this chock-boot figure applies to | Confirmed (no vehicle photo); the *equipment* relationship is strong (caption names these exact vehicles), stronger than the spur case above |

**Total: 23/23 vehicles have zero identification photographs.**

## Equipment (attachment) → figure mapping

| Attachment ID | Name | Photo(s) | Evidence | Confidence |
|---|---|---|---|---|
| att-iron-spur | Iron spur | fig-15.13a, fig-15.13b | `referenceId == 'para-31'` on both | Confirmed |
| att-iron-chock-boot | Iron chock-boot | fig-15.14 | `referenceId == 'para-32'` | Confirmed |
| att-kguub-1g | KGUUB-1G | fig-15.11 | `referenceId == 'para-29'`; caption names "KGUUB-1G" explicitly | Confirmed |
| att-kguub-2g | KGUUB-2G | fig-15.16ab, fig-15.16cde, fig-15.16ae (**not** fig-15.11) | fig-15.11's citation (`para-29`) is shared with 1G, but its **caption explicitly says "KGUUB-1G"** — showing it for 2G would be a wrong-variant photo. The three sequence figures' captions explicitly say **"KGUUB-2G"** (cited under para-36/para-38, reached here via an evidence-based override, not the shared para-29 match) | Confirmed (correction) |
| att-kguub-1k | KGUUB-1K | fig-15.12 | `referenceId == 'para-30'`; caption names "KGUUB-1K" | Confirmed |
| att-kguub-2k | KGUUB-2K | fig-15.12 (shared with 1K) | Same figure shows both wheeled variants side by side in one image (caption lists both) — a genuine single-figure depiction of two variants, not a mismatch | Confirmed |
| att-wood-chock | Wood stop-block | fig-15.8 | `referenceId == 'para-21'` on both | Confirmed |
| att-wood-packing | Spacer/packing board | none | `referenceId == 'para-24'`; no photo in the extract cites para-24 | Confirmed absence |
| att-nail | Fastening nail | none | `referenceId == 'para-25'`; no matching photo | Confirmed absence |
| att-staple | U-shaped staple | none | `referenceId == 'para-26'`; no matching photo | Confirmed absence |
| att-clamp-tensioner | MK-765 clamp-tensioner | fig-15.15 | `referenceId == 'para-33'`; caption names "MK-765" | Confirmed |
| att-clamp | S-765 clamp | fig-15.15 (shared) | Same figure shows both MK-765 and S-765 together (caption lists both) | Confirmed |
| att-wire-lashing | Wire lashing | fig-15.10 (**newly linked**) | `attachments.json` cites `table-7` (its *sizing* rule) for this attachment, but no photo cites `table-7`. fig-15.10's own citation is `para-19` ("Standard/reduced wire coil... by diameter" — the same physical wire stock), and its caption explicitly says "wire/rope lashing." Linked here via an evidence-based override, not the raw `referenceId` match | Confirmed (correction) |

**13/13 equipment types accounted for; 10 now have a correctly-attributed
photo, 3 (spacer board, nail, staple) genuinely have none in the extract.**

## Platform → figure mapping

The single real flatcar (`plat-generic-open-flatcar`, `referenceId ==
'para-51'`) has **no matching photo** — no figure in the extract cites
`para-51`. This was already correctly showing no photo before this phase;
no change was needed.

## Rule / method → figure mapping

| Rule/Method ID | Figure(s) | Evidence |
|---|---|---|
| rule-reusable-chock-tracked-selection | fig-15.11 | shares `para-29` |
| rule-reusable-chock-wheeled-selection | fig-15.12 | shares `para-30` |
| rule-vehicle-specific-hardware-lookup | fig-15.13a, fig-15.13b | shares `para-31` |
| rule-wheeled-lashing-count | fig-15.26 – fig-15.31 (6) | shares `para-55` |
| method 2 (Iron spurs) | fig-15.17ab, fig-15.17cd | shares `para-39` |
| method 3 (Wood stop-blocks + wire lashings) | fig-15.18 | shares `para-40` |
| method 4 (Iron chock-boots + spacer boards) | fig-15.14 | shares `para-32` |
| method 6 (Clamp-tensioners/clamps) | fig-15.15 | shares `para-33` |
| method 1, method 5 | none | no photo cites `para-35` or `para-34` |
| rule-wire-strand-count | none | no photo cites `table-7` |

These were already correctly wired (Reference Browser → Rules tab uses
`linker.photosFor(rule.referenceId)` unmodified) — a rule/method citing a
shared paragraph is legitimate evidence for a *procedure*, unlike a
vehicle's *identity*, so no change was needed here.

## Principle → figure mapping

| Principle ID | Figure(s) | Evidence |
|---|---|---|
| principle-chock-placement | fig-15.16ab | shares `para-36` |
| principle-vehicle-specific-hardware | fig-15.13a, fig-15.13b | shares `para-31` |
| principle-weight-class-method-count | fig-15.26 – fig-15.31 (6) | shares `para-55` |
| principle-symmetry, principle-braking-transfer | none | no photo cites `para-34` |
| principle-wire-angle | none | no photo cites `table-7` |

Also unmodified — correct as-is.

## Figures with no entity relationship (before this phase)

Three figures had **no** relationship to any vehicle, attachment, rule, or
principle — reachable only by raw browsing in the Reference Browser's
unfiltered Photos tab, never surfaced in context anywhere else:

- **fig-15.10** (wire/chain lashing photo) — fixed this phase: now linked
  to `att-wire-lashing`.
- **fig-15.16cde**, **fig-15.16ae** (KGUUB-2G sequence, continued /
  spacing) — fixed this phase: now linked to `att-kguub-2g`.

(fig-15.16ab was already reachable via `principle-chock-placement`, so it
was not fully orphaned, though it is now also correctly linked to
`att-kguub-2g`.)

## UNCONFIRMED items (flagged, not silently resolved)

- Whether fig-15.13a vs. fig-15.13b corresponds to any particular Ş-series
  spur *type* cannot be confirmed — both captions describe iron spurs
  generically ("view 1" / labeled parts), with no type number in either
  caption. Both are shown for every iron-spur vehicle/equipment context
  equally; no attempt was made to guess a tighter per-type match.
- Whether the KT-137/KT-34/KTT chock-boot sub-images within fig-15.14 map
  one-to-one to specific vehicles (e.g. does the KTT sub-image specifically
  depict the version used by IS-4/T-10?) cannot be confirmed from the
  caption alone — the single combined figure is shown for all 7 vehicles
  and for the attachment itself, without claiming a sub-image-level match.

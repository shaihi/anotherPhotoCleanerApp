# PhotoCull Test Dataset

## Purpose

This directory contains a reusable, deterministic test dataset for PhotoCull Phases 1–4.

- **No binary images are stored here.** Images are generated at test time using `TestImageFactory` (synthetic PNG data).
- The dataset is driven entirely by `manifest.json` and the per-category `expected/*.json` files.
- `TestDatasetLoader` reads the manifest, synthesizes `PhotoAsset` instances and image data, and exposes helper methods used by tests across all phases.

---

## Category Table

| # | Category ID | Assets | What it tests |
|---|---|---|---|
| 1 | `exact-duplicates` | 3 | Two assets share identical `hashSeed` (same SHA-256); third is unique. Tests SHA-256 grouping and date-based keeper selection (oldest = keeper). |
| 2 | `near-duplicates` | 3 | Three photos of same scene at increasing quality degradation, within 60 s. Tests composite score ranking — best quality becomes keeper. |
| 3 | `burst` | 4 | Four photos sharing a `burstIdentifier`. One has clearly highest sharpness. Tests burst grouping and sharpness-based keeper selection. |
| 4 | `favorites` | 2 | Favorite photo vs. sharper non-favorite sharing same hash. Tests Tier 0 preservation override — favorite is always kept. |
| 5 | `edited` | 2 | Edited photo vs. sharper non-edited non-favorite sharing same hash. Tests Tier 1 preservation override — edited is always kept. |
| 6 | `low-confidence-suppression` | 2 | Two near-equal quality photos. Confidence falls below threshold; both are kept (Rule A suppression). |
| 7 | `missing-signal-suppression` | 2 | One asset has `nil` signals. Cull suppressed by Rule B; both kept. |
| 8 | `unrelated-controls` | 3 | Three completely unrelated photos (different dates, different hashes). No groups should be produced. |
| 9 | `transitive-chain` | 3 | A≈B and B≈C pairs provided, but no direct A-C pair. Tests union-find transitivity produces one group of three. |

---

## Naming Conventions

- **Category IDs** are kebab-case slugs (e.g. `exact-duplicates`, `transitive-chain`).
- **Asset IDs** follow the pattern `{category-prefix}-{name}`, e.g. `ed-oldest`, `nd-best`, `burst-3`.
- Category prefixes are short abbreviations: `ed` (exact-duplicates), `nd` (near-duplicates), `burst`, `fav` (favorites), `edit` (edited), `lcs` (low-confidence-suppression), `mss` (missing-signal-suppression), `ctrl` (unrelated-controls), `tc` (transitive-chain).

---

## How to Add a New Category

1. Add a new entry to `manifest.json` under `"categories"` with a unique `id`, `description`, `groupingReason`, `assets`, `nearDuplicatePairs`, and `expectedFile`.
2. Create the corresponding `expected/{category-id}.json` file with `expectedGroups` and `expectedRecommendations`.
3. Add a loader test in `TestDataset/TestDatasetLoaderTests.swift` verifying that the manifest loads, expected file parses, and asset counts match spec.

---

## JSON Schema Summary

### `manifest.json` top level

| Field | Type | Description |
|---|---|---|
| `version` | Int | Schema version (currently 1) |
| `description` | String | Human-readable description |
| `categories` | [DatasetCategory] | Array of category entries |

### DatasetCategory fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique kebab-case category identifier |
| `description` | String | What behavior this category tests |
| `groupingReason` | String? | `"exactDuplicate"`, `"nearDuplicate"`, `"burst"`, or `null` for controls |
| `assets` | [DatasetAsset] | Asset definitions in this category |
| `nearDuplicatePairs` | [[String]]? | Explicit near-duplicate pairs (by asset ID); null unless category requires explicit pairs |
| `expectedFile` | String | Relative path from `TestDataset/` to the expected outcomes file |

### DatasetAsset fields

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique asset identifier |
| `creationDate` | String? | ISO-8601 UTC date string, or null |
| `pixelWidth` | Int | Image width in pixels |
| `pixelHeight` | Int | Image height in pixels |
| `isFavorite` | Bool | Mirrors `PHAsset.isFavorite` |
| `isEdited` | Bool | Whether the asset has been edited |
| `burstIdentifier` | String? | Shared burst ID, or null |
| `imageType` | String | One of: `"checkerboard"`, `"gradient"`, `"solid"` |
| `imageParams` | Object? | Type-specific parameters (see below) |
| `hashSeed` | String? | Shared seed for `cryptoHash`; assets sharing the same `hashSeed` produce identical hashes. Null = hash derived from own `id`. |
| `signals` | Object? | Quality signal values; null means signals are unavailable (triggers Rule B suppression) |

### `imageType` values

| Value | `imageParams` fields | Description |
|---|---|---|
| `"checkerboard"` | `squareSize: Int` | High-contrast checkerboard pattern; higher sharpness scores |
| `"gradient"` | none (null) | Horizontal gradient; medium sharpness |
| `"solid"` | `r: UInt8, g: UInt8, b: UInt8` | Flat single color; near-zero sharpness |

### `hashSeed` rules

- Two assets with the same non-null `hashSeed` value will have **identical** `cryptoHash` bytes in `hashResults(for:)`, simulating exact duplicates.
- An asset with `hashSeed: null` receives a hash derived from its own `id`, guaranteed unique within the dataset.

### `signals` fields

| Field | Type | Range | Description |
|---|---|---|---|
| `sharpness` | Double? | [0, 1] | Laplacian-variance sharpness score |
| `exposure` | Double? | [0, 1] | Exposure quality score |
| `subjectQuality` | Double? | [0, 1] | Subject detection/quality score |
| `resolution` | Double? | [0, 1] | Resolution normalized score |

---

## Platform Gating

`TestDatasetLoader`, `TestDatasetModels`, and `TestDatasetLoaderTests` are all gated with:

```swift
#if canImport(CoreGraphics)
// ...
#endif
```

This matches the guard used by `TestImageFactory`. All three files compile out cleanly on Linux and other platforms without CoreGraphics. No conditional imports are needed at the test-target level.

---

## `hashResults` Ordering

`TestDatasetLoader.hashResults(for:)` returns results **sorted by `asset.id` ascending** (lexicographic). Any test that indexes into the result array (e.g. `results[0]`, `results[1]`) **must include a comment** documenting this sort-order assumption and the expected ordering for the specific category being tested.

Example comment:

```swift
// hashResults sorted by asset.id ascending: ed-different < ed-newest < ed-oldest
// ed-oldest and ed-newest share hashSeed "ed-shared" → same hash
```

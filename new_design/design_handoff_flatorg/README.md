# Handoff: Flatorg — Task Detail Card & App Icon

## Overview

Flatorg is a flat-organisation app that helps flatmates manage shared cleaning tasks, a shopping list, and flat issues. This handoff covers two redesigns:

1. **Task detail card** — the floating popup shown when a user taps a task card on the Tasks home screen. Currently a centered modal; the redesign reworks it as a **bottom sheet** (more native on both Android and iOS, more breathing room).
2. **App icon** — refined version of the existing house + broom mark, redrawn for proper iOS (squircle) and Android (adaptive) standards.

The visual identity is preserved: mint background, deep teal accents, dark forest-green ink, status-color cards.

## About the Design Files

The files in `prototype/` are **design references created in HTML** — React + inline styles inside Babel-transpiled JSX, intended to be opened in a browser to inspect look and behavior. They are **not production code** and are not meant to be shipped or copied verbatim.

Your task is to **recreate these designs in the Flatorg codebase** (Flutter / native Android / native iOS / whatever the project actually uses) using its established components, theme tokens, and patterns. If no environment exists, choose the framework that fits the team and target platforms.

The HTML prototype is the source of truth for **visual spec** (colors, type, spacing, layout). Behavior should follow the existing app's conventions (close on backdrop tap, swipe-down to dismiss for the bottom sheet on Android & iOS, etc.).

## Fidelity

**High-fidelity.** Colors, type sizes, spacing, and corner radii are all final values. Type scale uses Sora in the prototype but should map to whatever the app currently uses (the original screenshots suggest a similar geometric humanist sans — keep that).

---

## Design tokens

### Colors

| Token | Hex | Use |
|---|---|---|
| `bg.mint` | `#DCEEC8` | App background |
| `bg.mintSoft` | `#EDF6E2` | Bottom-sheet surface, subtle mint highlight |
| `ink.primary` | `#0E2E1E` | Primary text, dark forest near-black |
| `ink.secondary` | `#264035` | Secondary text |
| `ink.muted` | `rgba(14,46,30,0.55–0.65)` | Tertiary / metadata |
| `accent.teal` | `#0E5648` | Primary accent — buttons, focused tab, dots |
| `accent.tealSoft` | `#1F6B5A` | Hover/pressed teal |
| `accent.green` | `#36B373` | Success / Resolved button |
| `status.blue.bg` | `#9DBEE8` | Pending task card bg |
| `status.blue.accent` | `#1E4FB6` | Pending stripe + label fg |
| `status.red.bg` | `#E8A39D` | Overdue card |
| `status.red.accent` | `#B53A30` | Overdue stripe |
| `status.yellow.bg` | `#F4D58A` | Soon / warning card |
| `status.yellow.accent` | `#B58820` | Soon stripe |
| `status.green.bg` | `#A6D9A6` | Done card |
| `status.green.accent` | `#2F7A3D` | Done stripe |
| `divider` | `rgba(14,46,30,0.10)` | Hairlines between rows |
| `scrim` | `rgba(14,30,22,0.45)` | Modal/sheet backdrop |

### Type

- Family: **Sora** in prototype — match the existing app font (a geometric humanist sans). If you don't have one, Sora 400/500/600/700/800 from Google Fonts is the reference.
- Sizes used:
  - Card title: **28px / 800 / -0.5 letter-spacing / line-height 1.1**
  - Subtask body: **15px / 400 / line-height 1.35**
  - Section label ("Subtasks · 4"): **12px / 700 / uppercase / 0.6 letter-spacing**, color `accent.teal`
  - Meta line ("Sun 26 Apr · 23:59 · Unassigned"): **13px / 500**, color `ink.muted`
  - Chip label: **12px / 700 / 0.3 letter-spacing**

### Radius

- Bottom sheet top corners: **28px**
- Cards / surfaces: **22px**
- Chips / pills: **9999px (full)**
- Small inputs/buttons: **12–14px**

### Spacing scale

4 / 8 / 10 / 12 / 14 / 18 / 22 / 28 px — mostly multiples of 2, used liberally.

### Shadows

- Sheet lift: `0 -10px 40px rgba(0,0,0,0.18)`
- Card / icon raise: `0 14px 28px rgba(0,0,0,0.18)`

---

## Screen 1 — Task detail card (bottom sheet)

**File:** `prototype/flatorg-cards.jsx` → component **`FOCardV3`**

### Purpose

User has tapped a task card on the Tasks home screen ("Toilet", "Kitchen", etc). Sheet slides up from the bottom showing the task's full description (title, due date, who it's assigned to, and the list of subtasks). User can dismiss by tapping the X, swiping down, or tapping the scrim.

### Layout (top → bottom)

The sheet is anchored to the bottom of the screen, full width, top corners rounded **28px**, surface color `bg.mintSoft` (`#EDF6E2`).

Internal padding: `10px 22px 28px` (top is small to accommodate the drag handle).

1. **Drag handle** — centered, 40×4px pill, `rgba(14,46,30,0.25)`. ~10px from top edge.
2. **Title row** — flex row, `gap: 10px`:
   - Left column (flex 1):
     - Title text "Toilet" — 28px / 800 / -0.5 letter-spacing
     - Meta line under it — 13px / 500 / `ink.muted`, format: `"<weekday>, <date> · <time>  ·  <assignee>"` (e.g. `"Sun, 26 Apr · 23:59  ·  Unassigned"`)
   - Right: **Close button** — 32×32 circle, background `rgba(14,46,30,0.06)`, X icon centered (12×12 stroke 1.8 round caps).
3. **Status chip row** — flex row, `gap: 8px`:
   - Cadence chip ("Weekly") — bg `rgba(14,86,72,0.10)`, fg `accent.teal`
   - Status chip ("Pending") — bg `rgba(30,79,182,0.12)`, fg `status.blue.accent`. Color matches the parent task card's status (red for overdue, etc.)
   - Pill shape, `padding: 5px 12px`, `font: 12 / 700 / 0.3 letter-spacing`.
4. **Hairline divider** — 1px, `divider` token.
5. **Subtasks section**:
   - Label: `"Subtasks · {count}"` — 12 / 700 / uppercase / `accent.teal`. Margin-bottom 8px.
   - List: each row is `flex` aligned center, `gap: 14px`, `padding: 12px 4px`, `font: 15 / 400 / line-height 1.35`.
     - Leading bullet: 6×6 circle, `accent.teal`.
     - Body text takes remaining width.

The whole sheet sits over a scrim (`rgba(14,30,22,0.45)` + `backdrop-filter: blur(2px)`). Tapping outside the sheet dismisses it.

### Status color mapping

The chip "Pending" uses the **same status color as the underlying task card** so the relationship is obvious. Mapping:

| Card status | chip bg | chip fg |
|---|---|---|
| Pending | `rgba(30,79,182,0.12)` | `#1E4FB6` |
| Overdue | `rgba(181,58,48,0.12)` | `#B53A30` |
| Soon | `rgba(181,136,32,0.14)` | `#B58820` |
| Done | `rgba(47,122,61,0.14)` | `#2F7A3D` |

### Behavior

- **Open**: slide up from bottom with spring (Material standard easing on Android, default sheet on iOS). 250–300ms.
- **Dismiss**: tap close button, tap scrim, swipe down past ~30% of sheet height, or system back gesture.
- **Sheet height**: hugs content; do not force fixed height. Add `safe-area-inset-bottom` padding on iOS so content sits above the home indicator.
- No new functionality — this is a **read-only detail view**. Do not introduce check-off state, comments, photos, etc., unless explicitly asked later.

### Sample content (for reference)

Title: `Toilet`
Due: `Sun, 26 Apr · 23:59`
Assigned: `Unassigned`
Subtasks:
- Clean toilet
- Clean sink (basin + drainage + mirror)
- Empty bin + replace toilet rolls
- Mopping / vacuuming

---

## Screen 2 — App icon

**File:** `prototype/flatorg-icons.jsx` → **Concept 1** (the chosen direction).

### Concept

Refined version of the existing icon DNA: **a house outline with a broom in front and sparkles in the upper-right**, on a warm orange background. Same metaphor as the original; cleaner geometry, single stroke weight, unmistakable broom shape.

### Background

Linear gradient at 140°: `#F0A06B → #D87740`.

(For a flat fill if your build pipeline doesn't support icon gradients, use solid `#E48E5C`.)

### Foreground (white, `#FFFFFF`)

All artwork is drawn inside a 100×100 logical box, then scaled to platform size. Stroke weight is **5 logical units**, line-join `round`, line-cap `round`.

1. **House** — five-point silhouette path: `M22 50 L50 26 L78 50 L78 74 L22 74 Z` — outline only, white stroke.
2. **Door** — solid white rect, `x:44 y:56 w:12 h:18 rx:1.5`.
3. **Broom** — rotated `-20°` around `(30, 60)`:
   - Handle: rect `x:28 y:30 w:4 h:32 rx:2`, white fill.
   - Binding band: rect `x:24 y:60 w:12 h:4 rx:1`, white fill.
   - Bristle fan (trapezoid): path `M22 64 L38 64 L44 80 L16 80 Z`, white fill.
   - Five vertical striations across the bristles, stroke `rgba(228,142,92,0.55)` (the bg orange, slightly transparent), 1.2 weight, round caps. Coordinates: `x1=22→40 y1=66 y2≈79`.
4. **Sparkle** — four-point star at upper-right, white fill: `M76 28 l1.5 4.5 4.5 1.5 -4.5 1.5 -1.5 4.5 -1.5 -4.5 -4.5 -1.5 4.5 -1.5z`.
5. **Sparkle dot** — small white circle at `(68, 42)`, r 1.6.

### Decoration on the shape itself

- Outer drop shadow: `0 14px 28px rgba(0,0,0,0.18)`.
- Inset highlight at top: `inset 0 1px 0 rgba(255,255,255,0.25)`.
- Subtle radial gloss at top-left: `radial-gradient(120% 80% at 30% 20%, rgba(255,255,255,0.18), transparent 60%)`.

These polish touches are optional — Apple/Google guidelines actually discourage built-in shadows on the icon itself, but the inner gloss reads well in product/marketing renders. **Ship the icon as just the gradient + foreground; reserve the gloss/shadow for marketing assets.**

### Platform export specs

#### iOS

- **Sizes**: ship `1024×1024` master + the standard set (1024 App Store, 180 @3x, 120 @2x, 87, 80, 60, 58, 40 etc — Xcode's asset catalog generates these from the master).
- **Shape**: the OS applies the squircle mask. Ship as a **full-bleed square** with the gradient extending edge-to-edge. Do not pre-round the corners; iOS will mask.
- **Padding**: keep the entire foreground (house + broom + sparkles) within the central **~80%** of the canvas — equivalent to 102 logical units of padding inside the 100-unit artwork plus the canvas edges. The prototype uses `padding: size * 0.18` for ios.
- **Format**: PNG, no transparency, sRGB. No translucent backgrounds.

#### Android (adaptive icon)

- **Two layers**:
  - **Background layer**: solid `#E48E5C` or the gradient (Android supports vector drawables with gradients in `res/drawable/`).
  - **Foreground layer**: house + broom + sparkles, all white, exported as a vector drawable.
- **Canvas**: 108dp × 108dp. The **safe zone is the central 66dp circle** (anything outside may be clipped by the launcher's mask — circle, squircle, rounded square, teardrop).
- **Foreground padding** in the prototype is 14% of canvas — that puts the artwork inside the safe zone.
- Provide a **monochrome layer** as well (Android 13+ themed icons): the same foreground shape, all one color, on transparent. Use `accent.teal` `#0E5648` as the tint reference.
- Also provide a **legacy square 512×512** for Play Store listing.

### Verifying the safe zone

The prototype renders the same artwork inside three Android masks (circle / squircle / rounded square) — view it in `prototype/index.html` under "Concept 1 · Refined classic" to confirm nothing critical (door, sparkle) gets clipped.

---

## Interactions & Behavior

Only the bottom sheet has interactions:

| Interaction | Trigger | Result |
|---|---|---|
| Open sheet | Tap a task card on Tasks screen | Sheet slides up from bottom, scrim fades in over ~250ms |
| Close — button | Tap X (top-right) | Sheet slides down + scrim fades out |
| Close — backdrop | Tap scrim | Same as close button |
| Close — gesture | Drag sheet down past 30% of its height, then release | Sheet animates the rest of the way and dismisses |
| Close — system | Android back press / iOS edge swipe | Same as close button |

No internal state to manage other than `isOpen` and the task being shown.

## State Management

- `selectedTaskId: string | null` — held by the parent (Tasks screen). Setting it opens the sheet; clearing it closes.
- The sheet reads task data (`title`, `dueAt`, `assignee`, `subtasks`, `status`, `cadence`) from whatever model layer the app already uses. **No new fields needed.**

## Assets

- No raster assets. All shapes are CSS / inline SVG in the prototype; reproduce them as platform-native vector drawables (SVG → AndroidVectorDrawable / SF Symbols-style PDF / Flutter `CustomPaint`, whatever fits).
- Sora font is for the prototype only — keep the app's existing font.

## Files in this bundle

```
prototype/
  index.html               ← open this in a browser to view the canvas
  design-canvas.jsx        ← the panning/zooming presentation shell
  ios-frame.jsx            ← iPhone bezel + status bar
  android-frame.jsx        ← Android bezel + status bar
  flatorg-app-screen.jsx   ← dimmed Tasks home screen behind the sheet
  flatorg-cards.jsx        ← FOCardV1, FOCardV2, FOCardV3 (use V3)
  flatorg-icons.jsx        ← Concept 1, 2, 3 (use Concept 1)
```

To preview: open `prototype/index.html` in any modern browser. Pan with mouse drag, zoom with mouse wheel, click any artboard label to open it fullscreen.

## Out of scope

- The other screens (Settings, Shopping, Issues) — not redesigned in this round.
- Status-color theming on the home Tasks cards — kept as-is.
- Any new functionality on the task card (no checking off subtasks, no comments, no photo proof) — explicit request from the designer.

# Item Icons Implementation Plan

**Goal:** Give every object in the current production map a consistent game icon and use it in existing menus.

**Architecture:** Extend the existing transparent SVG inventory-art direction with a dedicated runtime set, not the historical full-game catalog. One registry resolves item IDs and aliases (levels/repair states share the object's identity). The production-map generator exports icon paths for the future ship computer.

**Tech Stack:** Godot 4.6.3, SVG, Node.js asset generator, GdUnit4.

## Constraints And Decisions

- Stay on the current experimental branch and preserve existing work. No commit/push requested.
- Icons have transparent backgrounds, a 64-unit viewbox, distinct silhouettes and a restrained faceted palette. Retain text labels and tooltips.
- Cover raw materials, components, fluids, crops/seeds, structures, conduits, tools and ship modules. No icon overlays on undiscovered underground ore.
- Existing SVG assets make deterministic vector art the appropriate medium; no bitmap image-generation call is needed.
- The ship encyclopedia remains future work. Do not add crafting recipes or change costs/unlocks.

## Tasks

- [x] Test icon coverage for every production-map node and active tool; unknown IDs must not silently resolve to the wrong object.
- [x] Generate the SVG set and registry; render a contact sheet to inspect silhouettes at game scale.
- [x] Integrate icons into inventory, batch ingredients/output, assembly, industry, tool slots and ship module selectors.
- [x] Add icon paths/previews to the production map and update maintenance instructions.
- [x] Run all unit tests, focused workflow smoke tests and native 720p/1080p visual/layout checks.

## Verification

- Red: missing registry failed `test_item_icons.gd` before implementation.
- Green: 163 unit tests / 29 suites; zero failures, skips or orphans.
- Native `item_icons_smoke.gd`: all 47 imported textures nonblank and transparent, contact sheet and menus fit 720p/1080p, advanced recipes fit, assembly IDs unchanged. Screenshots in `reports/item-icons-*.png` inspected visually.
- A transfer-toolbar height regression was reproduced in a failing native assertion, then fixed by constraining selected OptionButton icons; the assertion now passes at both resolutions.
- `component_onboarding_smoke.gd`, `industry_smoke.gd`, `expedition_smoke.gd`: zero failures.
- Asset generator and production-map `--check` pass; `git diff --check` clean.
- Independent bounded review: no findings. No commit, push, merge or game launch left running.

## Review Focus

Long names must still fit beside icons. Popup item IDs/order and keyboard/controller selection must stay unchanged. All aliases must resolve to real imported textures. Production map and registry must regenerate deterministically. Known resources get icons in menus, not world spoilers.

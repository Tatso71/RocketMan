# Compact Assembly Popup

**Goal:** Replace long assembly-menu sentences with compact item rows and resource icons showing required / available counts. Green means the carried components are sufficient; missing components are gray. Keep paid assembly, unlocks, pending blueprints and instant free ladders unchanged.

**Architecture:** A focused reusable assembly cost-row control handles icon/count presentation. AssemblyUI uses a PopupPanel with stable rows, bounded scrolling, live accessible-cargo refresh and keyboard navigation; the same presentation serves pending-project funding.

## Tasks
- [x] RED tests for required/available ordering, affordable/free states and missing-resource gray.
- [x] Implement compact rows and picker/site popup without changing payment or placement rules.
- [x] Verify accessible Robbie cargo vs remote depot, live updates, selection without supplies, free ladder, pending funding/cancel, Escape/keyboard and bottom/right-edge placement.
- [x] Inspect native screenshots at 1280x720 / 1920x1080, run focused/full regressions and review.

## Verification
- Full unit suite: 209 tests across 37 suites, zero failures/errors/orphans (`reports/assembly-popup-unit-all.log`).
- Native assembly popup smoke: zero failures, including live cargo, pending funding/cancel, keyboard navigation, free ladders and viewport bounds (`reports/assembly-popup-native.log`).
- Component assembly, first-laboratory onboarding and item-icon integration smoke tests: zero failures.
- Visually inspected 720p/1080p picker and pending-project screenshots in `reports/assembly-popup-*.png` and `reports/assembly-project-popup.png`.
- Independent read-only review found no important functional bugs in the five-file UI/test scope. `git diff --check` passed.
- The user's open game was not restarted; the updated UI loads on the next launch.

## Constraints
- Preserve the dirty branch and the user's open game; no commit/push or restart requested.
- Unaffordable structures remain selectable as unpaid projects. Do not disable their row or grant free construction.
- Use existing item icons and panel theme. Names/costs fit fixed row tracks; no nested cards or verbose on-screen explanations.

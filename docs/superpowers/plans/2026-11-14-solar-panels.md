# Solar Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recharge the shared ship battery with constructible surface panels.
**Architecture:** Extend the existing blueprint/FIFO building lifecycle. Isolate
surface geometry and generation eligibility in SolarPower; integrate energy in
the outpost tick, using shared building persistence and orthogonal cable drawing.
**Tech Stack:** Godot 4.6, GDScript, gdUnit4, Node icon generator.
**Spec:** `docs/superpowers/specs/2026-11-14-solar-panels-design.md`

## Global Constraints
- 2 x 1 cells; 2 structural + 1 electronic; 0.1 kWh/s per eligible panel.
- Keep emergency recharge; no commits, push, merge or game restart requested.
- Preserve existing dirty valve/pump changes; no legacy migration required.

## Review Focus
- Empty battery must recover without a powered laboratory.
- Full battery with simultaneous consumers must cap the net balance correctly.
- Planned, building, damaged, disabled and unsupported panels must not generate.
- Outside placement must not open underground modules to above-ground placement.
- Surface blueprints and constructed panels must survive real save/load.

### Task 1: Runtime, placement and energy
Files: `scripts/systems/solar_power.gd`, `outpost_buildings.gd`,
`scripts/prototype/outpost_controller.gd`, `tests/unit/test_solar_power.gd`,
`tests/integration/solar_power_smoke.gd`.
- [x] Add failing geometry/catalog and lifecycle/energy tests; observe RED.
- [x] Add surface-only placement, construction connectivity and persistence.
- [x] Add generation before consumption eligibility, with final net battery cap.
- [x] Verify zero/full battery, additive production, exclusions and save/load.

### Task 2: Catalog and visual experience
Files: component catalog/data, icon and production map generators, README,
assembly UI, energy UI, world HUD, outpost renderer.
- [x] Extend recipe/icon registry and generated production map (delegated sidecar).
- [x] Expose panel before first laboratory; draw recognisable cells/supports/cable.
- [x] Display production, consumption and net energy; retain emergency action.
- [x] Verify generated files, full unit suite, native screenshots and runtime smoke.

### Task 3: Review
- [x] Fresh bounded review of solar feature and integration with dirty pump fix.
- [x] Resolve findings, rerun pertinent checks, report scope and limits.

## Verification Ledger
- Runtime RED: missing solar API, then missing panel switch. GREEN: native solar
  smoke includes actual paid component assembly, human Robbie delivery, zero/full
  battery, exclusions, orthogonal cables, save/load and 720p/1080p pixel checks.
- Review found greenhouse load omitted from net display and solar capped before
  greenhouse debits. Added failing tests and shared per-tick remaining budget;
  native smoke now passes with real growing/water-consuming greenhouse.
- 286 unit tests pass; production map 61 recipes/69 nodes and 52 icons check clean.
- Industry and remote-pump integration smoke pass.
- Zero-charge brownout regression: metered per-tick consumption prevents the
  report and HUD from claiming a surplus that is entirely consumed. Fresh review
  confirms findings resolved. Final native solar smoke and 286-unit suite pass.
- Native vital/rest UI smoke passes at 720p and 1080p with no HUD overlap.
- Ruling: update old utility smoke fixture to place its pump on a real straight
  pipe and expect current gray missing-resource color. These were obsolete
  expectations from before the plumbing and compact UI changes; no runtime
  behavior was reverted. Updated utility smoke passes.

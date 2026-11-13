# Explicit Production Orders Implementation Plan

> **For agentic workers:** Use executing-plans for core implementation. A disjoint UI sidecar may run in parallel; use a fresh reviewer at the end. No commit/push/restart without user request.

**Goal:** The player orders semilavorati; Robbie transports and builds without selecting recipes.

**Architecture:** Reuse paid fabrication jobs as FIFO queues per station, reserving resources/energy at submission. Keep actual stock, paid jobs and robot cargo as their existing owners. Reuse the workstation/fabrication UI for a directly accessible computer, rather than adding an inventory or alternative production subsystem.

**Tech Stack:** Godot 4.6.3, GDScript, existing JSON component recipes and icons.

**Spec:** `docs/superpowers/specs/2026-11-12-production-orders-design.md`.

## Global Constraints
- Human/companion logistics remains automatic; controlled Robbie stays manual.
- No implicit recipe requests or minimum-stock production from a project.
- Queued orders reserve actual ingredients and energy once, only when affordable.
- FIFO per station, independent stations progress concurrently; paid queue survives JSON save/load.
- Existing power, capacity, path, geometry and unlock rules remain authoritative.
- Reuse current branch and preserve pre-existing local changes; no git integration actions.

## Review Focus
- Multiple orders at one station must not advance simultaneously or reuse reserved resources.
- Full output storage must pause paid output instead of dropping it or creating invalid saves.
- Empty battery/damaged workshop must retain paid orders and expose the pause reason.
- Raw-only ship stock must not trigger recipe selection, idle shuttles or false full-depot states.
- Ready output delivery must work while the player is away; queue and controls fit 720p/1080p.

## Tasks
- [x] Core RED: add `production_orders_smoke.gd` for no automatic conversion, atomic explicit reservations, FIFO, independent stations, JSON queue, pause/resume and subsequent robotic construction; add queue validation unit cases.
- [x] Core GREEN: permit repeated component stations in `fabrication_state.restore`, retain validation for conflicting cube outputs; accept queued component orders in `outpost_controller.component_blocker`, advance one head per station, bound buffered output; remove buffer/demand/recipe decisions from `drone_logistics` and report missing finished components.
- [x] UI RED/GREEN: direct right-click computer, existing recipes/quantity/costs, live queue/progress, stock and robot status, secondary maintenance actions; native bounds and actual button submission tests.
- [x] Update autonomous workflow/safety regressions to explicit orders, preserve manual production and controlled Robbie tests; update tutorial text and authoring data to the new workflow.
- [x] Update README/design status and production-map generator editorial/metadata; regenerate/check map, icons and authored data.
- [x] Run full units plus focused native workflows/UI; fresh review, reproduce/fix important findings, record evidence.

## Interfaces And Files
- `Fabrication.jobs`: existing paid jobs in submission order. `job_at(station)` remains the active head; no new save queue field.
- `Outpost.fabricate_components(id, batches) -> bool`: submits one paid order, even while a previous order at that station runs, up to existing 200-job cap.
- `Outpost.advance_fabrication(delta)`: progresses only the first captured job per station per call. Other stations remain independent.
- `Logistics.available_components() -> Dictionary`: real ready components only, not reserved jobs or unconverted raw stock.
- UI sidecar owns `scripts/ui/fabrication_ui.gd`, `scripts/ui/workstation_menu.gd`, and new `tests/integration/production_computer_ui_smoke.gd`. Core owner handles controller/state/logistics, other tests, tutorials and docs.
- Direct station click uses `station_menu.open(point)` to open the production computer; `station_menu.open_actions(point)` retains deposit/withdraw/repair/upgrade actions as secondary controls.

## Evidence And Decisions
- User approved explicit manual production and queued orders on 12 November 2026.
- Implementation uses current checkout and native execution for the coupled core; UI is isolated to its existing files.
- No order cancellation is introduced: accepted orders remain paid and finish or pause. Existing building cancellation remains unchanged.
- Ready output pickup covers both ship and active underground laboratories, including costs split across actual stocks; worker mission `loading` is reconstructed after load rather than serializing a stale station pointer.
- Initial queue smoke: 11 expected failures, then all checks green; queue state units RED then 10/10 green. UI sidecar observed RED before implementation and native GREEN with captures.
- Complete human workflow and safety smokes pass after explicitly ordering the first laboratory and light batches. Full unit suite: 244/244, 45 suites (`reports/orders-all-units.log`).
- Focused native regressions passed: computer UI, component production/assembly, station interactions, human/controlled-Robbie guidance, assembly popup and protagonist. Component assembly needed one retry after a native OpenGL window creation failure before the script started.
- Paid-queue status and initially damaged computer access reproduced as three failing checks, fixed, and verified in `reports/orders-status-green.log`.
- Final independent review found pickup retries with near-full cargo, legacy repair-click interception, and unsafe snapped source access. All reproduced in `production_logistics_safety_smoke.gd` (six failing assertions including dependent repair/guidance checks), then fixed with capacity-first unloading, physical safe-source checks and maintenance routing; GREEN includes the existing one-time workshop repair cost.
- Delivery guidance was corrected in the same verification because promising autonomous conversion contradicts the central explicit-order rule. Controlled-Robbie authored overrides remain manual.
- Post-review full unit run: 244/244, 45 suites, no errors/failures/orphans (`reports/orders-reviewed-units.log`). No unresolved important findings, no additional reviewers requested.
- Post-review native checks all exit 0: production orders, logistics safety, computer UI, workstation interactions, autonomous laboratory/light workflow and autonomous safety (`reports/reviewed-*.log`). Production map check, item-icon check, authored design validation and diff whitespace check pass. This is focused integration coverage, not a claim that every historical integration entry point was executed.

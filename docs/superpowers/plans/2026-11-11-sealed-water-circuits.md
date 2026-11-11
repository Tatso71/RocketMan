# Sealed Water Circuits Implementation Plan

> Execute inline with test-driven core changes; delegate the isolated UI integration and request one final bounded review.

**Goal:** Playable sealed extraction, gravity outlets and separate powered water pumping without destroying or inventing water.

**Architecture:** New `water_circuit.gd` owns valves, outlets, pump orientation, topology and transient flow reports. It consumes the existing terrain/environment, component cargo, utility network and pump buffers. `hydraulics_ui.gd` owns placement/context controls/graphics; outpost and campaign own lifecycle/save validation.

**Tech Stack:** Godot 4.6.3, existing SVG registry and production-map generator.

**Spec:** `docs/superpowers/specs/2026-11-11-sealed-water-circuits-design.md`.

## Interfaces

`outpost.hydraulics` is the model; `outpost.hydraulic_ui` is the view.

Model public API (all return dictionaries by reference where relevant):

- `valves: Array`, `outlets: Array`, entries `{cell:Vector2i, direction:Vector2i, drilled:bool, opened:bool}` (outlets omit drilled).
- `at(cell:Vector2i) -> Dictionary`, `placement_blocker(kind:String,cell:Vector2i,direction:Vector2i,outpost) -> String`, `place(kind,cell,direction,outpost) -> bool` (`kind` valve/outlet).
- `drill(entry,outpost) -> bool`, `toggle(entry,outpost) -> bool`, `remove(entry,outpost) -> bool`.
- `report(entry,outpost) -> Dictionary` returns `{status:String, rate:float, total:float, kind:String}`; rate actual units/sec, total transferred session-independent if persisted in entry.
- `pump_ports(building) -> Dictionary` `{input:Vector2i,output:Vector2i}`, `reverse_pump(building,outpost) -> bool`, `pump_report(building,outpost) -> Dictionary` same status/rate fields.
- `advance(delta,outpost,powered_seconds) -> void`; `pumps_for(building,outpost) -> Array` for greenhouse receiver; `snapshot() -> Dictionary`, `restore(data,site,buildings) -> bool`.
- Constants `VALVE_COST`, `PASSIVE_RATE`, `PUMP_RATE`, `MAX_LIFT`.

UI public API: `begin(kind)`, `handle_input(event)->bool`, `tool_active()->bool`, `is_open()->bool`, `reset()`. All placement commands delegate to model; window and popup ownership stay in UI. T menu adds valve/outlet with stable IDs 10/11 (existing0..4 unchanged). R rotates preview. Right-click on valve/outlet opens controls; existing pump window gets reverse/direction/flow display. UI-only delegate writes `scripts/ui/hydraulics_ui.gd` and `scripts/ui/industry_ui.gd`; main owns every other file.

## Tasks

- [x] Core RED tests: all four wall faces remain sealed; closed/disconnected valves stop; gravity cannot lift; full or contaminated targets conserve volume; pump power/direction and separated networks; multiple outlets do not duplicate water; strict restore. Extra head/anchor/receiver edge cases remain in final verification.
- [x] Implement core + remove old radius-pump behavior, integrate greenhouse and outpost/campaign saves.
- [x] Add contextual UI, orientation preview, actual world outlet graphics, existing pump controls and flow animation.
- [x] Add valve/outlet icons, recipe-map entries and current technical documentation; record future ship tanks and construction volumes separately.
- [x] Run full units and focused onboarding/industry/reservoir/save/utility workflows, native 720p/1080p screenshots and texture/geometry checks; request bounded independent review and address findings.

## Verification And Rulings

- 178 unit tests / 30 suites pass, zero skips/orphans/errors. New water suite: 15 cases, including four faces, gravity route/head, pump barrier, full buffer, shared output credit, explicit pool intake, broken anchor, device cap and malformed saves.
- Native water smoke passes actual placement/click/rotation, physical upward transfer and falling water during panel inspection, 720p/1080p window bounds, safe terminal role changes and transactional JSON restore. Screenshots under `reports/water-*.png` inspected visually.
- Industry, utilities, reservoirs, expedition saves and Ocra component onboarding smoke tests pass. Native item-icon smoke passes with49 icons. Asset/map `--check` and `git diff --check` pass.
- Independent review found overlap, receiver-budget, panel-time and device-limit issues; fixed and covered by regressions. Bounded recheck: no actionable findings.
- Explicit aspirating terminal added to the same endpoint object so already-spilled water and natural pools remain usable. Changing role closes it; unconfigured ends remain capped. This is not another machine or automatic radius drainage.
- Industry fixture now advances water in its cavity while isolating unrelated exposed gas, then clears that tested gas before live farm-panel simulation. Real panel simulation advances all fluids together; production physics was not disabled to satisfy tests.
- Current icons/map/geology/scanner work preserved. No commit/push/merge requested or performed. Ship tanks and construction volumes remain future only.

## Review Focus

- Breaking a pipe or anchor while running must close/release correctly, without deleting fluid.
- Pump inlet and outlet must not connect implicitly through adjacent cells.
- No object/pipe placement inside solid terrain except the sealed bore through its anchor.
- Full cells, multiple liquids, shared receivers, tiny/invalid timesteps must conserve water.
- Invalid saved coordinates, duplicate devices, NaN/negative quantities and non-boolean controls must reject atomically.
- Menu IDs, long labels, icon registry, tooltip and 720p controls must remain usable.

No commits or publication requested. Keep all current local geology, scanner, production-map and icon work.

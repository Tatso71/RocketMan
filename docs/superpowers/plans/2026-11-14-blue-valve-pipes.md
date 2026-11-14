# Blue Valve and Pipes Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans or bounded parallel
> workers; preserve the existing uncommitted mining and vein-art work.

**Goal:** Replace sealed drilling with simple blue valves and free background pipes.
**Architecture:** Existing utility grid plus virtual endpoints and straight inline pumps.
**Tech Stack:** Godot 4.6.3, GDScript, gdUnit4, native smoke scenes.
**Spec:** docs/superpowers/specs/2026-11-14-blue-valve-pipes-design.md

## Constraints and Review Focus

No commits/push/merge without a fresh request. No old-save migrations. No chemical
mixtures. Check empty ends, full destinations, multiple branches, removed support,
power loss, inline direction changes and save atomicity. Never disturb prior work.

## Tasks

- [x] Reproduce and fix nearby exposed-face mining; test four rotations and walls.
- [x] Replace WaterCircuit with all-direction rock valves and finite endpoint flow;
  test sources/sinks, pump direction, lift, conservation and saves.
- [x] Integrate free water pipes, repeat-key guide rotation, aboveground ship links,
  straight 1-cell pump placement, noncollision and endpoint validation.
- [x] Replace hydraulic menus/visuals; render pipes behind actors/ladders, blue cubes
  on rock, ship ports, container fill and greenhouse sprinklers. Test input and views.
- [x] Add container recipe/icon and irrigation storage; regenerate production map and
  icon assets with their official generators; update current documentation.
- [x] Run unit/integration checks and native visual checks; fresh review; report limits.

## Worker Interfaces

WaterCircuit keeps at/place/placement_blocker/toggle/remove/report, but valve entries
are {kind:"valve",cell,opened,total} without direction/drilling/outlets. The obsolete
direction argument of placement is removed: placement_blocker(kind,cell,outpost),
place(kind,cell,outpost). Ship endpoints are returned by ship_ports(): Array and at().
pump_ports(building) returns external adjacent input/output cells and direction;
pump_direction(building) reads a Vector2i, set_pump_direction(building,direction,outpost)
validates it; reverse_pump remains a convenience. pump_placement_blocker(cell,outpost)
requires an existing water pipe and zero/one/two opposite neighboring pipes.
toggle_pump uses building.enabled. report/pump_report expose status/rate/total.
industry.state(container/greenhouse).water is finite stored water;
deliverable/withdraw operate on the greenhouse's own buffer.
Network.water_axes maps water pipe cell -> 0(horizontal)/1(vertical), and
cycle_water(cell) flips it. Network.valid_cell(cell,site) permits empty aboveground
cells down to Grid.ROCKET_CEILING for ship links.
ShipState.water_tanks={left:0.0,right:0.0}, 40 units each; sandbox WaterCircuit owns
equivalent local_ship_water if no campaign ShipState exists.

## Verification Ledger

- Mining reach regression reproduced 10 failures before the face-target fix; now
  four rotations, actual excavation, intact-wall and distance checks all pass.
- Background pipe placement smoke passes free/empty-handed placement, ladder
  coexistence, rock rejection, aboveground reach, JSON round trip and atomic
  rejection of an obsolete pipe format.
- Initial full unit pass: 272/272 across 48 suites, no errors or orphans.
- Found the energy legend missing the new container label in real scene smoke;
  reproduced with a failing coverage test and added the explicit tank label.
- Scanner pulse and mining-refusal regressions pass. Full movement/hatch/mining/
  save-load scene smoke passes after the legend fix, without runtime errors.
- Official production-map and item-icon checks pass (58 recipes/67 nodes,
  51 icons/31 aliases).
- Fresh review found imported water could exceed the native water-save limit and
  consecutive pumps could not exchange water across their blocked origin cells.
  Both issues were reproduced RED and fixed: water retains finite per-cell and
  combined-liquid validation; reciprocal adjacent pump ports transfer under the
  same power, direction, rate, lift and capacity budgets. Reviewer re-check clean.
- Final full unit suite: **277/277**, 48 suites, no errors/failures/orphans;
  `reports/blue-water-verified-units.log`.
- Native hydraulic UI smoke: **0 failures**, including 720p/1080p screenshots,
  actual irrigation consumption, pipe/ladder pixel ordering and ambient-lit ship
  ports that remain visible at distance without revealing dark rock valves;
  `reports/blue-water-native-ui.log`.
- Circuit native smoke, full industry/travel/save smoke, background pipe placement,
  mining refusal/reach, scanner and rocket movement/hatch/save regressions pass.
  Mixtures remain deferred. Hardware-controller QA remains outstanding. No commit,
  push, merge or restart of the user's already-running old game was performed.

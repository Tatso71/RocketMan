# RocketMan AI Handoff

## Current Direction (2026-10-24)

Tutorial update: new campaigns expose only Ocra until the first underground laboratory completes, revealing Viridia and Brina. Route validation enforces the gate; existing saves already exploring outer planets retain access. Robbie immediately requests 6 stone + 4 copper after the first mined cell, repeats unfinished objectives, recognizes a supported 4 x 3 room and explains cube placement/funding. Research remains global across planets and power outages.

Construction now uses a selectable dependency Tree in `construction_ui.gd`; laboratory is the root and light/pump children remain hidden before the first completed lab. Opening the picker alone draws no footprint. Invalid recipes are selectable and explain their blocker; choosing starts a movable preview, with the cursor anchored near the floor and the footprint growing upward. Invalid placement clicks leave the preview active without creating a cube. Physical backpack/nearby-Robbie supplies are combined at funding; the integration test reproduces 6 stone + 6 copper split across both holds.

Pumps are implemented: 2 x 2 m, 3 stone + 4 copper, 4 s build, 0.08 kWh/s construction and 0.03 kWh/s active draw. A linked powered lab is required. `environment_field.drain_water` removes finite water at 0.7 units/s through connected open cells within three grid steps; removed water is discarded, not stored. Drain statistics persist. Robbie navigates dry cells, stops outside water while the player is submerged, flashes red and explicitly warns of suit damage. Current verification: 70 unit tests and eight integration scripts; `robbie_tutorial_smoke.gd` covers the complete tutorial, tree, split cargo, pump, water alarm and save/load, with 720p/1080p captures.

Latest loop update: new arrivals spawn in the upper cockpit; `ship_rooms.gd` handles highlighted cockpit navigation/battery service and middle-bedroom rest. `crew_energy` is personal fatigue, distinct from ship `energy`; bed restores crew/suit state but not charge. The fixed Cantiere panel is removed. Right-click empty space opens `construction_ui.gd`: only laboratories/lights become unfunded creator cubes, reserve dashed footprints, request explicit local material transfer, then unfold/flash under timed progress bars. Only completed labs unlock research/services. Ladders are explicitly instant manual construction with B for 2 soil: no cube, popup, timer, drone or battery. Pending/building/active state and paid progress persist; legacy active structures and light kits remain compatible. Older paid ladder cubes migrate to ready ladders without another charge; unfunded ladder plans are discarded.

Shared power now drains ship battery continuously for active labs/linked lights and electric construction. Zero charge pauses construction and disables powered services/lighting, without destroying caches. Field-lab right-click includes a power toggle. Ordinary modal menus pause simulation; active rest continues the network and construction. Only the currently visited outpost is simulated. Cabin battery upgrades use the existing copper/crystal progression, not free capacity or a bed-generated charge. New test: `tests/integration/creator_cube_smoke.gd`; all seven integration scripts cover the changed cube flow. Geometry fixtures never become production starter excavations.

The current specification is `docs/superpowers/specs/2026-10-24-rocket-home-and-digging.md`, superseding the historical premise below. The main scene now routes to `scenes/prototype/expedition.tscn`: planet selection, automatic flight/landing, playable rocket cutaway/digging, and return to orbit. Keep the previous hub/biome scenes and unrelated local changes intact.

Geometry source of truth: `scripts/world/world_grid.gd` (1 cell = 1 m = 40 px). Cell positions in terrain and saves are integers. Three 3 m rooms, a 2 m shaft, and a 0.6 x 1.6 m player define the initial scale. Graphics may bevel cell borders but must not change collision footprints.

Campaign progress uses `SaveManager.write_campaign_save/read_campaign_save` at `user://saves/campaign_v1.json`. The standalone rocket scene still uses `rocket_home_v1.json`; do not overwrite legacy `slot_01.json`. Runtime controls are installed by the prototype without changing global Godot settings. Authoritative phase/ship/tool contracts are documented in `docs/technical/expedition-and-ship-systems.md`.

Current next work: try the dark close-camera mining loop, add powered sealed-room habitability, then physical grid-based ship expansions. Four digital-tool slots and a scanner are implemented; ship-station levels unlock additional extractors. Creatures remain a decorative placeholder; final 2.5D art and piloted flight remain later production steps.

Environment update: gas/water pockets, finite water flow, gas diffusion, scan warnings, suit protection and true indestructible anchors are implemented. Keep environment state separate from terrain removal lists. Use `tests/integration/hazards_smoke.gd` for exposure/scan/persistence checks. The current laboratory/drone contract is in `docs/superpowers/specs/2026-10-24-underground-construction-and-assistant.md`.

Construction update: initial ground is now untouched (no starter shaft/room/light/crate). AStar2D support drone, separate physical backpack/drone holds, laboratory placement, 32-unit local caches, lamp fabrication and placed illumination are implemented. Lab research gates advanced tool/drone upgrades, not first digging or emergency ladders. Follow the current construction spec and `tests/integration/outpost_smoke.gd`; older traversal tests explicitly create test-only tunnels. Never restore the former starter excavations into production setup.

Usability update: `field_inventory_ui.gd` shows live per-material backpack/drone counts and a three-column inventory (I), inspectable anywhere but transferable only at local depots. Scarica tutto unloads accessible holds; Prepara laboratorio atomically loads missing recipe supplies from the ship workshop. Cantiere compares available/required resources, and a non-solid laboratory may overlap the explorer during placement. `drone_guide_state.gd` + `drone_guide.gd` provide prioritized comic balloons, H/manual recall and saved mute/milestone state. Campaign guide ownership is global in ShipState; do not restore per-planet copies over it. Current verification: 52 unit tests and five integration scripts, including `inventory_guide_smoke.gd` (720p/1080p captures).

Direct interaction update: reachable ship/field laboratories now glow; right-click opens five actions through `workstation_menu.gd`. Field labs have saved levels I-III, level-derived cache capacity (32/48/64) and lamp range (8/10/12 m); ship-lab upgrade reuses the tool-station module. Selected station cache, line-of-sight checks and modal pause are owned by `outpost_controller.gd`. Suit repair works locally, hull repair only aboard. Clicking the drone replays exact session-local last text and must not mine; building mode retains placement priority. H still requests fresh advice. Verify with 55 unit tests and six integration scripts, including `workstation_smoke.gd`. Rendered tests check subwindow layouts and 720p/1080p highlights.

The remainder of this document describes the previous May baseline, retained for context.

Date: 2026-05-12
Audience: Aurora and AI coding agents

## One Sentence

RocketMan is a calm 2D exploratory platformer about inheriting an underground base, studying alien animal species, and rebuilding a rocket before the planet collapses.

## Product Direction

Use the direction from `docs/superpowers/specs/2026-05-10-rocketman-design.md`:

- Base mystery plus expedition modules.
- Animals are a core exploration system.
- Crafting is guided by discovered schemas.
- The rocket is the macro-objective.
- Combat is light and situational, not a pillar.
- Expeditions should produce knowledge or progress even when incomplete.

## Current Vertical Slice

Implemented systems:

- Godot project bootstrap
- Main scene and scene routing
- Persistent game state
- Base hub scene
- Exterior biome scene
- Player movement and interaction
- Inventory
- Expedition party limit
- Species codex
- Crafting lab
- First rocket objective HUD
- Save/config manager baseline
- Keyboard and gamepad input baseline

## Important Files

- `project.godot`
- `README.md`
- `docs/superpowers/specs/2026-05-10-rocketman-design.md`
- `docs/superpowers/plans/2026-05-10-rocketman-godot-vertical-slice.md`
- `docs/technical/godot-project-baseline.md`
- `docs/technical/steam-release-plan.md`
- `scripts/core/game_state.gd`
- `scripts/core/save_manager.gd`
- `scripts/core/scene_router.gd`
- `scripts/systems/inventory.gd`
- `scripts/systems/expedition_party.gd`
- `scripts/systems/crafting_lab.gd`
- `scenes/base/base_hub.tscn`
- `scenes/exterior/biome_01.tscn`

## Coding Guidelines

- Keep scripts small and responsibility-focused.
- Prefer explicit names over clever abstractions.
- Avoid unrelated refactors.
- Preserve autoload names unless intentionally migrating them.
- Add tests for shared systems and progression rules.
- Keep scene paths stable.
- Use `user://` for save/config data.
- Keep Steam integration optional and isolated.

## Current Input Contract

Core actions:

- `move_left`
- `move_right`
- `jump`
- `interact`
- `open_journal`
- `pause`

Every new gameplay mechanic should define keyboard and controller behavior.

## Save Contract

Use `SaveManager`.

Save data path:

```text
user://saves/slot_01.json
```

Settings path:

```text
user://config/settings.json
```

Do not store machine-specific video settings in progression saves.

## Steam Assumptions

Target Steam first with:

- Windows build
- Linux build
- Steam Deck compatibility in mind
- Steam Auto-Cloud first

Do not add Steamworks SDK until a feature needs it.

## Verification

Run:

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit
```

Then:

```powershell
addons\gdUnit4\runtest.cmd --godot_binary "%LOCALAPPDATA%\Programs\Godot\4.6.2\Godot_v4.6.2-stable_win64_console.exe" -a res://tests/unit/
```

Expected current result:

```text
4 test cases | 0 errors | 0 failures
```

## Next Best Tasks

1. Add a real save/load test around `SaveManager`.
2. Add controller prompt UI instead of hardcoded keyboard text.
3. Add export templates and `export_presets.cfg`.
4. Add a simple pause menu.
5. Replace scripted biome rewards with interactable pickups/scans.

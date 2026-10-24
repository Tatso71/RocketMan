# RocketMan AI Handoff

## Current Direction (2026-10-24)

The current specification is `docs/superpowers/specs/2026-10-24-rocket-home-and-digging.md`, superseding the historical premise below. The main scene now routes to `scenes/prototype/expedition.tscn`: planet selection, automatic flight/landing, playable rocket cutaway/digging, and return to orbit. Keep the previous hub/biome scenes and unrelated local changes intact.

Geometry source of truth: `scripts/world/world_grid.gd` (1 cell = 1 m = 40 px). Cell positions in terrain and saves are integers. Three 3 m rooms, a 2 m shaft, and a 0.6 x 1.6 m player define the initial scale. Graphics may bevel cell borders but must not change collision footprints.

Campaign progress uses `SaveManager.write_campaign_save/read_campaign_save` at `user://saves/campaign_v1.json`. The standalone rocket scene still uses `rocket_home_v1.json`; do not overwrite legacy `slot_01.json`. Runtime controls are installed by the prototype without changing global Godot settings. Authoritative phase/ship/tool contracts are documented in `docs/technical/expedition-and-ship-systems.md`.

Current next work: try the dark close-camera mining loop, add powered sealed-room habitability, then physical grid-based ship expansions. Four digital-tool slots and a scanner are implemented; ship-station levels unlock additional extractors. Creatures remain a decorative placeholder; final 2.5D art and piloted flight remain later production steps.

Environment update: gas/water pockets, finite water flow, gas diffusion, scan warnings, suit protection and true indestructible anchors are implemented. Keep environment state separate from terrain removal lists. Use `tests/integration/hazards_smoke.gd` for exposure/scan/persistence checks. The current laboratory/drone contract is in `docs/superpowers/specs/2026-10-24-underground-construction-and-assistant.md`.

Construction update: initial ground is now untouched (no starter shaft/room/light/crate). AStar2D support drone, separate physical backpack/drone holds, laboratory placement, 32-unit local caches, lamp fabrication and placed illumination are implemented. Lab research gates advanced tool/drone upgrades, not first digging or emergency ladders. Follow the current construction spec and `tests/integration/outpost_smoke.gd`; older traversal tests explicitly create test-only tunnels. Never restore the former starter excavations into production setup.

Usability update: `field_inventory_ui.gd` shows live per-material backpack/drone counts and a three-column inventory (I), inspectable anywhere but transferable only at local depots. Scarica tutto unloads accessible holds; Prepara laboratorio atomically loads missing recipe supplies from the ship workshop. Cantiere compares available/required resources, and a non-solid laboratory may overlap the explorer during placement. `drone_guide_state.gd` + `drone_guide.gd` provide prioritized comic balloons, H/manual recall and saved mute/milestone state. Campaign guide ownership is global in ShipState; do not restore per-planet copies over it. Current verification: 52 unit tests and five integration scripts, including `inventory_guide_smoke.gd` (720p/1080p captures).

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

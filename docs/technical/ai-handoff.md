# RocketMan AI Handoff

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

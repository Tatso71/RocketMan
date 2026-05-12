# RocketMan Godot Project Baseline

Date: 2026-05-12
Engine: Godot 4.6.2 stable
Target genre: 2D exploratory platformer
Primary distribution target: Steam PC

## Project Intent

RocketMan should be configured as a controller-friendly 2D platformer with a calm exploration loop:

base hub -> expedition prep -> exterior biome -> discovery -> return to base -> unlock/craft/progress.

The project should avoid assumptions that only work on keyboard and mouse. All core gameplay must remain playable with a gamepad so the game can target Steam and Steam Deck cleanly.

## Current Engine Baseline

The project is configured in `project.godot` with:

- Main scene: `res://scenes/app/game_root.tscn`
- Godot feature tag: `4.6`
- Base viewport: `1280x720`
- Stretch mode: `canvas_items`
- Stretch aspect: `keep`
- Custom user directory enabled: `RocketMan`

The selected stretch settings are appropriate for a 2D game that is not yet committed to strict pixel art. If RocketMan becomes a pixel art game, revisit texture import defaults, filtering, snapping, and viewport scaling before producing final art.

## Autoloads

Current autoloads:

- `GameStateStore`: persistent run state for scans, materials, terminals, and crafted parts.
- `SceneRouter`: scene transition helper.
- `SaveManager`: save/config file locations and JSON read/write helpers.

Keep autoloads small. Add new autoloads only for state or services that must survive scene changes.

## Input Baseline

Actions currently defined:

- `move_left`: keyboard A, left analog stick, D-pad left
- `move_right`: keyboard D, left analog stick, D-pad right
- `jump`: Space, gamepad south face button
- `interact`: E, gamepad west face button
- `open_journal`: J, gamepad north face button
- `pause`: Escape, gamepad Start/Menu

Design rule: every gameplay action needed to complete the game must have a gamepad binding from the start.

For UI prompts, prefer action-aware copy such as "Interact" internally, then map to glyphs in UI. Do not hardcode "Press E" in gameplay text.

## Save Data Baseline

Use `SaveManager` for file locations:

- Save slot: `user://saves/slot_01.json`
- Settings: `user://config/settings.json`

Keep save data separate from machine-specific settings. This makes Steam Cloud easier to configure and avoids syncing video/audio preferences as if they were progression.

Recommended save categories:

- Story/progression flags
- Scanned species
- Materials/inventory
- Crafted rocket parts
- Base unlocks
- Expedition unlocks

Recommended settings categories:

- Display mode
- Resolution
- Audio levels
- Language
- Input remapping

## Implementation Rules For Future Agents

- Preserve the core loop and modular hub/biome structure.
- Prefer data-driven species, material, schema, and biome definitions.
- Keep animals as exploration partners, not combat units.
- Do not add heavy base management systems unless explicitly requested.
- Avoid real-time fail pressure. Planet collapse is narrative pressure, not a constant timer.
- Keep Steam-specific code behind a small adapter if direct Steamworks integration becomes necessary.

## Verification Commands

Installed Godot path on this workstation:

```powershell
%LOCALAPPDATA%\Programs\Godot\4.6.2\Godot_v4.6.2-stable_win64_console.exe
```

Headless boot:

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --quit
```

GdUnit tests:

```powershell
addons\gdUnit4\runtest.cmd --godot_binary "%LOCALAPPDATA%\Programs\Godot\4.6.2\Godot_v4.6.2-stable_win64_console.exe" -a res://tests/unit/
```

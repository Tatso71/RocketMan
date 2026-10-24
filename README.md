# RocketMan

Godot 4 exploration game about landing on unknown planets and building a home beneath a three-storey rocket. Target presentation: colorful low-poly 2.5D; the current playable geometry prototype is native 2D.

## Current slice

- Three-floor rocket home: cockpit, living quarters, workshop
- Internal ladders and a lower hatch leading into a dig site
- Metric terrain: 1 cell = 1 metre = 40 prototype pixels
- Mining, material hardness, resource collection and ladder placement
- Separate outpost save/load; legacy base and biome scenes preserved
- Three destinations, automatic flight, vertical landing and return to orbit
- Persistent ship condition, fuel, batteries, cargo, repair and upgrade costs
- Four equipment slots, digital extraction beams, composition scanner and local illumination

Current design: `docs/superpowers/specs/2026-10-24-rocket-home-and-digging.md`.
Visual reference: `refs/rocket-concepts/03-landed-cutaway.png`.

## Run

Open `project.godot` in Godot 4.6 and press F5 for the complete expedition prototype. Select a destination and start the flight. F6 on `scenes/prototype/rocket_home.tscn` still runs the isolated digging sandbox.

Keyboard/mouse: A/D move, W/S or up/down climb, Space jump, E toggle nearby hatch, hold left mouse or F to use the current digital tool, 1-4 select equipment, Q cycle equipment, B place a one-metre ladder for 2 soil, G toggle metric overlay, mouse wheel zoom, C toggle close/overview camera, Home return to workshop. The scanner analyzes composition without destroying terrain.

Controller: left stick move/climb, A jump, X hatch, right stick aim, RB use tool, LB next tool, Y ladder, left-stick click grid, right-stick click camera, Back return home, Start ship menu. Controller bindings are implemented; physical controller QA remains necessary.

The prototype starts fresh; use Load to resume. Campaign progress is saved manually in `user://saves/campaign_v1.json`, including midflight state, ship and individual planets. The isolated sandbox still uses `rocket_home_v1.json`; neither overwrites legacy `slot_01.json`. In the expedition, use Ship for upgrades/maintenance in orbit or in the workshop; return aboard and close the hatch before Take Off.

PC target: 16:9, validated at 1920x1080 and 1280x720. The logical 1280x720 canvas scales to desktop resolution; close camera zoom is independent of window size. This is not yet a Steam release/export build.

## Test

`godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/ --ignoreHeadlessMode`

Set `godot` to your Godot console executable. End-to-end geometry/traversal checks: `godot --headless --path . -s res://tests/integration/rocket_home_smoke.gd`. Omit `--headless` and add `-- --capture` for a rendered screenshot in `reports/`.

Complete travel/equipment/persistence checks: `godot --headless --path . -s res://tests/integration/expedition_smoke.gd`. Run without `--headless`, with `-- --capture`, to generate PC screenshots of navigation, flight, landing, maintenance and dark digging.

## Large Assets

- Files under `assets/` and `source_assets/` with common image/source-art extensions are tracked with Git LFS.
- This repository is configured with `skip-smudge`, so heavy assets are not downloaded automatically on checkout.
- Download tracked assets only when needed with:

`git lfs pull --include="assets/**,source_assets/**"`

## Technical Docs

- `docs/technical/godot-project-baseline.md`
- `docs/technical/steam-release-plan.md`
- `docs/technical/ai-handoff.md`

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
- Indestructible formations, sealed gas/water pockets, environmental scan warnings and suit protection
- Untouched landing ground, a physically following radio-limited drone, backpack/drone cargo
- Buildable 4 x 3 m laboratory, local cache, lamp fabrication and persistent gallery lights
- Live backpack/drone contents, three-column inventory, local transfers and a laboratory supply shortcut
- Contextual drone speech balloons with manual recall and saved automatic-help preference

Current design: `docs/superpowers/specs/2026-10-24-rocket-home-and-digging.md`.
Complete content and systems design for AI implementation: [docs/design/README.md](docs/design/README.md) (versioned JSON catalogs, dependencies, recipes, GUI and visual assets; proposed systems are not all implemented).
Visual reference: `refs/rocket-concepts/03-landed-cutaway.png`.

## Run

Open `project.godot` in Godot 4.6 and press F5 for the complete expedition prototype. Select a destination and start the flight. F6 on `scenes/prototype/rocket_home.tscn` still runs the isolated digging sandbox.

Keyboard/mouse: A/D move, W/S or up/down climb, Space jump, E toggle nearby hatch, hold left mouse or F to use the current digital tool, 1-4 select equipment, Q cycle equipment, B place a one-metre ladder for 2 soil, G toggle metric overlay, mouse wheel zoom, C toggle close/overview camera, Home return to workshop. The scanner analyzes composition without destroying terrain.

Construction: V or Build toggles the grid preview; choose Laboratory/Light, move the mouse and click to place. Right click or Escape cancels. Lab costs 6 stone + 4 copper and needs a clear 4 x 3 m room with a full supporting floor; the explorer may stand inside while placing it. The Cantiere panel compares each required material with accessible backpack/drone/local-cache contents. Fabricate each light at the lab for 1 soil + 1 copper, then place its carried kit in an empty supported cell. Backpack capacity is 8; nearby drone adds 12. Mine results stay in these physical holds until explicitly deposited, never directly in ship storage.

Inventory: I or Inventario opens separate backpack, drone and local-deposit columns anywhere. Transfers work only in the workshop or beside an operational laboratory. Scarica tutto empties the backpack and the physically nearby drone into that deposit. In the ship workshop, Prepara laboratorio loads only missing ingredients for the 6 stone + 4 copper recipe; it checks stock and free carried space before transferring anything. Remote drone contents are visible but excluded from costs/capacity. E beside a lab opens the same cargo/crafting window; I or Escape closes it.

Drone help: contextual comic balloons explain first excavation, loading/unloading, laboratory placement, lights and actual hazards. H or the question-mark button recalls the current advice; Aiuti drone silences automatic speech. Hints do not pause play; the inventory does pause local movement/hazards. Seen hints, milestones and the mute preference are saved, globally for campaigns and locally for the isolated sandbox.

Controller: left stick move/climb, A jump, X hatch, right stick aim, RB use tool, LB next tool, Y ladder, left-stick click grid, right-stick click camera, Back return home, Start ship menu. Controller bindings are implemented; physical controller QA remains necessary.

Controller construction: LB+Y toggles building, right stick moves the snapped preview, X places, B cancels. UI controls also accept normal focus navigation. New games have no pre-excavated passages; older saves retain their actual player-made terrain changes.

The prototype starts fresh; use Load to resume. Campaign progress is saved manually in `user://saves/campaign_v1.json`, including midflight state, ship and individual planets. The isolated sandbox still uses `rocket_home_v1.json`; neither overwrites legacy `slot_01.json`. In the expedition, use Ship for upgrades/maintenance in orbit or in the workshop; return aboard and close the hatch before Take Off.

PC target: 16:9, validated at 1920x1080 and 1280x720. The logical 1280x720 canvas scales to desktop resolution; close camera zoom is independent of window size. This is not yet a Steam release/export build.

## Test

`godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/ --ignoreHeadlessMode`

Set `godot` to your Godot console executable. End-to-end geometry/traversal checks: `godot --headless --path . -s res://tests/integration/rocket_home_smoke.gd`. Omit `--headless` and add `-- --capture` for a rendered screenshot in `reports/`.

Complete travel/equipment/persistence checks: `godot --headless --path . -s res://tests/integration/expedition_smoke.gd`. Run without `--headless`, with `-- --capture`, to generate PC screenshots of navigation, flight, landing, maintenance and dark digging.

Hazard checks: `godot --headless --path . -s res://tests/integration/hazards_smoke.gd`. Scanner can warn of a pocket adjacent to a wall before you break it. Gas degrades suit protection; water slows movement and can submerge the explorer (W/up swims upward). At zero protection the prototype recalls you to the ship; protection recovers aboard. Anchor formations cannot be destroyed even by Plasma. Fluids remain a small grid simulation, not full pressure/ship-contamination physics.

Drone/building checks: `godot --headless --path . -s res://tests/integration/outpost_smoke.gd`; remove `--headless` and append `-- --capture` for 1080p screenshots. Regression tests carve their own fixtures; these tunnels are not part of a new game.

Inventory/tutorial checks: `godot --headless --path . -s res://tests/integration/inventory_guide_smoke.gd`; remove `--headless` and append `-- --capture` for the inventory and 720p/1080p balloon screenshots. Checks include exact local recipe preparation, full/missing-stock atomicity, remote read-only inventory, player-overlapping laboratory placement and saved tutorial progress.

## Large Assets

- Files under `assets/` and `source_assets/` with common image/source-art extensions are tracked with Git LFS.
- This repository is configured with `skip-smudge`, so heavy assets are not downloaded automatically on checkout.
- Download tracked assets only when needed with:

`git lfs pull --include="assets/**,source_assets/**"`

## Technical Docs

- `docs/technical/godot-project-baseline.md`
- `docs/technical/steam-release-plan.md`
- `docs/technical/ai-handoff.md`

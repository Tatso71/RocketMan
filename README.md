# RocketMan

Godot 4 exploration game about landing on unknown planets and building a home beneath a three-storey rocket. Target presentation: colorful low-poly 2.5D; the current playable geometry prototype is native 2D.

## Current slice

- Three-floor rocket home: cockpit, living quarters, workshop
- Internal ladders and a lower hatch leading into a dig site
- Metric terrain: 1 cell = 1 metre = 40 prototype pixels
- Mining, material hardness, resource collection and ladder placement
- Separate outpost save/load; legacy base and biome scenes preserved
- Ocra tutorial destination first; Viridia and Brina unlock after the first completed laboratory
- Persistent ship condition, fuel, batteries, cargo, repair and upgrade costs
- Four equipment slots, digital extraction beams, composition scanner and local illumination
- Indestructible formations, sealed gas/water pockets, environmental scan warnings and suit protection
- Untouched landing ground, a physically following radio-limited drone, backpack/drone cargo
- Buildable 4 x 3 m laboratory, local cache, lamp fabrication and persistent gallery lights
- Live backpack/drone contents, three-column inventory, local transfers and a laboratory supply shortcut
- Contextual drone speech balloons with manual recall and saved automatic-help preference
- Proximity-highlighted laboratories with right-click actions for materials, construction, repairs and upgrades
- Cockpit arrival, interactive navigation floor, bedroom rest and separate personal/ship energy
- Seven-step data-authored Ocra tutorial, saved objectives and Robbie's contextual action panel
- Physical laboratory cubes fabricated aboard, weighted cargo, unfolding construction and shared battery draw

Current design: `docs/superpowers/specs/2026-10-24-rocket-home-and-digging.md`.
Complete content and systems design for AI implementation: [docs/design/README.md](docs/design/README.md) (versioned JSON catalogs, dependencies, recipes, GUI and visual assets; proposed systems are not all implemented).
Visual reference: `refs/rocket-concepts/03-landed-cutaway.png`.

## Run

Open `project.godot` in Godot 4.6 and press F5 for the complete expedition prototype. Select a destination and start the flight. F6 on `scenes/prototype/rocket_home.tscn` still runs the isolated digging sandbox.

Keyboard/mouse: A/D move, W/S or up/down climb, Space jump, E toggle nearby hatch, hold left mouse or F to use the current digital tool, 1-4 select equipment, Q cycle equipment, B instantly build a one-metre ladder for 2 soil, G toggle metric overlay, mouse wheel zoom, C toggle close/overview camera, Home return to workshop. The scanner analyzes composition without destroying terrain.

Arrival and rooms: each fresh landing starts the pilot in the top-floor cockpit. Its highlight/right-click menu opens ship management, battery upgrades or takeoff. Descend the internal ladder to the highlighted bedroom: right-click and Riposa to recover personal energy and suit integrity. Walking/climbing/tool pulses spend personal energy; exhaustion slows movement, without hard-locking the return trip. Rest does not refill the ship battery. Existing saves retain actual player position. Home/emergency recall still returns to the workshop.

Construction: in the ship workshop, right-click and Costruisci opens fabrication. The laboratory recipe consumes 6 stone + 4 copper once at completion, from physical carried/nearby-Robbie/ship stock. It produces a laboratory cube occupying 4 cargo units in one hold. Right-click underground, select Laboratory and Posiziona cubo to move the dashed 4 x 3 m preview; a valid click consumes only that cube and starts unfolding, with no second material transfer. Opening a picker alone draws no footprint; invalid recipes stay selectable and invalid placements consume nothing. The footprint grows upward from the floor. Existing unfunded laboratory sites retain their old local-funding prompt. Lights/pumps still use that local-funding flow in this slice; they remain hidden children of the laboratory until the first completion. Ladders are instant manual construction with B for 2 soil, without cube, popup, timer or energy.

Costs/duration: laboratory fabrication 6 stone + 4 copper + 0.01 kWh / 5 s, then 5 s unfolding; light 1 soil + 1 copper / 2.5 s; pump 3 stone + 4 copper / 4 s; ladder 2 soil / instantaneous. Closing an unfinished fabrication cancels without spending materials. One laboratory cube weighs 4 abstract cargo units and cannot be split across containers. Backpack capacity is 8; nearby Robbie adds 12. Previously fabricated light kits remain accepted. Mine results stay in physical holds until explicitly deposited, never directly in ship storage.

Laboratory interaction: the ship workbench or a reachable underground laboratory lights up when available. Right-click its room/bench to open Deposita materiali, Preleva materiali, Costruisci, Ripara and Potenzia laboratorio. Deposit is immediate; withdrawal opens the local inventory. Construction offers laboratory-cube fabrication aboard and footprint planning underground. E beside an underground lab opens the same contextual menu. A wall blocks access even at short distance. When several labs are near, the clicked lab supplies the selected depot. Accendi/Spegni controls a field lab's power demand; an unpowered lab retains physical storage access but cannot craft, repair, research-upgrade or light its surroundings.

Power network: active field labs draw 0.04/0.05/0.06 kWh/s at levels I/II/III; linked lights add 0.008 kWh/s. Unfolding lab/light cubes draw 0.06/0.02 kWh/s. No demand comes from unfunded cubes or ladders. The HUD shows ship charge, network kWh/min and remaining runtime. Zero charge pauses electric construction and disables powered services/lights; it never makes battery energy negative. Cabin management upgrades battery capacity from 60 to 100/140 kWh using copper/crystals, without refilling it. Only the currently visited outpost is simulated; menus pause it, except active bed rest, during which construction and network draw continue.

Inventory: I or Inventario opens separate backpack, Robbie and local-deposit columns. Transfers work only in the workshop or beside a reachable laboratory; remote storage is read-only. Scarica tutto empties accessible holds. Fabbrica cubo opens the workshop recipe rather than asking the player to carry ten raw ingredients to the site. Counts and transfers respect the cube's four-unit weight. Ingredient availability includes the ship hold only while physically aboard the workshop. Robbie's contents remain visible but are usable only nearby and connected. The legacy raw-supply helper remains for compatibility, not as the primary visible command.

Tutorial/Robbie: seven authored tasks run from cockpit descent to the first active laboratory: workshop, hatch, two mined cells, instant ladder, physical cube, supported 4 x 3 room, deployment/completion. A persistent panel shows one goal, progress, relevant counts and a contextual action. Actual events advance the tutorial even when speech is muted or actions happen early; no time or acknowledgement gate is imposed. Tasks live in `design/v1/progression.json` under `ocra_tutorial`; see [adding Robbie tasks](docs/technical/robbie-tutorial-authoring.md). Dangers take priority over repeatable advice. Robbie prefers clear resting positions about 2 m away, avoids the player's body while navigating and still helps within 3 m. Underwater it stops outside water and flashes red. Full 12-planet progression, Ferrum and an Ocra termination layer are not introduced by this slice; existing three-destination unlocks remain compatible.

Pump: the powered 2 x 2 device may be placed in water (not gas) inside an active lab's connection radius. It removes up to 0.7 water units/s through connected open cells within three grid steps, never through rock. It draws 0.03 kWh/s, or 0.08 during unfolding, from the shared battery. No drainage occurs before completion, without lab power or beyond remaining battery runtime. Removed water and cumulative drainage statistics persist; water is discarded in this prototype rather than stored in a tank/inventory.

Repairs: aboard, suit repair is free and hull repair costs 2 stone + 1 copper for 25 integrity. An underground powered lab restores the suit for 2 soil + 1 copper from portable/local stock; it cannot repair the ship remotely. Ship-lab upgrades use the existing tool-station progression and research gate. Each underground-lab level (I-III) adds 16 cache units and 2 m lamp connection range: 32/48/64 units and 8/10/12 m. Upgrade costs are 4 stone + 3 copper times the current level, with increased running draw. New lights use the cube workflow; the old kit-crafting API remains for backward compatibility, not as a visible primary action.

Drone help: contextual comic balloons explain first excavation, loading/unloading, laboratory placement, lights and actual hazards. Left-click the drone to repeat its exact last displayed message, even with automatic hints muted; H or the question-mark button requests advice for the current situation. Building mode retains click-to-place priority. Aiuti drone silences automatic speech. Hints do not pause play; inventory and station menus pause local movement/hazards. Seen hints, milestones and the mute preference are saved, globally for campaigns and locally for the isolated sandbox.

Controller: left stick move/climb, A jump, X hatch, right stick aim, RB use tool, LB next tool, Y ladder, left-stick click grid, right-stick click camera, Back return home, Start ship menu. Controller bindings are implemented; physical controller QA remains necessary.

Controller construction: LB+Y toggles building, right stick moves the snapped preview, X places, B cancels. UI controls also accept normal focus navigation. New games have no pre-excavated passages; older saves retain their actual player-made terrain changes.

The prototype starts fresh; use Load to resume. Campaign progress is saved manually in `user://saves/campaign_v1.json`, including midflight state, ship and individual planets. The isolated sandbox still uses `rocket_home_v1.json`; neither overwrites legacy `slot_01.json`. In the expedition, use Ship for upgrades/maintenance in orbit or in the workshop; return aboard and close the hatch before Take Off.

PC target: 16:9, validated at 1920x1080 and 1280x720. The logical 1280x720 canvas scales to desktop resolution; close camera zoom is independent of window size. This is not yet a Steam release/export build.

## Test

`godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/ --ignoreHeadlessMode`

Set `godot` to your Godot console executable. End-to-end geometry/traversal checks: `godot --headless --path . -s res://tests/integration/rocket_home_smoke.gd`. Omit `--headless` and add `-- --capture` for a rendered screenshot in `reports/`.

Complete travel/equipment/persistence checks: `godot --headless --path . -s res://tests/integration/expedition_smoke.gd`. Run without `--headless`, with `-- --capture`, to generate PC screenshots of navigation, flight, landing, maintenance and dark digging.

Hazard checks: `godot --headless --path . -s res://tests/integration/hazards_smoke.gd`. Scanner can warn of a pocket adjacent to a wall before you break it. Gas degrades suit protection; water slows movement and can submerge the explorer (W/up swims upward). At zero protection the prototype recalls you to the ship; rest in the bedroom or use a repair station to recover. Anchor formations cannot be destroyed even by Plasma. Fluids remain a small grid simulation, not full pressure/ship-contamination physics.

Drone/building checks: `godot --headless --path . -s res://tests/integration/outpost_smoke.gd`; remove `--headless` and append `-- --capture` for 1080p screenshots. Regression tests carve their own fixtures; these tunnels are not part of a new game.

Inventory/tutorial checks: `godot --headless --path . -s res://tests/integration/inventory_guide_smoke.gd`; remove `--headless` and append `-- --capture` for the inventory and 720p/1080p balloon screenshots. Checks include exact local recipe preparation, full/missing-stock atomicity, remote read-only inventory, player-overlapping laboratory placement and saved tutorial progress.

Station interaction checks: `godot --headless --path . -s res://tests/integration/workstation_smoke.gd`; rendered `-- --capture` includes 720p/1080p highlights and popup/detail screens. Covers all five actions, selected-cache isolation, wall occlusion, real upgrade effects, drone replay without mining, and upgraded-level persistence. Detailed window-layout checks use a real renderer, since headless subwindows can expose an uninitialized viewport size.

Creator-cube/room/power checks: `godot --headless --path . -s res://tests/integration/creator_cube_smoke.gd`; rendered `-- --capture` produces cockpit, bedroom, picker, missing-material/confirmation, unfolding and powered/unpowered outpost screens at 720p/1080p. Covers exact-once charging, half-built save/load, manual ladders, battery drain/cutoff and real cabin battery upgrades/takeoff.

Tutorial/dependency/pump checks: `godot --headless --path . -s res://tests/integration/robbie_tutorial_smoke.gd`; rendered `-- --capture` includes initial Ocra-only navigation, both dependency-tree states, room guidance, pumping and red water alarm at 720p/1080p. Reproduces the 6-stone/6-copper backpack/Robbie split, invalid clicks and upward floor-anchored placement.

Ocra onboarding: `godot --headless --path . -s res://tests/integration/ocra_onboarding_smoke.gd`. Traverses actual ship ladders, mines the room without tunnel fixtures, fabricates/carries/deploys the paid cube, checks Robbie's spacing, resumes a half-built save and completes the tutorial. Rendered `-- --capture` checks objectives, balloons, fabrication and the completed lab at 720p/1080p.

## Large Assets

- Files under `assets/` and `source_assets/` with common image/source-art extensions are tracked with Git LFS.
- This repository is configured with `skip-smudge`, so heavy assets are not downloaded automatically on checkout.
- Download tracked assets only when needed with:

`git lfs pull --include="assets/**,source_assets/**"`

## Technical Docs

- `docs/technical/godot-project-baseline.md`
- `docs/technical/steam-release-plan.md`
- `docs/technical/ai-handoff.md`

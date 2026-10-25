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
- Buildable 4 x 3 m laboratory and local cache; saved legacy lights/pumps remain operational
- Shared player/Robbie materials, visible combined totals, empty initial ship stock and local depot transfers
- Contextual drone speech balloons with manual recall and saved automatic-help preference
- Proximity-highlighted laboratories with right-click actions for materials, construction, repairs and upgrades
- Cockpit arrival, interactive navigation floor, bedroom rest and separate personal/ship energy
- Nine-step data-authored Ocra tutorial, saved objectives and Robbie's contextual action panel
- Persistent physical cube fabrication at ship/field benches, one-cube hand carry, unfolding and shared battery draw

Current design: `docs/superpowers/specs/2026-10-24-rocket-home-and-digging.md`.
Complete content and systems design for AI implementation: [docs/design/README.md](docs/design/README.md) (versioned JSON catalogs, dependencies, recipes, GUI and visual assets; proposed systems are not all implemented).
Visual reference: `refs/rocket-concepts/03-landed-cutaway.png`.

## Run

Open `project.godot` in Godot 4.6 and press F5 for the complete expedition prototype. Select a destination and start the flight. F6 on `scenes/prototype/rocket_home.tscn` still runs the isolated digging sandbox.

Keyboard/mouse: A/D move, W/S or up/down climb, Space picks up a nearby cube or drops the carried cube (otherwise jumps), E toggle nearby hatch, hold left mouse or F to use the current digital tool, 1-4 select equipment, Q cycle equipment, B instantly build a one-metre ladder for 2 soil, G toggle metric overlay, mouse wheel zoom, C toggle close/overview camera, Home return to workshop. Put the cube down before using a mining tool.

Arrival and rooms: each fresh landing starts the pilot in the top-floor cockpit. Its highlight/right-click menu opens ship management, battery upgrades or takeoff. Descend the internal ladder to the highlighted bedroom: right-click and Riposa to recover personal energy and suit integrity. Walking/climbing/tool pulses spend personal energy; exhaustion slows movement, without hard-locking the return trip. Rest does not refill the ship battery. Existing saves retain actual player position. Home/emergency recall still returns to the workshop.

Construction: right-click a reachable ship or underground laboratory and choose Costruisci. Each recipe row shows output name/level, time, red/green individual ingredient totals and Crea, disabled until affordable and the bench is available. Crea atomically consumes 6 stone + 4 copper from player + Robbie + that station's local storage and starts materializing a physical cube on the bench. Space picks it up into hands, Space drops it at the destination, then right-click that cube and Attiva laboratorio. Only activation checks the full supported, safe 4 x 3 m footprint. Invalid activation retains the cube with a red dashed box and a reason; pick it up to reposition. Successful activation unfolds it without another payment. The player can remain inside the nonblocking room. There are no free new underground blueprints. Only laboratory is currently offered; lights, water pump and gas-removal fan are future unlocks. Ladders remain instant manual construction with B for 2 soil.

Costs/duration: laboratory fabrication 6 stone + 4 copper + 0.01 kWh; station levels I/II/III take 5/3.33/2.5 seconds and currently output a level-I laboratory. Unfolding takes another 5 seconds. Jobs and ready outputs survive closing the panel and save/load; each station has one reserved output slot until pickup. One cube is carried in hands separately from raw inventory capacity. Backpack capacity is 8, Robbie adds 12, and their resources are always shared regardless of radio/distance. A new ship has no starter resources. Existing saves keep real stock and old paid inventory cubes, which materialize on pickup. Mining never directly credits ship storage.

Laboratory interaction: the ship workbench or a reachable underground laboratory lights up when available. Right-click its room/bench to open Deposita materiali, Preleva materiali, Costruisci, Ripara and Potenzia laboratorio. Deposit is immediate; withdrawal opens local inventory; construction opens the same physical-production table at either bench. E beside an underground lab opens its contextual menu. Walls block station access, and the selected station supplies only its own depot. Accendi/Spegni stops powered services while retaining access to physical storage; paid field production pauses rather than disappearing.

Power network: active field labs draw 0.04/0.05/0.06 kWh/s at levels I/II/III; saved linked lights add 0.008 kWh/s. Unfolding lab/light cubes draw 0.06/0.02 kWh/s. No demand comes from unfunded legacy plans or ladders. Zero charge pauses electric construction and powered services without negative battery energy. Cabin management upgrades battery capacity from 60 to 100/140 kWh without refilling it. Only the visited outpost is simulated; menus pause movement/hazards, but explicit paid fabrication continues. Ship jobs and cubes aboard travel with the ship; local jobs/cubes remain on their planet. No offline fabrication is simulated.

Inventory: I or Inventario opens backpack, Robbie and local-deposit columns. The compact HUD also shows the shared total. Transfers require a reachable laboratory, but always include both portable holds. Ship/depot ingredients are local, never remotely available. Fabbrica cubo opens that bench's recipe; the produced cube is not an inventory resource or another raw-material haul. Weighted inventory cubes remain supported only for old saves.

Tutorial/Robbie: nine authored tasks cover workshop, hatch, two mined cells, instant ladder, actual material collection, supported 4 x 3 room, bench fabrication, hand pickup and activation/completion. Actual events advance saved objectives even with speech muted or actions performed early. Tasks live in `design/v1/progression.json` under `ocra_tutorial`; see [adding Robbie tasks](docs/technical/robbie-tutorial-authoring.md). Dangers preempt repeatable advice. Robbie keeps about 2 m personal space and still obeys radio/navigation/water restrictions while its resources remain shared. Full 12-planet progression, Ferrum and an Ocra termination layer are not introduced here.

Pump: the powered 2 x 2 device may be placed in water (not gas) inside an active lab's connection radius. It removes up to 0.7 water units/s through connected open cells within three grid steps, never through rock. It draws 0.03 kWh/s, or 0.08 during unfolding, from the shared battery. No drainage occurs before completion, without lab power or beyond remaining battery runtime. Removed water and cumulative drainage statistics persist; water is discarded in this prototype rather than stored in a tank/inventory.

Repairs: aboard, suit repair is free and hull repair costs 2 stone + 1 copper for 25 integrity. Powered field labs repair suit for 2 soil + 1 copper from shared/local stock. Ship/field laboratory upgrades cost 4 stone + 3 copper times the current level and speed up fabrication; the ship laboratory level is distinct from the drill upgrade in ship management. Field levels also expand storage to 32/48/64 units and saved lamp links to 8/10/12 m. Old light-kit and raw-plan APIs remain for save compatibility, not visible new construction.

Drone help: contextual comic balloons explain first excavation, loading/unloading, laboratory placement, lights and actual hazards. Left-click the drone to repeat its exact last displayed message, even with automatic hints muted; H or the question-mark button requests advice for the current situation. Building mode retains click-to-place priority. Aiuti drone silences automatic speech. Hints do not pause play; inventory and station menus pause local movement/hazards. Seen hints, milestones and the mute preference are saved, globally for campaigns and locally for the isolated sandbox.

Controller: left stick move/climb, A jump, X hatch, right stick aim, RB use tool, LB next tool, Y ladder, left-stick click grid, right-stick click camera, Back return home, Start ship menu. Controller bindings are implemented; physical controller QA remains necessary.

Controller: contextual A uses the same pickup/drop-before-jump priority; UI controls accept normal focus navigation. The new activation popup is currently reached with mouse right-click; full hardware-controller interaction QA remains pending. New games have no pre-excavated passages; older saves retain their actual player-made terrain changes.

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

Physical fabrication: `godot --headless --path . -s res://tests/integration/physical_fabrication_smoke.gd`. Covers empty starting stock, split ingredients with distant Robbie, recipe colors/disabled actions, paid production independent of windows, ready/carried/dropped cube persistence, contextual Space without jumping, invalid red footprint, one-time activation, faster field laboratories, power pause and ship-factory ownership across travel. Add `-- --capture` with the native renderer for 720p/1080p GUI screenshots.

## Large Assets

- Files under `assets/` and `source_assets/` with common image/source-art extensions are tracked with Git LFS.
- This repository is configured with `skip-smudge`, so heavy assets are not downloaded automatically on checkout.
- Download tracked assets only when needed with:

`git lfs pull --include="assets/**,source_assets/**"`

## Technical Docs

- `docs/technical/godot-project-baseline.md`
- `docs/technical/steam-release-plan.md`
- `docs/technical/ai-handoff.md`

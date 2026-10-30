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
- Authored Ocra veins, indestructible massifs, sealed water/gas/oil pockets and depth-dependent darkness
- Untouched landing ground, a physically following radio-limited drone with exclusive material cargo and autonomous deliveries
- Buildable 4 x 3 m laboratory and local cache, unlocking lights, water pumps and gas fans
- Shared player/Robbie materials, visible combined totals, empty initial ship stock and local depot transfers
- Contextual drone speech balloons with manual recall and saved automatic-help preference
- Proximity-highlighted laboratories with right-click actions for materials, construction, repairs and upgrades
- Cockpit arrival, interactive navigation floor, bedroom rest and separate personal/ship energy
- Nine-step data-authored Ocra tutorial, saved objectives and Robbie's contextual action panel
- Persistent physical cube fabrication at ship/field benches, one-cube hand carry, unfolding and shared battery draw
- Gas converters, connected furnaces, irrigated greenhouses, finite local energy/water and planet seed discoveries
- Instant metre-grid water/gas pipes and energy cables; removable underground ladders and conduits

Current design: `docs/superpowers/specs/2026-10-24-rocket-home-and-digging.md`.
Complete content and systems design for AI implementation: [docs/design/README.md](docs/design/README.md) (versioned JSON catalogs, dependencies, recipes, GUI and visual assets; proposed systems are not all implemented).
Visual reference: `refs/rocket-concepts/03-landed-cutaway.png`.

## Run

Open `project.godot` in Godot 4.6 and press F5 for the complete expedition prototype. Select a destination and start the flight. F6 on `scenes/prototype/rocket_home.tscn` still runs the isolated digging sandbox.

In destination selection, Arriva subito al pianeta skips the flight/vertical-landing scenes and immediately opens the selected planet's playable cutaway. Avvia volo remains available for the normal presentation. Both routes use the same unlock checks, fuel/energy payment, landing wear and saved-outpost restoration; the shortcut does not grant resources or excavations.

New Ocra layout: the 48 x 24 m site retains virgin ground and the first 8 m tutorial resource route, with coherent copper/crystal veins, unbreakable massifs and six sealed pockets (10 water, 8 gas, 12 petroleum cell-volumes). Petroleum flows more slowly than water, slows/contaminates the explorer and damages the suit on contact; the scanner and Robbie identify it separately. It is not yet a collectible fuel, and the water pump cannot extract it. Fluids do not flow through rock or overlap beyond one liquid cell-volume. Breaking one gas pocket does not disperse other sealed pockets. Geology is authored in `scripts/data/ocra_geology.gd` and `scripts/data/hazard_layout.gd`.

Darkness increases smoothly between 2 and 16 m: the personal light contracts and dims, independently of tool reach. Powered laboratories and lamps retain their illumination, keeping installed gallery lighting useful. New saves record `layout_version`; pre-existing outposts retain their original terrain and pocket layout instead of replacing excavated tunnels or buildings.

Robbie text lab: open `scenes/labs/robbie_text_lab.tscn` and press F6. Search/select a message, edit title, balloon, priority and tutorial detail, and inspect the live preview. Salva testi (Ctrl+S) writes `design/v1/robbie_texts.json`, with a `.bak` of the previous file; external edits are detected before writing. This isolated scene never starts or saves a campaign. The game reads the same catalog. Tutorial completion rules remain in `progression.ocra_tutorial`; newly authored steps automatically appear in the lab with their fallback copy. Close/reload warns about unsaved changes. Restart a running game after changing copy.

Robbie navigation uses swept-body clearance, acceleration/braking, path lookahead, stable resting targets and body-aware avoidance. Refreshing a route no longer sends it back to the start-cell centre. It respects the radio limit, waits outside liquids and retains personal space where gallery geometry permits.

Keyboard/mouse: A/D move, W/S or up/down climb, Space picks up a nearby cube or drops the carried cube (otherwise jumps), E toggle nearby hatch, hold left mouse or F to use the current digital tool, 1-4 select equipment, Q cycle equipment, B instantly build a one-metre ladder for 2 soil, G toggle metric overlay, mouse wheel zoom, C toggle close/overview camera, Home return to workshop. Put the cube down before using a mining tool.

The lower hatch occupies one metre-grid cell, centred on its access ladder. Climb until your feet clear the workshop floor, then move left or right. Hatch traversal regression: `godot --headless --fixed-fps 60 --path . -s res://tests/integration/hatch_smoke.gd`; native `-- --capture` also writes 720p/1080p screenshots.

Equipment: 1 mining tool, 2 scanner, 3 bomb, 4 jetpack. Mining upgrades replace slot 1, retaining soil extraction. Start with four ready bombs, with a four-bomb reserve shown in slot 3. Placement consumes one prepared bomb, never raw resources. Replacements are made at either laboratory through Costruisci: 1 stone + 2 copper + 0.01 kWh, 2 seconds per bomb at level I, faster at higher lab levels. Bomb production shares the existing bench and progress bar, persists mid-job, pauses when unpowered or the reserve is full, and adds ammunition rather than a room cube. Empty reserves stay empty across saves and planetary travel. Bombs occupy one full cell; click to place on a free supported cell. Numbers follow placement order. Enter arms a 0.55-second-spaced sequence only when the explorer is at least 4 m from every remaining bomb; approaching again suspends the sequence until another safe Enter. Right-click disarms an unwanted bomb without a refund. Blasts excavate compatible terrain within 2 m, preserve indestructible/compact rock and structural supports, and leave uncollected ore on the ground. Nearby installations become nonoperational wrecks: right-click to repair for half their recipe, rounded up. Ladders and conduits need rebuilding. Ship workshop blast damage also affects the hull. Bombs, loose ore and damage persist; loading never starts an explosion automatically.

Jetpack: select 4 and hold Space or W for thrust. Its separate 100% battery lasts 5 seconds of sustained flight and recharges at 25%/s while standing inside the ship workshop or an intact, enabled, powered field lab. Charging uses 0.02 ship kWh per percentage point; empty supply batteries cannot recharge it. Water disables thrust. The hotbar shows charge and a meter. Cube pickup/drop still takes priority on the initial Space press.

Industry: after the first laboratory, fabricate furnace, gas-converter and greenhouse cubes with the existing bench/carry/unfold workflow. T or the bottom-left pipe icon selects instant water/gas pipes or energy cables, each costing 1 copper per metre; left-click/drag places, right-click/Esc exits. Gas pipes must reach actual gas and the converter's input; energy cables connect its output to furnaces/greenhouses. A water pipe from a powered pump feeds the greenhouse. Right-click a machine for orders, progress, reserves, harvest and power switch. Lost connections pause paid work. The converter stores at most 12 kWh and stops burning finite gas when full; it does not refill the ship battery. Connected pumps retain up to 8 water volumes instead of discarding them. See [industry-and-crops.md](docs/technical/industry-and-crops.md) for ports, recipes and simulation rules.

The ship has only three seed potatoes in a shared seed reserve, separate from mineral cargo. Ocra, Viridia and Brina reveal different seed capsules as their blocks are excavated; right-click a revealed capsule to collect once. Greenhouses consume water/electricity while growing, yielding three food units and two seeds. Full cargo preserves the harvest. Select food in inventory and Consuma to recover 20 personal energy. All jobs, networks, tanks, crops and seed discoveries persist; global seeds travel with the ship without being reset from old planet snapshots.

Underground ladders can now be broken with the mining beam, right-click/Smonta scala, the dismantle tool or Shift+B. No free material refund; internal ship ladders are protected. Water/gas pipes and cables can be removed independently at crossings. Ladders still build instantly for 2 soil, without cubes or a laboratory.

Arrival and rooms: each fresh landing starts the pilot in the top-floor cockpit. Its highlight/right-click menu opens ship management, battery upgrades or takeoff. Descend the internal ladder to the highlighted bedroom: right-click and Riposa to recover personal energy and suit integrity. Walking/climbing/tool pulses spend personal energy; exhaustion slows movement, without hard-locking the return trip. Rest does not refill the ship battery. Existing saves retain actual player position. Home/emergency recall still returns to the workshop.

Construction: right-click a reachable ship or underground laboratory and choose Costruisci. Each recipe row shows output name/level, time, red/green ingredient totals and Crea, disabled until affordable and the bench is available. Initially laboratory and bombs are visible; completing the first lab permanently unlocks the utility and industrial recipes at both station types. Structure recipes atomically pay nearby Robbie + that station's local storage once and materialize a physical cube on the bench. Space picks it up, Space drops it, and right-click that cube activates its correct structure. Invalid activation retains the cube with a red dashed footprint and an explanation, without a second payment. The player can stay inside these nonblocking structures, including the one-cell light. Ladders remain instant manual construction with B for 2 soil.

Costs/duration: laboratory fabrication 6 stone + 4 copper + 0.01 kWh; station levels I/II/III take 5/3.33/2.5 seconds and currently output a level-I laboratory. Unfolding takes another 5 seconds. Jobs and ready outputs survive closing the panel and save/load; each station has one reserved output slot until pickup. One cube is carried in hands separately from raw inventory capacity. Only Robbie carries materials: 20 initial units, +8 per drone upgrade. Collection and spending from his cargo require him within 3 m, with a clear connection and no delivery in progress. Y sends him physically to the ship, unloads what fits in the stiva, then returns to collecting range; a full stiva preserves the remainder. Keep the hatch open and clear. Robbie can finish deliveries while menus are open. Old backpack contents merge into his cargo without loss. A new ship has no starter mineral resources. Mining never directly credits ship storage.

Utility cubes use the same saved production, hand carry, activation and unfolding system. Light: 1 soil + 1 copper, 2.5 s fabrication + 2.5 s deployment, 1 x 1 m. Water pump: 3 stone + 4 copper, 4 + 4 s, 2 x 2 m. Gas fan: 2 stone + 3 copper, 4 + 4 s, 2 x 2 m. Lab levels divide fabrication times by 1 / 1.5 / 2; all outputs are level I. Raw recipes live in `progression.prototype_fabrication`, explicitly scoped to the current prototype rather than the later 12-planet processed-material economy. Cube colors/names distinguish contents and survive loading or interplanetary transport.

Laboratory interaction: the ship workbench or a reachable underground laboratory lights up when available. Right-click its room/bench to open Deposita materiali, Preleva materiali, Costruisci, Ripara and Potenzia laboratorio. Deposit is immediate; withdrawal opens local inventory; construction opens the same physical-production table at either bench. E beside an underground lab opens its contextual menu. Walls block station access, and the selected station supplies only its own depot. Accendi/Spegni stops powered services while retaining access to physical storage; paid field production pauses rather than disappearing.

Power network: active field labs draw 0.04/0.05/0.06 kWh/s at levels I/II/III; lights add 0.008, pumps 0.03 and fans 0.02 kWh/s. Unfolding lab/light/pump/fan cubes draw 0.06/0.02/0.08/0.05 kWh/s. Devices require an enabled, powered, safe laboratory within its 8/10/12 m connection radius. Right-click a device to switch it off or on. No demand comes from unfunded legacy plans or ladders. Zero charge pauses electric construction and powered services without negative battery energy. Cabin management upgrades battery capacity from 60 to 100/140 kWh without refilling it. Only the visited outpost is simulated; menus pause movement/hazards, but explicit paid fabrication continues. Ship jobs and cubes aboard travel with the ship; local jobs/cubes remain on their planet. No offline fabrication is simulated.

Energy bars: each active field lab shows shared battery charge and a segmented consumption strip above its room. Near a laboratory, a compact energy panel below cargo shows real ship kWh/capacity, local kWh/min, colored lab/light/pump/fan contributions and total-network autonomy. The charge bar expands with battery upgrades; it is not a separate lab battery. Segments compare actual draw with the installed equipment's nominal draw, not an invented local wattage limit. Overlapping lab ranges attribute a powered device to its nearest operational supplier exactly once, falling back when that supplier is switched off. The ship workshop panel shows the whole network. Industrial gas-converter cables are separate from these existing radius-based ship/lab links; energy connectors remain a proposed next system.

Inventory: I or Inventario shows Robbie and the local deposit, without a player backpack. Transfers require a reachable laboratory and nearby Robbie. Ship/depot ingredients are local, never remotely available. Fabbrica cubo opens that bench's recipe; the produced cube is not an inventory resource or another raw-material haul. Weighted inventory cubes remain supported only for old saves.

Tutorial/Robbie: nine authored tasks cover workshop, hatch, two mined cells, instant ladder, actual material collection, supported 4 x 3 room, bench fabrication, hand pickup and activation/completion. Actual events advance saved objectives even with speech muted or actions performed early. Tasks live in `design/v1/progression.json` under `ocra_tutorial`; see [adding Robbie tasks](docs/technical/robbie-tutorial-authoring.md). Dangers preempt repeatable advice. Robbie keeps about 2 m personal space with body-aware narrow ladder navigation. His radio, collection range and liquid restrictions still apply; raw cargo is unavailable during delivery. Full 12-planet progression, Ferrum and an Ocra termination layer are not introduced here.

Pump: the powered 2 x 2 device may be placed in water (not gas) inside an active lab's connection radius. It removes up to 0.7 water units/s through connected open cells within three grid steps, never through rock. It draws 0.03 kWh/s, or 0.08 during unfolding, from the shared battery. No drainage occurs before completion, without lab power or beyond remaining battery runtime. Removed water and cumulative drainage statistics persist; water is discarded in this prototype rather than stored in a tank/inventory.

Gas fan: the 2 x 2 device can unfold and operate in gas, but not water. It removes up to 0.35 normalized gas units/s in connected excavated cells within three Manhattan grid steps, using 0.02 kWh/s (0.05 while unfolding). It never extracts through rock, never creates negative gas, and retains cumulative filtration and its power-switch state in saves. Neither a pump nor a fan removes fluid on its completion frame. Both effects are capped to the same actual battery-powered runtime. Keep the supplying lab outside the contaminated area; its ship/laboratory power link still uses range rather than the industrial cable network.

Repairs: aboard, suit repair is free and hull repair costs 2 stone + 1 copper for 25 integrity. Powered field labs repair suit for 2 soil + 1 copper from shared/local stock. Ship/field laboratory upgrades cost 4 stone + 3 copper times the current level and speed up fabrication; the ship laboratory level is distinct from the drill upgrade in ship management. Field levels also expand storage to 32/48/64 units and saved lamp links to 8/10/12 m. Old light-kit and raw-plan APIs remain for save compatibility, not visible new construction.

Drone help: contextual comic balloons explain first excavation, loading/unloading, laboratory placement, lights and actual hazards. Left-click the drone to repeat its exact last displayed message, even with automatic hints muted; H or the question-mark button requests advice for the current situation. Building mode retains click-to-place priority. Aiuti drone silences automatic speech. Hints do not pause play; inventory and station menus pause local movement/hazards. Seen hints, milestones and the mute preference are saved, globally for campaigns and locally for the isolated sandbox.

Controller: left stick move/climb, A jump, X hatch, right stick aim, RB use tool, LB next tool, Y ladder, left-stick click grid, right-stick click camera, Back return home, Start ship menu. Controller bindings are implemented; physical controller QA remains necessary.

Controller: contextual A uses the same pickup/drop-before-jump priority; UI controls accept normal focus navigation. The new activation popup is currently reached with mouse right-click; full hardware-controller interaction QA remains pending. New games have no pre-excavated passages; older saves retain their actual player-made terrain changes.

The prototype starts fresh; use Load to resume. Campaign progress is saved manually in `user://saves/campaign_v1.json`, including midflight state, ship and individual planets. The isolated sandbox still uses `rocket_home_v1.json`; neither overwrites legacy `slot_01.json`. In the expedition, use Ship for upgrades/maintenance in orbit or in the workshop; return aboard and close the hatch before Take Off.

PC target: 16:9, validated at 1920x1080 and 1280x720. The logical 1280x720 canvas scales to desktop resolution; close camera zoom is independent of window size. This is not yet a Steam release/export build.

Equipment/delivery checks: `godot --headless --fixed-fps 60 --path . -s res://tests/integration/equipment_smoke.gd`. Includes real cabin-to-ground navigation, an exact-once delivery and return, numbered paid bombs, distance safety, ordered blasts, particles, preserved loose ore, repair costs, save/load and actual jetpack flight/recharging. Native `-- --capture` writes PC screenshots.

Light/ammunition regression: `godot --headless --fixed-fps 60 --path . -s res://tests/integration/light_and_ammo_smoke.gd`. Covers equal personal lighting in every slot and at depth, a depleted jetpack, four initial bombs, laboratory-only replenishment, production progress, exact-once payment and persistence of zero ammunition. Native `-- --capture` compares rendered terrain pixels and captures the bomb recipe at 720p/1080p.

## Test

Industry/crop/network checks: `godot --headless --fixed-fps 60 --path . -s res://tests/integration/industry_smoke.gd`. Covers paid physical machine cubes, smelting ingredients for the greenhouse, gas-energy conservation, finite irrigation, cut/repair of both networks, saved crops/seeds, full-cargo harvest atomicity and ladder demolition. Native `-- --capture` renders the outpost and machine/fabrication/inventory panels at PC resolutions.

Authored Ocra/navigation/text-lab checks: `godot --headless --fixed-fps 60 --path . -s res://tests/integration/ocra_world_smoke.gd`. With the native renderer and `-- --capture`, writes deep-tunnel, lamp, petroleum and text-lab screenshots at 720p/1080p. Includes legacy/new save compatibility, finite oil, a real shaft/bend/hatch route, stationary-facing stability and live text preview without modifying the real dialog catalog.

`godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/ --ignoreHeadlessMode`

Set `godot` to your Godot console executable. End-to-end geometry/traversal checks: `godot --headless --path . -s res://tests/integration/rocket_home_smoke.gd`. Omit `--headless` and add `-- --capture` for a rendered screenshot in `reports/`.

Complete travel/equipment/persistence checks: `godot --headless --path . -s res://tests/integration/expedition_smoke.gd`. Run without `--headless`, with `-- --capture`, to generate PC screenshots of navigation, flight, landing, maintenance and dark digging.

Instant-arrival checks: `godot --headless --path . -s res://tests/integration/instant_arrival_smoke.gd`. Covers the actual menu button at 720p/1080p, eligibility, unchanged travel costs and landing wear, normal saves, takeoff and restored outpost revisits. Native `-- --capture` saves menu screenshots.

Hazard checks: `godot --headless --path . -s res://tests/integration/hazards_smoke.gd`. Scanner can warn of a pocket adjacent to a wall before you break it. Gas degrades suit protection; water slows movement and can submerge the explorer (W/up swims upward). At zero protection the prototype recalls you to the ship; rest in the bedroom or use a repair station to recover. Anchor formations cannot be destroyed even by Plasma. Fluids remain a small grid simulation, not full pressure/ship-contamination physics.

Drone/building checks: `godot --headless --path . -s res://tests/integration/outpost_smoke.gd`; remove `--headless` and append `-- --capture` for 1080p screenshots. Regression tests carve their own fixtures; these tunnels are not part of a new game.

Inventory/tutorial checks: `godot --headless --path . -s res://tests/integration/inventory_guide_smoke.gd`; remove `--headless` and append `-- --capture` for the inventory and 720p/1080p balloon screenshots. Checks include exact local recipe preparation, full/missing-stock atomicity, remote read-only inventory, player-overlapping laboratory placement and saved tutorial progress.

Station interaction checks: `godot --headless --path . -s res://tests/integration/workstation_smoke.gd`; rendered `-- --capture` includes 720p/1080p highlights and popup/detail screens. Covers all five actions, selected-cache isolation, wall occlusion, real upgrade effects, drone replay without mining, and upgraded-level persistence. Detailed window-layout checks use a real renderer, since headless subwindows can expose an uninitialized viewport size.

Creator-cube/room/power checks: `godot --headless --path . -s res://tests/integration/creator_cube_smoke.gd`; rendered `-- --capture` produces cockpit, bedroom, picker, missing-material/confirmation, unfolding and powered/unpowered outpost screens at 720p/1080p. Covers exact-once charging, half-built save/load, manual ladders, battery drain/cutoff and real cabin battery upgrades/takeoff.

Tutorial/dependency/pump checks: `godot --headless --path . -s res://tests/integration/robbie_tutorial_smoke.gd`; rendered `-- --capture` includes initial Ocra-only navigation, both dependency-tree states, room guidance, pumping and red water alarm at 720p/1080p. Uses 6 stone/6 copper in Robbie, invalid clicks and upward floor-anchored placement.

Ocra onboarding: `godot --headless --path . -s res://tests/integration/ocra_onboarding_smoke.gd`. Traverses actual ship ladders, mines the room without tunnel fixtures, fabricates/carries/deploys the paid cube, checks Robbie's spacing, resumes a half-built save and completes the tutorial. Rendered `-- --capture` checks objectives, balloons, fabrication and the completed lab at 720p/1080p.

Physical fabrication: `godot --headless --path . -s res://tests/integration/physical_fabrication_smoke.gd`. Covers empty starting stock, ingredients in nearby Robbie, recipe colors/disabled actions, paid production independent of windows, ready/carried/dropped cube persistence, contextual Space without jumping, invalid red footprint, one-time activation, faster field laboratories, power pause and ship-factory ownership across travel. Add `-- --capture` with the native renderer for 720p/1080p GUI screenshots.

Utility cubes: `godot --headless --path . -s res://tests/integration/utility_cubes_smoke.gd`. Checks actual first-lab unlock, all three recipe buttons, shared ingredient payment, paid jobs and unfolding across save/load, typed cubes, invalid pump placement/recovery, active illumination, finite water/gas removal, rock obstruction, device switches, battery cutoff and interplanetary transport. Native `-- --capture` verifies all four recipe rows at 720p/1080p and animated fan pixels.

## Large Assets

- Files under `assets/` and `source_assets/` with common image/source-art extensions are tracked with Git LFS.
- This repository is configured with `skip-smudge`, so heavy assets are not downloaded automatically on checkout.
- Download tracked assets only when needed with:

`git lfs pull --include="assets/**,source_assets/**"`

## Technical Docs

- `docs/technical/godot-project-baseline.md`
- `docs/technical/steam-release-plan.md`
- `docs/technical/ai-handoff.md`

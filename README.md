# RocketMan

Godot 4 exploration game about landing on unknown planets and building a home beneath a three-storey rocket. The playable prototype is native 2D, with metric physics and a faceted rock renderer. PC target: 1280 x 720 and 1920 x 1080, 16:9.

For Aurora: [a message from Paolo and how to experiment](docs/team/per-aurora.md). Repository agents read [AGENTS.md](AGENTS.md) first.

## Current Prototype

The November 10 component economy supersedes the older physical-room-cube workflow. Design catalogs for the full 12-planet game contain future and historical proposals, not a list of implemented features.

- Choose **Umano** or **Robbie** before the first departure. Start with Ocra; the first completed underground laboratory unlocks Viridia and Brina.
- Three-floor rocket: cockpit, bedroom/cryogenic crew, workshop. New arrivals start in the cockpit. The ship workshop already functions, but there are no free mineral stocks.
- One logical cell is one metre, or 40 prototype pixels. Mining, placement, collision and finite fluid simulation share this geometry.
- Controlled Robbie uses a 0.5 x 0.8 m capsule and compact artwork, so one-cell-high passages are traversable. The human remains 0.6 x 1.6 m. Body centers/bounds also drive mining, scanner/light origins, liquid exposure, placement and tight-tunnel save validation.
- Soil, stone and compact-rock excavation produce no cargo. Keep excavating even with a full hold or absent Robbie; valuable ore that cannot be collected remains on the ground.
- Collect copper, iron, crystals, quartz and rare cobalt. Pulse handles the starting ores; upgraded tools handle cobalt and compact rock. Anchor formations remain indestructible.
- Robbie carries materials and components: initial capacity 20, upgraded by 8 per drone level. Four components of one type occupy one cargo unit, rounded up. Y sends companion Robbie to unload and return; when playing Robbie, Y deposits at the accessible laboratory instead.
- Companion Robbie follows through explored safe passages anywhere on the finite planet, without a ship-distance or depth limit. Local assistance still requires being within 3 m and a clear path; the magnet has its own upgradeable local radius. Closed hatches, solid terrain and dangerous liquids still block movement. Installation power-link reach is separate and unchanged.
- Companion navigation includes collision-checked open air beneath and around the hull. An open hatch can lead to a separate left/right surface shaft without excavating beneath the rocket; a closed hatch or real hull wall still blocks the route. There is no teleport or automatic terrain removal.
- Right-click a reachable laboratory and choose **Produci componenti**. Select batches, review total ingredients/time/energy and order. Production persists, pauses without power and keeps output if storage is full. **Ritira componenti** loads ready components with one action.
- Right-click free space, choose a structure, then position its metric outline. Only an excavated, supported, reachable and safe footprint is valid. Assembly consumes carried components once; insufficient components leave a nonfunctional pending project. Right-click that project to assemble or cancel it.
- The compact assembly popup shows item icons and component icons with available / required counts (**Hai / Servono**, e.g. 0 / 4). Green names indicate sufficient accessible cargo; missing components and unaffordable names are gray. Unaffordable projects remain selectable, and pending-project funding uses the same counters. The remote ship depot is not counted.
- Pending-project popups show the current assembly blocker directly below the cost, rather than only in the disabled button tooltip. The message updates as cargo, reach and laboratory power change; an unblocked project shows **Pronto al montaggio**.
- Lamps, pumps, gas fans, furnaces, gas-energy converters and greenhouses unlock after the first field laboratory. A field laboratory is a local component workshop, not remote access to the ship depot.
- Lamps can relay power: ship -> laboratory -> lamp -> lamp. The first link uses the laboratory radius (8 m at level I, +2 m per laboratory level); each lamp-to-lamp link is at most 8 m. Only active, enabled, healthy lights in safe cells relay power. All consumption belongs to one real source lab, with no self-powered lamp loops or double billing. A disabled/damaged intermediate cuts its branch unless another rooted path is available. Paid construction pauses without chain power; planned and assembling lamps never relay. Automatic red orthogonal cables show actual upstream parents, turn muted when unpowered and add no extra recipe cost or collider. Labs still require ship power/reach; pump/fan and industrial-cable rules are unchanged. Chains reconstruct after save/load.
- Underground ladders are immediate and free to place/remove. Internal ship ladders remain protected. Water/gas pipes and energy cables are immediate but consume components.
- Jetpack: five seconds of base thrust, instantly replenished by a real landing on a solid floor. Ladders and water do not recharge it. Ship energy no longer recharges the jetpack. Duration and thrust are separate parameters for future upgrades.
- The human explorer has procedural articulated walking, upward/downward ladder cycles, jump and jetpack-launch poses, sustained flight, falling and a brief landing compression. Mining aims the two-handed tool and retriggers recoil per pulse; the beam starts at its animated muzzle. These poses do not change movement or colliders.
- Hard landings flash the controlled human/Robbie red for 0.9 seconds and consume personal energy, not ship power or suit integrity. The penalty scales with downward impact speed above 440 px/s, capped at 50 energy points. Normal jumps are safe; jetpack braking reduces impact, and standing on the ground never repeats the penalty.
- Personal HUD vitals use two thin 4 px meters with percentages: amber energy and cyan suit integrity. The human rest panel shares the same widget and colors, updating during recovery. Controlled Robbie uses charge/hull labels; the cryogenic-crew panel does not offer human rest or recovery meters.
- Four initial bombs, finite laboratory replenishment, numbered placement and distance-safe ordered detonation. Blasts can damage installations; repairs cost components.
- Sealed irregular water, acid and oil reservoirs can leak into excavated tunnels. Natural gas pockets are temporarily disabled, including their cavities; retained gas physics is exercised only by explicit QA opt-ins. Darkness intensifies with depth; powered laboratories and lamps maintain local lighting.
- The terrain renderer blends rock faces and irregular fractures without changing physics. G reveals the diagnostic metre grid. The editor export `organic_terrain` permits visual A/B comparison with the previous renderer.
- Terrain mixes GPT-painted rock surfaces in continuous world coordinates, with seeded noise warping, large-scale strata and chipped exposed rims. Decorative silhouettes protrude 1-5 pixels into excavated space, without changing the square metre colliders. Images do not restart on each cell.
- Terrain geometry/UV/noise and sealed-pocket masks are cached. Four atlas-layer batches replace per-cell triangle submissions; illumination remains live and shared vertices are evaluated once per frame. Native pixel comparisons retain the prior appearance. Profiling commands and measured limits: [terrain performance](docs/technical/terrain-performance.md).
- Ore identity is hidden outside scanner mode, including already analysed deposits. Passive scanner waves place a centered icon on each detected special cell, without floating popups or group labels. Nearby identified cells show the material icon and a thin material-colored cell border; both fade together. Distant or insufficient-level detections use one neutral gray icon without a content-colored border. Hover identifies a current reveal only within 2.5/4/5.5/7 m at scanner levels I/II/III/IV, capped by detection range 4/5/6/7 m. Cobalt requires level III to identify. Traces fade over 2 seconds at level I (+0.7 seconds/level), clear when leaving scanner mode, and do not illuminate or excavate terrain. Discovered analyses persist in saves; scanner clicks do not perform point scans or emit an extraction beam. Bomb/jetpack modes also never emit that beam; their own placement/thrust controls remain.
- Water cavities are physically visible as continuous blue liquid with small rising bubbles, even before breaching their rock walls. Shapes follow the existing arbitrary cell masks, not rectangular containers; normal darkness still applies. Other sealed reservoir cavities remain camouflaged as host rock until breached. Visibility never releases fluid; rock removal still triggers leaks. Ambient audio clues are not implemented yet; existing Robbie danger warnings remain.
- Each valuable ore block yields 1 piece (65%), 2 pieces (25%) or 3 pieces (10%) of the same mineral, including bomb excavation. Pieces fall and bounce independently. Robbie seeks nearby reachable ore and attracts it with a 2 m magnet, gaining 0.35 m per drone module upgrade. Full cargo, delivery missions and intervening walls prevent pickup; remaining pieces, positions and velocities persist in saves. Common soil/stone still produce no inventory items.
- New two-/three-piece drops briefly show a rising, fading x2/x3 at the broken block. One-piece drops and common rock have no badge; loading saved ore never replays old bonuses.
- Robbie's data-authored tutorial now covers mineral collection, batch production, component pickup and the first actual assembly. Texts remain editable in the text-lab scene.
- Robbie's speech automatically inserts small catalog icons after named minerals, fluids and construction components, including plurals. Dialogue and replay retain the editable plain text; no icon markup is required in the text lab.

## First Laboratory

| Production | Ingredients | Output |
| --- | --- | --- |
| Structural batch | 4 iron | 2 structural components |
| Electronic batch | 3 copper + 1 crystal | 2 electronic components |

Mine **8 iron, 3 copper and 1 crystal** near the ship. Order two structural batches and one electronic batch at the ship workshop. Each base batch takes 2 seconds and 0.01 kWh at level I; higher laboratory levels reduce time. Retrieve the resulting **4 structural + 2 electronic components**, then assemble the laboratory in a supported 4 x 3 m room.

Copper and iron lie immediately left of the access ladder. Three additional starter crystal blocks sit just beyond that iron on the same left-hand route, before deep hazards; the original right-hand crystals remain. Robbie's material hint explains the route. An actually blocked companion path takes precedence over tutorial hints; distance from the ship does not stop Robbie.

Assembly costs: lamp 1 electronic; pump 2 structural + 2 electronic; fan 1 structural + 2 electronic; furnace 3 structural + 1 electronic; converter 2 + 2; greenhouse 4 + 2. Initial machine footprints, activation time and power links are preserved. No structure provides services while merely planned or still assembling.

The furnace remains optional for initial progression. It smelts copper ingots and quartz-based glass for the alternate electronic recipe. Rare cobalt allows a more efficient structural alloy. There are still only two construction-component types.

Runtime costs: [prototype_components.json](design/v1/prototype_components.json). Approved specification: [free digging and components](docs/superpowers/specs/2026-11-10-scavo-libero-componenti-design.md).

Living crafting reference: [production map](docs/design/mappa-produzione.md), generated from the playable prototype's recipes and cost functions. It includes inputs, outputs, stations, unlocks and a reverse ingredient index, separately from future proposals. [Structured map](design/generated/production-map.json) is ready for a future ship-computer guide; that in-game screen is not implemented yet.

## Run And Controls

Open `project.godot` in Godot 4.6.3 and press F5 for the complete game, including protagonist selection. **Arriva subito al pianeta** skips flight and landing presentation without granting supplies. F6 on `scenes/prototype/rocket_home.tscn` or `robbie_home.tscn` starts an isolated sandbox and intentionally skips selection.

For construction playtests, launch the complete game with `-- --construction-test` (Godot editor/debug builds only). Fresh campaigns start with 24 structural and 40 electronic components in Robbie, using 16 of its 20 real cargo units. Recipes, first-lab unlocks and deployment constraints remain unchanged. Normal starts stay empty; loading a campaign replaces this initial stock with its saved cargo rather than granting more.

- A/D move; W/S climb; Space jumps or supplies jetpack thrust. There is no component-economy cube pickup/drop command.
- E interacts with the hatch/nearby laboratory. Right-click laboratories, machines or free construction space for their contextual menus.
- 1 mining tool, 2 scanner, 3 bomb, 4 jetpack. Left-click/F uses the selected tool; Enter detonates placed bombs from at least 4 m away.
- Playtest shortcut: in scanner mode, + / - (including the numeric keypad) adjusts a local level-I-IV override. It changes real detection/identification range, shows the level in the HUD and clears old scan waves; it does not purchase upgrades or modify the shared catalog/save data.
- B places a free ladder, Shift+B removes it; the extraction beam also removes underground ladders.
- T selects water/gas pipes or energy cables. Pipes cost 1 structural component per metre; cables cost 1 electronic component per metre.
- Network lines use red for power, blue for water and green for gas. Automatic ship/laboratory/lamp leads use orthogonal 90-degree bends. The cable drawing itself is not a separate relay item: active lamps extend their rooted network in 8 m hops.
- I opens inventory; Y handles Robbie's delivery/deposit; H requests advice. Clicking companion Robbie repeats his last balloon.
- G toggles the grid; mouse wheel zooms; C switches close/overview camera; Home performs emergency return.

Controller bindings remain supported by the prototype, but complete hardware-controller QA and controller access to all new context menus remain outstanding.

## Industry And Crew

Gas pipes feed converters from finite real reservoirs; energy cables connect converters to furnaces and greenhouses. Water uses sealed wall valves, explicit pipe terminals and powered pumps with distinct inlet/outlet networks. T opens conduits; R rotates valve/terminal placement. Right-click a valve to perforate in seal and open it, or configure a terminal as intake/discharge. Gravity moves water downhill; pumps lift it and feed greenhouses. Physical discharge fills or overflows an excavated basin. Unconfigured ends stay capped; no radius pump deletes water. See [water circuits](docs/technical/water-circuits.md).

Natural gas generation is currently paused: the converter has no naturally available fuel in ordinary new worlds. Gas-powered local industry therefore awaits that resource or a separately designed supply; no free-energy fallback has been added. Water pumps still use the laboratory/ship battery.

Broken connections pause paid work rather than losing progress. The ship starts with three seed potatoes; excavated capsules reveal other cultivars. Human food consumption restores personal energy; Robbie cannot eat crops. Ship fluid tanks/ports and buildable floors/volumes remain future work.

In Robbie mode, the middle floor has upright cryopods for a male biomedical/technical scientist, a female botanist/chemist and a cat. The crew remains asleep; waking and specialist abilities are not implemented. Powered laboratories recharge Robbie's personal battery and repair his shell using ship energy. This maintenance is distinct from the jetpack's free landing recharge.

Ship battery upgrades increase the shared reserve from 60 to 100/140 kWh. Laboratory/device energy bars report actual charge and consumption, not a separate invented lab capacity. Off-world outposts and offline fabrication are not simulated.

## Saves And Texts

This experimental economy uses **new save slots**: `user://saves/campaign_components_v1.json` and `rocket_home_components_v1.json`, with `_robbie` before the extension for the robot variant. Old `campaign_v1.json`, `rocket_home_v1.json` and `slot_01.json` are not imported or overwritten. Start a new game to test this branch. Mixed economy payloads are rejected before restoring the current world.

Open `scenes/labs/robbie_text_lab.tscn` and press F6 to edit [robbie_texts.json](design/v1/robbie_texts.json), including variant overrides. The lab does not run or overwrite a campaign. See [tutorial authoring](docs/technical/robbie-tutorial-authoring.md).

## Verification

Use the installed Godot console executable as `godot`:

```powershell
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/ --ignoreHeadlessMode
godot --headless --fixed-fps 60 --path . -s res://tests/integration/component_onboarding_smoke.gd
godot --rendering-method gl_compatibility --fixed-fps 60 --path . -s res://tests/integration/organic_terrain_smoke.gd -- --capture
node tools/design/validate.mjs
node tools/design/check-ladders.mjs
node tools/design/build-item-icons.mjs --check
godot --headless --path . -s res://tools/design/build-production-map.gd -- --check
```

Additional component checks: `free_digging_smoke.gd`, `component_production_smoke.gd`, `component_assembly_smoke.gd`, `ground_jetpack_smoke.gd`. Independent suites still cover travel, hatch navigation, hazards/reservoirs, inventory/guide, workstations, industry, utilities, scanner and both protagonists. Historical cube-only command-line entry points delegate to their component replacements. Native `-- --capture` writes screenshots under ignored `reports/`.

## Assets And Further Design

The current economy has a dedicated set of 49 transparent, faceted SVG item icons in `assets/ui/items/`. Inventory, fabrication, construction, industry, tool slots and ship selectors use `scripts/data/item_icon_catalog.gd`; the production map exports the same paths. Levels and repair states share object identity. Regenerate assets with `node tools/design/build-item-icons.mjs`; no hidden-ore world markers are added.

Image/source-art assets are tracked with Git LFS, configured with skip-smudge. Fetch only when required: `git lfs pull --include="assets/**,source_assets/**"`. SVG icons are ordinary Git assets.

- [Full proposed design](docs/design/README.md)
- [Reservoir model](docs/technical/reservoirs.md)
- [Industry and crops](docs/technical/industry-and-crops.md)
- [Historical AI handoff](docs/technical/ai-handoff.md)
- [Steam release plan](docs/technical/steam-release-plan.md)

This is a development prototype, not yet a Steam export/release build or final 2.5D/3D art production.

# RocketMan

Godot 4 exploration game about landing on unknown planets and building a home beneath a three-storey rocket. The playable prototype is native 2D, with metric physics and a faceted rock renderer. PC target: 1280 x 720 and 1920 x 1080, 16:9.

For Aurora: [a message from Paolo and how to experiment](docs/team/per-aurora.md). Repository agents read [AGENTS.md](AGENTS.md) first.

## Current Prototype

The November 10 component economy supersedes the older physical-room-cube workflow. Design catalogs for the full 12-planet game contain future and historical proposals, not a list of implemented features.

- Choose **Umano** or **Robbie** before the first departure. Start with Ocra; the first completed underground laboratory unlocks Viridia and Brina.
- Three-floor rocket: cockpit, bedroom/cryogenic crew, workshop. New arrivals start in the cockpit. The ship workshop already functions, but there are no free mineral stocks.
- One logical cell is one metre, or 40 prototype pixels. Mining, placement, collision and finite fluid simulation share this geometry.
- Soil, stone and compact-rock excavation produce no cargo. Keep excavating even with a full hold or absent Robbie; valuable ore that cannot be collected remains on the ground.
- Collect copper, iron, crystals, quartz and rare cobalt. Pulse handles the starting ores; upgraded tools handle cobalt and compact rock. Anchor formations remain indestructible.
- Robbie carries materials and components: initial capacity 20, upgraded by 8 per drone level. Four components of one type occupy one cargo unit, rounded up. Y sends companion Robbie to unload and return; when playing Robbie, Y deposits at the accessible laboratory instead.
- Right-click a reachable laboratory and choose **Produci componenti**. Select batches, review total ingredients/time/energy and order. Production persists, pauses without power and keeps output if storage is full. **Ritira componenti** loads ready components with one action.
- Right-click free space, choose a structure, then position its metric outline. Only an excavated, supported, reachable and safe footprint is valid. Assembly consumes carried components once; insufficient components leave a nonfunctional pending project. Right-click that project to assemble or cancel it.
- Lamps, pumps, gas fans, furnaces, gas-energy converters and greenhouses unlock after the first field laboratory. A field laboratory is a local component workshop, not remote access to the ship depot.
- Underground ladders are immediate and free to place/remove. Internal ship ladders remain protected. Water/gas pipes and energy cables are immediate but consume components.
- Jetpack: five seconds of base thrust, instantly replenished by a real landing on a solid floor. Ladders and water do not recharge it. Ship energy no longer recharges the jetpack. Duration and thrust are separate parameters for future upgrades.
- Four initial bombs, finite laboratory replenishment, numbered placement and distance-safe ordered detonation. Blasts can damage installations; repairs cost components.
- Sealed irregular water, acid, oil and gas reservoirs can leak into excavated tunnels. Darkness intensifies with depth; powered laboratories and lamps maintain local lighting.
- The terrain renderer blends rock faces and irregular fractures without changing physics. G reveals the diagnostic metre grid. The editor export `organic_terrain` permits visual A/B comparison with the previous renderer.
- Terrain faces now use the GPT-generated 16-sprite atlas in `assets/terrain/rock-atlas-v1.png`, with chipped exposed rims and unchanged metric collision.
- Ore falls as physical fragments, bounces and remains on the floor. Robbie seeks nearby reachable ore and attracts it with a 2 m magnet, gaining 0.35 m per drone module upgrade. Full cargo, delivery missions and intervening walls prevent pickup; fragment position and velocity persist in saves. Common soil/stone still produce no inventory items.
- Robbie's data-authored tutorial now covers mineral collection, batch production, component pickup and the first actual assembly. Texts remain editable in the text-lab scene.

## First Laboratory

| Production | Ingredients | Output |
| --- | --- | --- |
| Structural batch | 4 iron | 2 structural components |
| Electronic batch | 3 copper + 1 crystal | 2 electronic components |

Mine **8 iron, 3 copper and 1 crystal** near the ship. Order two structural batches and one electronic batch at the ship workshop. Each base batch takes 2 seconds and 0.01 kWh at level I; higher laboratory levels reduce time. Retrieve the resulting **4 structural + 2 electronic components**, then assemble the laboratory in a supported 4 x 3 m room.

Assembly costs: lamp 1 electronic; pump 2 structural + 2 electronic; fan 1 structural + 2 electronic; furnace 3 structural + 1 electronic; converter 2 + 2; greenhouse 4 + 2. Initial machine footprints, activation time and power links are preserved. No structure provides services while merely planned or still assembling.

The furnace remains optional for initial progression. It smelts copper ingots and quartz-based glass for the alternate electronic recipe. Rare cobalt allows a more efficient structural alloy. There are still only two construction-component types.

Runtime costs: [prototype_components.json](design/v1/prototype_components.json). Approved specification: [free digging and components](docs/superpowers/specs/2026-11-10-scavo-libero-componenti-design.md).

## Run And Controls

Open `project.godot` in Godot 4.6.3 and press F5 for the complete game, including protagonist selection. **Arriva subito al pianeta** skips flight and landing presentation without granting supplies. F6 on `scenes/prototype/rocket_home.tscn` or `robbie_home.tscn` starts an isolated sandbox and intentionally skips selection.

- A/D move; W/S climb; Space jumps or supplies jetpack thrust. There is no component-economy cube pickup/drop command.
- E interacts with the hatch/nearby laboratory. Right-click laboratories, machines or free construction space for their contextual menus.
- 1 mining tool, 2 scanner, 3 bomb, 4 jetpack. Left-click/F uses the selected tool; Enter detonates placed bombs from at least 4 m away.
- B places a free ladder, Shift+B removes it; the extraction beam also removes underground ladders.
- T selects water/gas pipes or energy cables. Pipes cost 1 structural component per metre; cables cost 1 electronic component per metre.
- I opens inventory; Y handles Robbie's delivery/deposit; H requests advice. Clicking companion Robbie repeats his last balloon.
- G toggles the grid; mouse wheel zooms; C switches close/overview camera; Home performs emergency return.

Controller bindings remain supported by the prototype, but complete hardware-controller QA and controller access to all new context menus remain outstanding.

## Industry And Crew

Gas pipes feed converters from finite real reservoirs; energy cables connect converters to furnaces and greenhouses. Powered water pumps can store water and irrigate greenhouses through pipes. Broken connections pause paid work rather than losing progress. The ship starts with three seed potatoes; excavated capsules reveal other cultivars. Human food consumption restores personal energy; Robbie cannot eat crops.

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
```

Additional component checks: `free_digging_smoke.gd`, `component_production_smoke.gd`, `component_assembly_smoke.gd`, `ground_jetpack_smoke.gd`. Independent suites still cover travel, hatch navigation, hazards/reservoirs, inventory/guide, workstations, industry, utilities, scanner and both protagonists. Historical cube-only command-line entry points delegate to their component replacements. Native `-- --capture` writes screenshots under ignored `reports/`.

## Assets And Further Design

Image/source-art assets are tracked with Git LFS, configured with skip-smudge. Fetch only when required: `git lfs pull --include="assets/**,source_assets/**"`. SVG icons are ordinary Git assets.

- [Full proposed design](docs/design/README.md)
- [Reservoir model](docs/technical/reservoirs.md)
- [Industry and crops](docs/technical/industry-and-crops.md)
- [Historical AI handoff](docs/technical/ai-handoff.md)
- [Steam release plan](docs/technical/steam-release-plan.md)

This is a development prototype, not yet a Steam export/release build or final 2.5D/3D art production.

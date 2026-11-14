# RocketMan

Godot 4 exploration game about landing on unknown planets and building a home beneath a three-storey rocket. The playable prototype is native 2D, with metric physics and a faceted rock renderer. PC target: 1280 x 720 and 1920 x 1080, 16:9.

For Aurora: [a message from Paolo and how to experiment](docs/team/per-aurora.md). Repository agents read [AGENTS.md](AGENTS.md) first.

## Current Prototype

The November 10 component economy supersedes the older physical-room-cube workflow. Design catalogs for the full 12-planet game contain future and historical proposals, not a list of implemented features.

November 13 production update: placing a construction blueprint is a complete order in the human variant. Robbie collects ore, unloads at the ship, has the ship prepare only the first project's missing components, retrieves ready components, delivers and constructs on site while the player keeps digging. Projects follow strict original-placement FIFO: a blocked first project pauses the queue until resolved or cancelled. Ready stock and already-paid output, including manual orders, are reused before paying for more batches; only the shortfall is rounded up to existing recipe batches. There is no minimum stock or speculative production for later projects. This supersedes the November 12 manual-only production requirement. Player-controlled Robbie retains manual orders, pickup and assembly. Additional robot manufacture remains future design.

- Choose **Umano** or **Robbie** before the first departure. Start with Ocra; the first completed underground laboratory unlocks Viridia and Brina.
- Three-floor rocket: cockpit, bedroom/cryogenic crew, workshop. New arrivals start in the cockpit. The ship workshop already functions, but there are no free mineral stocks.
- One logical cell is one metre, or 40 prototype pixels. Mining, placement, collision and finite fluid simulation share this geometry.
- Controlled Robbie uses a 0.5 x 0.8 m capsule and compact artwork, so one-cell-high passages are traversable. The human remains 0.6 x 1.6 m. Body centers/bounds also drive mining, scanner/light origins, liquid exposure, placement and tight-tunnel save validation.
- Soil, stone and compact-rock excavation produce no cargo. Keep excavating even with a full hold or absent Robbie; valuable ore that cannot be collected remains on the ground.
- Collect copper, iron, crystals, quartz and rare cobalt. Pulse handles the starting ores; upgraded tools handle cobalt and compact rock. Anchor formations remain indestructible.
- A refused mining attempt shows a short fading message near the target as well as in the status bar: incompatible tools name the first suitable tool from the catalog (Risonatore for cobalt, Plasma for compact rock); indestructible cores say so explicitly. Refused attempts emit no extraction pulse and consume no energy. The message avoids the cargo/tutorial panels and clears when changing tools or returning home.
- Robbie carries materials and components: initial capacity 20, upgraded by 8 per drone level. Four components of one type occupy one cargo unit, rounded up. Companion Robbie automatically unloads when nearly full or after a brief collection pause; Y remains an optional manual dispatch. When playing Robbie, Y deposits at the accessible laboratory instead.
- Companion Robbie follows through explored safe passages anywhere on the finite planet, without a ship-distance or depth limit. Local assistance still requires being within 3 m and a clear path; the magnet has its own upgradeable local radius. Closed hatches, solid terrain and dangerous liquids still block movement. Installation power-link reach is separate and unchanged.
- Companion navigation includes collision-checked open air beneath and around the hull. An open hatch can lead to a separate left/right surface shaft without excavating beneath the rocket; a closed hatch or real hull wall still blocks the route. There is no teleport or automatic terrain removal.
- Production computer: right-click a reachable laboratory to inspect queue status and stock or optionally anticipate component needs with manual orders. Select batches and review owned/needed ingredients, time and energy before ordering. Multiple paid orders are processed sequentially per station; independent laboratories work concurrently. Paid queues persist, pause without power and retain output when storage fills. A human construction blueprint already authorizes its missing-component production; returning to the computer is not required. **Ritira componenti** remains available for manual/player-controlled-Robbie logistics. Maintenance and material transfers are secondary station actions.
- Right-click free space, choose a structure, then position its metric outline. Only an excavated, supported, reachable and safe footprint is valid. Human projects enter Robbie's strict placement-order queue, including when components are not ready. He prepares only the head project's missing components, physically brings them and stays on site for paid construction before advancing to the next project. Missing materials, blocked passages, damaged machinery or missing power at the head pause the entire project queue, never skip to an easier later project. Right-click a project for live status, optional manual assembly or cancellation; cancelling the head advances the queue. Player-controlled Robbie keeps manual assembly.
- The compact assembly popup shows item icons and component icons with available / required counts (**Hai / Servono**, e.g. 0 / 4). Green names indicate sufficient components; missing components and unaffordable names are gray. Human automatic logistics shows real ready stock across laboratories and Robbie as delivery information, never a remote payment. Manual logistics counts accessible cargo only. Unaffordable projects remain selectable.
- Pending-project popups show the current blocker directly below the cost, rather than only in the disabled button tooltip. The blocked first FIFO project gives a concrete reason, such as missing iron, a closed hatch, full output storage or unavailable power; later projects wait for it. The message updates as cargo, reach and laboratory power change; an unblocked project shows **Pronto al montaggio**.
- Lamps, pumps, gas fans, furnaces, gas-energy converters, greenhouses and water containers unlock after the first field laboratory. A field laboratory is a local component workshop, not remote access to the ship depot.
- Solar panels are available before the first field laboratory: supported outdoor 2 x 1 m projects costing 2 structural + 1 electronic component. Each active, enabled, healthy panel continuously generates 6 kWh/min (0.1 kWh/s), with no night cycle. A free automatic cable links directly to the ship at any distance, without a laboratory or industrial cable network. Multiple panels add their production to the shared ship battery, capped at its capacity; planned or assembling panels generate nothing. The existing free +15 kWh recharge remains an emergency service.
- Lamps can relay power: ship -> laboratory -> lamp -> lamp. The first link uses the laboratory radius (8 m at level I, +2 m per laboratory level); each lamp-to-lamp link is at most 8 m. Only active, enabled, healthy lights in safe cells relay power. All consumption belongs to one real source lab, with no self-powered lamp loops or double billing. A disabled/damaged intermediate cuts its branch unless another rooted path is available. Paid construction pauses without chain power; planned and assembling lamps never relay. Automatic red orthogonal cables show actual upstream parents, turn muted when unpowered and add no extra recipe cost or collider. Labs still require ship power/reach; fan and industrial-cable rules are unchanged. Pumps have no laboratory or ship-distance limit for placement, assembly or operation. Chains reconstruct after save/load.
- Underground ladders and background water pipes are immediate and free to place/remove. Internal ship ladders remain protected. Gas pipes and energy cables still consume components.
- Jetpack: five seconds of base thrust, instantly replenished by a real landing on a solid floor. Ladders and water do not recharge it. Ship energy no longer recharges the jetpack. Duration and thrust are separate parameters for future upgrades.
- The human explorer has procedural articulated walking, upward/downward ladder cycles, jump and jetpack-launch poses, sustained flight, falling and a brief landing compression. Mining aims the two-handed tool and retriggers recoil per pulse; the beam starts at its animated muzzle. These poses do not change movement or colliders.
- Hard landings flash the controlled human/Robbie red for 0.9 seconds and consume personal energy, not ship power or suit integrity. The penalty scales with downward impact speed above 440 px/s, capped at 50 energy points. Normal jumps are safe; jetpack braking reduces impact, and standing on the ground never repeats the penalty.
- Personal HUD vitals use two thin 4 px meters with percentages: amber energy and cyan suit integrity. The human rest panel shares the same widget and colors, updating during recovery. Controlled Robbie uses charge/hull labels; the cryogenic-crew panel does not offer human rest or recovery meters.
- Four initial bombs, finite laboratory replenishment, numbered placement and distance-safe ordered detonation. Blasts can damage installations; repairs cost components.
- Bombs bypass mining-tool compatibility for ordinary ores and pure veins, including cobalt, but never break compact rock (`bedrock`), indestructible cores or terrain protected by installations. Explosions are not a universal substitute for tool upgrades.
- Sealed irregular water, acid and oil reservoirs can leak into excavated tunnels. Natural gas pockets are temporarily disabled, including their cavities; retained gas physics is exercised only by explicit QA opt-ins. Darkness intensifies with depth; powered laboratories and lamps maintain local lighting.
- The terrain renderer blends rock faces and irregular fractures without changing physics. G reveals the diagnostic metre grid. The editor export `organic_terrain` permits visual A/B comparison with the previous renderer.
- Terrain mixes GPT-painted rock surfaces in continuous world coordinates, with seeded noise warping, large-scale strata and chipped exposed rims. Decorative silhouettes protrude 1-5 pixels into excavated space, without changing the square metre colliders. Images do not restart on each cell.
- Terrain geometry/UV/noise and sealed-pocket masks are cached. Four atlas-layer batches replace per-cell triangle submissions; illumination remains live and shared vertices are evaluated once per frame. Native pixel comparisons retain the prior appearance. Profiling commands and measured limits: [terrain performance](docs/technical/terrain-performance.md).
- Ore identity is hidden outside scanner mode, including already analysed deposits. Passive scanner waves place a centered icon on each detected special cell, without floating popups or group labels. Nearby identified cells show the material icon and a thin material-colored cell border; both fade together. Distant or insufficient-level detections use one neutral gray icon without a content-colored border. Hover identifies a current reveal only within 2.5/4/5.5/7 m at scanner levels I/II/III/IV, capped by detection range 4/5/6/7 m. Cobalt requires level III to identify. Traces fade over 2 seconds at level I (+0.7 seconds/level), clear when leaving scanner mode, and do not illuminate or excavate terrain. Discovered analyses persist in saves; scanner clicks do not perform point scans or emit an extraction beam. Bomb/jetpack modes also never emit that beam; their own placement/thrust controls remain.
- Water cavities are physically visible as continuous blue liquid with small rising bubbles, even before breaching their rock walls. Shapes follow the existing arbitrary cell masks, not rectangular containers; normal darkness still applies. Other sealed reservoir cavities remain camouflaged as host rock until breached. Visibility never releases fluid; rock removal still triggers leaks. Ambient audio clues are not implemented yet; existing Robbie danger warnings remain.
- Dispersed valuable ore yields 1 unit (65%), 2 units (25%) or 3 units (10%), including bomb excavation. Pure ore veins are finite irregular solid masks of copper, iron, crystal, quartz or cobalt: each block requires 10 mining strength and yields 12 units. The softer starter deposits remain unchanged. Exposed, lit pure faces show irregular continuous mineral seams and small inclusions over the painted host rock, rather than full-cell tints. The cached world-space decoration crosses cell boundaries without repeating a tile, leaves most rock visible and does not reveal buried ore or glow in darkness. Mining progress is visible on the selected block; metric collision geometry is unchanged.
- Ore falls and bounces in at most three weighted physical bundles per cell. Robbie seeks reachable fragments and attracts them with a 2 m magnet, gaining 0.35 m per drone module upgrade. Full cargo leaves all residual quantities on the ground; partial pickup, bundle counts, positions and velocities persist in saves. The autonomous worker returns for uncollected ore after unloading. Common soil/stone still produce no inventory items.
- New two-/three-piece drops briefly show a rising, fading x2/x3 at the broken block. One-piece drops and common rock have no badge; loading saved ore never replays old bonuses.
- Robbie's data-authored tutorial covers collection, room excavation and the first laboratory blueprint: automatic missing-component preparation, delivery and building in the human variant; manual orders, component pickup and assembly when controlling Robbie. Texts remain editable in the text-lab scene.
- Robbie's speech automatically inserts small catalog icons after named minerals, fluids and construction components, including plurals. Dialogue and replay retain the editable plain text; no icon markup is required in the text lab.

## First Laboratory

| Production | Ingredients | Output |
| --- | --- | --- |
| Structural batch | 4 iron | 2 structural components |
| Electronic batch | 3 copper + 1 crystal | 2 electronic components |

Mine **8 iron, 3 copper and 1 crystal** near the ship, clear a supported **4 x 3 m** room and place the laboratory blueprint. Robbie collects and physically unloads the ore; the ship prepares the missing components, then Robbie retrieves, delivers and constructs while you keep digging. Starting from empty component stock, this uses **2 structural batches + 1 electronic batch**, yielding **4 structural + 2 electronic components**. There is no forced return to the production computer. Basic batch recipes still take 2 seconds and 0.01 kWh at level I; costs are reserved once when submitted. In the controlled-Robbie variant, order those batches at the computer, then retrieve and assemble the components manually.

Automatic production is limited to the missing components of the first project in original placement order, after counting real ready stock and output already paid for. Existing batch sizes may leave a real surplus; it is reused, not a minimum-stock target. A blocked head reports its concrete reason and pauses later projects until resolved or cancelled. Robbie does not auto-mine, create ingredients, bypass cargo capacity, cross closed hatches or hazardous liquid passages, or spend remote materials directly at a project. Paid assembly pauses if the worker leaves. Unfinished orders, real cargo and project order survive save/load; tasks/routes are reconstructed. Multiple Robbie manufacture is not implemented.

Copper and iron lie immediately left of the access ladder. Three additional starter crystal blocks sit just beyond that iron on the same left-hand route, before deep hazards; the original right-hand crystals remain. Robbie's material hint explains the route. An actually blocked companion path takes precedence over tutorial hints; distance from the ship does not stop Robbie.

Assembly costs: solar panel 2 structural + 1 electronic; lamp 1 electronic; pump 2 structural + 2 electronic; fan 1 structural + 2 electronic; furnace 3 structural + 1 electronic; converter 2 + 2; greenhouse 4 + 2; water container 2 structural + 1 electronic. Solar panels occupy a supported outdoor 2 x 1 m footprint and need no first-lab unlock. Pumps now occupy one pipe-mounted cell without floor support; water containers occupy 2 x 2 m. Other machine footprints, activation times and power links are unchanged. No structure provides services while merely planned or still assembling.

The furnace remains optional for initial progression. It smelts copper ingots and quartz-based glass for the alternate electronic recipe. Rare cobalt allows a more efficient structural alloy. There are still only two construction-component types.

Runtime costs: [prototype_components.json](design/v1/prototype_components.json). Approved specifications: [free digging and components](docs/superpowers/specs/2026-11-10-scavo-libero-componenti-design.md), [blueprints as complete FIFO orders](docs/superpowers/specs/2026-11-13-project-orders-design.md). The [November 12 manual-only direction](docs/superpowers/specs/2026-11-12-production-orders-design.md) is historical and superseded for the human variant; optional manual production remains available.

Living crafting reference: [production map](docs/design/mappa-produzione.md), generated from the playable prototype's recipes and cost functions. It includes inputs, outputs, stations, unlocks and a reverse ingredient index, separately from future proposals. [Structured map](design/generated/production-map.json) is ready for a future ship-computer guide; that in-game screen is not implemented yet.

## Run And Controls

Open `project.godot` in Godot 4.6.3 and press F5 for the complete game, including protagonist selection. **Arriva subito al pianeta** skips flight and landing presentation without granting supplies. F6 on `scenes/prototype/rocket_home.tscn` or `robbie_home.tscn` starts an isolated sandbox and intentionally skips selection.

For construction playtests, launch the complete game with `-- --construction-test` (Godot editor/debug builds only). Fresh campaigns start with 24 structural and 40 electronic components in Robbie, using 16 of its 20 real cargo units. Recipes, first-lab unlocks and deployment constraints remain unchanged. Normal starts stay empty; loading a campaign replaces this initial stock with its saved cargo rather than granting more.

- A/D move; W/S climb; Space jumps or supplies jetpack thrust. There is no component-economy cube pickup/drop command.
- E interacts with the hatch/nearby laboratory. Right-click laboratories, machines or free construction space for their contextual menus.
- 1 mining tool, 2 scanner, 3 bomb, 4 jetpack. Left-click/F uses the selected tool; Enter detonates placed bombs from at least 4 m away.
- Playtest shortcut: in scanner mode, + / - (including the numeric keypad) adjusts a local level-I-IV override. It changes real detection/identification range, shows the level in the HUD and clears old scan waves; it does not purchase upgrades or modify the shared catalog/save data.
- B places a free ladder, Shift+B removes it; the extraction beam also removes underground ladders.
- T offers blue valves, water pipes, pumps, greenhouses and water containers, plus gas pipes and energy cables. P selects the water-pipe mouse tool without placing anything. Left click places at the cursor; dragging fills all crossed cardinal cells without gaps, including elbows. Shift+left click/drag removes only water pipes; right click or Escape exits. Rock, reach and pump-axis limits stop a stroke at its last valid cell. Adjacent pipes join automatically. Gas pipes cost 1 structural component per metre; cables cost 1 electronic component per metre.
- Network lines use red for power, blue for water and green for gas. Automatic ship/laboratory/lamp leads use orthogonal 90-degree bends. The cable drawing itself is not a separate relay item: active lamps extend their rooted network in 8 m hops.
- I opens inventory; Y handles Robbie's delivery/deposit; H requests advice. Clicking companion Robbie repeats his last balloon.
- G toggles the grid; mouse wheel zooms; C switches close/overview camera; Home performs emergency return.

Controller bindings remain supported by the prototype, but complete hardware-controller QA and controller access to all new context menus remain outstanding.

## Industry And Crew

Gas pipes feed converters from finite real reservoirs; energy cables connect converters to furnaces or supply greenhouses as an alternative to local laboratory power. Free blue valves occupy rock cells beside water, leaving rock and water intact; all four faces accept pipes, without drilling, tools or orientation. Mining beams cannot excavate a valve's rock: right-click the valve and choose **Rimuovi valvola** first. This removes the valve without digging its rock. Free water pipes run in the background without collision, including behind ladders. Dangling ends never spill. Passive flow is limited to 0.35 units/s below the source head; powered pumps deliver up to 0.7 units/s with 6 m lift. A pump occupies one cell on an existing terminal or straight pipe, without a floor; corners and junctions are invalid. Right-click controls its switch and direction. Pump costs are unchanged and its buffer holds 8 units.

Water containers are normal 2 x 2 m construction projects costing 2 structural and 1 electronic component, unlocked after the first field laboratory. They hold 32 units and need no operating energy; paid assembly still consumes ship energy. Greenhouses store 4 units, retain seeds/crops, and grow only while actually consuming irrigation water and energy. They use the nearest operational laboratory within its light range, debiting the shared ship battery; without that supply they can use a cabled gas converter. Rain marks actual irrigation, not merely a connected pipe. Natural gas generation is currently paused, so ordinary new worlds cannot yet fuel converters or furnaces. Water pumps use the shared ship battery through an operational laboratory anywhere on the site, with no proximity gate or mandatory local relay. Empty batteries, disabled/damaged pumps and hazardous footprints still stop operation; the six-metre hydraulic lift limit remains separate from electrical distance.

Broken connections retain paid work and stored water; a greenhouse can use its remaining buffer before pausing. The ship has two permanent blue booster ports, each connected to its own 40-unit water tank, retained through travel and save/load. The ship starts with three seed potatoes; excavated capsules reveal other cultivars. Human food consumption restores personal energy; Robbie cannot eat crops. Only water is transported by hydraulics; mixtures, reactions, other tank fluids and buildable floors/volumes remain future work. Incompatible old hydraulic saves require a new game and are rejected without deleting files or replacing the current game.

In Robbie mode, the middle floor has upright cryopods for a male biomedical/technical scientist, a female botanist/chemist and a cat. The crew remains asleep; waking and specialist abilities are not implemented. Powered laboratories recharge Robbie's personal battery and repair his shell using ship energy. This maintenance is distinct from the jetpack's free landing recharge.

Ship battery upgrades increase the shared reserve from 60 to 100/140 kWh. Laboratory/device energy bars report actual charge and consumption, not a separate invented lab capacity. Off-world outposts and offline fabrication are not simulated.

## Saves And Texts

This experimental economy uses **new save slots**: `user://saves/campaign_components_v1.json` and `rocket_home_components_v1.json`, with `_robbie` before the extension for the robot variant. Old `campaign_v1.json`, `rocket_home_v1.json` and `slot_01.json` are not imported or overwritten. Start a new game to test this branch. Mixed economy payloads are rejected before restoring the current world.

Open `scenes/labs/robbie_text_lab.tscn` and press F6 to edit [robbie_texts.json](design/v1/robbie_texts.json), including variant overrides. The lab does not run or overwrite a campaign. See [tutorial authoring](docs/technical/robbie-tutorial-authoring.md).

## Verification

Use the installed Godot console executable as `godot`:

```powershell
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit/ --ignoreHeadlessMode
godot --headless --fixed-fps 60 --path . -s res://tests/integration/autonomous_robbie_smoke.gd
godot --headless --fixed-fps 60 --path . -s res://tests/integration/autonomous_robbie_safety_smoke.gd
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

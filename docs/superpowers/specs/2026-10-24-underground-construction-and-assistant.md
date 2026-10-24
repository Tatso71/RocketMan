# Underground Construction and Ship Assistant

Date: 2026-10-24
Status: First playable laboratory, lights, water pumps, limited-range following drone, physical cargo, graphical inventory and contextual/tutorial speech balloons are implemented. Doors, filters and relay networks remain proposals.

## Current Cube Workflow

Ocra onboarding update: the seven-step task list in `design/v1/progression.json:ocra_tutorial` is live. The new-laboratory flow below replaces free raw-funded placement for new UI actions: ship workshop -> fabricate for 6 stone + 4 copper, 5 s, 0.01 kWh -> one carried `lab_cube` using 4 inventory units -> valid 4 x 3 preview -> consume one cube -> 5 s unfolding -> active lab. No second ingredient payment is taken at the site. Fabrication commits only after revalidating local ingredients and output space; cancellation before completion is free. Old planned labs still accept their original raw funding. Lights/pumps retain raw-funded sites for now. A nearby drone is not a blanket construction prerequisite: its stock counts only when it is actually connected and within reach. Manual ladders are unchanged.

The persistent objective panel and Robbie messages advance from actual events, not reading balloons or waiting a target number of minutes. Tutorial progress belongs to the campaign guide state; older saves infer progress and preserve already active structures. Authoring details: `docs/technical/robbie-tutorial-authoring.md`. These changes do not add Ferrum, change planet seeds, inject tutorial excavations or define when Ocra becomes exhausted.

This section supersedes the earlier instant-placement and kit-crafting interaction below. New landings place the pilot in the upper cockpit. The cockpit, middle bedroom and bottom workshop highlight when reachable; cockpit right-click opens navigation/ship battery management, bedroom right-click opens rest. Personal energy and suit recovery are separate from ship charge. Fatigue slows movement but does not hard-lock traversal. Passive aboard suit recovery is replaced by rest or repair.

Right-click empty terrain space for the floating dependency tree; the fixed Cantiere panel has been removed. Opening the tree alone draws no footprint. Laboratory is the root; light/pump children remain hidden until at least one lab completes. Invalid recipes remain selectable, explain their blockers and enter a movable preview through Posiziona cubo. The cursor anchors near the floor, with the footprint growing upward; invalid clicks place nothing and keep the preview active.

Laboratory (4 x 3 m, 6 stone + 4 copper), light (1 x 1 m, 1 soil + 1 copper) and pump (2 x 2 m, 3 stone + 4 copper) use creator cubes. Ladders are the explicit exception: the character builds them instantly with B for 2 soil, without any cube or confirmation. Empty cells, applicable floor support, hazards, reach and structure reservations are checked before placement. A laboratory may overlap the explorer. For old laboratory plans and current light/pump plans, approach triggers a prompt listing exact deficits; confirmation alone spends local physical backpack/nearby-Robbie/cache stock once. New lab cubes are already paid and skip this funding prompt. No partial donation is taken and ship storage is not usable remotely. Remove an unfunded legacy cube to release its reservation without cost.

Funded cubes enter `building`, visibly opening and growing/flashing the final graphics beneath a progress bar. Laboratory/light/pump build times are 5/2.5/4 seconds; ladders have no construction phase. Only `active` structures provide services; first lab completion unlocks laboratory research, dependency recipes and the two further planets. Missing power pauses electric unfolding. Pending, funded and active stages persist; reload neither restarts progress nor repays materials. Prompt history tracks all nearby cubes until the player leaves, avoiding modal loops between adjacent sites.

Laboratories continuously draw 0.04/0.05/0.06 kWh/s by level; linked lights add 0.008 kWh/s and pumps 0.03. Lab/light/pump construction draws 0.06/0.02/0.08 kWh/s. The shared ship battery has 60 kWh base capacity, upgradeable to 100/140 with copper and crystals via cabin ship management. Capacity upgrades do not refill charge. Accendi/Spegni controls each active lab; a zero battery disables its powered services, lights and pumps while preserving access to the physical cache/switch. The HUD shows demand and remaining runtime. Only the visited outpost is simulated. Ordinary modal menus pause simulation; active bed rest continues construction/power draw while restoring crew stats, never adding battery charge.

Pumps allow water in their footprint, but not gas, and need a powered laboratory connection. They drain 0.7 water-volume units/s through connected open cells within three grid steps, clamped to actual battery runtime. They do not drain through rock or retroactively during the completion step. Removed water is discarded; reservoirs remain future work. Total drained volume persists with the structure.

Instant manual ladders are the bootstrap exception: no radio/drone, full-floor support, active lab or electrical energy is needed. They immediately consume 2 available soil and appear as usable ladders, so deeper expeditions retain a return option even with a dead battery. On loading saves from the short-lived ladder-cube prototype, paid in-progress ladders become ready without another charge; unfunded ladder plans are dropped. Old light kits and preexisting active structures/ladders remain compatible, but kit fabrication is no longer the primary visible construction action.

## First Playable Loop

1. Select the only initial destination, Ocra, land on untouched ground and begin in the cockpit. There is no excavated shaft, starter room, underground ladder, crate or installed light. Natural sealed gas/water cavities remain geological features, not a prepared base. Viridia/Brina appear after first laboratory completion; already-exploring legacy saves retain access.
2. Descend to the workshop, open the hatch and mine two real cells. Build the first ladder instantly with B and 2 gathered soil.
3. Return aboard and use Costruisci/Fabbrica cubo. Fabrication uses 6 stone + 4 copper from local carried or workshop supplies and creates a four-unit laboratory cube. The backpack holds 8 units; Robbie initially holds 12.
4. Enlarge a dry supported room to fit a 4 x 3 m laboratory. Bring the paid cube, not the same ingredients a second time; ship storage is not a remote resource pool.
5. Place the cube and wait for unfolding. It provides a local 32-unit cache and unlocks advanced tool/drone research. Its frame lights up when the explorer is in reach; right-click for its actions.
6. Choose Light from the field laboratory construction menu. Current light plans still request 1 soil + 1 copper locally, or accept an already crafted kit. The supported 1 x 1 m site must connect to an active lab within 8 m at level I (10/12 m at levels II/III).

The circular dependency is deliberately avoided: digging the first room does NOT require owning the room's laboratory. Without it, carrying capacity, visibility and progression limit expansion. Further habitability systems should strengthen this soft gate rather than prevent the first excavation.

Laboratory activation currently requires a dry, gas-free footprint inside the ship radio radius and some ship battery energy. This is a prototype power/data link, not simulated cables or a sealed atmosphere. A laboratory is a workstation and depot, not yet a fully habitable room.

## Direct Station Interaction

The ship workshop and placed laboratories share five right-click actions: deposit, withdraw, construct, repair and upgrade. A proximity highlight marks actual interaction availability; terrain collision rays prevent using a lab through a wall. Clicking a particular lab binds its own cache when two are in reach. Context/detail windows pause local simulation; world clicks cannot fall through into mining. Inventory remains accessible as a secondary keyboard/HUD shortcut.

Construction opens the same dependency tree used by right-click empty-space placement. Inventory keeps atomic ship-supply preparation as a separate action. No new room or terrain is created by the menu itself: the player still excavates and places the grid blueprint.

Repairs affect existing state, not invented item durability: free suit restoration aboard, 2 soil + 1 copper suit restoration at a field lab, and 2 stone + 1 copper for 25 ship hull integrity only aboard. Tool/drone damage and lab damage simulation are not implemented.

The ship laboratory's upgrade action uses the existing tool-station module and research prerequisite. An underground laboratory has local levels I-III, adding 16 cache units and 2 m lamp connection per step, at a cost of 4 stone + 3 copper times its current level. Thus cache capacities are 32/48/64, lamp ranges 8/10/12 m. Costs consume only physically available carried/local supplies. This does not enlarge the 4 x 3 m footprint or extend the ship-to-drone radio radius. Level persists in optional structure data; legacy structures default to I.

## Progression Proposal

The workshop aboard the rocket already supplies basic equipment. Do not require a laboratory just to survive the first tunnel. Use this sequence:

1. Excavate a safe niche and maintain a route back to the rocket.
2. Carry supplies from the rocket with the drone.
3. Build a small laboratory as the first substantial outpost objective, then fabricate and install lights.
4. Use powered pumps for water, then later add sealing, gas filters, relays and advanced analysis.
5. Extend the network and make deeper rooms genuinely habitable.

Each hazard should create a reason to build, not only a demand for a stronger extractor. Some indestructible formations must be routed around. Water suggests drainage and reservoirs; gas suggests detectors, isolation and filtration.

## Metric Building Contract

All footprints use `world_grid.gd`: one cell = one metre. Initial proposal:

| Structure | Footprint | Purpose |
| --- | --- | --- |
| Work light | 1 x 1 m | Local powered visibility |
| Door / airlock connection | 1 x 2 m | Separate safe and unsafe areas |
| Relay | 1 x 1 m | Extend computer/robot signal |
| Pump | 2 x 2 m | Remove or redirect finite water |
| Gas filter | 2 x 2 m | Reduce local contamination |
| Small laboratory | 4 x 3 m | Analyze samples, research equipment and organisms |

Placement shows a snapped footprint preview. Validate empty space, declared support surface, available resources and appropriate power/data connections before spending materials. Reject overlap with terrain, fluid or other structures. The laboratory may overlap the explorer: its non-solid furnishing does not trap the player. A floor light still rejects player overlap. A room's enclosing walls and air quality remain separate from the furniture placed inside it.

Laboratory, floor-light and pump dimensions are implemented; the other structures remain proposals. A transit tunnel can be 2 m high, while the player must excavate a proper 3 m-high laboratory room. Placement validates full floor support, hazards, structure overlap, radio range and drone proximity; local materials are checked when funding. Missing-material errors report actual deficits, independently of the carried unit total. Supporting floor cells cannot be mined from underneath installed structures. Dismantling/repositioning of funded structures is not implemented yet.

## Robot Assistant Proposal

The robot is a mobile terminal of the ship's computer, not a second autonomous player. Its usefulness depends on a limited signal network. Start by testing a 12-15 m connection range from the ship or nearest relay; attenuation/line-of-sight rules need playtesting.

Current implementation: a 15 m geometric radius from the ship collar. Native Godot AStar2D paths follow excavated cells and respect actual floor/hatch collision rays; a circular physics body cannot pass through terrain. Outside range it waits at the radio limit, preserving its cargo. It can assist collection/payment only when connected, within 3 m of the explorer, and with a clear physical segment between them. It must be aboard before takeoff. No relay network is implemented yet.

Drone upgrades require the first lab's research unlock. Each level adds 5 m range and 4 cargo units. A new planet reuses the same global carried inventory; it does not copy material caches from the previous outpost.

Possible starting abilities:

- Explain the next immediate objective when asked, without constant tutorial interruptions.
- Keep known scans and place a return-route breadcrumb on explored passages.
- Warn about detected gas, water and incompatible or indestructible materials.
- Check whether a selected blueprint fits the metric grid and which connection is missing.
- Carry a small task light; outside signal range it cannot reveal distant deposits or fetch new analysis.

Possible upgrades:

- Antenna: longer relay range and more reliable cave links.
- Battery: short disconnected operation instead of immediately stopping.
- Sensor package: improved composition, pressure and biological readings.
- Utility attachment: mark a leak, apply a temporary patch or repair a nearby powered device.
- Small cargo clamp: carry a few samples back, not automate the whole expedition.

The robot should not dig automatically, solve every discovery or deliver perfect danger prediction before the player has invested in sensors. Give it a clear limited state outside signal range: return to the last relay or wait, rather than disappear. Four player equipment slots do not automatically imply four robot attachments; decide that loadout separately.

## Implemented Foundation

`environment_field.gd` provides finite water, connected-cell pump drainage, local gas concentration, breach events and sensor readings on integer cells. `outpost_buildings.gd` owns placed structures, levels, cache capacity and device-link range; `field_cargo.gd` owns portable inventory; `support_drone.gd` supplies physical dry-cell following/navigation and a red immersion alarm. `outpost_controller.gd` handles station access, selected caches, transactions, snapped previews and powered structures. `construction_ui.gd` supplies the dependency tree and funding popup; `workstation_menu.gd` supplies station actions. `field_inventory_ui.gd` shows live backpack/drone contents, separate storage and explicit local transfers. Filters, pressure simulation, automated drone jobs and relays are still future work.

## Contextual Assistant

`drone_guide_state.gd` owns authored Italian messages, priorities, once-only milestones, cooldowns and repeated-condition latches. `drone_guide.gd` selects advice from semantic events and actual world conditions, draws the comic balloon near the drone, and avoids the explorer and HUD. Offscreen/range-limit advice uses a radio presentation. Exposure and breached-pocket alerts take priority; no hint reveals unscanned distant resources or hazards.

The first successful excavation immediately triggers Robbie's 6-stone/4-copper collection objective. Once supplies are ready, advice changes to room excavation. A nearby supported free 4 x 3 space triggers right-click/cube-footprint guidance, followed by funding advice. Unfinished tutorial objectives repeat about every 20-25 seconds; submerged damage warnings repeat every 10 seconds and take priority. Robbie waits outside water and flashes red while the player is submerged, then resumes following on dry ground.

The question-mark button/H recalls advice even when automatic help is muted. Other full-cargo/signal hints retain their repeated-condition latches. Reading timers freeze while modal inventory/maintenance is open. Seen messages, milestones and mute preference persist with the campaign's ship state, not separately per planet; standalone saves retain their own guide progress. Legacy saves infer completed excavation/building milestones. A journal, branching conversations, voice and drone automation are not implemented.

Left-clicking the visible drone repeats the exact last rendered balloon text, rather than re-evaluating current advice; the hit target tracks the world/camera transform. This works while automatic speech is muted and consumes the click before mining. Building mode deliberately keeps click-to-place priority. The exact replay cache is session-local; persistent tutorial knowledge remains in the existing guide state.

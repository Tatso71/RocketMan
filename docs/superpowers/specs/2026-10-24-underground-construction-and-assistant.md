# Underground Construction and Ship Assistant

Date: 2026-10-24
Status: First playable laboratory, portable lights, limited-range following drone, physical cargo, graphical inventory and contextual speech balloons are implemented. Doors, pumps, filters and relay networks remain proposals.

## First Playable Loop

1. Land on untouched ground. There is no excavated shaft, starter room, underground ladder, crate or installed light. Natural sealed gas/water cavities remain geological features, not a prepared base.
2. Use Inventario in the ship workshop to load supplies. Prepara laboratorio transfers the missing stone/copper recipe after validating both stock and space. The backpack holds 8 inventory units; the drone initially holds another 12.
3. Open the hatch and dig the actual first cells below the ship. Emergency ladders remain available without a lab so the player can always make a return route.
4. Enlarge a dry supported room to fit a 4 x 3 m laboratory. Bring 6 stone + 4 copper; ship storage is not a remote resource pool.
5. Place the lab with the drone nearby and connected. It provides a local 32-unit cache and unlocks advanced tool/drone research.
6. Carry 1 soil + 1 copper to the lab to fabricate a portable light. The light kit occupies one carried unit. Place the crafted light on a supported 1 x 1 m cell connected to an active lab within 8 m.

The circular dependency is deliberately avoided: digging the first room does NOT require owning the room's laboratory. Without it, carrying capacity, visibility and progression limit expansion. Further habitability systems should strengthen this soft gate rather than prevent the first excavation.

Laboratory activation currently requires a dry, gas-free footprint inside the ship radio radius and some ship battery energy. This is a prototype power/data link, not simulated cables or a sealed atmosphere. A laboratory is a workstation and depot, not yet a fully habitable room.

## Progression Proposal

The workshop aboard the rocket already supplies basic equipment. Do not require a laboratory just to survive the first tunnel. Use this sequence:

1. Excavate a safe niche and maintain a route back to the rocket.
2. Carry supplies from the rocket with the drone.
3. Build a small laboratory as the first substantial outpost objective, then fabricate and install lights.
4. Later add sealing, pumps, gas filters, relays and advanced analysis as systems are implemented.
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

Laboratory and floor-light dimensions are implemented; the other structures remain proposals. A transit tunnel can be 2 m high, while the player must excavate a proper 3 m-high laboratory room. Placement validates full floor support, hazards, structure overlap, radio range, drone proximity and local materials before charging. Missing-material errors report actual deficits, independently of the carried unit total. Supporting floor cells cannot be mined from underneath installed structures. Dismantling/repositioning is not implemented yet.

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

`environment_field.gd` provides finite water, local gas concentration, breach events and sensor readings on integer cells. `outpost_buildings.gd` owns placed structures and their caches; `field_cargo.gd` owns portable inventory; `support_drone.gd` supplies physical following/navigation. `outpost_controller.gd` handles snapped previews, lamp fabrication and built lights. `field_inventory_ui.gd` shows live backpack/drone contents, separate storage and explicit local transfers. Pumps, filters, pressure simulation, automated drone jobs and relays are still future work.

## Contextual Assistant

`drone_guide_state.gd` owns authored Italian messages, priorities, once-only milestones, cooldowns and repeated-condition latches. `drone_guide.gd` selects advice from semantic events and actual world conditions, draws the comic balloon near the drone, and avoids the explorer and HUD. Offscreen/range-limit advice uses a radio presentation. Exposure and breached-pocket alerts take priority; no hint reveals unscanned distant resources or hazards.

The question-mark button/H recalls advice even when automatic help is muted. Automatic hints do not continuously repeat while the same full-cargo/build/signal condition persists. Reading timers freeze while modal inventory/maintenance is open. Seen messages, milestones and mute preference persist with the campaign's ship state, not separately per planet; standalone saves retain their own guide progress. Legacy saves infer completed excavation/building milestones. A journal, branching conversations, voice and drone automation are not implemented.

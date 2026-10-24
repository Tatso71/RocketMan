# Expedition, Ship and Digital Tools

Date: 2026-10-24
Status: Playable foundation, not final simulation or balance

## Ownership

- `scripts/systems/expedition_state.gd`: pure expedition state and legal phase transitions.
- `scripts/systems/ship_state.gd`: one persistent ship, ship storage, global field-cargo ownership, equipment, resource transactions and derived attributes.
- `scripts/systems/field_cargo.gd`: bounded backpack/drone holds and atomic local transfers/payments.
- `scripts/ui/field_inventory_ui.gd`: always-available inventory inspection, live cargo HUD and locally gated transfers/recipe preparation.
- `scripts/systems/drone_guide_state.gd`: pure speech priority/cooldown state, authored messages and persistent tutorial milestones.
- `scripts/ui/drone_guide.gd`: contextual selection, manual/mute controls and viewport-clamped comic balloons.
- `scripts/systems/outpost_buildings.gd`: metric structure footprints and per-laboratory caches.
- `scripts/player/support_drone.gd`: native AStar2D navigation and a physical flying follower inside the ship radio radius.
- `scripts/prototype/outpost_controller.gd`: construction preview, local cargo/crafting UI and placed lights.
- `scripts/data/planet_def.gd` and `planet_catalog.gd`: planet identity, seed, scan clues, colors, route cost and landing hazard.
- `scripts/data/ship_module_def.gd` and `ship_module_catalog.gd`: upgrade definitions and integral metre-based footprints.
- `scripts/data/digital_tool_def.gd` and `digital_tool_catalog.gd`: read-only tool definitions (mode, compatible materials, reach, power, energy, beam appearance).
- `scripts/prototype/expedition.gd`: scene orchestration and UI, not the authoritative resource economy.
- `scripts/prototype/rocket_home.gd`: local metric excavation, physics, visibility, scans and player interaction.

The main entry routes to `scenes/prototype/expedition.tscn`. The standalone rocket scene remains independently runnable for traversal tests. No extra global autoload is required.

## Phases

`SELECT -> FLIGHT -> LANDING -> DIGGING -> TAKEOFF -> SELECT`

Flight/landing/takeoff are timed visual sequences, not manually piloted physics. Selection cannot change after departure. Travel fuel and energy are charged once at departure; landing wear is charged once on entry to digging. Takeoff requires the astronaut aboard, closed hatch, sufficient hull/fuel/energy, and captures the local outpost before removing its scene.

Each destination preserves its own removed cells, ladders, scans and hatch state. Changing planets changes deterministic material distribution and palette, not a fully generated planetary ecosystem yet.

## Ship Attributes

| Attribute | Baseline | Current behavior |
| --- | --- | --- |
| Hull | 100 integrity | Landing wear, +25 repair, +40 capacity per upgrade |
| Fuel | 80 abstract units | Route cost, 6 takeoff units; engine reduces route cost |
| Battery | 60 kWh | Travel and tool pulses; +40 capacity per upgrade |
| Cargo | 120 inventory units | Counts gathered materials; +80 capacity per upgrade |
| Dry mass | 8000 kg | Derived upgrade mass, informational until flight physics exists |
| Crew | 1 nominal place | Habitat upgrade adds places; no crew simulation yet |
| Oxygen reserve | 120 nominal minutes | Capacity only, no oxygen drain or pressure simulation yet |
| Tool station | Level I | Adds mining power, unlocks resonator at II and plasma at III |
| Suit protection | 100% | Environmental exposure, emergency return, recovery aboard ship |

Module levels range from I to III. Costs scale with current level and are checked before mutation. Upgrading capacity does not refill it. Service is available in orbit or in the workshop, not remotely from underground or during flight. Cargo can be jettisoned explicitly to avoid a full-hold deadlock.

Prototype economy: 2 soil -> 20 fuel units; emergency solar recharge -> 15 kWh at no material cost. The latter deliberately prevents being stranded with an empty battery before finding crystals. These are balancing placeholders, not final fuel chemistry or solar simulation.

Module footprints describe future installation requirements. Capacity upgrades do NOT yet enlarge the visible hull or add rooms. Next construction step: grid-aligned sockets, collision-safe placement and external expansion scenes, preserving the three initial rooms.

## Digital Tools

Temporary loadout limit: four slots (`SLOT_COUNT`), saved with the ship. Start with Pulse and Scanner. Tool-station upgrades fill free slots with newly unlocked tools; a later loadout screen can replace this automatic assignment without changing definitions.

| Tool | Use | Reach | Pulse energy | Beam |
| --- | --- | --- | --- | --- |
| Pulse | Soil, stone, copper | 3 m | 0.20 kWh | Thin turquoise |
| Scanner | Reads material and resistance, does not mine | 4 m | 0.05 kWh | Fine gold |
| Resonator | Stone, copper, crystal | 3 m | 0.30 kWh | Medium violet |
| Plasma | Includes protected deep rock | 2.5 m | 0.60 kWh | Thick coral |

The target outline uses the same validation as tool use: first physical obstruction, metric range, material compatibility, energy and cargo space. An unavailable target is red, with a reason in the status bar. Scanner uses scanning compatibility rather than pretending to break the cell. Every completed mined cell credits exactly one unit; scanner pulses never credit materials.

Held left mouse/F/RB produces pulses. Beam waves and width/color come from the tool definition, not the terrain. Deep compact rock yields ordinary stone rather than creating an unsupported fifth cargo resource. Scan records are cell coordinates in the individual outpost, restored only for cells that still exist.

## Visibility and PC Camera

The prototype shades cell drawing around the explorer's tool radius and player-built lights, with a soft falloff. Remote terrain and cavities share the same darkness; remote veins are not drawn. This is a local visibility mask, NOT line-of-sight occlusion or a full lighting simulation yet. Future work: cable networks, continuous lighting power consumption, ray occlusion and unexplored fog memory.

Update: the starter lamp, crate, room and shaft have been removed. Only natural sealed cavities start as air below the surface. New game terrain directly below the collar is solid. The ship ladder ends at ground level; underground ladders must be placed by the player. Player-built laboratory and floor lights now supply local illumination. Light power is a prototype range/availability check, not a continuous cable/consumption simulation.

## Underground Hazards

`hazard_layout.gd` defines small deterministic test pockets per terrain seed. `environment_field.gd` owns their fluid state separately from terrain geometry:

- Gas and water start in sealed two-by-two metre cavities, behind mineable walls.
- Scanner reads an adjacent pocket through one wall-cell face, without opening it. Known hazard walls have a warning marker.
- Breaches are reported once. Gas diffuses only through excavated adjacent cells and slowly disperses after release. Water flows down first and then laterally, with finite cell volumes; no infinite source is spawned.
- Both fields are restricted to the underground grid. They do not yet simulate contamination of the rocket, pressure, explosions, temperature, buoyancy or full fluid dynamics.
- Water slows movement. Up/climb input can swim upward without requiring a ladder. Submersion is checked at the head against actual cell fill height, not merely whether the cell has any water.
- Gas exposure and submersion reduce suit protection. At zero, the prototype recalls the explorer to the workshop with 25% protection, preserving cargo. Protection recovers inside the ship. This is a recoverable prototype risk, not a death/respawn system.
- Dark cross-marked anchor formations and the bottom boundary cannot be mined by any tool. They remain distinct from compact rock, which Plasma can break. Scan both to learn the distinction.

Outpost snapshots now include optional versioned hazard fields and local suit data. Campaign suit protection remains authoritative in ShipState, just like shared cargo. Legacy snapshots without hazard data initialize the new test pockets; old terrain removal lists add their cavity cells during restoration. Invalid volumes, solid-cell fluid entries, unknown breach IDs and malformed coordinates are rejected before replacing live world state. This prototype terrain revision introduces anchor formations and enforces them on load.

The first laboratory, floor lights, following/cargo drone, graphical inventory and contextual assistant balloons are implemented as described in `docs/superpowers/specs/2026-10-24-underground-construction-and-assistant.md`. Doors, pumps, filters and a relay network remain proposals.

Close camera starts at 1.1x; mouse wheel adjusts 0.78-1.5x and C toggles overview/close. The old 0.78x view remains useful for the complete rocket. Visibility is metric and does not expand with resolution or camera zoom, preventing a larger monitor from revealing more deposits. Prototype lamps/ladders already known to the player remain visible.

PC/Steam target is 16:9. Logical 1280x720 UI scales to 1920x1080; integration captures verify both resolutions. Actual Steam export presets, release packaging, Steamworks and complete controller hardware QA remain separate work.

## Save Contracts

- Campaign: `user://saves/campaign_v1.json` via SaveManager campaign methods.
- Isolated digging sandbox: `user://saves/rocket_home_v1.json` (unchanged path).
- Legacy progression: `user://saves/slot_01.json` (untouched).

Campaign save includes phase/progress so resuming flight does not pay twice. Ship cargo is authoritative; the local sandbox's copied materials are ignored when restoring campaign outposts, so traveling cannot duplicate resources. Terrain seed and integral coordinates are validated before replacing a campaign. Save is manual; a fresh launch does not auto-load or overwrite progress.

Portable inventory is now separate from ship storage: 8 backpack units and initially 12 drone units. ShipState saves the field holds globally; campaign outpost copies are ignored on load. Laboratory caches remain local to their planet. A legacy campaign without field-cargo data initializes empty portable holds while preserving its ship resources. Legacy standalone material data migrates to the local ship deposit. Numeric stock values normalize to integer counts after JSON decoding. Placed structures validate free cells, support and non-overlap before replacing live state.

Guide progress follows the same ownership rule: ShipState owns campaign `drone_guide`, outpost copies are ignored, and standalone restore validates its own optional guide data before world mutation. Only seen IDs, semantic milestones and mute preference persist; active balloons, reading timers and contextual polling are runtime-only. Older saves without this field remain compatible. Laboratory placement deliberately permits overlap with the explorer because it creates no blocking collision.

Lab research unlocks tool-station and drone upgrades, but basic digging and emergency ladders remain available without a lab to avoid an impossible bootstrap. Upgraded drone range is 15/20/25 m, capacity 12/16/20 units. A lamp is crafted at a nearby active lab for 1 soil + 1 copper, carried as one unit and then installed on a supported 1 m cell within 8 m of an active lab. There is no instant transport from ship storage to the building site.

## Next Steps

1. Try the close camera and darkness before committing to final visibility distances.
2. Add powered, sealed rooms: excavated space must not automatically be habitable.
3. Add actual expansion sockets/rooms using the declared metric module footprints.
4. Separate equipment ownership, loadout and tool crafting once enough tools exist.
5. Add flight interaction and planet-specific ecology after the travel/build loop feels right.

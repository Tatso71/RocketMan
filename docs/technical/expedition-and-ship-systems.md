# Expedition, Ship and Digital Tools

Date: 2026-10-24
Status: Playable foundation, not final simulation or balance

## Ownership

- `scripts/systems/expedition_state.gd`: pure expedition state and legal phase transitions.
- `scripts/systems/ship_state.gd`: one persistent ship, shared cargo, equipment, resource transactions and derived attributes.
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

The prototype shades cell drawing around the explorer's tool radius, with a soft falloff and one known starter lamp. Remote terrain and cavities share the same darkness; remote veins are not drawn. This is a local visibility mask, NOT line-of-sight occlusion or a full lighting simulation yet. Future work: cave lights, power-dependent lamps, ray occlusion and unexplored fog memory.

Close camera starts at 1.1x; mouse wheel adjusts 0.78-1.5x and C toggles overview/close. The old 0.78x view remains useful for the complete rocket. Visibility is metric and does not expand with resolution or camera zoom, preventing a larger monitor from revealing more deposits. Prototype lamps/ladders already known to the player remain visible.

PC/Steam target is 16:9. Logical 1280x720 UI scales to 1920x1080; integration captures verify both resolutions. Actual Steam export presets, release packaging, Steamworks and complete controller hardware QA remain separate work.

## Save Contracts

- Campaign: `user://saves/campaign_v1.json` via SaveManager campaign methods.
- Isolated digging sandbox: `user://saves/rocket_home_v1.json` (unchanged path).
- Legacy progression: `user://saves/slot_01.json` (untouched).

Campaign save includes phase/progress so resuming flight does not pay twice. Ship cargo is authoritative; the local sandbox's copied materials are ignored when restoring campaign outposts, so traveling cannot duplicate resources. Terrain seed and integral coordinates are validated before replacing a campaign. Save is manual; a fresh launch does not auto-load or overwrite progress.

## Next Steps

1. Try the close camera and darkness before committing to final visibility distances.
2. Add powered, sealed rooms: excavated space must not automatically be habitable.
3. Add actual expansion sockets/rooms using the declared metric module footprints.
4. Separate equipment ownership, loadout and tool crafting once enough tools exist.
5. Add flight interaction and planet-specific ecology after the travel/build loop feels right.

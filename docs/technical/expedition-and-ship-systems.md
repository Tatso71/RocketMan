# Expedition, Ship and Digital Tools

Date: 2026-10-24
Status: Playable foundation, not final simulation or balance

## Ownership

- `scripts/systems/expedition_state.gd`: pure expedition state and legal phase transitions.
- `scripts/systems/ship_state.gd`: one persistent ship, ship storage, global field-cargo ownership, equipment, resource transactions and derived attributes.
- `scripts/systems/field_cargo.gd`: bounded backpack/drone holds and atomic local transfers/payments.
- `scripts/ui/field_inventory_ui.gd`: always-available inventory inspection, live cargo HUD and locally gated transfers/recipe preparation.
- `scripts/ui/workstation_menu.gd`: shared right-click lab actions and construction/repair/upgrade detail views.
- `scripts/ui/construction_ui.gd`: world-location recipe picker, local cube funding confirmation and per-proximity prompt tracking.
- `scripts/ui/ship_rooms.gd`: cockpit navigation/battery actions, bedroom rest and separate personal-stat recovery.
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

New campaigns expose only Ocra. Completing the first field laboratory sets persistent ship research and unlocks Viridia/Brina in both navigation UI and route validation. Legacy campaigns already visiting outer planets retain access; locked SELECT destinations normalize to Ocra on restore. A fresh landing never adds tutorial tunnels or prebuilt structures.

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

The prototype shades cell drawing around the explorer's tool radius and player-built lights, with a soft falloff. Remote terrain and cavities share the same darkness; remote veins are not drawn. This is a local visibility mask, NOT line-of-sight occlusion or a full lighting simulation yet. Future work: cable networks, ray occlusion and unexplored fog memory. Continuous lighting power consumption is now implemented via the shared battery network.

Update: the starter lamp, crate, room and shaft have been removed. Only natural sealed cavities start as air below the surface. New game terrain directly below the collar is solid. The ship ladder ends at ground level; underground ladders must be built by the player. Player-built laboratory and floor lights supply local illumination and continuously debit ship charge; cable routing is not simulated.

## Underground Hazards

`hazard_layout.gd` defines small deterministic test pockets per terrain seed. `environment_field.gd` owns their fluid state separately from terrain geometry:

- Gas and water start in sealed two-by-two metre cavities, behind mineable walls.
- Scanner reads an adjacent pocket through one wall-cell face, without opening it. Known hazard walls have a warning marker.
- Breaches are reported once. Gas diffuses only through excavated adjacent cells and slowly disperses after release. Water flows down first and then laterally, with finite cell volumes; no infinite source is spawned.
- Both fields are restricted to the underground grid. They do not yet simulate contamination of the rocket, pressure, explosions, temperature, buoyancy or full fluid dynamics.
- Water slows movement. Up/climb input can swim upward without requiring a ladder. Submersion is checked at the head against actual cell fill height, not merely whether the cell has any water.
- Gas exposure and submersion reduce suit protection. At zero, the prototype recalls the explorer to the workshop with 25% protection, preserving cargo. Protection recovers through bedroom rest or station repairs, not passive aboard regeneration. This is a recoverable prototype risk, not a death/respawn system.
- Dark cross-marked anchor formations and the bottom boundary cannot be mined by any tool. They remain distinct from compact rock, which Plasma can break. Scan both to learn the distinction.

Outpost snapshots now include optional versioned hazard fields and local suit data. Campaign suit protection remains authoritative in ShipState, just like shared cargo. Legacy snapshots without hazard data initialize the new test pockets; old terrain removal lists add their cavity cells during restoration. Invalid volumes, solid-cell fluid entries, unknown breach IDs and malformed coordinates are rejected before replacing live world state. This prototype terrain revision introduces anchor formations and enforces them on load.

The first laboratory, floor lights, water pumps, following/cargo drone, graphical inventory and contextual assistant balloons are implemented as described in `docs/superpowers/specs/2026-10-24-underground-construction-and-assistant.md`. Doors, filters and a relay network remain proposals. Pumps remove finite water through open connected cells, never through rock. While the explorer is submerged, Robbie waits outside the water, flashes red and warns of actual suit damage; dry following resumes afterward.

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

Station interaction update: ship workshop and placed labs highlight in reach and accept right-click for five contextual actions. `outpost_controller.gd` validates access (including physical ray occlusion) and holds the selected station so adjacent laboratory caches do not get mixed. Popup/detail windows participate in `controls_blocked()`. Field suit repair pays 2 soil + 1 copper locally; ship hull repair still uses its existing aboard-only transaction. The ship lab upgrades the existing drill/tool station. Field lab levels I-III add cache space (32/48/64) and lamp-link range (8/10/12 m), not radio range or building footprint. Lamp fabrication at the ship becomes available after unlocking lab research.

Structure snapshots include optional integral `level`, validated before stock capacity and live-world mutation; old snapshots default to level I. Inventory, lamp placement and illumination all use the model's level-derived capacity/range helpers. The drone's world-space click target is transformed from viewport coordinates; replay consumes the click before mining and preserves the last visible text even if the context has since changed. H remains a fresh contextual-help request.

## Creator Cubes and Energy

`outpost_buildings.gd` adds optional `state` (`planned`, `building`, `active`), integral level, finite normalized progress and boolean enabled state. Legacy structures default to active with full progress. Unfunded/in-progress stock must be empty and level I; malformed or inconsistent states are rejected transactionally. `install` remains a low-level active/fixture operation; production laboratory/light placement calls `plan`, which rejects ladders. All reserved footprints block conflicting construction. Manual ladders are added instantly to the native grid after atomic 2-soil payment. On restore, earlier paid ladder cubes become active without another payment and unfunded ladder plans are discarded; ready legacy ladders are merged into the native grid.

`outpost_controller.gd` separates laboratory/light/pump placement from material funding. Funding revalidates reach, geometry, safety, connection and cargo, then atomically pays and transitions to building. `advance` uses available battery runtime to clamp electric progress/draw, never negative energy. Laboratory/light/pump draw is 0.04 (+0.01 per lab level)/0.008/0.03 kWh/s; construction draw is 0.06/0.02/0.08. Manual ladders bypass this workflow: `rocket_home.place_ladder` pays 2 soil and installs immediately with no power or drone dependency. Scene menus pause advancement except while actively resting. Unpowered labs preserve mechanical cache access but not crafting/repair/upgrading/illumination. Only the loaded planet has a running network.

`construction_ui.gd` opens a dependency Tree without a footprint. Only selecting a recipe draws it; Posiziona cubo enters movable placement. Invalid recipes stay selectable and invalid clicks create nothing. The cursor anchors the footprint at the floor, expanding upward. Lamp/pump children stay hidden until global lab research, then remain visible even without a currently powered local lab; local operational prerequisites still apply. Payment combines physical backpack, nearby connected drone and eligible local cache, never remote ship storage.

The pump footprint is 2 x 2 m, costs 3 stone + 4 copper and unfolds in 4 s. Unlike other electric structures it permits water in its footprint, but not gas. Powered pumps drain 0.7 finite water-volume units/s, breadth-first through open cells within three Manhattan steps from the intake. Drainage uses actual battery runtime, starts only after the completion step and pauses without its linked active lab. Optional finite nonnegative `drained` totals persist in structure snapshots. There is no reservoir or recycled-water item yet.

Robbie's early tutorial begins on the first successful mining event, repeats unfinished objectives at 20-25 s intervals and changes from gathering supplies to excavating/fitting/funding the first lab. The guide polls supported nearby 4 x 3 spaces, not hidden remote resources. Water warnings repeat while submerged and take priority over the tutorial. Automatic help can still be muted through its existing toggle; manual recall is always available.

`ship_state.gd` owns campaign `crew_energy`, separate from battery `energy`; outpost copies are ignored on campaign restore, as with cargo/suit data. Standalone snapshots own local crew and ship charge. Legacy crew defaults to 100. Personal energy drains on motion/tool pulses, with a soft movement penalty at zero. Bedroom rest restores crew energy/suit integrity while preserving the distinction from ship charge. Cabin management now permits normal ship service/upgrade operations aboard the top floor as well as the workshop. New arrivals spawn at (-60, -320), while explicit load preserves saved positions and emergency recall stays at the workshop.

Verification: 70 unit tests and eight integration scripts, including `creator_cube_smoke.gd` for room/cube/energy interactions and `robbie_tutorial_smoke.gd` for tutorial gating, dependency visibility, invalid placement, split cargo funding, finite powered drainage, underwater warnings and persistence. Rendered captures verify 720p/1080p. Ship battery upgrades require real ship resources and increase capacity without filling it.

## Next Steps

1. Try the close camera and darkness before committing to final visibility distances.
2. Add powered, sealed rooms: excavated space must not automatically be habitable.
3. Add actual expansion sockets/rooms using the declared metric module footprints.
4. Separate equipment ownership, loadout and tool crafting once enough tools exist.
5. Add flight interaction and planet-specific ecology after the travel/build loop feels right.

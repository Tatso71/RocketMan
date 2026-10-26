# RocketMan: Rocket Home and Planetary Digging

Date: 2026-10-24
Status: Current approved product direction
Supersedes the premise and progression in the 2026-05-10 design. Older scenes remain as legacy experiments.

## Player Fantasy

Land on an unknown planet and turn the ground beneath your rocket into a home. Explore further to discover materials, organisms and new ways to inhabit the unknown.

## Core Loop

1. Choose a planet using incomplete but meaningful scan information.
2. Land vertically; the rocket is the initial safe habitat.
3. Dig directly beneath its sealed lower hatch.
4. Explore, collect and understand the local ecosystem.
5. Equip tools and extend habitable tunnels and rooms.
6. Leave a persistent outpost and travel to another planet in the same mobile home.

Planetary collapse and repairing an inherited rocket are no longer the primary premise. Discovery, preparation and a visible growing home replace mandatory time pressure.

## Rocket and Presentation

- In flight: intact opaque rocket hull, pilot visible through upper porthole.
- Vertical landing: extended feet, side engines, free central lower passage.
- Landed: side-on cutaway visualization, not a physically removed hull.
- Exactly three initial rooms: upper cockpit, middle living quarters, lower workshop.
- Internal ladder connects floors; lower hatch connects to a two-metre-wide shaft.
- Final visual target: colorful low-poly 2.5D with a fixed lateral camera.
- First prototype: native 2D geometry to validate scale, traversal and digging before 3D production.
- Approved visual anchor: `refs/rocket-concepts/03-landed-cutaway.png`.

## Metric Geometry Contract

`scripts/world/world_grid.gd` is the shared conversion boundary.

- One integer cell represents 1 x 1 metre; the prototype renders one metre as 40 pixels.
- Surface is row 0; positive Y is depth; negative Y is above ground.
- Cell coordinates identify the top-left corner; conversion uses floor, including negative coordinates.
- Rocket inner width: 8 cells / 8 metres.
- Floor rows: -8, -5, -2; ceiling: -11. Each room occupies 3 metres vertically before floor thickness.
- Suggested first shaft: columns -1 and 0, two metres across, excavated by the player (not pre-carved).
- Transit passages can be two metres high; a laboratory needs a three-metre-high room excavated by the player.
- Player collision envelope: 0.6 x 1.6 metres, anchored at the feet.
- Ladder segment: one cell tall; interior ladder opening: one cell wide.
- Wall/floor thickness is a deliberate sub-cell component (0.2 m floor), not a separate placement grid.
- Terrain drawing and collision rectangles derive from the same cell rectangles.
- Save terrain and ladder locations as integer cells, never rounded screen coordinates.
- Bevels, furniture and decoration may use finer visual detail; they do not redefine usable cell space.

Future room, door and machine footprints must use whole-cell dimensions and declared connection points. Local gas/water and shared battery draw are prototyped; pressure, temperature and cable networks are not. Excavated does not automatically mean habitable in the eventual game.

## Prototype Scope

Implemented: three-floor traversal, jump, ladders, lower hatch, reachable-cell digital extraction, scanner, four equipment slots, per-tool material compatibility/beam appearance, local terrain darkness, adjustable camera, inventory and ladder placement. Full expedition prototype adds three destinations, automatic flight/landing/takeoff, shared ship cargo, repair/refuel/solar recharge, attribute upgrades and separate persistent outposts.

Environment prototype: indestructible anchor formations, sealed gas/water pockets, scan warnings, finite water flow, gas spread and recoverable suit exposure. The laboratory/drone system is documented in `2026-10-24-underground-construction-and-assistant.md`.

Construction update: limited-range physical support drone, backpack/drone logistics, metric laboratory, local cache, lamp crafting and placed lights are implemented. New arrivals have untouched ground, no starter tunnel or underground equipment. See the updated construction specification; full habitat sealing and relay networks remain future work.

Current interaction update: arrive in the cockpit after piloting; right-click its highlighted room to manage the ship, expand battery capacity or take off. The middle bedroom highlights and provides timed rest for personal energy/suit recovery, separate from the shared ship battery. Only laboratory and light construction use creator cubes: right-click empty space, choose the footprint, place an unfunded cube, bring materials and confirm their transfer. Dashed reservations, timed opening/flashing graphics and a progress bar precede activation. The fixed construction panel is removed. Active labs/lights drain ship battery and stop when unpowered. Ladders are built instantly by the character with B for 2 soil, without cubes, confirmations, drone or electricity. Pending/building stages and paid progress survive save/load.

Digging removes one 1 m2 cross-section cell. It does not claim a physical cubic-metre yield until world thickness is defined. Resource amounts are inventory units.

Not yet implemented: manually piloted flight, full procedural planets, pressure/oxygen simulation, buildable sealed rooms, physically expanding hull/modules, individual tool crafting, active creature ecology or final 3D art. The small companion is a visual placeholder only. See `docs/technical/expedition-and-ship-systems.md` for the implemented phase/ship/tool contracts and remaining work.

## Creature Direction

Creatures belong to ecosystems. Observation and appropriate habitats unlock coexistence. They can illuminate, reveal materials, interfere with infrastructure or open paths, rather than functioning solely as equipable bonuses.

## Acceptance

- All three floors can be visited and left without teleporting.
- Closed hatch blocks the shaft; open hatch allows descent and return.
- Mining checks range and first physical obstruction, not only visual proximity.
- Hardness changes hit count; protected deep rock cannot be mined with the starter tool.
- Resources are credited exactly once per removed cell.
- Save/load preserves cell changes, resources, ladders and hatch state without touching legacy progress.
- Grid math includes explicit negative-coordinate and JSON roundtrip tests.

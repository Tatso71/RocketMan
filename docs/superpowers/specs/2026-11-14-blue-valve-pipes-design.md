# Blue Valves and Background Pipes

The user requested direct implementation after describing this replacement for
the sealed-drilling system. Mixtures and chemical reactions are deferred.

## Experience

- T offers a blue valve, pump, greenhouse and water container. Old drilling,
  orientation and explicit outlet/intake devices are removed.
- A blue valve occupies an existing rock cell with water in an orthogonally
  adjacent cell. No component cost, research unlock, tool or orientation is
  required. Placement leaves rock and water intact. Its four faces accept pipes.
  New valves are enabled immediately; the closed-circuit check prevents any flow
  until a compatible receiver exists. Manual closing is optional.
- Water pipes are free, noncolliding background infrastructure. They coexist
  with ladders and actors, but cannot occupy rock. Neighboring cells connect
  automatically, including elbows and junctions.
- P selects the water-pipe mouse tool, also available from T. Click or drag to
  place continuous connected pieces; Shift+click/drag removes water pipes only.
  Right click or Escape exits. Automatic joins create elbows and junctions.
  This supersedes the earlier same-day actor-cell shortcut; see
  `2026-11-14-mouse-pipe-placement-design.md` for the approved input revision.
- A dangling pipe cannot spill water. Fluid is transferred only to compatible
  finite-capacity endpoints. Removing a pipe stops transfer, never destroys or
  duplicates stored water.
- Pumps occupy one cell on a pipe endpoint or straight run, never a corner or
  junction. Existing construction costs and laboratory power still apply.
  Right-click controls on/off and direction. Their internal buffer is 8 units;
  active delivery has a 6 m lift and 0.7 units/s limit. Passive flow is limited
  to 0.35 units/s and cannot flow above its source head.
- Two permanent blue ports on the ship's lateral boosters connect to separate
  40-unit water tanks, retained through travel and save/load.
- Water containers are normal constructible modules with 32-unit capacity.
  Greenhouses retain seeds/crops and receive up to 4 units of irrigation water;
  visible rain and plant growth require actual water consumption. Water is the
  only transported liquid in this implementation; mixing is explicitly future.

## Implementation Choices

Replace the old WaterCircuit implementation, retaining the utility grid and
building/production systems. Valve rock cells and ship ports are virtual nodes
beside the empty-cell pipe network. Pumps split the graph at their own cell.
No per-pipe rigid bodies, collision shapes or unconstrained world outlets.
New hydraulic saves use a new version; incompatible saves are rejected atomically
without deleting files. Ordinary water-tank icons join the shared item registry.

## Verification

Cover valve placement from all directions, no unlock/material charge, free pipe
placement and ladder overlap, automatic corners, pump corners and direction,
closed-end safety, finite conservation, uphill lift limits, greenhouse water
consumption, ship persistence, malformed save rejection, UI controls and 720p /
1080p rendering. Retain the nearby-exposed-face mining regression.

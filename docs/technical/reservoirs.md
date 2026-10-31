# Reservoir Prototype

Branch: `feature/falde`. One cell is 1 m / 40 prototype pixels.

## Geometry

`scripts/data/hazard_layout.gd` defines bounded cavities independently of their contents. Rectangular legacy pockets use origin/size; new irregular basins add ASCII row masks, with `#` denoting an interior cell. `cells()` returns the real interior, while `boundary()` returns its unique orthogonally adjacent rock cells. There are no diagonal leaks.

New Ocra uses layout version 2: two unchanged shallow tutorial pockets plus four larger deep reservoirs and an acid basin. Every reservoir is connected, disjoint from other interiors, outside indestructible geology and initially sealed by rock. The tutorial's central first 8 m are not excavated or replaced. Other planets retain their existing pockets.

The dig site removes cavity cells before creating terrain colliders. Fluids are therefore contents of air space, never blocks needing a mining tool. Breaking any boundary cell opens the basin, but whether fluid escapes depends on the opening: a hole above a liquid's surface does not empty it upward.

## Simulation

`environment_field.gd` advances in 0.2 s steps. Each liquid cell holds a finite fraction of one cell-volume; acid, water and oil share that capacity. Gravity transfers downward first, then neighboring cells equalize laterally. Per-step rates live in `fluid_catalog.gd`:

| Fluid | Downward Limit | Lateral Limit | Contact |
| --- | --- | --- | --- |
| Water | 1.0 | 0.2 | Wet/slowed; head immersion damages suit at 12/s |
| Acid | 0.7 | 0.12 | Wet/slowed; corrosion at 28/s |
| Oil | 0.15 | 0.04 | Wet/slowed; contamination at 4/s |

Rendering and exposure share stacked liquid rectangles in a partially occupied cell, with acid below water below oil. The solver is a grid prototype, not a full pressure/compressibility or multi-fluid displacement simulation. It does not model chemical neutralization, oil extraction, ignition or explosive gas.

Gas diffuses between connected air faces with an upward transport bias; solid rock and full liquid cells block entry. Released gas slowly dissipates. Unopened gas basins retain their original concentration even if another reservoir is leaking. Water, oil and acid do not disappear naturally or refill from their original basin.

## Presentation And Safety

`reservoir_view.gd` draws contiguous contents without internal grid lines. Only external edges receive a contour. Shared edge lighting avoids cell seams; free liquid surfaces ripple, acid bubbles and gas wisps animate. Existing depth darkness and real light sources still control visibility; this does not reveal the complete underground map.

Targeted scanner analysis reports the substance beyond a boundary wall. Opening a basin reports the appropriate Robbie event. Acid has separate editable `acid_leak` and `acid_danger` messages in the existing text lab catalog. Robbie avoids acid like other liquids, waits and flashes red when the explorer is exposed. Jetpack thrust is already disabled by liquid contact.

Ordinary water pumps remove only water, never acid/oil. Fans and gas converters retain their finite gas-only behavior. Acid prevents normal structures being installed or operating in its contaminated cells; no new extractor or protective equipment is granted by this change.

## Persistence And Tests

New worlds use terrain layout 2 and environmental save version 3. Layouts 0/1 preserve their original cavity geometry. Environmental versions 1/2 remain readable; no new acid is injected into an existing old outpost. Decoding validates positions, individual volumes, total original capacity and combined liquid occupancy before mutating live state. A saved leak resumes with its remaining contents, not a new full basin.

Unit coverage: `tests/unit/test_reservoirs.gd`, plus legacy environment/geology suites. Playable-world coverage: `tests/integration/reservoirs_smoke.gd`; append `-- --capture` with the native renderer for 720p/1080p screenshots and cross-cell continuity checks. Test galleries and extra inspection lighting are fixture-only; they are never added to production landings.

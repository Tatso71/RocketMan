# Character Geometry

One cell is 1 m / 40 px. Feet remain the player node's origin.

| Controlled Actor | Width | Height | Collision |
| --- | --- | --- | --- |
| Human | 0.6 m / 24 px | 1.6 m / 64 px | Capsule |
| Robbie | 0.5 m / 20 px | 0.8 m / 32 px | Capsule |

`rocket_explorer.gd` owns `body_size()`, `body_center()` and `body_rect_at(feet)`. `rocket_home.player_center()` exposes the selected actor's actual center to tools and services. Do not reintroduce a fixed human 32 px center or 64 px bounds into shared interaction code.

Mining rays, scanner pulses/identification distance, personal light, bomb/installation reach, service recharging and hatch overlap use those dimensions. Environment exposure defaults to the human height for pure-model callers, while the live world supplies the selected body height. A robot under a one-cell water level can be submerged while a standing human's head remains above it.

Save validation uses model body bounds against restored terrain. A safe one-cell robot tunnel must not silently relocate the player to the ship on load. Human geometry, movement speeds and jetpack rules remain unchanged. The robot drawing and beam muzzle share a compact render transform; the actor node itself stays unscaled.

## Companion Ship Exit

The companion has its own 8 px collision radius and 10 px clearance sweep. Its navigation graph previously treated the collar as the only usable below-ship air column, disconnecting real open-air paths to separate surface shafts. Negative-row navigation nodes now require a real terrain-layer circle-overlap check within finite world bounds. Swept graph edges and physical movement still reject hull walls, floors and closed hatches.

No arrival excavation or under-ship digging rule is introduced. Left/right shafts in tests are test-only terrain edits. Controlled Robbie's hidden cargo surrogate follows the same actual body center, without a second visible/collidable companion.

## Verification

- `test_actor_geometry.gd`: variant dimensions, centers and bounds.
- `robbie_body_smoke.gd`: real horizontal movement through a one-cell corridor, human rejection, tight-tunnel saves, mining, scanner origins, height-sensitive water exposure and PC screenshots.
- `drone_ship_exit_smoke.gd`: cockpit/workshop starts, left/right entrances, closed/open hatch, Y unloading/return, intact rocket soil and no teleporting.
- Existing protagonist, first-laboratory onboarding, hatch, equipment, scanner and guide tests remain applicable.

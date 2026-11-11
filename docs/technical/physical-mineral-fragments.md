# Physical Mineral Fragments

Useful minerals always spawn a fragment; common soil and stone still yield nothing. `ExpeditionGear.drops` retains stable source-cell IDs and material types for persistence. A matching `ore_fragment.gd` CharacterBody2D supplies gravity, a 4 px collision radius, restitution 0.38 and horizontal impact damping. The terrain stays on collision layer 1; actors use layer 2 so the companion and fragments do not collide with the explorer.

New valuable drops yielding two or three pieces emit a world-space `mining_yield_popup.gd` x2/x3 badge at the source cell. It rises 28 px and fades over 1.1 seconds, with a dark font outline. Shared `spawn_ore` covers mining and blasts; its outstanding-drop guard prevents duplicate feedback. Badges are cosmetic, not saved, and cleared on restore without replay. Single yields and common terrain have no badge.

The magnet belongs to Robbie, not the human's inventory-access radius. It works during follow/manual control, with cargo space and a clear terrain ray, regardless of distance or depth from the ship. Base radius is 2 m, plus 0.35 m per drone module upgrade. Fragments accelerate towards Robbie and are credited once on arrival. Full cargo and delivery missions leave fragments on the floor. Companion navigation includes all explored safe cells; installation power-link reach is a separate constraint.

Companion navigation approaches reachable nearby ore before returning to its ordinary following formation. Graph routes may temporarily pass the explorer in narrow shafts; resting goals still preserve personal space. Terrain and liquid exclusions remain physical/path constraints, not visual shortcuts or teleportation.

Saves retain each fragment's exact position and velocity. Older entries containing only source cell/material initialize at their source. Validation permits the bounded above-ground ship/surface area as well as excavated underground cells, because a magnet may pull fragments through the open hatch.

Regression: `tests/integration/magnetic_fragments_smoke.gd` covers falling, actual bounce, full cargo, position roundtrip, above-ground save compatibility, magnetic pickup independent of human proximity, no duplication, obstruction by rock, and a narrow shaft with blind bends. Real Ocra onboarding tests wait for physical collection instead of assuming immediate inventory credit.

Terrain art: [atlas metadata and generation prompt](../../assets/terrain/README.md). Sprite UVs do not alter cell geometry or fluid boundaries.

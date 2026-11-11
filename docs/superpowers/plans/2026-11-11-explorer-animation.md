# Explorer Animation Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Animate walking, mining, jumping/jetpack launch, landing and both ladder directions.

**Architecture:** A deterministic presentation-only pose model observes the existing physics. The procedural explorer renderer articulates limbs from that pose; mining explicitly triggers recoil and shares its muzzle with the beam renderer.

**Tech Stack:** Godot 4.6, GDScript, CanvasItem drawing, GdUnit4.

**Spec:** The user's animation request in this chat; retain the current character artwork and movement rules.

## Constraints
- Preserve collider dimensions, movement speeds, ladder logic, battery and mining rules.
- Keep the Robbie playable variant working.
- No commit, push, merge or restart of the user's open game is requested.

## Review Focus
- Spawn/teleport must not look like an impact.
- Menus must not continue locomotion or input-driven firing.
- Ladder idle must hold its pose and descending must reverse the climbing cycle.
- Tool changes must clear firing visuals; repeated mining pulses must retrigger recoil.
- The beam origin must follow the animated weapon, including left-facing poses.

## Task 1: Pose Model
- [x] Add failing unit tests in `tests/unit/test_explorer_animation.gd` for states, ladder direction, landing recovery, recoil and reset.
- [x] Implement `scripts/player/explorer_animation.gd`: `advance(delta, velocity, grounded, climbing, jetting)`, `fire()`, `reset()`, `pose()`.
- [x] Run the focused suite and verify it passes.

## Task 2: Articulated Character
- [x] Integrate the model after existing movement in `rocket_explorer.gd`, without changing physics.
- [x] Draw human limbs, launch tuck, airborne legs, landing compression and a two-handed aiming/recoil pose. Preserve the robot variant.
- [x] Hook actual mining pulses, tool changes and teleport resets in `rocket_home.gd`; share `beam_origin()` with beam drawing.

## Task 3: Verification
- [x] Add a native integration test with real input and deterministic pose captures.
- [x] Inspect screenshots at PC resolutions, compare pose pixels and verify the unchanged collider.
- [x] Run all unit tests and relevant hatch, equipment and jetpack regressions.
- [x] Review the focused diff and update README with implemented behavior.

## Execution Notes
- Presentation-only launch anticipation: thrust begins immediately as before; the visible legs tuck at takeoff without adding input delay.
- RED: missing model failed the focused suite; GREEN: all six new tests pass. Full suite: 194 tests, 33 suites, no failures or orphans.
- Native input/capture smoke verifies walking, both ladder directions/idle, jump, landing, launch, flight, mining, tool switching, unchanged collision and screenshots at 1280x720 / 1920x1080.
- Review reproduced two edge cases (menu during a shot, teleport during a shot) as failing integration assertions; fixes cancel stale firing and redraw the actor without advancing paused locomotion.
- Hatch, ground-jetpack, equipment and excavation-readability regressions pass. Independent scoped review found no remaining concrete defects after fixes.

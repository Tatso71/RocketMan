# Robbie Compact Body And Ship Exit

**Goal:** Controlled Robbie fits a one-cell corridor; companion Robbie can leave the ship toward a separate surface dig. Human geometry remains 0.6 x 1.6 m. Do not implement the deferred no-dig-under-ship rule.

**Architecture:** Give the controlled variant a 0.5 x 0.8 m capsule and compact procedural visual transform. Centralize body size/center/bounds so mining, scanning, lights, environment exposure, placement and save validation use the actual body. Independently reproduce companion navigation from the workshop through open air to a lateral shaft, then fix only its navigation model.

## Tasks
- [x] RED unit/native tests for dimensions, real single-cell movement, tight-tunnel saves and height-sensitive liquid exposure.
- [x] Implement metric variant body helpers and consistent controlled Robbie drawing/beam origin; preserve human physics.
- [x] Update interaction/environment/save consumers and standalone scanner test doubles.
- [x] Reproduce/fix companion ship exit without pre-excavation, noclip or teleportation.
- [x] Run unit, hatch/equipment/protagonist/onboarding and native screenshot regressions; review focused changes.

## Constraints
- Existing dirty work and the open user game (PID observed 54048) remain untouched.
- No commit/push or new branch requested. No old-level compatibility required.
- Physics movement constants and cargo recipes remain unchanged; only the controlled robot's body geometry shrinks.

## Evidence
- RED: five body integration failures reproduced the human-sized robot collider, blocked one-cell traversal, rejected tunnel save and wrong head-water exposure. Pure actor geometry test failed for the missing shared geometry API. Additional ceiling-save regression failed at (-400 px feet) before replacing the human-specific minimum with actor-height clearance.
- GREEN: actual one-cell movement, compact tunnel/ceiling save validation, compact-center mining/scanner pulses and height-sensitive water pass; human remains 24 x 64 px, robot is 20 x 32 px. Native 720p/1080p screenshots inspected.
- Ship exit root: navigation excluded real free air around the collar/hull. Physics already allowed the route. Collision-overlap aerial nodes and existing swept edges now connect separate left/right surface shafts from workshop/cockpit. Closed hatches/hull walls remain blocking; Y unload/return is physical, with intact ground under the rocket. New headless/native tests pass all four cases without teleportation.
- Full unit suite: 206 tests / 36 suites, no errors, failures or orphans. Protagonist, both first-laboratory onboarding variants, hatch, equipment, scanner and native inventory/guide regressions pass. The protagonist test now compares actual 1-3 piece ore yields instead of assuming one.
- Independent read-only geometry/ship-exit review and ceiling-fix follow-up found no important defects. Diff whitespace check passes. Navigation CPU probe is 1.871 ms/call (120 manual samples, rendering excluded), not an FPS claim.
- No commit/push or restart of the user's open game. The no-dig-under-ship rule remains deferred.

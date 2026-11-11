# Mining Usability And Performance Plan

> **For agentic workers:** Use superpowers:subagent-driven-development for independent scanner, drone, terrain and ore tasks; parent integrates and verifies.

**Goal:** Make first-lab exploration readable, productive and responsive, fixing the user's six playtest observations.

**Architecture:** Preserve metric physics and component economy. Revise presentation at scanner/actor boundaries, guarantee starter ore in authored Ocra geology, add finite physical multi-piece yields and measure rendering/navigation cost before optimization.

**Tech Stack:** Godot 4.6.3, GDScript, procedural CanvasItem, GdUnit4 and native integration captures.

**Spec:** Latest playtest in this chat: natural falling pose; reliable Robbie following; accessible starter crystals; 65/25/10 percent one/two/three pieces; centered scanner icons and hover names with level/range limits; investigate slow game.

## Boundaries
- The previous animation-only commit `6d74901` is already published on `codex/scavo-libero`. These new changes remain local until separately authorized.
- Preserve all other uncommitted work, free common-rock digging, 15 m upgradeable Robbie signal, safe fluid avoidance and finite component costs.
- No old-level compatibility is required. Do not close the user's open game during tests.
- Scanner detection radius stays 4/5/6/7 m; identification radius 2.5/4/5.5/7 m, cobalt identified at level III+. Distant detections stay gray and anonymous; no floating labels.

## Tasks
- [x] Reproduce roots of poor following and slow frame times; record measured evidence.
- [x] Replace scanner readout labels with cell-centered icons, neutral distant markers and hover identity; update scanner tests/captures.
- [x] Fix route reliability without teleporting, removing signal limits or following into dangerous liquids.
- [x] Add physical ore yield of 1/2/3 with exact 65/25/10 roll buckets, capacity-safe pickup and save conservation.
- [x] Guarantee several Pulse-mineable crystals on the early left-hand digging route and update Robbie's guidance.
- [x] Replace the stiff free-fall pose with relaxed arms and bent/staggered legs, keeping climbing and physics unchanged.
- [x] Optimize measured renderer hotspots; verify continuous appearance, light movement and collider invariants.
- [x] Integrate all work, refresh docs/generated production map as needed, run full unit/native tests and inspect PC screenshots.

## Verification
- Probability boundary tests over all 100 buckets, plus partial pickup/full cargo/JSON roundtrip.
- Reachable starter resources within initial signal/scanner distances, untouched arrival terrain and unchanged recipes.
- Narrow shafts, bends, out-of-signal return and unloading missions.
- Near identified vs distant anonymous scanner markers, higher-level recognition, mode exit and no permanent resource leaks.
- Warmed CPU draw timings and actual native frame times, never fixed-fps values presented as performance measurements.

## Execution Notes
- Falling is the former arms-raised pose. Change presentation only.
- Early crystals added at (-5,2), (-5,3), (-4,4), while preserving eight initial iron blocks and three copper blocks. The old right-hand crystals remain.
- Robbie root causes reproduced: invisible resting points across corners/floors and stale navigation when the last liquid obstacle disappears. Connectivity components avoid repeated AStar searches during goal selection. Signal status includes range; guide prioritizes this warning even during the tutorial.
- Scanner-native pixel tests cover both PC resolutions and zoom 0.6/1/1.6. Legacy terrain decorations were removed to avoid a second identity channel. HUD hover now overrides temporary notifications; unknown detections stay anonymous.
- Exact ore buckets, independent bouncing bodies, one-slot partial pickup, primary promotion, leftover/save conservation and atomic invalid restore pass. Both first-laboratory onboarding variants pass, along with free digging, magnetic fragments and equipment.
- CPU probe (120 warmed manual calls; rendering excluded): world/HUD 0.336 ms, inventory UI 0.417 ms, tutorial UI 0.047 ms, environment 0.395 ms, outpost 0.023 ms, gear without ore 0.013 ms, original navigation 1.369 ms. Native renderer measurement is a separate task; these are not FPS claims.
- Paired native benchmark: terrain CPU 204.80 -> 22.88 ms at 720p surface, 440.73 -> 47.25 ms at 720p overview; frame 369.27 -> 29.83 ms / 805.86 -> 54.16 ms. 1080p also measured. Four views retain exact baseline pixels. Details and limitations are in `docs/technical/terrain-performance.md`; no 60 FPS guarantee.
- Independent review reproduced two P2 edge cases: stale hover names after hover/mode exit and separated extra ore omitted from seeking. Added failing integration assertions, then explicit scanner-readout lifetime and all-piece seeking. Both now pass; review closed without remaining important defects, including terrain caches.
- Final full unit run: 205/205, 35 suites, no errors/failures/orphans. Parent native scanner, animation and terrain-performance checks pass; 720p/1080p screenshots inspected. Native terrain verification covers original pixels, live lights, excavation/refill, reseeding, sealed/released reservoirs and unchanged colliders. Catalog validation, icon `--check` and production-map `--check` pass.
- Only the earlier animation-only commit is published. This playtest iteration is intentionally uncommitted, with all pre-existing local work preserved and the user's game left open.

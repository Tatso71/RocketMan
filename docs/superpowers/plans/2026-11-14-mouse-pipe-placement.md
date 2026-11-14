# Mouse Pipe Placement Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline; preserve all
> existing dirty work. No commit, push, merge or game restart requested.

**Goal:** P selects pipes; mouse paints/removes continuous free pipe strokes.
**Architecture:** Extend IndustryUI input and preview; prioritize the active water
tool in the world input dispatcher. No changes to fluid simulation or economy.
**Tech Stack:** Godot 4.6.3 / GDScript.
**Spec:** docs/superpowers/specs/2026-11-14-mouse-pipe-placement-design.md

- [x] Add failing real-scene input tests for P selection/no placement, mouse click,
  sparse/faster horizontal and diagonal dragging, Shift removal preserving ladders,
  blocked strokes, release/focus/control cleanup and cancellation over repair UI.
- [x] Implement cursor tool and orthogonal interpolation; retain reach/rock/pump
  validation and idempotence. Update old keyboard-specific UI smoke assertions.
- [x] Update preview/tooltips and current README/Robbie text/spec instructions.
- [x] Run focused headless/native input and 720p/1080p visual tests, full unit suite,
  map/icon checks and diff check; obtain a bounded fresh review and record evidence.

Review focus: button release without a final motion, modifier changes, blocked
cells in a long stroke, no mining or other popup click-through, stale drag anchors
after leaving a mode, and large pointer jumps must not hang the frame.

## Evidence

- Initial real-scene test: 12 expected failures before implementation; all pass
  after the mouse-tool change. Sparse horizontal/diagonal strokes, release-only
  final segments, obstacle stops/detours, free removal preserving ladders, blocked
  controls and right-click cancellation over bombs are covered.
- Fresh review found Shift-release could recreate an erased endpoint and rejected
  initial presses could restart beyond rock. Both reproduced RED and fixed;
  reviewer recheck has no further findings.
- `reports/mouse-pipe-final-units.log`: 279/279 tests, 49 suites, no failures,
  errors or orphans. Path tests cover 169 signed direction/length combinations,
  cardinal connectivity and bounded extreme inputs.
- `reports/mouse-pipe-final-native.log`: zero failures, including pixel-verified
  blue placement and amber removal previews at 1280x720 and 1920x1080.
- `reports/mouse-pipe-hydraulics-native.log`: zero failures for the existing
  valve/pump/tank/greenhouse controls and pipe/ladder pixel ordering.
- Official production-map/item-icon checks and `git diff --check` pass. No new
  save format, commit, push, merge, or restart of the user's running game.

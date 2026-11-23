# Greenhouse Cables And Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development. Track steps below.

**Goal:** Connect remote greenhouses to ship/lab electricity and expose real fluid movement.
**Architecture:** Reuse the existing cell utility graph and real shared battery.
Add nonpersistent per-edge hydraulic flow measurements; renderer consumes them.
**Tech Stack:** Godot 4.6, GDScript, gdUnit4, native integration/pixel tests.
**Spec:** `docs/superpowers/specs/2026-11-22-greenhouse-cables-flow-design.md`

## Constraints
- Keep existing costs, finite water, construction FIFO, solar energy accounting.
- Ship roots (-6,-2), (5,-2); greenhouse/lab bottom-left port cells.
- Existing local-lab convenience retained; manual cables have no electrical reach cap.
- Do not touch other running Godot projects or restart the user's game.

## Review Focus
- Cut cable, disabled/damaged sources, empty batteries, alternate sources.
- Shared debit of multiple growing greenhouses, including full/empty solar battery.
- Aboveground cable save validation without allowing gas through solid rock.
- Actual flow only on used routes, no ghost flow after stop/cut/load.
- Background visibility and readable geometry at 720p/1080p without revealing terrain.

### Runtime Power (Main Agent)
Files: outpost controller, industry state, utility network; new cabled-greenhouse smoke.
- [x] RED tests for ship/lab links, reach, energy, disconnection, persistence.
- [x] Implement source resolution and debit; permit aboveground energy cells.
- [x] Expose roots and retain known automatic cable visibility in penumbra.

### Hydraulic Flow (Independent Worker)
Files: water_circuit.gd and dedicated tests.
- [x] RED signed edge-flow tests, actual transfers, branch/cut/blocked receiver.
- [x] Implement `flow_between(first, second) -> float` (signed u/s, current tick).
- [x] Verify conservation and no persistence of ephemeral flow data.

### UI And Renderer (Independent Worker)
Files: industry_ui.gd and dedicated UI/native tests.
- [x] RED cable mouse stroke / dark visibility tests.
- [x] Generalize contiguous strokes to cables; draw thicker water and real flow.
- [x] Draw ship/lab red sockets, show greenhouse source, readable low-light utilities.
- [x] Native 720p/1080p screenshots/pixel checks.

### Integration
- [x] Update README and production-map generator/editorial notes; regenerate/check.
- [x] Full unit suite, cable/industry/solar/water/UI regression smoke tests.
- [x] Fresh review and fixes; report no publishing or restart.

## Verification Ledger
- RED: missing greenhouse source API, aboveground cable restore and new map rules.
  GREEN: real ship/lab cable growth, cuts, empty/full battery, solar recovery,
  multiple crops and real JSON world roundtrip.
- 306 unit tests pass. Industry, solar, remote pump and native lamp relay smoke
  pass. Native cable-input tests prove paid continuous strokes and selective
  erasure. Native 720p/1080p tests measure 10/6px pipe casing/bore, signed movement,
  static zero-flow branches, dim visibility and red sockets; full-world captures
  show actual ship water, pump and two irrigated cabled greenhouses.
- Review found inactive ship source shown instead of a charged converter. Added
  failing combined-source UI test; resolve powered source before unavailable
  connections. GREEN confirms label and real energy debit match.
- Regenerated production map and icons; icon regeneration only normalizes line
  endings of existing solar SVG/catalog after checkout, with no semantic change.
- Costs unchanged: water free, cable one electronic per cell. No publishing,
  restart, new save format or unrelated gameplay changes.
- November 23 layering correction: explicit z1 absolute manual-utility plane
  below z2 installation artwork. Hydraulic overlays and physical cubes keep
  their original absolute z8/z7 planes; player, Robbie and ladders stay in front.
  RED native regression: 18 layer/pixel failures. GREEN: all nine runtime modules
  cover crossing utility pixels at 720p/1080p. Hydraulic UI, utility renderer
  and the 306-unit suite pass after the correction.

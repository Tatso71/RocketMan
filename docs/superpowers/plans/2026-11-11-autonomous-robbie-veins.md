# Autonomous Robbie And Pure Veins Implementation Plan

> **For agentic workers:** Use executing-plans for the integrated logistics workflow; the independent geology task may be delegated with a disjoint write set. No commit, push or merge without a new user request.

**Goal:** The human keeps digging while companion Robbie collects ore, physically unloads at the ship, automatically converts ingredients, delivers components and constructs queued projects; pure finite ore veins reward difficult manual excavation.

**Architecture:** Existing physical navigation remains authoritative. A per-worker logistics controller owns task selection and transient target identity; actual cargo, ship stock, paid fabrication jobs and building progress retain their existing single owners. Work is reconstructed from saved stock/plans and resumes without duplicate payment. A deterministic pure-vein map supplies hardness and yield independently of excavation state.

**Tech Stack:** Godot 4.6.3, GDScript, existing AStar2D/navigation, existing fabrication and component recipes.

**Spec:** `docs/design/robbie-logistica-futura.md` and the user approval in this chat.

## Constraints And Rulings
- Automatic companion workflow only for the human variant; controlled Robbie remains manual, explicitly chosen by the user.
- No automatic mining or new extractors. Soil/common rock still generate no cargo.
- Existing placement geometry, support, unlocks, power and hazards remain binding. Player proximity is needed for placing a project, not for a distant worker to fund/build it.
- Pure vein initial balance: irregular masks, 10 mining strength and 12 ore units per pure block; common dispersed deposits retain existing 1/2/3 yields.
- At most three visible fragment bodies per mined cell, carrying integer bundles; no material loss when cargo fills.
- Automatic ship production uses existing paid timed component jobs. Keep a small useful component buffer and prioritize queued structure demand; never create free ingredients or overfill holds.
- Per-worker state/targets rather than a singleton task embedded in the player; robot manufacture and multiple workers remain future work.
- Save validation is strict. Resuming may recompute routes/tasks from real stock, but must preserve in-transit cargo, paid production and paid construction.

## Tasks
- [x] Geology RED/GREEN: pure irregular finite veins, increased hardness, fixed rich yield, no cavities/protected-cell overlap; APIs `pure_vein(cell) -> Dictionary`, `mining_cost(cell) -> int`, `ore_yield_amount(cell) -> int` remain usable after mining for payout.
- [x] Fragment RED/GREEN: max-three weighted physical fragments, exact partial pickup, bounded validated save/restore, x12 badge for pure ore.
- [x] Logistics RED/GREEN: automatic collection/unload/ship conversion/delivery/build, reusable existing navigation, materials/energy paid once, cancellation/blocked route/source repair, no player proximity dependency at a worker-operated site.
- [x] UX: pending projects show worker/material/power state; tutorial no longer orders manual conversion/transfers; both 720p/1080p layouts checked.
- [x] End-to-end: physical raw-cargo-to-lab run, then fragment pickup through powered light construction while the player stays away; JSON round trips cover weighted fragments, paid conversion and paid construction; full unit suite, focused native regressions and fresh review.
- [x] Update README, design status and production-map generator/data; no recipe/icon additions for future multiple Robbie.

## Verification Evidence
- Full GdUnit run: 242 tests in 45 suites, no failures/errors/orphans (`reports/autonomous-unit-final.log`).
- Native integration: autonomous workflow, logistics safety, weighted fragments, arrival recovery and construction test start all pass (`reports/auto-final-*.log`).
- Native UI: automatic and controlled-Robbie variants pass at 720p/1080p; manual assembly popup also passes with captures (`reports/autonomous-ui-final.log`, `reports/assembly-popup-final.log`).
- Focused regressions: component production/assembly, relay lights, protagonist/body and multiple fragments pass. These are focused checks, not a claim that every historical integration script was run.
- Pure-vein native checks confirm ten-hit mining and twelve-unit payout, with exposed-face captures (`reports/pure-veins-visual.log`).
- Independent review findings reproduced and fixed: waypoint snapping/refresh, unusable project starvation, full-depot parking, unreachable reunion work starvation and repaired paid-site resumption.
- Production map check, item icon check, design validation and `git diff --check` pass. Existing hold capacities and power constraints remain intentional; additional Robbie manufacture is future work.

## Review Focus
- Cargo-full pickup leaves residual ore; interrupted/cancelled deliveries retain components exactly once.
- Closed hatch, hazardous flooded route and removed project never trigger teleportation or consumption at a distance.
- Damaged ship workshop and empty battery pause processing/building without losing paid work.
- Load/revisit retains shared cargo and paid work; transient task reconstruction cannot duplicate ownership.
- Prototype first-lab tutorial remains achievable without raw starter stock or advanced tools.

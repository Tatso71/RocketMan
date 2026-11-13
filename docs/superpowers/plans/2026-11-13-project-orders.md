# Complete Project Orders Implementation Plan

**Goal:** A placed project requests its own missing components; companion Robbie serves projects in placement order.
**Spec:** `docs/superpowers/specs/2026-11-13-project-orders-design.md`.
**Architecture:** Reuse the existing paid FIFO fabrication jobs. Add worker-at-ship ordering to the same validated transaction as manual orders; compute deficits against actual stocks and paid outputs. Preserve structure array order as the persistent project FIFO.

- [x] RED: `project_orders_fifo_smoke.gd` covers automatic missing-only orders, repeated dispatch, JSON persistence, remote player, strict blocked-head FIFO, completed lab/light sequence and cancellation.
- [x] GREEN: station-aware `component_blocker`/`fabricate_components` share payment validation for player and physically present worker; logistics requests only head-project deficits, never speculative buffers, and never skips an unfinished head.
- [x] Update existing autonomous workflow/safety expectations and tutorial/computer guidance; controlled Robbie and manual production remain supported.
- [x] Update README and production-map generator/metadata; regenerate/check docs and icons.
- [x] Run full units and focused native project/production/UI regressions; fresh focused review and RED/GREEN fixes if needed.

Constraints: no teleportation, no double reservations, no inventory creation, paid queues/structure order persist. Already-paid production is retained if its project is cancelled; output remains real reusable stock. User subsequently authorized commit, push and merge to main after successful verification; no game restart requested.

## Evidence
- New FIFO/project-order smoke observed eight failures before implementation; after correcting a test fixture built above a natural water cavity, all queue/order/JSON/physical construction checks pass.
- Full unit suite 244/244 across 45 suites; headless project FIFO, autonomous first-lab/light workflow, transport safety, explicit computer orders and safe-source regressions pass.
- A later affordable project is deliberately no longer used as a fallback when the first is blocked. This supersedes the earlier starvation-avoidance policy; cancellation advances the FIFO.
- Independent review found optional manual assembly bypassed FIFO. Two failing checks reproduced funding/progress/power bypass; fixed with FIFO guards in funding, assembly progress and consumption. Full suite then 244/244; authored voice assertion was updated to the new project-order wording.
- Native FIFO/project order, component production/assembly, workstation, computer UI, human/controlled-Robbie guidance, assembly popup and protagonist tests pass. Headless transport/source/capacity and save regressions pass; map/icon checks and design validation pass. Coverage is focused integration plus all unit suites, not every historical integration script.

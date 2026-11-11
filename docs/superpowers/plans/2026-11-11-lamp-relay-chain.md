# Lamp Relay Chain

**Goal:** Allow laboratory -> lamp -> lamp power chains, with bounded individual links, one real source laboratory, no self-powered cycles and existing red orthogonal automatic cables.

**Architecture:** A small pure lamp-network resolver builds a rooted multi-source breadth-first graph. Outpost supplies eligible labs/relays and caches by scalar topology plus dictionary identity, sharing eligibility snapshots within synchronous update/draw passes. Lamp construction, activation, illumination, consumption reports and cable parents share the same route. Other devices keep their existing direct lab rules.

**Constraints:** Lamp-to-lamp links are at most 8 m (chosen to match level-I lab reach). Initial lab links retain 8 m + 2 m per lab level. Only active, enabled, healthy, dry lamps relay real power; unpaid/building lamps never relay. Sources retain ship power/range rules. No extra cable cost, new resources, physical routing, save migration, commit/push or automatic game restart.

## Tasks
- [x] RED unit tests: chain beyond original lab radius, nearest direct lab, shortest-hop relay parent, branches, cycles with no root and bounded gaps.
- [x] Implement the pure resolver and shared cached route in Outpost; preserve other device behavior.
- [x] Verify actual paid chained assembly, progress pause/resume, lighting, source ownership, battery loss, broken/disabled intermediates, alternate route and save/restore.
- [x] Verify parent-to-child red orthogonal cables and actionable out-of-network popup reason at 720p/1080p.
- [x] Full unit suite, focused existing power/popup regressions, review and README update.
- [x] Address review performance finding with per-pass snapshots; verify 200 structures and immediate invalidation outside each pass.

## Verification
- Full GdUnit suite: 233 tests, 44 suites, zero failures/errors/orphans (`reports/lamp-relay-unit-final.log`).
- Native relay-chain, local-lamp, utility-cube and assembly-popup regressions: zero failures (`reports/lamp-relay-final-*.log`); chain screenshots checked at 720p and 1080p.
- Batch regression: RED 40,000/40,000/79,800 safety checks for load/lighting/reports; GREEN 400 each. Nested update/draw scopes release snapshots; same-frame source changes remain visible.
- Battery exhaustion regression exposed a floating-point residue; simulation now clamps the fully spent budget to exactly zero and refreshes lights with no powered sources.
- Read-only review after optimization: no actionable correctness findings. Operation counts are not an FPS benchmark. Native multi-lab handover and fluid-driven relay loss are not separately covered; pure multi-root routing and runtime disabled/damaged relay loss are covered.
- `git diff --check`: clean. No commit, push, merge or game restart performed for this change.

# Mining Feedback And Continuous Veins Plan

**Spec:** `docs/superpowers/specs/2026-11-14-mining-feedback-veins-design.md`.
**Approach:** Native execution for mining feedback and tests; independent renderer sidecar, then integrated verification and fresh review. Use existing Godot drawing/atlas helpers, no new inventory or mining rules.

- [x] RED/GREEN: actual failed mining clicks display tool-specific visible feedback, do not spend energy; verify real bomb exclusions.
- [x] Feedback polish: clear stale messages on tool/home/load transitions, native720/1080 captures and clamped bounds.
- [x] Renderer RED/GREEN: cache deterministic world-space mineral decorations, adjacent-cell continuity, exposed/illuminated gating, no hidden-ore reveal; remove flat pure-cell overlay.
- [x] Inspect native screenshots and pixel checks for all five mineral surfaces at720/1080, verify cache cost bounds.
- [x] Update README/technical notes, run full units and focused mining/scanner/fragment/native regressions; fresh review and fixes.

Sidecar write ownership: renderer/helper and new renderer-specific tests only.
Main ownership: `rocket_home.gd`, `mining_feedback.gd`, `mining_refusal_smoke.gd`, docs and other regressions. Preserve current recipes/yields. No Git integration actions authorized for this task.

## Evidence
- Dedicated-feedback test observed RED before implementation. Native GREEN covers actual refused cobalt/bedrock/anchor clicks, tool names, no resource changes, viewport bounds, panel avoidance, expiry/tool-switch cleanup and actual explosions.
- Tooltip initial wrapped-height/overlap defects reproduced by native checks and fixed before the visual sidecar integration. Captures: `reports/mining-refusal-720.png`, `reports/mining-refusal-1080.png`.
- Initial full unit run before vein renderer changes: 244/244, 45 suites (`reports/mining-feedback-units.log`).
- Final full suite: 252/252, 46 suites, no failures/errors/orphans (`reports/mining-vein-complete-units.log`). Focused scanner/icon/pulse/weighted-fragment regressions pass.
- Native art smoke exits 0 for all five minerals, two raster sizes, buried/dark/hidden/excavated masks and real gameplay captures (`reports/vein-art-final-output.log`). Copper/crystal closeups and gameplay captures inspected.
- Overlay lighting reuses cached host-rock corner samples and bilinear weights; ordinary non-vein cells make no additional lighting requests (RED/GREEN unit coverage). Warmed ore-only CPU draw median measured around 1.2-1.7 ms in the isolated copper fixture, one extra submission; not GPU/FPS or developed-outpost guarantees.
- Fresh independent review found a left-edge refusal hidden beneath the tutorial. Reproduced RED and fixed with fallback positions beside reserved panels, minimizing overlap then distance. Native refusal smoke GREEN includes that exact case.
- Recipe/map contents unchanged; official regeneration corrected only checkout line endings and map/icon checks pass. No gameplay economy changes, Git publication or user-game restart.

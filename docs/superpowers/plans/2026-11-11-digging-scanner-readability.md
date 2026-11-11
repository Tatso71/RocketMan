# Digging And Scanner Readability

**Goal:** Four requested changes: cosmetic excavation irregularity without player collision changes; mining beam only in mining mode; no natural gas pockets for now; clear material identity during scanner reveals.

**Architecture:** Terrain edge ornaments remain rendering-only, bounded to 2-5 pixels outside a solid cell, deterministic and rendered after base cells. Tool switching clears stale beam state; scanner clicks are inert and automatic waves remain. Gas generation is temporarily disabled by a central default-off toggle; isolated physics/industry QA may explicitly enable it. Scanner labels group revealed veins, use material names/colors/icons and stay temporary.

## Tasks

- [x] RED tests for cosmetic edge bounds, scanner click effects and stale beam clearing, default gas-free worlds, scanner identity/group labels.
- [x] Main: terrain silhouettes and mode-correct tool activation/drawing; keep logical collider rectangles unchanged and bomb placement/jetpack flight working.
- [x] Scanner worker: only `scripts/ui/scanner_pulse_view.gd` plus new `tests/unit/test_scan_identity.gd`; improve reveals without spoilers or overlapping text. Names for anchor/bedrock explain unbreakability/tool requirement.
- [x] Gas worker: only `scripts/data/hazard_layout.gd`, new gas-generation test and narrow existing gas-specific test opt-ins. Natural worlds contain neither gas nor gas pocket cavities; physics code retained for future use. No free energy workaround or unrelated balance change.
- [x] Main: integration/native 720p/1080p checks, HUD/tool/physics smoke tests, documentation/map update and bounded review.

## Constraints

Preserve all dirty prior work and current branch. No commit/push requested. No old-level/save compatibility required. Do not stop the user's running game; native QA uses its own short-lived process. Gas-dependent industry remains paused in ordinary play while natural gas generation is disabled; keep this limitation explicit.

User's excavation wording is interpreted as cosmetic irregularities that do NOT collide with the player, consistent with the metric grid design. Only exposed borders are decorated; do not reveal ore or sealed pockets outside scanner mode. Scanner remains passive, not a point-and-shoot tool.

## Verification

- RED/GREEN: absent edge-profile helper, scanner firing/energy consumption and stale beams, ordinary gas generation, identity/layout helpers, duplicate label selection, and historical HUD identity leak.
- Final units: 188 tests / 32 suites, no errors, failures, skips or orphans (`reports/digging-verified-unit.log`).
- Native combined smoke: 720p/1080p screenshots, material labels, all tool modes, unchanged metre colliders and rock-coloured pixels beyond their bounds (`reports/digging-verified-native.log`). Visually inspected; at most5 callouts prioritise distinct materials and avoid the explorer/HUD.
- Equipment, ground jetpack, hatch, passive pulses, geology/history, expedition, Ocra world and isolated hazard/reservoir smoke tests pass. Native water-circuit smoke still passes. Gas-engine QA explicitly opts in; ordinary generation remains off.
- Water smoke geometry requires a real display: headless font/window bounds produced four layout failures; native rerun passed all four. No production layout was changed for that harness limitation.
- Map/icon generators `--check` and whitespace check pass. Review found the old status HUD exposed historical ore names after scanning; active-reveal gating fixed it, recheck clean.
- Documentation explains gas-dependent local industry is paused without natural fuel. No automatic free energy added. No commits/push/merge and no closure/restart of the user's existing game.

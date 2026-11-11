# Local Lamp Power And Assembly Feedback

**Goal:** Lamps assemble and run from a nearby operational field laboratory even beyond the ship's direct radius; project popups show the current blocker; funded lamps display an automatic cable to their supplying laboratory.

**Scope:** Keep laboratory-to-ship power requirements, lamp recipe/radius, other devices and manual industrial cable networks unchanged. The automatic lamp lead is included in lamp assembly, not a new inventory item or a paid T-menu conduit. No new power sources, teleport, save migration, commit/push or game restart.

## Tasks
- [x] Reproduce a supported lamp outside direct ship reach but within a powered laboratory's 8 m radius. Verify funding, unfolding, illumination, consumption, exhaustion and restoration.
- [x] Make the same local connection predicate drive lamp funding, construction progress and active power.
- [x] Display live funding blockers directly under the project cost, including missing components, reach, unsafe floor and unavailable laboratory.
- [x] Draw automatic lamp cables to the actual supplying lab, including unpowered fallback appearance and no cables for unpaid plans. Hide cable segments behind rock and outside illumination; keep leads cosmetic/non-colliding.
- [x] Show the automatic ship-to-laboratory cable as well, completing the visible ship -> laboratory -> lamp chain.
- [x] Run full unit suite and native popup/power regressions, inspect 720p/1080p screenshots, update README.

## Decisions
- The actual nearest operational laboratory owns the lamp and its consumption. If all nearby labs lose power, the cable may show the nearest active lab in muted colors; no operational source means no light.
- Keep direct ship reach for pumps/fans and all other existing devices; this request changes lamps only.

## Verification
- RED: the new deep-lamp integration reproduced sufficient ingredients but blocked funding, no construction/light/consumption, and missing automatic connections.
- Full GdUnit suite: 226 tests / 42 suites, zero failures/errors/orphans.
- Native `local_lamp_power_smoke.gd`, `assembly_popup_smoke.gd` and `utility_cubes_smoke.gd` passed, including paid assembly, live reason with green materials, no cable surcharge, battery loss, save roundtrip, multiple-lab power accounting and unchanged free ladders. Inspected 720p/1080p captures.
- Independent bounded read-only review found no important regressions.
- Additional `component_onboarding_smoke.gd` run failed before any laboratory exists: the starter crystal remained uncollected by companion Robbie (`reports/local-lamp-onboarding.log`). A clean repeat passed both variants and the first-laboratory path (`reports/local-lamp-onboarding-recheck.log`). This remains an intermittent collection/test issue; no mining/navigation/tutorial production changes were made in this task. Track separately rather than weakening collection requirements or changing unrelated behavior.

## Selective Publication
- The requested lamp/popup commit was exported from the index and verified independently of unrelated local work: 164 unit tests, assembly-popup integration and deep-lamp/cable/JSON integration passed.
- Dependencies include the popup's item-icon catalog/assets and removal of ship-distance gating from local cargo assistance/physical clearance. Broader companion navigation, terrain, fluids, animation, HUD vitals and scanner experiments remain outside this commit.

# Water And Discovery Feedback

**Goal:** Show physical blue, bubbly water cavities before breach, outline scanner-identified cells, show brief x2/x3 ore-yield feedback, and add material icons to Robbie's speech.

**Architecture:** Reuse finite reservoir cells/lighting and existing fluid simulation. Stop camouflaging water only; other sealed hazards keep their current visibility rules. Scanner markers gain a recognition-gated outline. Ore feedback is a transient world-space effect emitted only when new valuable drops spawn. Speech uses catalog icons while preserving editable plain-text dialogue.

**Constraints:** Keep square metre physics and arbitrary reservoir masks. No new stock, changed yield odds, free construction, permanent scanner traces, gas generation, commits, pushes or game restart. Preserve unrelated local work.

## Tasks
- [x] Add failing tests and render water cavities/bubbles without changing the fluid simulation.
- [x] Add failing tests and draw cell outlines only for recognized scanner contents, fading with markers.
- [x] Add failing tests and transient x2/x3 feedback for new drops (including blasts, not restored saves).
- [x] Add tested inline material icons to Robbie's dialogue, including replay and edited text.
- [x] Add tested hard-landing energy loss and temporary red flashes, without penalizing normal jumps or controlled jetpack landings.
- [x] Reverse assembly counters to available / required (Hai / Servono), preserving colors, pending plans and payment rules.
- [x] Run full unit suite and relevant integration tests; inspect native 720p/1080p screenshots; update README.

## Decisions
- Water is physically visible inside the existing illumination radius, even outside scanner mode. The scanner still reaches farther into darkness; visual visibility never releases the pocket.
- Keep x2/x3 anchored at the broken block, rising briefly with a readable dark outline. No x1, no permanent save data, and no multiplier on common rock.
- Retain unknown gray scanner icons without a content-colored outline.
- Additional user request: hard falls consume personal energy (not ship power). Use impact speed rather than total airborne height, allowing jetpack braking; normal jumps remain below the safe threshold.
- Additional user request supersedes the earlier popup plan's count ordering: owned first, needed second.
- Native rendering exposed missing existing anchor/bedrock icons. Add dedicated icons through the established generator and a regression test, avoiding null texture draw calls.

## Verification
- Observed RED before implementing water visibility, bubble geometry, recognized borders, missing hard-formation icons, multiplier popup, fall penalty, owned-first counters and material speech.
- Full GdUnit suite: 224 tests across 41 suites, no failures/errors/orphans (`reports/water-feedback-unit-all.log`).
- Native water feedback, scanner icons (720p/1080p, zoom 0.6/1/1.6), assembly popup, geological scanning and material speech integrations passed without engine errors. Inspected normal-water, bubble detail, multiplier, speech and counter screenshots.
- Actual fall/collision integration passed for both controlled actors, including safe small drops, hard impacts, immediate red tint, no repeated ground damage, flash expiry and safe low-speed final approach. Existing one-cell Robbie body regression passed.
- Multi-fragment mining/blasts/persistence, real first-laboratory onboarding and reservoir simulation smoke tests passed.
- Water circuits passed natively, including valve/pump/terminal controls at 720p/1080p. The headless run's four window-layout assertions failed because its native Window bounds do not match real rendering; all fluid/circuit behavior checks passed there too. No plumbing production change was made to accommodate headless window geometry.
- Item-icon generator check and `git diff --check` passed. A fresh independent read-only review found no important bugs. Residual gaps: input-driven jetpack braking and exceptionally long custom speech were not separately stress-tested.
- No commit/push or restart; the user's existing game remains untouched by these edits.

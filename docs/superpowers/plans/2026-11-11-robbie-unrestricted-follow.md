# Robbie Unrestricted Follow

**Goal:** Remove ship-distance travel/collection restrictions from the companion, without removing safe paths, physical movement, local magnet reach or infrastructure energy limits.

**Architecture:** The graph includes all explored safe cells of the finite planet. Following and ore pickup depend only on local reach/path and mission state. The former ship signal parameter remains only as an explicitly named infrastructure power-link range, preserving existing installation behavior and upgrades.

**Constraints:** Preserve the dirty branch, all prior changes and the user's open game. No commit/push/merge requested. No old-level compatibility work.

## Tasks
- [x] RED: following beyond 15 m sideways/deep/diagonal, collecting/assisting there and saving a distant drone.
- [x] Remove companion range checks from graph, sweeps, targets, pickup, assistance and save restore.
- [x] Replace obsolete signal UI/help with path-obstruction guidance; separate power-link naming for installations.
- [x] Update affected regressions, production-map metadata/docs and verify unit/native tests.

## Checks
- Y unloading and return work from deep locations without teleporting.
- Solid rock, closed hatches and hazardous liquids remain impassable.
- Local assistance 3 m and magnet 2 m (+0.35 m/level) remain; cargo upgrades still work.

## Evidence
- RED: six failures reproduced the old horizontal/deep/diagonal follow, local assistance and distant return limits.
- GREEN: headless and native reliability tests pass without teleporting. The base drone follows past 15 m, collects a physical ore fragment there, survives save/restore, reaches 22 m depth and a deep diagonal tunnel, unloads with Y and returns physically.
- Liquid avoidance/recovery, hatch behavior, outpost placement/power services, local assistance, multi-piece ore and Ocra-world regressions pass. Installation reach retains its existing numerical behavior under explicit power-link naming.
- Full unit suite: 205 tests, 35 suites, no failures/errors/orphans. Production-map check and diff whitespace check pass. Independent read-only review found no issues.
- Changes remain local; the user's open game was not restarted.

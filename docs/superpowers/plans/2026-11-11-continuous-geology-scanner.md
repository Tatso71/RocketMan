# Continuous Geology And Scanner

Approved direction: continuous hybrid painted/procedural rock, no preventive ore symbols, temporary scanner revelation with persistent discoveries. Continue codex/scavo-libero; do not commit, push or merge without a new request.

1. RED tests: world-space texture coordinates are continuous across metric cell boundaries and do not reset per cell; scanner wave reveals only reached ore/anomalies, expires/clears on switching tools, preserves knowledge and terrain.
2. Terrain: reuse the generated atlas as layered world-space materials. Engine FastNoiseLite supplies stable warping/blend fields; geometry remains 40 px/m. Keep neighbor-aware inward rim decoration. Hide ore-specific glyphs and colors, including legacy renderer. Mask sealed pocket cavities with the host rock and hide unreleased fluid rendering; revealed scanner overlays are independent of lighting.
3. Scanner: bounded transient reveals updated as the actual wavefront crosses cells, radius from tool level, fade duration increasing by level. Persistent scanned coordinates retain discoveries; restore clears transient state and reconstructs known hazard readings. Existing precise point analysis remains.
4. Integration: update obsolete visual-only pulse test expectations, add native captures and pixel checks at 720p/1080p (no ore overlay outside scanner, no repetition at one-cell displacement, unchanged removed cells/physics). Add a small scanned-discovery list to the scanner overlay rather than a full new journal subsystem. Document behavior and limitations.
5. Verify: focused RED/GREEN suites, all units, relevant integration suites (scanner, terrain, hazards, reservoirs, tutorial and save), fresh independent review, then fix Important findings with regressions. Leave current running user game alone; changes apply next launch.

Implementation choice: use world-coordinate UVs and per-vertex layer blending directly in the existing terrain drawing helper, rather than attaching a shader to the entire world node (which also draws the ship, ladders and beam). This preserves draw ordering and native lighting. It is the same hybrid material approach without a new scene-rendering architecture.

Safety: undiscovered sealed pockets stay physically unchanged; camouflage is presentation only. No new passive audio assets in this tranche: existing Robbie danger warnings remain; environmental audio cues are a later polish step.

## Execution Status

Completed locally: all five tasks, 158 passing unit tests, 28 passing integration entrypoints on post-review code, native 720p/1080p and pixel comparisons, one independent review and three RED/GREEN corrections. No commit, push or merge. Environmental audio and an explicit inactive-outpost malformed-history integration case remain deferred; the shared validator already checks all outposts.

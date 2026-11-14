# Terrain Performance

Measured on 11 November 2026 with Godot 4.6.3, OpenGL Compatibility, GTX 1070. The previous continuous renderer rebuilt four textured triangles per cell per atlas layer on every frame. The optimized renderer caches metric geometry/UV/noise, shares vertices and submits four cross-cell atlas batches. Edge decoration and live lighting remain.

## Paired Native Benchmark

Same process, uncapped, VSync disabled, simulation frozen, 20 warm-up and 60 measured frames for each variant/view. These are CPU draw and wall-clock frame measurements, not fixed-fps deltas or GPU-only timings.

| View | Terrain CPU Before / After (ms) | Frame Before / After (ms) |
| --- | --- | --- |
| 1280 x 720 surface | 204.80 / 22.88 | 369.27 / 29.83 |
| 1280 x 720 overview | 440.73 / 47.25 | 805.86 / 54.16 |
| 1920 x 1080 surface | 329.19 / 32.65 | 604.23 / 38.57 |
| 1920 x 1080 overview | 397.77 / 49.45 | 743.45 / 56.91 |

The 720p surface case reduced total rendered draw calls from 8076 to 336. All four reference images matched exactly. Native checks also cover moving player/structure lights, excavation/refill, seed changes, pocket breaches and unchanged metric colliders. Unlit textured triangles are retained for fidelity rather than aggressively culled.

## Reproduce

```powershell
godot --rendering-method gl_compatibility --path . -s res://tests/integration/terrain_performance_smoke.gd -- --compare
godot --headless --path . -s res://tests/integration/gameplay_cpu_profile.gd
```

The first command writes ignored JSON measurements and screenshots in `reports/terrain-perf-*`. Do not add `--fixed-fps` to the performance command. The second samples warmed manual calls with rendering excluded; it is a component CPU probe, not gameplay FPS.

The current reference shares the visible-water rule: sealed water is visible, while oil retains camouflage until breached. Exact image comparison runs only with `--compare`, against the reference captured in that same run; unrelated older screenshots in `reports/` are not test baselines. Both water visibility and oil-mask invalidation are checked independently.

## Limits

The 14 November vein-art update adds deterministic deposit-wide ribbons and
inclusions, clipped once into metric cells and cached separately from the host
rock atlas. Only exposed, lit, retained pure-ore cells enter the visible batch;
dynamic vertex lighting is applied in one additional colored-triangle submission.
There is no per-frame polygon clipping and no new collider or emissive material.
The timings above predate this decoration; see the focused vein-surface smoke
measurements under ignored `reports/` for its incremental CPU cost.

This is a substantial improvement, not a 60 FPS guarantee. Native frame times still exceed the 16.7 ms target in these frozen views; active-gameplay, cold cache rebuild spikes, other GPUs/backends and larger developed outposts require further profiling. Other running applications may affect wall-clock measurements. The benchmark does not close an already open user game.

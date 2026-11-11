# Rock Atlas V1

Generated with the built-in GPT image generator, 2026-11-10. Source image is preserved in Codex generated_images; this project copy is the runtime asset.

Prompt: production 2D side-view mining-game terrain atlas, exact 4 by 4 grid, square fully filled orthographic rock faces, four variants per row: reddish ochre clay, neutral gray slate, dark blue-gray basalt, dark green-gray ancient stone. Friendly richly painted angular chipped facets, fissures and strata, readable at 40 pixels. No isometric perspective, text, props, characters or mineral crystals. Seam-compatible colors at edges; chipped details inside square cell silhouettes.

The renderer derives tile dimensions from the actual image. It samples inside each tile to avoid atlas bleeding, applies per-vertex exploration lighting, and overlays gameplay ore glyphs. Exposed rim decoration is visual only; collision and targeting stay exactly 40 pixels per metre.

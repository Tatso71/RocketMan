# RocketMan

Godot 4 project for a 2D exploratory platformer about an underground base, alien animal expeditions, and rebuilding a rocket before planetary collapse.

## Current slice

- Base hub prototype
- One exterior biome
- Inventory and crafting foundations
- First rocket objective

## Run

`/Applications/Godot.app/Contents/MacOS/Godot --path .`

## Test

`bash addons/gdUnit4/runtest.sh --godot_binary '/Applications/Godot.app/Contents/MacOS/Godot' -a res://tests/unit/`

## Large Assets

- Files under `assets/` and `source_assets/` with common image/source-art extensions are tracked with Git LFS.
- This repository is configured with `skip-smudge`, so heavy assets are not downloaded automatically on checkout.
- Download tracked assets only when needed with:

`git lfs pull --include="assets/**,source_assets/**"`

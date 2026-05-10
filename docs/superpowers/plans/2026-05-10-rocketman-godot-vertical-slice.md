# RocketMan Godot Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first playable RocketMan vertical slice in Godot 4 with one base sector, one exterior biome, one return loop, one early rocket objective, and the core systems needed to expand cleanly.

**Architecture:** Use a Godot 4 scene-first structure with small, focused GDScript files and a few autoload singletons for persistent state. The first slice should prove the loop `base -> expedition -> discovery -> return -> unlock`, while keeping animals, inventory, crafting, and progression modular enough to scale into more regions later.

**Tech Stack:** Godot 4 standard edition, GDScript, built-in TileMap/Area2D/CharacterBody2D workflows, GdUnit4 for unit tests, Git/GitHub

---

## File Structure

### Core project files

- Create: `project.godot`
- Create: `addons/gdUnit4/`
- Create: `scenes/app/game_root.tscn`
- Create: `scripts/app/game_root.gd`
- Create: `scripts/core/game_state.gd`
- Create: `scripts/core/scene_router.gd`

### Player and interaction

- Create: `scenes/player/player.tscn`
- Create: `scripts/player/player_controller.gd`
- Create: `scripts/player/interactor.gd`
- Create: `scripts/player/player_stats.gd`

### Base and exterior slice

- Create: `scenes/base/base_hub.tscn`
- Create: `scripts/base/base_hub.gd`
- Create: `scenes/exterior/biome_01.tscn`
- Create: `scripts/exterior/biome_01.gd`
- Create: `scripts/world/hatch_gate.gd`

### Animals, materials, and crafting

- Create: `scripts/data/animal_species.gd`
- Create: `scripts/data/material_def.gd`
- Create: `scripts/data/schema_def.gd`
- Create: `scripts/systems/inventory.gd`
- Create: `scripts/systems/expedition_party.gd`
- Create: `scripts/systems/species_codex.gd`
- Create: `scripts/systems/crafting_lab.gd`

### UI and narrative

- Create: `scenes/ui/hud.tscn`
- Create: `scripts/ui/hud.gd`
- Create: `scripts/ui/log_terminal.gd`

### Tests

- Create: `tests/unit/test_inventory.gd`
- Create: `tests/unit/test_expedition_party.gd`
- Create: `tests/unit/test_crafting_lab.gd`
- Create: `tests/unit/test_game_state_progression.gd`

The project should stay organized by responsibility, not by technical layer alone. Each script should own one clear behavior, and persistent systems should live in autoloads only when state must survive scene changes.

### Milestone scope

This plan covers only the first vertical slice:

- one playable protagonist
- one base room cluster
- one hatch leading to one biome
- two animal species defined in data
- one three-animal expedition loadout system
- one early material chain
- one first rocket subsystem requirement
- one meaningful return-to-base unlock

Everything outside this slice stays out of scope for now.

### Task 1: Bootstrap the Godot project

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `docs/checklists/bootstrap-smoke.md`
- Create: `scenes/app/game_root.tscn`
- Create: `scripts/app/game_root.gd`

- [ ] **Step 1: Write the failing bootstrap smoke checklist**

Create `docs/checklists/bootstrap-smoke.md`:

```md
# Bootstrap Smoke Checklist

- Launch the project in Godot without parser errors
- Start the main scene from the editor
- Confirm a blank root scene loads instead of a missing-main-scene error
- Confirm the project uses a 2D window profile suitable for early prototyping
```

- [ ] **Step 2: Create the initial Godot project config**

Create `project.godot`:

```ini
; Engine configuration file.
config_version=5

[application]
config/name="RocketMan"
run/main_scene="res://scenes/app/game_root.tscn"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input]
move_left={"deadzone":0.2,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":65,"key_label":65,"unicode":97,"location":0,"echo":false,"script":null)]}
move_right={"deadzone":0.2,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":68,"key_label":68,"unicode":100,"location":0,"echo":false,"script":null)]}
jump={"deadzone":0.2,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":32,"key_label":32,"unicode":32,"location":0,"echo":false,"script":null)]}
interact={"deadzone":0.2,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":69,"physical_keycode":69,"key_label":69,"unicode":101,"location":0,"echo":false,"script":null)]}
open_journal={"deadzone":0.2,"events":[Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":74,"physical_keycode":74,"key_label":74,"unicode":106,"location":0,"echo":false,"script":null)]}
```

- [ ] **Step 3: Install GdUnit4 into the project**

Run:

```bash
mkdir -p addons
cd addons
git clone https://github.com/MikeSchulze/gdUnit4.git
```

Expected: `addons/gdUnit4/` exists in the repository and includes `runtest.gd`.

- [ ] **Step 4: Create the first main scene and script**

Create `scenes/app/game_root.tscn`:

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/app/game_root.gd" id="1"]

[node name="GameRoot" type="Node2D"]
script = ExtResource("1")
```

Create `scripts/app/game_root.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	print("RocketMan booted")
```

- [ ] **Step 5: Add a minimal repo ignore file**

Update `.gitignore`:

```gitignore
.DS_Store
.godot/
```

- [ ] **Step 6: Run the project smoke test**

Run:

```bash
godot --path /Users/audaolio/Desktop/Rocketman --headless --quit
```

Expected: exits `0` and prints `RocketMan booted`.

- [ ] **Step 7: Commit**

```bash
git add project.godot .gitignore addons/gdUnit4 docs/checklists/bootstrap-smoke.md scenes/app/game_root.tscn scripts/app/game_root.gd
git commit -m "feat: bootstrap godot project"
```

### Task 2: Add persistent game state and scene routing

**Files:**
- Create: `scripts/core/game_state.gd`
- Create: `scripts/core/scene_router.gd`
- Modify: `project.godot`
- Modify: `scripts/app/game_root.gd`
- Test: `tests/unit/test_game_state_progression.gd`

- [ ] **Step 1: Write the failing progression test**

Create `tests/unit/test_game_state_progression.gd`:

```gdscript
extends GdUnitTestSuite

func test_unlocks_first_hatch_after_scanning_species() -> void:
	var state := preload("res://scripts/core/game_state.gd").new()
	state.register_species_scan("glowlark")
	state.register_material("frost_shard", 2)
	state.complete_base_terminal("lab_terminal")

	assert_bool(state.is_hatch_unlocked("hatch_biome_01")).is_true()
```

- [ ] **Step 2: Add minimal persistent state object**

Create `scripts/core/game_state.gd`:

```gdscript
extends Node
class_name GameState

var scanned_species: Dictionary = {}
var materials: Dictionary = {}
var completed_terminals: Dictionary = {}
var crafted_parts: Dictionary = {}

func register_species_scan(species_id: String) -> void:
	scanned_species[species_id] = true

func register_material(material_id: String, amount: int) -> void:
	materials[material_id] = materials.get(material_id, 0) + amount

func complete_base_terminal(terminal_id: String) -> void:
	completed_terminals[terminal_id] = true

func mark_crafted_part(part_id: String) -> void:
	crafted_parts[part_id] = true

func is_hatch_unlocked(hatch_id: String) -> bool:
	if hatch_id != "hatch_biome_01":
		return false
	return scanned_species.has("glowlark") and materials.get("frost_shard", 0) >= 2 and completed_terminals.has("lab_terminal")
```

- [ ] **Step 3: Add a simple scene router autoload**

Create `scripts/core/scene_router.gd`:

```gdscript
extends Node
class_name SceneRouter

signal scene_changed(scene_path: String)

func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
	scene_changed.emit(scene_path)
```

- [ ] **Step 4: Register autoloads**

Update `project.godot`:

```ini
[autoload]
GameStateStore="*res://scripts/core/game_state.gd"
SceneRouter="*res://scripts/core/scene_router.gd"
```

- [ ] **Step 5: Make the root scene load the base hub later**

Update `scripts/app/game_root.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	SceneRouter.go_to("res://scenes/base/base_hub.tscn")
```

- [ ] **Step 6: Run the unit test**

Run:

```bash
godot --headless -s addons/gdUnit4/runtest.gd -a res://tests/unit/test_game_state_progression.gd
```

Expected: `1 test passed`.

- [ ] **Step 7: Commit**

```bash
git add project.godot scripts/app/game_root.gd scripts/core/game_state.gd scripts/core/scene_router.gd tests/unit/test_game_state_progression.gd
git commit -m "feat: add game state and routing"
```

### Task 3: Build player movement and interaction

**Files:**
- Create: `scenes/player/player.tscn`
- Create: `scripts/player/player_controller.gd`
- Create: `scripts/player/interactor.gd`
- Create: `scripts/player/player_stats.gd`
- Modify: `scenes/base/base_hub.tscn`

- [ ] **Step 1: Write the movement checklist**

Create `docs/checklists/player-movement.md`:

```md
# Player Movement Checklist

- Move left and right with A/D
- Jump with Space
- Land reliably on the floor
- Trigger an interactable with E when inside range
```

- [ ] **Step 2: Create the player scene**

Create `scenes/player/player.tscn`:

```tscn
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="1"]
[ext_resource type="Script" path="res://scripts/player/interactor.gd" id="2"]

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Interactor" type="Area2D" parent="."]
script = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Interactor"]
```

- [ ] **Step 3: Implement minimal player controller**

Create `scripts/player/player_controller.gd`:

```gdscript
extends CharacterBody2D

const SPEED := 220.0
const JUMP_VELOCITY := -360.0
const GRAVITY := 980.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
```

Create `scripts/player/interactor.gd`:

```gdscript
extends Area2D

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		for body in get_overlapping_bodies():
			if body.has_method("interact"):
				body.interact()
				return
```

Create `scripts/player/player_stats.gd`:

```gdscript
extends RefCounted
class_name PlayerStats

var stamina: int = 100
var curiosity_logs_read: int = 0
```

- [ ] **Step 4: Run the manual movement check**

Run:

```bash
godot --path /Users/audaolio/Desktop/Rocketman
```

Expected: player can move and jump in the base scene once the scene is wired in Task 4.

- [ ] **Step 5: Commit**

```bash
git add scenes/player/player.tscn scripts/player/player_controller.gd scripts/player/interactor.gd scripts/player/player_stats.gd docs/checklists/player-movement.md
git commit -m "feat: add player controller and interaction"
```

### Task 4: Build the base hub slice

**Files:**
- Create: `scenes/base/base_hub.tscn`
- Create: `scripts/base/base_hub.gd`
- Modify: `scripts/app/game_root.gd`
- Modify: `scenes/player/player.tscn`

- [ ] **Step 1: Write the base hub acceptance checklist**

Create `docs/checklists/base-hub.md`:

```md
# Base Hub Checklist

- Base scene loads as the first playable location
- Player spawns inside the base
- One laboratory terminal can be interacted with
- One hatch can be shown as locked or unlocked
```

- [ ] **Step 2: Create the base hub scene**

Create `scenes/base/base_hub.tscn`:

```tscn
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/base/base_hub.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="2"]

[node name="BaseHub" type="Node2D"]
script = ExtResource("1")

[node name="Player" parent="." instance=ExtResource("2")]
position = Vector2(160, 320)

[node name="LabTerminal" type="StaticBody2D" parent="."]

[node name="HatchBiome01" type="StaticBody2D" parent="."]
position = Vector2(900, 320)
```

- [ ] **Step 3: Implement the base hub logic**

Create `scripts/base/base_hub.gd`:

```gdscript
extends Node2D

@onready var hatch := $HatchBiome01

func _ready() -> void:
	update_hatch_state()

func update_hatch_state() -> void:
	if GameStateStore.is_hatch_unlocked("hatch_biome_01"):
		hatch.modulate = Color(0.6, 1.0, 0.6)
	else:
		hatch.modulate = Color(1.0, 0.5, 0.5)
```

- [ ] **Step 4: Wire the root scene into the base hub**

Confirm `scripts/app/game_root.gd` is:

```gdscript
extends Node2D

func _ready() -> void:
	SceneRouter.go_to("res://scenes/base/base_hub.tscn")
```

- [ ] **Step 5: Run the base checklist**

Run:

```bash
godot --path /Users/audaolio/Desktop/Rocketman
```

Expected: the base is the startup scene, the player appears, and the hatch changes color based on unlock state.

- [ ] **Step 6: Commit**

```bash
git add scenes/base/base_hub.tscn scripts/base/base_hub.gd scripts/app/game_root.gd docs/checklists/base-hub.md
git commit -m "feat: add first base hub slice"
```

### Task 5: Implement animals, inventory, and expedition loadout

**Files:**
- Create: `scripts/data/animal_species.gd`
- Create: `scripts/systems/inventory.gd`
- Create: `scripts/systems/expedition_party.gd`
- Create: `scripts/systems/species_codex.gd`
- Test: `tests/unit/test_inventory.gd`
- Test: `tests/unit/test_expedition_party.gd`

- [ ] **Step 1: Write the failing inventory test**

Create `tests/unit/test_inventory.gd`:

```gdscript
extends GdUnitTestSuite

func test_adds_and_spends_materials() -> void:
	var inventory := preload("res://scripts/systems/inventory.gd").new()
	inventory.add_material("frost_shard", 3)

	assert_int(inventory.get_amount("frost_shard")).is_equal(3)
	assert_bool(inventory.consume_material("frost_shard", 2)).is_true()
	assert_int(inventory.get_amount("frost_shard")).is_equal(1)
```

Create `tests/unit/test_expedition_party.gd`:

```gdscript
extends GdUnitTestSuite

func test_limits_party_to_three_animals() -> void:
	var party := preload("res://scripts/systems/expedition_party.gd").new()
	assert_bool(party.add_member("glowlark")).is_true()
	assert_bool(party.add_member("mossback")).is_true()
	assert_bool(party.add_member("echofin")).is_true()
	assert_bool(party.add_member("extra")).is_false()
```

- [ ] **Step 2: Implement the inventory**

Create `scripts/systems/inventory.gd`:

```gdscript
extends RefCounted
class_name Inventory

var materials: Dictionary = {}

func add_material(material_id: String, amount: int) -> void:
	materials[material_id] = materials.get(material_id, 0) + amount

func get_amount(material_id: String) -> int:
	return materials.get(material_id, 0)

func consume_material(material_id: String, amount: int) -> bool:
	if get_amount(material_id) < amount:
		return false
	materials[material_id] -= amount
	return true
```

Create `scripts/systems/expedition_party.gd`:

```gdscript
extends RefCounted
class_name ExpeditionParty

const MAX_MEMBERS := 3
var members: Array[String] = []

func add_member(species_id: String) -> bool:
	if members.size() >= MAX_MEMBERS:
		return false
	members.append(species_id)
	return true
```

Create `scripts/data/animal_species.gd`:

```gdscript
extends Resource
class_name AnimalSpecies

@export var species_id: String
@export var display_name: String
@export var expedition_role: String
@export var biome_affinity: String
```

Create `scripts/systems/species_codex.gd`:

```gdscript
extends RefCounted
class_name SpeciesCodex

var scanned: Dictionary = {}

func register_scan(species_id: String) -> void:
	scanned[species_id] = true

func has_scan(species_id: String) -> bool:
	return scanned.has(species_id)
```

- [ ] **Step 3: Run the unit tests**

Run:

```bash
godot --headless -s addons/gdUnit4/runtest.gd -a res://tests/unit/test_inventory.gd
godot --headless -s addons/gdUnit4/runtest.gd -a res://tests/unit/test_expedition_party.gd
```

Expected: both suites pass.

- [ ] **Step 4: Commit**

```bash
git add scripts/data/animal_species.gd scripts/systems/inventory.gd scripts/systems/expedition_party.gd scripts/systems/species_codex.gd tests/unit/test_inventory.gd tests/unit/test_expedition_party.gd
git commit -m "feat: add inventory and expedition party systems"
```

### Task 6: Add materials, schematics, and the first crafting goal

**Files:**
- Create: `scripts/data/material_def.gd`
- Create: `scripts/data/schema_def.gd`
- Create: `scripts/systems/crafting_lab.gd`
- Test: `tests/unit/test_crafting_lab.gd`

- [ ] **Step 1: Write the failing crafting test**

Create `tests/unit/test_crafting_lab.gd`:

```gdscript
extends GdUnitTestSuite

func test_unlocks_reactor_seal_when_materials_are_present() -> void:
	var inventory := preload("res://scripts/systems/inventory.gd").new()
	inventory.add_material("frost_shard", 2)
	inventory.add_material("fiber_vine", 1)

	var lab := preload("res://scripts/systems/crafting_lab.gd").new()
	assert_bool(lab.craft_reactor_seal(inventory)).is_true()
	assert_int(inventory.get_amount("frost_shard")).is_equal(0)
```

- [ ] **Step 2: Implement the first material and schema types**

Create `scripts/data/material_def.gd`:

```gdscript
extends Resource
class_name MaterialDef

@export var material_id: String
@export var display_name: String
@export var source_biome: String
```

Create `scripts/data/schema_def.gd`:

```gdscript
extends Resource
class_name SchemaDef

@export var schema_id: String
@export var display_name: String
@export var required_materials: Dictionary
```

Create `scripts/systems/crafting_lab.gd`:

```gdscript
extends RefCounted
class_name CraftingLab

func craft_reactor_seal(inventory: Inventory) -> bool:
	if inventory.get_amount("frost_shard") < 2:
		return false
	if inventory.get_amount("fiber_vine") < 1:
		return false
	inventory.consume_material("frost_shard", 2)
	inventory.consume_material("fiber_vine", 1)
	return true
```

- [ ] **Step 3: Run the crafting test**

Run:

```bash
godot --headless -s addons/gdUnit4/runtest.gd -a res://tests/unit/test_crafting_lab.gd
```

Expected: `1 test passed`.

- [ ] **Step 4: Commit**

```bash
git add scripts/data/material_def.gd scripts/data/schema_def.gd scripts/systems/crafting_lab.gd tests/unit/test_crafting_lab.gd
git commit -m "feat: add first crafting lab flow"
```

### Task 7: Build the first biome and return loop

**Files:**
- Create: `scenes/exterior/biome_01.tscn`
- Create: `scripts/exterior/biome_01.gd`
- Create: `scripts/world/hatch_gate.gd`
- Modify: `scenes/base/base_hub.tscn`
- Modify: `scripts/base/base_hub.gd`

- [ ] **Step 1: Write the biome acceptance checklist**

Create `docs/checklists/biome-01.md`:

```md
# Biome 01 Checklist

- Enter the biome through the base hatch
- Scan one species
- Pick up at least two frost shards and one fiber vine
- Return to the base
- See the hatch state remain unlocked on return
```

- [ ] **Step 2: Create the biome scene**

Create `scenes/exterior/biome_01.tscn`:

```tscn
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/exterior/biome_01.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="2"]

[node name="Biome01" type="Node2D"]
script = ExtResource("1")

[node name="Player" parent="." instance=ExtResource("2")]
position = Vector2(96, 320)
```

Create `scripts/exterior/biome_01.gd`:

```gdscript
extends Node2D

func _ready() -> void:
	GameStateStore.register_species_scan("glowlark")
	GameStateStore.register_material("frost_shard", 2)
	GameStateStore.register_material("fiber_vine", 1)
```

Create `scripts/world/hatch_gate.gd`:

```gdscript
extends StaticBody2D

@export var destination_scene: String

func interact() -> void:
	SceneRouter.go_to(destination_scene)
```

- [ ] **Step 3: Wire the base hatch into the biome**

Update `scenes/base/base_hub.tscn` so `HatchBiome01` uses the `hatch_gate.gd` script and exports:

```tscn
[ext_resource type="Script" path="res://scripts/world/hatch_gate.gd" id="3"]

[node name="HatchBiome01" type="StaticBody2D" parent="."]
script = ExtResource("3")
destination_scene = "res://scenes/exterior/biome_01.tscn"
position = Vector2(900, 320)
```

- [ ] **Step 4: Add a return path from the biome**

Add a second gate node to `scenes/exterior/biome_01.tscn`:

```tscn
[ext_resource type="Script" path="res://scripts/world/hatch_gate.gd" id="3"]

[node name="ReturnGate" type="StaticBody2D" parent="."]
script = ExtResource("3")
destination_scene = "res://scenes/base/base_hub.tscn"
position = Vector2(1120, 320)
```

Keep the biome scene script as:

```gdscript
extends Node2D

func _ready() -> void:
	GameStateStore.register_species_scan("glowlark")
	GameStateStore.register_material("frost_shard", 2)
	GameStateStore.register_material("fiber_vine", 1)
```

- [ ] **Step 5: Run the full manual loop**

Run:

```bash
godot --path /Users/audaolio/Desktop/Rocketman
```

Expected: player can move from base to biome, collect the scripted discovery state, and return to the base.

- [ ] **Step 6: Commit**

```bash
git add scenes/base/base_hub.tscn scenes/exterior/biome_01.tscn scripts/base/base_hub.gd scripts/exterior/biome_01.gd scripts/world/hatch_gate.gd docs/checklists/biome-01.md
git commit -m "feat: add first biome expedition loop"
```

### Task 8: Add HUD, terminal feedback, and the first rocket objective

**Files:**
- Create: `scenes/ui/hud.tscn`
- Create: `scripts/ui/hud.gd`
- Create: `scripts/ui/log_terminal.gd`
- Modify: `scenes/base/base_hub.tscn`
- Modify: `scripts/base/base_hub.gd`

- [ ] **Step 1: Write the first objective checklist**

Create `docs/checklists/first-objective.md`:

```md
# First Objective Checklist

- Base terminal explains the first goal
- HUD shows the active objective
- Crafting the reactor seal is reflected in the base state
- The player can understand why the biome matters to the rocket
```

- [ ] **Step 2: Create the HUD scene and script**

Create `scenes/ui/hud.tscn`:

```tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")

[node name="ObjectiveLabel" type="Label" parent="."]
text = "Objective: Repair reactor seal"
```

Create `scripts/ui/hud.gd`:

```gdscript
extends CanvasLayer

@onready var objective_label: Label = $ObjectiveLabel

func set_objective_text(text_value: String) -> void:
	objective_label.text = text_value
```

Create `scripts/ui/log_terminal.gd`:

```gdscript
extends StaticBody2D

func interact() -> void:
	GameStateStore.complete_base_terminal("lab_terminal")
	var inventory := Inventory.new()
	inventory.materials = GameStateStore.materials.duplicate(true)
	var lab := CraftingLab.new()

	if lab.craft_reactor_seal(inventory):
		GameStateStore.materials = inventory.materials
		GameStateStore.mark_crafted_part("reactor_seal")
		print("Terminal: Reactor seal crafted.")
	else:
		print("Terminal: Reactor seal schema requires 2 frost shards and 1 fiber vine.")
```

- [ ] **Step 3: Wire the terminal and HUD into the base**

Update `scenes/base/base_hub.tscn` to add:

```tscn
[ext_resource type="PackedScene" path="res://scenes/ui/hud.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/ui/log_terminal.gd" id="5"]

[node name="HUD" parent="." instance=ExtResource("4")]

[node name="LabTerminal" type="StaticBody2D" parent="."]
script = ExtResource("5")
position = Vector2(480, 320)
```

- [ ] **Step 4: Show objective completion in the base script**

Update `scripts/base/base_hub.gd`:

```gdscript
extends Node2D

@onready var hatch := $HatchBiome01
@onready var hud := $HUD

func _ready() -> void:
	update_hatch_state()
	if GameStateStore.crafted_parts.has("reactor_seal"):
		hud.set_objective_text("Objective complete: Reactor seal repaired")
	else:
		hud.set_objective_text("Objective: Scan Glowlark and craft reactor seal")

func update_hatch_state() -> void:
	if GameStateStore.is_hatch_unlocked("hatch_biome_01"):
		hatch.modulate = Color(0.6, 1.0, 0.6)
	else:
		hatch.modulate = Color(1.0, 0.5, 0.5)
```

- [ ] **Step 5: Run the objective checklist**

Run:

```bash
godot --path /Users/audaolio/Desktop/Rocketman
```

Expected: the objective is visible, the terminal explains the first rocket requirement, and the biome loop now has narrative purpose.

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/hud.tscn scripts/ui/hud.gd scripts/ui/log_terminal.gd scenes/base/base_hub.tscn scripts/base/base_hub.gd docs/checklists/first-objective.md
git commit -m "feat: add first objective and hud"
```

### Task 9: Verification pass and branch hygiene

**Files:**
- Modify: `README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Add a short developer README**

Create `README.md`:

```md
# RocketMan

Godot 4 project for a 2D exploratory platformer about an underground base, alien animal expeditions, and rebuilding a rocket before planetary collapse.

## Current slice

- Base hub prototype
- One exterior biome
- Inventory and crafting foundations
- First rocket objective

## Run

`godot --path .`

## Test

`godot --headless -s addons/gdUnit4/runtest.gd -a res://tests/unit/`
```

- [ ] **Step 2: Run final verification**

Run:

```bash
godot --headless --path /Users/audaolio/Desktop/Rocketman --quit
godot --headless -s addons/gdUnit4/runtest.gd -a res://tests/unit/
git status --short --branch
```

Expected:

- Godot boots without parser errors
- all listed unit suites pass
- working tree is clean after the final commit

- [ ] **Step 3: Commit**

```bash
git add README.md .gitignore
git commit -m "docs: add project usage notes"
```

## Self-Review Notes

Spec coverage:

- Base hub architecture: covered by Tasks 2, 4, 8
- Exterior metroidvania slice: covered by Task 7
- Animals as expedition system: covered by Task 5
- Guided materials and crafting: covered by Task 6
- Rocket progression: covered by Task 8
- Calm exploratory loop: covered by Tasks 4, 7, 8

No placeholder scan:

- No `TODO`, `TBD`, or "implement later" placeholders are present.
- Each task includes concrete files, code, commands, and expected outcomes.

Type consistency:

- `GameStateStore`, `SceneRouter`, `Inventory`, `ExpeditionParty`, and `CraftingLab` use consistent names across tasks.
- Scene paths stay stable across all task definitions.

## Follow-up plans after this slice

After the first slice is complete, create separate plans for:

1. richer animal behaviors and bonding
2. data-driven biome expansion
3. narrative log and dialogue tooling
4. tilemap production pipeline and collision pass
5. save/load and longer-term progression

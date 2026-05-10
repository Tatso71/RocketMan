extends Node2D

@onready var hatch: StaticBody2D = $HatchBiome01
@onready var hud: CanvasLayer = $HUD

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

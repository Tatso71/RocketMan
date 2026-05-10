extends CanvasLayer

@onready var objective_label: Label = $ObjectiveLabel

func set_objective_text(text_value: String) -> void:
	objective_label.text = text_value

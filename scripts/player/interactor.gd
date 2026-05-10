extends Area2D

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		for body in get_overlapping_bodies():
			if body.has_method("interact"):
				body.interact()
				return

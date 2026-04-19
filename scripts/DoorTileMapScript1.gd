extends Area2D

@export var door: NodePath

func _on_body_entered(body):
	if body.has_method("take_damage") and body.has_key > 0:
		body.has_key -= 1
		$DoorSound.play()
		await $DoorSound.finished
		get_node(door).queue_free()
		queue_free()

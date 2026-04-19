extends Area2D

func _on_body_entered(body):
	print("body entered: ", body.name)
	if body.has_method("take_damage"):
		get_tree().change_scene_to_file("res://scenes/Dungeon/level_3.tscn")

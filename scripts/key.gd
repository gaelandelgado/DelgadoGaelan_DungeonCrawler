extends Area2D

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.has_key += 1
		$PickupSound.play()
		await $PickupSound.finished
		queue_free()

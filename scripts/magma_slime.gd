extends CharacterBody2D

const WALK_SPEED = 30.0
const ATTACK_RANGE = 40.0
const SUMMON_INTERVAL = 15.0
const SLIMES_PER_WAVE = 3

@onready var anim = $AnimatedSprite2D
@onready var hurt_sounds = [$HurtSound1, $HurtSound2]
@onready var footsteps = [$Footstep1, $Footstep2]
@onready var footstep_timer = $FootstepTimer
@onready var summon_timer = $SummonTimer

@export var summoned_slime_paths: Array[NodePath]

var key_scene = load("res://scenes/Dungeon/key.tscn")

var direction = Vector2.ZERO
var is_attacking = false
var is_hurt = false
var is_dead = false
var is_immune = true
var is_summoning = false
var player = null
var current_wave = 0
var active_slimes = []
var last_hurt_sound = 0
var footstep_index = 0
var max_health = 4
var health = 4
var damage = 8

func _ready():
	player = get_tree().get_first_node_in_group("player")
	scale = Vector2(2.5, 2.5)

	for path in summoned_slime_paths:
		var slime = get_node(path)
		if slime:
			slime.visible = false
			slime.process_mode = Node.PROCESS_MODE_DISABLED

	summon_timer.wait_time = SUMMON_INTERVAL
	summon_timer.start()
	summon_slimes()

func _physics_process(_delta):
	if is_immune:
		modulate = Color(1.5, 1.5, 1.5)
	else:
		modulate = Color(1.0, 1.0, 1.0)
		
	if is_dead or is_hurt or is_summoning or player == null:
		velocity = Vector2.ZERO
		footstep_timer.stop()
		move_and_slide()
		update_animation()
		return

	var alive = active_slimes.filter(func(s): return is_instance_valid(s) and s.visible and not s.is_dead)
	is_immune = alive.size() > 0

	var dist = global_position.distance_to(player.global_position)

	if dist <= ATTACK_RANGE:
		if not is_attacking:
			is_attacking = true
	else:
		direction = (player.global_position - global_position).normalized()
		velocity = direction * WALK_SPEED

	if velocity != Vector2.ZERO and not is_attacking and not is_hurt and not is_dead:
		if footstep_timer.is_stopped():
			play_footstep()
	else:
		footstep_timer.stop()

	move_and_slide()
	update_animation()

func summon_slimes():
	is_summoning = true
	is_immune = true
	velocity = Vector2.ZERO
	active_slimes = []

	var offsets = [
		Vector2(0, 0),
		Vector2(-40, 0),
		Vector2(40, 0)
	]

	var wave_start = current_wave * SLIMES_PER_WAVE

	for i in range(SLIMES_PER_WAVE):
		var index = wave_start + i
		if index >= summoned_slime_paths.size():
			break
		var slime = get_node(summoned_slime_paths[index])
		if slime:
			slime.health = slime.max_health
			slime.is_dead = false
			slime.is_hurt = false
			slime.is_attacking = false
			slime.global_position = global_position + offsets[i]
			slime.visible = true
			slime.process_mode = Node.PROCESS_MODE_INHERIT
			active_slimes.append(slime)

	await get_tree().create_timer(1.0).timeout
	is_summoning = false
	summon_timer.start()

func _on_summon_timer_timeout():
	summon_slimes()

func play_footstep():
	footsteps[footstep_index].play()
	footstep_index = (footstep_index + 1) % 2
	footstep_timer.wait_time = 0.6
	footstep_timer.start()

func _on_footstep_timer_timeout():
	if velocity != Vector2.ZERO and not is_dead and not is_hurt and not is_attacking:
		play_footstep()

func update_animation():
	if is_dead:
		if anim.animation != "death_" + get_direction_name():
			anim.play("death_" + get_direction_name())
		return
	if is_hurt:
		anim.play("hurt_" + get_direction_name())
		return
	if is_summoning:
		anim.play("idle_" + get_direction_name())
		return
	if is_attacking:
		anim.play("attack_" + get_direction_name())
		return

	if velocity == Vector2.ZERO:
		anim.play("idle_" + get_direction_name())
	else:
		anim.play("walk_" + get_direction_name())

func get_direction_name() -> String:
	if abs(direction.y) > abs(direction.x):
		return "down" if direction.y > 0 else "up"
	else:
		return "right" if direction.x > 0 else "left"

func _on_animated_sprite_2d_animation_finished():
	if is_attacking:
		is_attacking = false
	if is_hurt:
		is_hurt = false
	if is_dead:
		var key = key_scene.instantiate()
		get_tree().current_scene.add_child(key)
		key.global_position = global_position
		var music = get_tree().current_scene.get_node("AudioStreamPlayer2D")
		music.seek(360.0)
		music.set("parameters/looping", false)
		queue_free()

func _on_attack_hitbox_area_entered(area):
	if area.name == "Hurtbox":
		var parent = area.get_parent()
		if parent.has_method("take_damage"):
			parent.take_damage(damage)

func take_damage(amount):
	if is_dead or is_hurt or is_immune:
		return
	is_hurt = true
	health -= 1
	last_hurt_sound = (last_hurt_sound + 1) % 2
	hurt_sounds[last_hurt_sound].play()
	if health <= 0:
		is_dead = true
	else:
		current_wave += 1
		summon_timer.stop()
		summon_slimes()

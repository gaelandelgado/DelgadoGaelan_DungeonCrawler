extends CharacterBody2D

const WALK_SPEED = 60.0
const RUN_SPEED = 100.0
const CHASE_RANGE = 100.0
const ATTACK_RANGE = 20.0
const WANDER_RANGE = 60.0
const WANDER_TIME = 5.5

enum State {IDLE, WANDER, CHASE, ATTACK, FLEE}
var state = State.IDLE

@onready var anim = $AnimatedSprite2D
@onready var footsteps = [$Footstep1, $Footstep2]
@onready var footstep_timer = $FootstepTimer
@onready var hurt_sounds = [$HurtSound1, $HurtSound2]

@export var drops_key = false
@export var is_coward = false
@onready var key_scene = preload("res://scenes/Dungeon/key.tscn")
@export var is_level_2 = false

var direction = Vector2.ZERO
var is_attacking = false
var is_hurt = false
var is_dead = false
var player = null
var wander_target = Vector2.ZERO
var wander_timer = 0.0
var footstep_index = 0
var last_hurt_sound = 0
var max_health = 3
var health = 3
var damage = 5

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if is_coward:
		anim.modulate = Color(0.5, 0.5, 1.0)
	if is_level_2:
		max_health = 6
		health = 6
		anim.modulate = Color(1.0, 0.2, 0.2)

func _physics_process(_delta):
	if is_dead or is_hurt or is_attacking or player == null:
		velocity = Vector2.ZERO
		footstep_timer.stop()
		move_and_slide()
		update_animation()
		return

	var dist = global_position.distance_to(player.global_position)

	if dist <= ATTACK_RANGE:
		if is_coward:
			state = State.FLEE
		else:
			state = State.ATTACK
	elif dist <= CHASE_RANGE:
		if is_coward:
			state = State.FLEE
		else:
			state = State.CHASE
	else:
		wander_timer -= _delta
		if wander_timer <= 0:
			state = State.WANDER
			wander_target = global_position + Vector2(randf_range(-WANDER_RANGE, WANDER_RANGE), randf_range(-WANDER_RANGE, WANDER_RANGE))
			wander_timer = WANDER_TIME

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			direction = Vector2.ZERO
		State.WANDER:
			direction = (wander_target - global_position).normalized()
			velocity = direction * WALK_SPEED * 0.5
			if global_position.distance_to(wander_target) < 5:
				state = State.IDLE
				wander_timer = WANDER_TIME
		State.CHASE:
			direction = (player.global_position - global_position).normalized()
			velocity = direction * WALK_SPEED
		State.ATTACK:
			if not is_attacking:
				is_attacking = true
			velocity = Vector2.ZERO
		State.FLEE:
			direction = (global_position - player.global_position).normalized()
			velocity = direction * RUN_SPEED

	if velocity != Vector2.ZERO and not is_attacking and not is_hurt and not is_dead:
		if footstep_timer.is_stopped():
			play_footstep()
	else:
		footstep_timer.stop()

	move_and_slide()
	update_animation()

func play_footstep():
	footsteps[footstep_index].play()
	footstep_index = (footstep_index + 1) % 2
	footstep_timer.wait_time = 0.52 if state == State.CHASE else 0.7
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
	if is_attacking:
		anim.play("attack_" + get_direction_name())
		return

	match state:
		State.IDLE:
			anim.play("idle_" + get_direction_name())
		State.WANDER:
			anim.play("walk_" + get_direction_name())
		State.CHASE:
			anim.play("run_" + get_direction_name())
		State.ATTACK:
			anim.play("attack_" + get_direction_name())
		State.FLEE:
			anim.play("run_" + get_direction_name())

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
		if drops_key:
			var key = key_scene.instantiate()
			key.global_position = global_position
			get_parent().add_child(key)
		queue_free()

func _on_attack_hitbox_area_entered(area):
	if area.name == "Hurtbox":
		var parent = area.get_parent()
		if parent.has_method("take_damage"):
			parent.take_damage(damage)

func take_damage(amount):
	if is_dead or is_hurt:
		return
	is_hurt = true
	health -= amount
	last_hurt_sound = (last_hurt_sound + 1) % 2
	hurt_sounds[last_hurt_sound].play()
	if health <= 0:
		is_dead = true

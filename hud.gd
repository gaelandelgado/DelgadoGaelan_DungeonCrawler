extends CanvasLayer

@onready var health_bar = $HealthBar
@onready var mana_bar = $ManaBar
@onready var stamina_bar = $StaminaBar

var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	if player:
		health_bar.max_value = player.max_health
		mana_bar.max_value = player.max_mana
		stamina_bar.max_value = player.max_stamina

func _process(_delta):
	if player:
		print(player.health, " ", player.stamina)
		health_bar.value = player.health
		mana_bar.value = player.mana
		stamina_bar.value = player.stamina

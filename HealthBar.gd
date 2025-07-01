extends Control
class_name HealthBar

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel

var max_hp: int = 100
var current_hp: int = 100

func _ready():
	update_health_display()

func set_health(current: int, maximum: int):
	current_hp = current
	max_hp = maximum
	update_health_display()

func update_health_display():
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		
		# Change color based on health percentage
		var health_percentage = float(current_hp) / float(max_hp)
		if health_percentage > 0.6:
			health_bar.modulate = Color.GREEN
		elif health_percentage > 0.3:
			health_bar.modulate = Color.YELLOW
		else:
			health_bar.modulate = Color.RED
	
	if health_label:
		health_label.text = "%d/%d" % [current_hp, max_hp]

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	update_health_display()

func heal(amount: int):
	current_hp = min(max_hp, current_hp + amount)
	update_health_display()

func is_alive() -> bool:
	return current_hp > 0 
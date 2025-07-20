extends Control
class_name DamageBar

@onready var damage_bar: ProgressBar = $DamageBar
@onready var damage_label: Label = $DamageLabel

var max_damage: int = 1000  # Maximum damage for the bar scale
var current_damage: int = 0

func _ready():
	update_damage_display()

func set_damage(current: int, maximum: int = 1000):
	current_damage = current
	max_damage = maximum
	update_damage_display()

func update_damage_display():
	if damage_bar:
		damage_bar.max_value = max_damage
		damage_bar.value = current_damage
		
		# Change color based on damage percentage
		var damage_percentage = float(current_damage) / float(max_damage)
		if damage_percentage > 0.7:
			damage_bar.modulate = Color.GOLD  # High damage = gold
		elif damage_percentage > 0.4:
			damage_bar.modulate = Color.ORANGE  # Medium damage = orange
		else:
			damage_bar.modulate = Color.RED  # Low damage = red
	
	if damage_label:
		damage_label.text = "%d damage" % current_damage

func add_damage(amount: int):
	current_damage += amount
	update_damage_display()

func reset_damage():
	current_damage = 0
	update_damage_display()

func get_current_damage() -> int:
	return current_damage 
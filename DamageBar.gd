extends Control
class_name DamageBar

@onready var damage_bar: ProgressBar = $DamageBar
@onready var damage_label: Label = $DamageLabel

# Dynamic damage ranges
var damage_ranges = [
	{"min": 0, "max": 100, "color": Color.RED},
	{"min": 100, "max": 250, "color": Color.ORANGE},
	{"min": 250, "max": 500, "color": Color(1.0, 0.7, 0.0, 1.0)},  # Bright gold
	{"min": 500, "max": 1000, "color": Color(1.0, 0.8, 0.0, 1.0)},  # Brighter gold
	{"min": 1000, "max": 1500, "color": Color(1.0, 0.9, 0.0, 1.0)},  # Brightest gold
]

var current_damage: int = 0
var current_range_index: int = 0
var bonus_shots_granted: int = 0

# Signal for when bonus shots are granted
signal bonus_shot_granted(shots_granted: int, total_damage: int)

func _ready():
	update_damage_display()

func set_damage(current: int):
	current_damage = current
	check_for_range_expansion()
	update_damage_display()

func check_for_range_expansion():
	"""Check if we need to expand the damage range and grant bonus shots"""
	var previous_range_index = current_range_index
	
	# Find the appropriate range for current damage
	for i in range(damage_ranges.size()):
		var range_data = damage_ranges[i]
		if current_damage >= range_data["min"] and current_damage <= range_data["max"]:
			current_range_index = i
			break
	
	# If we've moved to a new range, grant bonus shots
	if current_range_index > previous_range_index:
		var new_bonus_shots = current_range_index - previous_range_index
		bonus_shots_granted += new_bonus_shots
		
		# Emit signal for bonus shots granted
		bonus_shot_granted.emit(new_bonus_shots, current_damage)
		
		print("🎯 DAMAGE BAR: Expanded to range ", damage_ranges[current_range_index]["min"], "-", damage_ranges[current_range_index]["max"])
		print("🎯 DAMAGE BAR: Granted ", new_bonus_shots, " bonus shots! Total bonus shots: ", bonus_shots_granted)

func update_damage_display():
	if damage_bar:
		var current_range = damage_ranges[current_range_index]
		damage_bar.min_value = current_range["min"]
		damage_bar.max_value = current_range["max"]
		damage_bar.value = current_damage
		
		# Set color based on current range
		damage_bar.modulate = current_range["color"]
	
	if damage_label:
		var current_range = damage_ranges[current_range_index]
		damage_label.text = "%d damage (%d-%d)" % [current_damage, current_range["min"], current_range["max"]]
		
		# Add bonus shots indicator if any have been granted
		if bonus_shots_granted > 0:
			damage_label.text += " +%d shots" % bonus_shots_granted

func add_damage(amount: int):
	current_damage += amount
	check_for_range_expansion()
	update_damage_display()

func reset_damage():
	current_damage = 0
	current_range_index = 0
	bonus_shots_granted = 0
	update_damage_display()

func get_current_damage() -> int:
	return current_damage

func get_bonus_shots_granted() -> int:
	return bonus_shots_granted

func get_current_range() -> Dictionary:
	return damage_ranges[current_range_index] 

extends Control
class_name BlockHealthBar

@onready var block_bar: ProgressBar = $BlockBar
@onready var block_label: Label = $BlockLabel

var max_block: int = 25
var current_block: int = 25
var is_active: bool = false

func _ready():
	update_block_display()
	# Start hidden
	visible = false

func set_block(current: int, maximum: int):
	current_block = current
	max_block = maximum
	is_active = current > 0
	visible = is_active
	update_block_display()

func update_block_display():
	if block_bar:
		block_bar.max_value = max_block
		block_bar.value = current_block
		
		# Always blue for block
		block_bar.modulate = Color.BLUE
	
	if block_label:
		block_label.text = "%d/%d" % [current_block, max_block]

func take_block_damage(amount: int) -> int:
	"""Take damage to block. Returns remaining damage that should go to health."""
	var damage_to_block = min(current_block, amount)
	var remaining_damage = amount - damage_to_block
	
	current_block = max(0, current_block - damage_to_block)
	is_active = current_block > 0
	visible = is_active
	update_block_display()
	
	print("Block took", damage_to_block, "damage. Remaining damage:", remaining_damage)
	return remaining_damage

func clear_block():
	"""Clear all block points"""
	current_block = 0
	is_active = false
	visible = false
	update_block_display()

func has_block() -> bool:
	return is_active and current_block > 0

func get_block_amount() -> int:
	return current_block 
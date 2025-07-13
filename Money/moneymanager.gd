extends Node

# Currency system for $Looty
var current_looty: int = 50  # Player starts with 50 $Looty

signal looty_changed(new_amount: int)

func _ready():
	# Initialize with starting amount
	current_looty = 50
	looty_changed.emit(current_looty)

func get_looty() -> int:
	"""Get current $Looty amount"""
	return current_looty

func add_looty(amount: int) -> void:
	"""Add $Looty to player's balance"""
	current_looty += amount
	looty_changed.emit(current_looty)
	print("Added %d $Looty. New balance: %d $Looty" % [amount, current_looty])

func spend_looty(amount: int) -> bool:
	"""Spend $Looty if player has enough. Returns true if successful."""
	if current_looty >= amount:
		current_looty -= amount
		looty_changed.emit(current_looty)
		print("Spent %d $Looty. New balance: %d $Looty" % [amount, current_looty])
		return true
	else:
		print("Not enough $Looty! Need %d, have %d" % [amount, current_looty])
		return false

func can_afford(amount: int) -> bool:
	"""Check if player can afford the given amount"""
	return current_looty >= amount

func give_hole_completion_reward() -> int:
	"""Give random $Looty reward for completing a hole (5-50)"""
	var reward_amount = randi_range(5, 50)
	add_looty(reward_amount)
	return reward_amount

func reset_to_starting_amount() -> void:
	"""Reset $Looty to starting amount (for new games)"""
	current_looty = 50
	looty_changed.emit(current_looty)
	print("Reset $Looty to starting amount: %d" % current_looty)

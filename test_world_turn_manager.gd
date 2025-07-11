extends Control

# Test script for WorldTurnManager
# This script tests the WorldTurnManager functionality

@onready var world_turn_manager: Node = $NPC/WorldTurnManager
@onready var test_button: Button = $TestButton
@onready var status_label: Label = $StatusLabel

func _ready():
	print("=== WORLD TURN MANAGER TEST INITIALIZED ===")
	
	# Connect test button
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
	
	# Connect to WorldTurnManager signals
	if world_turn_manager:
		world_turn_manager.world_turn_started.connect(_on_world_turn_started)
		world_turn_manager.world_turn_ended.connect(_on_world_turn_ended)
		world_turn_manager.npc_turn_started.connect(_on_npc_turn_started)
		world_turn_manager.npc_turn_ended.connect(_on_npc_turn_ended)
		world_turn_manager.all_npcs_turn_completed.connect(_on_all_npcs_turn_completed)
		
		print("✓ WorldTurnManager signals connected")
	else:
		print("✗ ERROR: WorldTurnManager not found!")
	
	_update_status()

func _on_test_button_pressed():
	"""Test the WorldTurnManager by simulating a player turn end"""
	print("=== TESTING WORLD TURN MANAGER ===")
	
	if world_turn_manager:
		print("Starting world turn test...")
		world_turn_manager.start_world_turn()
	else:
		print("ERROR: WorldTurnManager not available")

func _on_world_turn_started():
	"""Called when world turn starts"""
	print("=== WORLD TURN STARTED ===")
	_update_status()

func _on_world_turn_ended():
	"""Called when world turn ends"""
	print("=== WORLD TURN ENDED ===")
	_update_status()

func _on_npc_turn_started(npc: Node):
	"""Called when an NPC's turn starts"""
	print("NPC turn started: ", npc.name)
	_update_status()

func _on_npc_turn_ended(npc: Node):
	"""Called when an NPC's turn ends"""
	print("NPC turn ended: ", npc.name)
	_update_status()

func _on_all_npcs_turn_completed():
	"""Called when all NPCs have completed their turns"""
	print("=== ALL NPCs TURN COMPLETED ===")
	_update_status()

func _update_status():
	"""Update the status display"""
	if not status_label or not world_turn_manager:
		return
	
	var progress = world_turn_manager.get_turn_progress()
	var status_text = "WorldTurnManager Status:\n"
	status_text += "Active: " + str(progress.is_active) + "\n"
	status_text += "Current NPC: " + (progress.current_npc.name if progress.current_npc else "None") + "\n"
	status_text += "Progress: " + str(progress.current_index + 1) + "/" + str(progress.total_npcs) + "\n"
	status_text += "Completed: " + str(progress.completed) + "\n"
	status_text += "Skipped: " + str(progress.skipped) + "\n"
	status_text += "Registered NPCs: " + str(world_turn_manager.get_registered_npcs().size())
	
	status_label.text = status_text

func get_player_reference() -> Node:
	"""Get player reference for testing"""
	return get_node_or_null("Player")

func show_turn_message(message: String, duration: float) -> void:
	"""Show turn message for testing"""
	print("Turn message: ", message, " (", duration, "s)") 
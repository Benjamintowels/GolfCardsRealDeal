extends Node

# WorldTurnManager - Centralized NPC turn management system
# Handles all NPC turns with consistent logic and proper sequencing
# Replaces scattered turn management in course_1.gd and Entities.gd

signal world_turn_started
signal world_turn_ended
signal npc_turn_started(npc: Node)
signal npc_turn_ended(npc: Node)
signal all_npcs_turn_completed

# Turn management state
var is_world_turn_active: bool = false
var current_npc_index: int = -1
var npcs_in_turn_order: Array[Node] = []
var turn_sequence_complete: bool = true  # Start as true to allow first turn

# NPC registration and management
var registered_npcs: Array[Node] = []
var npc_priority_cache: Dictionary = {}  # Cache NPC priorities for performance
var _last_registered_npcs_size: int = 0  # Track size changes for debugging
var _debug_call_stack: Array[String] = []  # Track function calls for debugging

# Turn completion tracking
var npcs_completed_this_turn: Array[Node] = []
var npcs_skipped_this_turn: Array[Node] = []

# Camera and UI management
var course_reference: Node = null
var camera_reference: Node = null
var end_turn_button: Control = null

# Turn message system
var turn_message_display: Control = null

# Performance optimization
var last_turn_cleanup_time: float = 0.0
const TURN_CLEANUP_INTERVAL: float = 5.0  # Clean up old data every 5 seconds

# Together Mode - All NPCs execute simultaneously in priority cascade
var together_mode_enabled: bool = false
var together_mode_turn_duration: float = 1.5  # Total time for together mode turn (reduced from 3.0)
var together_mode_cascade_delay: float = 0.05  # Delay between NPC activations in cascade (reduced from 0.1)

# NPC Priority System (higher number = higher priority/faster)
const NPC_PRIORITIES = {
	"Squirrel": 4,      # Fastest - ball chasers
	"ZombieGolfer": 3,  # Fast - aggressive
	"GangMember": 2,    # Medium - patrol/chase
	"Police": 1,        # Slow - defensive
	"default": 0        # Unknown NPCs
}

# Turn validation constants
const MAX_VISION_RANGE: int = 20  # Maximum tiles for player vision
const MIN_TURN_INTERVAL: float = 0.25  # Minimum time between NPC turns (reduced from 0.5)
const CAMERA_TRANSITION_DURATION: float = 0.25  # Time for camera transitions (reduced from 0.5)

func _ready():
	"""Initialize the WorldTurnManager"""
	print("=== WORLD TURN MANAGER INITIALIZED ===")
	
	# Find course reference
	_find_course_reference()
	
	# Setup signal connections
	_setup_signal_connections()
	
	# Initialize tracking variables
	_last_registered_npcs_size = 0
	
	print("WorldTurnManager ready")

func _find_course_reference() -> void:
	"""Find the course_1.gd script reference"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			course_reference = current_node
			print("Found course reference: ", course_reference.name)
			break
		current_node = current_node.get_parent()
	
	if not course_reference:
		# Try alternative approach - look for the main scene root
		var scene_root = get_tree().current_scene
		if scene_root and scene_root.get_script() and scene_root.get_script().resource_path.ends_with("course_1.gd"):
			course_reference = scene_root
			print("Found course reference via scene root: ", course_reference.name)
		else:
			print("ERROR: Could not find course_1.gd reference!")
			print("Current scene root: ", scene_root.name if scene_root else "None")
			print("Scene root script: ", scene_root.get_script().resource_path if scene_root and scene_root.get_script() else "None")

func _setup_signal_connections() -> void:
	"""Setup signal connections for turn management"""
	if course_reference:
		print("Setting up signal connections with course: ", course_reference.name)
		# Connect to course signals if they exist
		if course_reference.has_signal("player_turn_ended"):
			course_reference.player_turn_ended.connect(_on_player_turn_ended)
			print("✓ Connected to player_turn_ended signal")
		else:
			print("✗ Course does not have player_turn_ended signal")
		
		# Find camera and UI references
		camera_reference = course_reference.get_node_or_null("GameCamera")
		end_turn_button = course_reference.get_node_or_null("UILayer/EndTurnButton")
		turn_message_display = course_reference.get_node_or_null("UILayer/TurnMessageDisplay")
		
		print("Camera reference: ", camera_reference.name if camera_reference else "None")
		print("End turn button: ", end_turn_button.name if end_turn_button else "None")
		print("Turn message display: ", turn_message_display.name if turn_message_display else "None")
	else:
		print("✗ No course reference available for signal connections")

func register_npc(npc: Node) -> void:
	"""Register an NPC to be managed by this system"""
	print("=== NPC REGISTRATION ATTEMPT ===")
	print("NPC: ", npc.name if npc else "None")
	print("NPC valid: ", is_instance_valid(npc) if npc else "N/A")
	print("Already registered: ", npc in registered_npcs if npc else "N/A")
	print("Current registered_npcs size: ", registered_npcs.size())
	
	if npc and npc not in registered_npcs:
		registered_npcs.append(npc)
		print("✓ Registered NPC: ", npc.name, " (Total NPCs: ", registered_npcs.size(), ")")
		
		# Connect to NPC's turn_completed signal
		if npc.has_signal("turn_completed"):
			npc.turn_completed.connect(_on_npc_turn_completed.bind(npc))
			print("✓ Connected to turn_completed signal")
		else:
			print("WARNING: NPC ", npc.name, " does not have turn_completed signal")
		
		print("=== END NPC REGISTRATION ===")
	else:
		print("✗ NPC registration failed or already registered")
		print("=== END NPC REGISTRATION ===")

func unregister_npc(npc: Node) -> void:
	"""Unregister an NPC from the system"""
	if npc in registered_npcs:
		registered_npcs.erase(npc)
		print("Unregistered NPC: ", npc.name, " (Total NPCs: ", registered_npcs.size(), ")")

func _on_player_turn_ended() -> void:

	start_world_turn()

func start_world_turn() -> void:
	"""Start the world turn sequence for all active NPCs"""
	_debug_call_stack.append("start_world_turn")
	
	if is_world_turn_active:
		print("World turn already active, ignoring start request")
		_debug_call_stack.pop_back()
		return
	
	# Additional guard to prevent multiple calls during the same frame
	if not turn_sequence_complete:
		print("World turn sequence already in progress, ignoring start request")
		_debug_call_stack.pop_back()
		return
	
	print("=== STARTING WORLD TURN SEQUENCE ===")
	
	# Reset turn state
	is_world_turn_active = true
	current_npc_index = -1
	turn_sequence_complete = false
	npcs_completed_this_turn.clear()
	npcs_skipped_this_turn.clear()
	
	# Emit world turn started signal
	world_turn_started.emit()
	
	# Get active NPCs for this turn
	npcs_in_turn_order = _get_active_npcs_for_turn()
	
	if npcs_in_turn_order.is_empty():
		print("No active NPCs found - completing world turn immediately")
		_complete_world_turn()
		return
	
	print("Found ", npcs_in_turn_order.size(), " active NPCs for world turn")
	
	# Show "World Turn" message
	_show_turn_message("World Turn", 2.0)
	
	# Start processing NPC turns
	_process_next_npc_turn()
	
	_debug_call_stack.pop_back()

func _get_active_npcs_for_turn() -> Array[Node]:
	"""Get all NPCs that should take a turn this world turn"""
	var active_npcs: Array[Node] = []
	
	
	for npc in registered_npcs:
		if not is_instance_valid(npc):
			continue
		
		
		# Check if NPC is alive
		if not _is_npc_alive(npc):
			continue
		
		# Debug: Check if NPC has required methods
		var has_grid_position = npc.has_method("get_grid_position")
		var has_take_turn = npc.has_method("take_turn")
		
		# Check if NPC is frozen and won't thaw this turn
		if _is_npc_frozen_and_wont_thaw(npc):
			continue
		
		# Check if NPC should take a turn based on type and conditions
		if _should_npc_take_turn(npc):
			active_npcs.append(npc)
	
	# Sort NPCs by priority (highest priority first)
	active_npcs.sort_custom(func(a, b): return get_npc_priority(a) > get_npc_priority(b))
	
	print("Active NPCs for turn (sorted by priority):")
	for npc in active_npcs:
		print("  - ", npc.name, " (Priority: ", get_npc_priority(npc), ")")
	
	print("=== END NPC CHECK ===")
	return active_npcs

func _is_npc_alive(npc: Node) -> bool:
	"""Check if an NPC is alive"""
	if npc.has_method("get_is_dead"):
		return not npc.get_is_dead()
	elif npc.has_method("is_dead"):
		return not npc.is_dead()
	elif "is_dead" in npc:
		return not npc.is_dead
	elif "is_alive" in npc:
		return npc.is_alive
	else:
		# Default to alive if no death checking method found
		return true

func _is_npc_frozen_and_wont_thaw(npc: Node) -> bool:
	"""Check if an NPC is frozen and won't thaw this turn"""
	var is_frozen = false
	if npc.has_method("is_frozen_state"):
		is_frozen = npc.is_frozen_state()
	elif "is_frozen" in npc:
		is_frozen = npc.is_frozen
	else:
		return false  # Not frozen if no freeze system
	
	if not is_frozen:
		return false
	
	# Check if NPC will thaw this turn
	var will_thaw_this_turn = false
	if npc.has_method("get_freeze_turns_remaining"):
		var turns_remaining = npc.get_freeze_turns_remaining()
		will_thaw_this_turn = turns_remaining <= 1
	elif "freeze_turns_remaining" in npc:
		var turns_remaining = npc.freeze_turns_remaining
		will_thaw_this_turn = turns_remaining <= 1
	
	return not will_thaw_this_turn

func _should_npc_take_turn(npc: Node) -> bool:
	"""Check if an NPC should take a turn based on their type and current conditions"""
	var script_path = npc.get_script().resource_path if npc.get_script() else ""
	
	# Special handling for ball-detecting NPCs (like Squirrels)
	if "Squirrel.gd" in script_path:
		return _should_squirrel_take_turn(npc)
	
	# For other NPCs, check if they're within player vision range
	return _is_npc_in_player_vision(npc)

func _should_squirrel_take_turn(npc: Node) -> bool:
	"""Check if a Squirrel should take a turn (based on ball detection)"""
	if npc.has_method("has_detected_golf_ball"):
		var has_ball = npc.has_detected_golf_ball()
		print("    Squirrel ball detection: ", has_ball)
		return has_ball
	elif "nearest_golf_ball" in npc:
		var has_ball = npc.nearest_golf_ball != null and is_instance_valid(npc.nearest_golf_ball)
		print("    Squirrel fallback ball detection: ", has_ball)
		return has_ball
	else:
		print("    Squirrel has no ball detection method, allowing turn")
		return true

func _is_npc_in_player_vision(npc: Node) -> bool:
	"""Check if an NPC is within the player's vision range"""
	if not course_reference:
		print("    VISION: No course reference")
		return false
	
	if not npc.has_method("get_grid_position"):
		print("    VISION: NPC missing get_grid_position method")
		return false
	
	var player_pos = course_reference.player_manager.get_player_grid_pos()
	var npc_pos = npc.get_grid_position()
	var distance = player_pos.distance_to(npc_pos)
	
	print("    VISION: Player pos:", player_pos, "NPC pos:", npc_pos, "Distance:", distance, "Max range:", MAX_VISION_RANGE)
	
	return distance <= MAX_VISION_RANGE

func get_npc_priority(npc: Node) -> int:
	"""Get the priority rating for an NPC (higher = faster/more important)"""
	# Check cache first
	var npc_id = npc.get_instance_id()
	if npc_id in npc_priority_cache:
		return npc_priority_cache[npc_id]
	
	# Determine priority based on script
	var script_path = npc.get_script().resource_path if npc.get_script() else ""
	var priority = NPC_PRIORITIES.get("default", 0)
	
	for npc_type in NPC_PRIORITIES:
		if npc_type in script_path:
			priority = NPC_PRIORITIES[npc_type]
			break
	
	# Cache the result
	npc_priority_cache[npc_id] = priority
	return priority

func _process_next_npc_turn() -> void:
	"""Process the next NPC's turn in the sequence"""
	# If together mode is enabled, use cascade execution
	if together_mode_enabled:
		_process_together_mode_turn()
		return
	
	current_npc_index += 1
	
	# Safety check to prevent infinite loops
	if current_npc_index >= npcs_in_turn_order.size():
		# All NPCs have taken their turn
		_complete_world_turn()
		return
	
	var current_npc = npcs_in_turn_order[current_npc_index]
	if not is_instance_valid(current_npc):
		print("NPC became invalid, skipping to next")
		_process_next_npc_turn()
		return
	
	print("=== PROCESSING NPC TURN ===")
	print("NPC: ", current_npc.name, " (", current_npc_index + 1, "/", npcs_in_turn_order.size(), ")")
	print("Priority: ", get_npc_priority(current_npc))
	
	# Emit NPC turn started signal
	npc_turn_started.emit(current_npc)
	
	# Special handling for squirrels: update ball detection before turn
	_update_squirrel_ball_detection(current_npc)
	
	# Check if NPC should still take turn after updates
	if not _should_npc_take_turn(current_npc):
		print("NPC should not take turn after updates, skipping")
		npcs_skipped_this_turn.append(current_npc)
		npc_turn_ended.emit(current_npc)
		_process_next_npc_turn()
		return
	
	# Transition camera to NPC
	await _transition_camera_to_npc(current_npc)
	
	# Wait for camera transition
	await get_tree().create_timer(CAMERA_TRANSITION_DURATION).timeout
	
	# Take the NPC's turn
	print("Taking turn for NPC: ", current_npc.name)
	current_npc.take_turn()
	
	# Simple, reliable turn completion: wait a fixed time
	# This prevents NPCs from getting stuck and ensures consistent timing
	var turn_duration = 1.0  # 1 second per turn (reduced from 2.0 for faster transitions)
	await get_tree().create_timer(turn_duration).timeout
	
	# Wait a moment to let player see the result
	await get_tree().create_timer(MIN_TURN_INTERVAL).timeout
	
	# Mark NPC as completed
	npcs_completed_this_turn.append(current_npc)
	npc_turn_ended.emit(current_npc)
	
	print("=== NPC TURN COMPLETED ===")
	print("NPC: ", current_npc.name)
	
	# Process next NPC
	_process_next_npc_turn()

func _process_together_mode_turn() -> void:
	"""Process all NPC turns simultaneously in a priority cascade"""
	print("=== TOGETHER MODE: CASCADE EXECUTION ===")
	print("Total NPCs to process: ", npcs_in_turn_order.size())
	
	# Show "World Turn - Together!" message
	_show_turn_message("World Turn - Together!", 1.5)
	
	# Wait a moment for message to display
	await get_tree().create_timer(0.25).timeout
	
	# Group NPCs by priority for cascade effect
	var priority_groups: Dictionary = {}
	for npc in npcs_in_turn_order:
		if not is_instance_valid(npc):
			continue
		
		var priority = get_npc_priority(npc)
		if not priority_groups.has(priority):
			priority_groups[priority] = []
		priority_groups[priority].append(npc)
	
	# Get sorted priorities (highest first)
	var sorted_priorities = priority_groups.keys()
	sorted_priorities.sort()
	sorted_priorities.reverse()
	
	print("Priority groups for cascade:")
	for priority in sorted_priorities:
		print("  Priority ", priority, ": ", priority_groups[priority].size(), " NPCs")
	
	# Find the highest priority NPC for camera focus
	var highest_priority_npc = _get_highest_priority_npc_for_camera()
	if highest_priority_npc:
		print("=== TOGETHER MODE: CAMERA TRANSITION ===")
		print("Moving camera to highest priority NPC: ", highest_priority_npc.name, " (Priority: ", get_npc_priority(highest_priority_npc), ")")
		
		# Transition camera to the highest priority NPC
		await _transition_camera_to_npc(highest_priority_npc)
		
		# Wait for camera transition
		await get_tree().create_timer(CAMERA_TRANSITION_DURATION).timeout
	else:
		print("No valid NPCs found for camera focus")
	
	# Execute cascade by priority
	for priority in sorted_priorities:
		var npcs_in_priority = priority_groups[priority]
		print("=== CASCADE PRIORITY ", priority, " ===")
		
		# Execute all NPCs in this priority simultaneously
		var turn_tasks: Array = []
		for npc in npcs_in_priority:
			if not is_instance_valid(npc):
				continue
			
			# Update squirrel ball detection
			_update_squirrel_ball_detection(npc)
			
			# Check if NPC should take turn
			if not _should_npc_take_turn(npc):
				print("  Skipping NPC: ", npc.name)
				npcs_skipped_this_turn.append(npc)
				continue
			
			print("  Activating NPC: ", npc.name)
			
			# Emit turn started signal
			npc_turn_started.emit(npc)
			
			# Start NPC turn asynchronously
			var turn_task = _execute_npc_turn_async(npc)
			turn_tasks.append(turn_task)
		
		# Wait for all NPCs in this priority to complete their turns
		if not turn_tasks.is_empty():
			await _wait_for_all_tasks(turn_tasks)
		
		# Small delay between priority groups for visual effect
		if priority != sorted_priorities[-1]:  # Not the last priority
			await get_tree().create_timer(together_mode_cascade_delay).timeout
	
	# Wait for the total turn duration to complete
	var remaining_time = together_mode_turn_duration - (Time.get_ticks_msec() / 1000.0)
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout
	
	print("=== TOGETHER MODE COMPLETED ===")
	_complete_world_turn()

func _execute_npc_turn_async(npc: Node) -> Dictionary:
	"""Execute an NPC's turn asynchronously and return a task reference"""
	var task = {
		"npc": npc,
		"completed": false,
		"start_time": Time.get_ticks_msec() / 1000.0
	}
	
	# Start the turn execution
	_execute_npc_turn_task(task)
	
	return task

func _execute_npc_turn_task(task: Dictionary) -> void:
	"""Execute the actual NPC turn for a task"""
	var npc = task.npc
	if not is_instance_valid(npc):
		task.completed = true
		return
	
	print("  Starting turn for: ", npc.name)
	
	# Take the NPC's turn
	npc.take_turn()
	
	# Wait for the NPC's turn to actually complete
	# Most NPCs emit a signal when their turn is done, or we can wait for a reasonable duration
	var turn_start_time = Time.get_ticks_msec() / 1000.0
	var max_turn_duration = 1.5  # Maximum 1.5 seconds for an NPC turn (reduced from 3.0)
	
	# Wait for either the NPC to signal completion or timeout
	while Time.get_ticks_msec() / 1000.0 - turn_start_time < max_turn_duration:
		# Check if NPC has completed their turn (many NPCs have a turn_completed flag)
		if npc.has_method("is_turn_completed") and npc.is_turn_completed():
			break
		elif "turn_completed" in npc and npc.turn_completed:
			break
		elif npc.has_method("get_turn_state") and npc.get_turn_state() == "completed":
			break
		
		# Small delay to avoid busy waiting
		await get_tree().create_timer(0.05).timeout
	
	# Mark task as completed
	task.completed = true
	npcs_completed_this_turn.append(npc)
	npc_turn_ended.emit(npc)
	
	print("  Completed turn for: ", npc.name)

func _get_highest_priority_npc_for_camera() -> Node:
	"""Get the highest priority NPC that should take a turn for camera focus"""
	var highest_priority_npc: Node = null
	var highest_priority: int = -1
	
	for npc in npcs_in_turn_order:
		if not is_instance_valid(npc):
			continue
		
		# Check if NPC should take a turn
		if not _should_npc_take_turn(npc):
			continue
		
		var priority = get_npc_priority(npc)
		if priority > highest_priority:
			highest_priority = priority
			highest_priority_npc = npc
	
	print("Highest priority NPC for camera: ", highest_priority_npc.name if highest_priority_npc else "None", " (Priority: ", highest_priority, ")")
	return highest_priority_npc

func _wait_for_all_tasks(tasks: Array) -> void:
	"""Wait for all tasks to complete"""
	var completed_tasks = 0
	var total_tasks = tasks.size()
	
	while completed_tasks < total_tasks:
		completed_tasks = 0
		for task in tasks:
			if task.completed:
				completed_tasks += 1
		
		if completed_tasks < total_tasks:
			await get_tree().create_timer(0.05).timeout

func toggle_together_mode() -> void:
	"""Toggle together mode on/off"""
	together_mode_enabled = !together_mode_enabled
	print("=== TOGETHER MODE TOGGLED ===")
	print("Together mode: ", "ENABLED" if together_mode_enabled else "DISABLED")
	
	# Show toggle message
	var message = "Together Mode: ON" if together_mode_enabled else "Together Mode: OFF"
	_show_turn_message(message, 2.0)

func set_together_mode(enabled: bool) -> void:
	"""Set together mode to a specific state"""
	together_mode_enabled = enabled
	print("=== TOGETHER MODE SET ===")
	print("Together mode: ", "ENABLED" if together_mode_enabled else "DISABLED")
	
	# Show setting message
	var message = "Together Mode: ON" if together_mode_enabled else "Together Mode: OFF"
	_show_turn_message(message, 2.0)

func is_together_mode_enabled() -> bool:
	"""Check if together mode is currently enabled"""
	return together_mode_enabled

func set_together_mode_duration(duration: float) -> void:
	"""Set the total duration for together mode turns"""
	together_mode_turn_duration = duration
	print("Together mode duration set to: ", duration, " seconds")

func set_together_mode_cascade_delay(delay: float) -> void:
	"""Set the delay between priority groups in cascade mode"""
	together_mode_cascade_delay = delay
	print("Together mode cascade delay set to: ", delay, " seconds")

func _update_squirrel_ball_detection(npc: Node) -> void:
	"""Update ball detection for Squirrel NPCs before their turn"""
	var script_path = npc.get_script().resource_path if npc.get_script() else ""
	if "Squirrel.gd" not in script_path:
		return
	
	print("=== UPDATING SQUIRREL BALL DETECTION ===")
	print("Squirrel: ", npc.name)
	
	if npc.has_method("_check_vision_for_golf_balls"):
		npc._check_vision_for_golf_balls()
	
	if npc.has_method("_update_nearest_golf_ball"):
		npc._update_nearest_golf_ball()
	
	print("=== END SQUIRREL BALL DETECTION UPDATE ===")

func _transition_camera_to_npc(npc: Node) -> void:
	"""Transition camera to focus on the NPC"""
	if not camera_reference or not npc:
		return
	
	print("Transitioning camera to NPC: ", npc.name)
	
	# Call course's camera transition method if available
	if course_reference.has_method("transition_camera_to_npc"):
		await course_reference.transition_camera_to_npc(npc)
	else:
		# Fallback: simple camera movement
		var target_pos = npc.global_position
		if camera_reference.has_method("transition_to_position"):
			await camera_reference.transition_to_position(target_pos)
		else:
			# Direct position setting as last resort
			camera_reference.global_position = target_pos

func _on_npc_turn_completed(npc: Node) -> void:
	"""Called when an NPC completes their turn"""
	print("NPC turn completed signal received: ", npc.name)
	# This is handled in _process_next_npc_turn, but we keep it for compatibility

func _complete_world_turn() -> void:
	"""Complete the world turn sequence"""
	print("=== COMPLETING WORLD TURN ===")
	print("NPCs completed: ", npcs_completed_this_turn.size())
	print("NPCs skipped: ", npcs_skipped_this_turn.size())
	
	# Reset turn state
	is_world_turn_active = false
	current_npc_index = -1
	turn_sequence_complete = true
	
	# Show "Your Turn" message
	_show_turn_message("Your Turn", 2.0)
	
	# Wait for message to display, then transition camera back to player
	await get_tree().create_timer(0.5).timeout
	await _transition_camera_to_player()
	
	# Re-enable end turn button
	if end_turn_button:
		end_turn_button.get_node("TextureButton").mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Emit completion signals
	all_npcs_turn_completed.emit()
	world_turn_ended.emit()
	
	print("=== WORLD TURN COMPLETED ===")
	
	# Continue with normal turn flow
	_continue_player_turn()

func _transition_camera_to_player() -> void:
	"""Transition camera back to the player"""
	if not camera_reference or not course_reference:
		return
	
	print("Transitioning camera back to player")
	
	# Call course's camera transition method if available
	if course_reference.has_method("transition_camera_to_player"):
		await course_reference.transition_camera_to_player()
	else:
		# Fallback: simple camera movement to player
		var player_pos = course_reference.player_manager.get_player_node().global_position if course_reference.player_manager and course_reference.player_manager.get_player_node() else Vector2.ZERO
		if camera_reference.has_method("transition_to_position"):
			await camera_reference.transition_to_position(player_pos)
		else:
			# Direct position setting as last resort
			camera_reference.global_position = player_pos

func _continue_player_turn() -> void:
	"""Continue with the player's turn after world turn completion"""
	if not course_reference:
		return
	
	print("Continuing player turn")
	
	# Call course's turn continuation method
	if course_reference.has_method("_continue_after_world_turn"):
		course_reference._continue_after_world_turn()
	else:
		# Fallback: basic turn continuation
		if course_reference.has_method("enter_draw_cards_phase"):
			course_reference.enter_draw_cards_phase()
		elif course_reference.has_method("draw_cards_for_shot"):
			course_reference.draw_cards_for_shot(5)

func _show_turn_message(message: String, duration: float) -> void:
	"""Show a turn message to the player"""
	if turn_message_display and turn_message_display.has_method("show_message"):
		turn_message_display.show_message(message, duration)
	elif course_reference and course_reference.has_method("show_turn_message"):
		course_reference.show_turn_message(message, duration)
	else:
		print("Turn message: ", message)

func get_registered_npcs() -> Array[Node]:
	"""Get all registered NPCs"""
	return registered_npcs

func is_world_turn_in_progress() -> bool:
	"""Check if a world turn is currently in progress"""
	return is_world_turn_active

func get_current_npc() -> Node:
	"""Get the NPC currently taking their turn"""
	if current_npc_index >= 0 and current_npc_index < npcs_in_turn_order.size():
		return npcs_in_turn_order[current_npc_index]
	return null

func get_turn_progress() -> Dictionary:
	"""Get information about the current turn progress"""
	return {
		"is_active": is_world_turn_active,
		"current_index": current_npc_index,
		"total_npcs": npcs_in_turn_order.size(),
		"completed": npcs_completed_this_turn.size(),
		"skipped": npcs_skipped_this_turn.size(),
		"current_npc": get_current_npc(),
		"together_mode": together_mode_enabled,
		"together_duration": together_mode_turn_duration,
		"together_cascade_delay": together_mode_cascade_delay
	}

func force_complete_world_turn() -> void:
	"""Force complete the current world turn (for debugging/emergency)"""
	if is_world_turn_active:
		print("Force completing world turn")
		_complete_world_turn()

func manually_start_world_turn() -> void:
	"""Manually start world turn for testing purposes"""
	print("=== MANUALLY STARTING WORLD TURN ===")
	print("Together mode: ", "ENABLED" if together_mode_enabled else "DISABLED")
	start_world_turn()

func force_advance_to_next_npc() -> void:
	"""Force advance to the next NPC in the turn sequence (for debugging)"""
	if is_world_turn_active and current_npc_index < npcs_in_turn_order.size():
		print("Force advancing to next NPC")
		_process_next_npc_turn()


func _process(delta: float) -> void:
	"""Process function for cleanup and maintenance"""
	# Track registered_npcs size changes
	if registered_npcs.size() != _last_registered_npcs_size:
		_last_registered_npcs_size = registered_npcs.size()
	
	# Periodic cleanup of old data
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_turn_cleanup_time > TURN_CLEANUP_INTERVAL:
		_cleanup_old_data()
		last_turn_cleanup_time = current_time

func _cleanup_old_data() -> void:
	"""Clean up old data to prevent memory leaks"""
	_debug_call_stack.append("_cleanup_old_data")
	
	# Don't clean up during active world turns to prevent NPCs from disappearing
	if is_world_turn_active:
		_debug_call_stack.pop_back()
		return
	
	
	# Remove invalid NPCs from registration
	var valid_npcs: Array[Node] = []
	for npc in registered_npcs:
		if is_instance_valid(npc):
			valid_npcs.append(npc)
	
	if valid_npcs.size() != registered_npcs.size():
		var removed_count = registered_npcs.size() - valid_npcs.size()
		registered_npcs = valid_npcs
		
	
	# Clean up priority cache for invalid NPCs
	var valid_cache_keys: Array = []
	for npc_id in npc_priority_cache:
		# We can't easily check if the instance ID is still valid, so we'll just clear the cache periodically
		valid_cache_keys.append(npc_id)
	
	if valid_cache_keys.size() != npc_priority_cache.size():
		npc_priority_cache.clear()
	
	_debug_call_stack.pop_back()

extends Node
class_name GameState3DManager

# GameState3DManager - Handles 3D game phases and state transitions
# Optimized for 3D space with clear state management

signal phase_changed(new_phase: String)
signal game_started
signal game_completed

# Game phases
enum GamePhase {
	INITIALIZING,
	READY,
	PLAYER_MOVING,
	BALL_FLYING,
	BALL_LANDED,
	HOLE_COMPLETED,
	GAME_COMPLETED
}

# Current state
var current_phase: GamePhase = GamePhase.INITIALIZING
var current_hole: int = 1
var total_holes: int = 18
var shots_taken: int = 0
var total_score: int = 0

# Game settings
var is_aiming: bool = false
var is_ball_in_flight: bool = false

func _ready():
	print("✓ GameState3DManager initialized")

func set_phase(new_phase: GamePhase):
	"""Set the current game phase"""
	var old_phase = current_phase
	current_phase = new_phase
	
	# Handle phase-specific logic
	_handle_phase_transition(old_phase, new_phase)
	
	# Emit signal
	phase_changed.emit(_get_phase_name(new_phase))
	
	print("✓ Game phase changed from", _get_phase_name(old_phase), "to", _get_phase_name(new_phase))

func _handle_phase_transition(old_phase: GamePhase, new_phase: GamePhase):
	"""Handle specific phase transitions"""
	
	match new_phase:
		GamePhase.READY:
			if old_phase == GamePhase.INITIALIZING:
				game_started.emit()
		
		GamePhase.BALL_FLYING:
			is_ball_in_flight = true
			shots_taken += 1
		
		GamePhase.BALL_LANDED:
			is_ball_in_flight = false
		
		GamePhase.HOLE_COMPLETED:
			_on_hole_completed()
		
		GamePhase.GAME_COMPLETED:
			game_completed.emit()

func _on_hole_completed():
	"""Handle hole completion"""
	print("✓ Hole", current_hole, "completed in", shots_taken, "shots")
	
	# Calculate score for this hole
	var hole_score = _calculate_hole_score(shots_taken)
	total_score += hole_score
	
	# Reset for next hole
	shots_taken = 0
	current_hole += 1
	
	if current_hole > total_holes:
		set_phase(GamePhase.GAME_COMPLETED)

func _calculate_hole_score(shots: int) -> int:
	"""Calculate score for a hole based on shots taken"""
	# Simple scoring: par is 3, each shot over par adds 1 to score
	var par = 3
	var score = max(0, shots - par)
	return score

func _get_phase_name(phase: GamePhase) -> String:
	"""Get the string name of a phase"""
	match phase:
		GamePhase.INITIALIZING: return "initializing"
		GamePhase.READY: return "ready"
		GamePhase.PLAYER_MOVING: return "player_moving"
		GamePhase.BALL_FLYING: return "ball_flying"
		GamePhase.BALL_LANDED: return "ball_landed"
		GamePhase.HOLE_COMPLETED: return "hole_completed"
		GamePhase.GAME_COMPLETED: return "game_completed"
		_: return "unknown"

# Public API
func get_current_phase() -> GamePhase:
	return current_phase

func get_current_phase_name() -> String:
	return _get_phase_name(current_phase)

func get_current_hole() -> int:
	return current_hole

func get_total_holes() -> int:
	return total_holes

func get_shots_taken() -> int:
	return shots_taken

func get_total_score() -> int:
	return total_score

func is_aiming_phase() -> bool:
	return is_aiming

func is_ball_flying() -> bool:
	return is_ball_in_flight

func set_aiming(aiming: bool):
	"""Set aiming state"""
	is_aiming = aiming

func reset_hole():
	"""Reset current hole state"""
	shots_taken = 0
	set_phase(GamePhase.READY)

func get_game_info() -> Dictionary:
	"""Get current game information"""
	return {
		"current_phase": get_current_phase_name(),
		"current_hole": current_hole,
		"total_holes": total_holes,
		"shots_taken": shots_taken,
		"total_score": total_score,
		"is_aiming": is_aiming,
		"is_ball_flying": is_ball_in_flight
	} 
extends AnimatedSprite2D

# Simple electric shock effect for electrified objects
var shock_duration: float = 2.0
var shock_timer: float = 0.0
var damage_applied: bool = false
var area2d: Area2D
var shock_sound: AudioStreamPlayer2D

func _ready():
	area2d = $Area2D
	shock_sound = $Shock
	
	# Start the shock animation
	play("default")
	
	# Apply damage to the parent object
	_apply_damage_to_parent()

func _process(delta):
	# Timer for auto-cleanup
	shock_timer += delta
	if shock_timer >= shock_duration:
		queue_free()

func _apply_damage_to_parent():
	"""Apply damage to the parent object if it has a take_damage method"""
	if damage_applied:
		return
		
	var parent = get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(20)
		print("Applied 20 electric damage to: ", parent.name)
		damage_applied = true

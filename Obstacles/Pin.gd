extends BaseObstacle

signal hole_in_one(score: int)
signal pin_flag_hit(ball: Node2D)  # New signal for pin flag hits

# Pin flag reflection settings
const HOLE_IN_HEIGHT_MAX = 5.0  # Maximum height for hole-in
var PIN_FLAG_HEIGHT_MAX = 400.0  # Will be set dynamically based on Marker2D position

func _ready():
	# Connect to the flag Area2D's area_entered signal (for flag hits)
	var flag_area = $FlagArea
	if flag_area:
		# Set collision layer to 1 so golf balls can detect it
		flag_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		flag_area.collision_mask = 1
		
		flag_area.connect("area_entered", _on_flag_area_entered)
	
	# Connect to the hole Area2D's area_entered signal (for hole-in detection)
	var hole_area = get_node_or_null("HoleArea")
	if hole_area:
		# Set collision layer to 1 so golf balls can detect it
		hole_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		hole_area.collision_mask = 1
		
		hole_area.connect("area_entered", _on_hole_area_entered)
		print("Hole collision area connected")
	else:
		print("No HoleArea found - hole-in detection may not work properly")
	
	# Set collision height based on Marker2D position (if it exists)
	var top_marker = get_node_or_null("TopMarker")
	if top_marker:
		# Convert the marker's Y position to ball height units
		# The marker's Y position is negative (up), so we take the absolute value
		PIN_FLAG_HEIGHT_MAX = abs(top_marker.position.y)
		print("Pin collision height set to:", PIN_FLAG_HEIGHT_MAX, "based on TopMarker position")
	else:
		# Fallback to default value
		PIN_FLAG_HEIGHT_MAX = 400.0
		print("No TopMarker found, using default collision height:", PIN_FLAG_HEIGHT_MAX)

# Returns the Y-sorting reference point (base of pin)
func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("YsortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func _process(delta):
	# Y-sort: set z_index based on global y position, but ensure it's above ground
	# REMOVED: z_index = int(global_position.y) + 10  # This was overriding the fixed z_index = 1000
	pass

func _on_flag_area_entered(area: Area2D):
	"""Handle collisions with the flag area (for flag hits)"""
	# Check if the area belongs to a golf ball
	if area.get_parent() and area.get_parent().has_method("get_height"):
		var golf_ball = area.get_parent()
		var ball_height = golf_ball.get_height()
		
		# Check if this is a ghost ball (ghost balls have is_ghost property set to true)
		if "is_ghost" in golf_ball and golf_ball.is_ghost:
			return
		
		# Only handle flag hits (not hole-ins) in this area
		if ball_height > HOLE_IN_HEIGHT_MAX and ball_height <= PIN_FLAG_HEIGHT_MAX:
			# Ball hit the pin flag - apply reflection effect
			# Play the pin flag hit sound
			var hit_flag_audio = get_node_or_null("HitFlag")
			if hit_flag_audio:
				hit_flag_audio.play()
			
			# Emit signal for pin flag hit
			pin_flag_hit.emit(golf_ball)
			
			# Apply velocity reduction (75% reduction = 25% of original velocity)
			if golf_ball.has_method("set_velocity"):
				var current_velocity = golf_ball.get_velocity()
				var reduced_velocity = current_velocity * 0.25  # 25% of original velocity
				golf_ball.set_velocity(reduced_velocity)

func _on_hole_area_entered(area: Area2D):
	"""Handle collisions with the hole area (for hole-in detection)"""
	# Check if the area belongs to a golf ball
	if area.get_parent() and area.get_parent().has_method("get_height"):
		var golf_ball = area.get_parent()
		var ball_height = golf_ball.get_height()
		
		# Check if this is a ghost ball (ghost balls have is_ghost property set to true)
		if "is_ghost" in golf_ball and golf_ball.is_ghost:
			return
		
		# Check if the ball is in the hole-in height range (0-5) for all shots
		# This should work for both rolling balls and balls dropping from above
		if ball_height >= 0.0 and ball_height <= HOLE_IN_HEIGHT_MAX:
			# Check if this is a scramble ball
			var is_scramble_ball = golf_ball.is_in_group("scramble_balls")
			
			if is_scramble_ball:
				# Handle scramble ball hole completion
				# Get the CardEffectHandler reference from metadata
				var card_effect_handler = get_meta("card_effect_handler", null)
				
				if card_effect_handler and card_effect_handler.has_method("handle_scramble_ball_hole_completion"):
					# Call the CardEffectHandler to handle scramble ball hole completion
					card_effect_handler.handle_scramble_ball_hole_completion(golf_ball)
				else:
					# Fallback to normal hole completion
					hole_in_one.emit(0)
			else:
				# Normal ball hole completion
				# Play the hole-in sound
				var hole_in_audio = get_node_or_null("HoleIn")
				if hole_in_audio:
					hole_in_audio.play()
				
				# Emit signal for hole completion
				hole_in_one.emit(0)  # 0 indicates hole completion, score will be calculated by course
			
			# Queue free the ball (CardEffectHandler will handle scramble balls)
			if not is_scramble_ball:
				golf_ball.queue_free()
			
			# Note: Removed direct call to show_hole_completion_dialog() 
			# The course will handle this through the signal connection

extends BaseObstacle

signal hole_in_one(score: int)
signal pin_flag_hit(ball: Node2D)  # New signal for pin flag hits
signal gimme_triggered(ball: Node2D)  # New signal for gimme detection
signal gimme_ball_exited(ball: Node2D)  # New signal for when ball exits gimme area

# Gimme tracking variables
var ball_in_gimme_area := false
var current_gimme_ball: Node2D = null

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
	
	# Connect to the gimme Area2D's area_entered and area_exited signals (for gimme detection)
	var gimme_area = get_node_or_null("GimmeArea")
	if gimme_area:
		# Set collision layer to 0 so it doesn't interfere with physics
		gimme_area.collision_layer = 0
		# Set collision mask to 1 so it can detect golf balls on layer 1
		gimme_area.collision_mask = 1
		
		gimme_area.connect("area_entered", _on_gimme_area_entered)
		gimme_area.connect("area_exited", _on_gimme_area_exited)
		print("Gimme collision area connected")
	else:
		print("No GimmeArea found - gimme detection may not work properly")
	
	# Set collision height based on TopHeight Marker2D position (if it exists)
	var top_height_marker = get_node_or_null("TopHeight")
	if top_height_marker:
		# Convert the marker's Y position to ball height units
		# The marker's Y position is negative (up), so we take the absolute value
		PIN_FLAG_HEIGHT_MAX = abs(top_height_marker.position.y)
		print("Pin collision height set to:", PIN_FLAG_HEIGHT_MAX, "based on TopHeight marker position")
	else:
		# If TopHeight marker is missing, set PIN_FLAG_HEIGHT_MAX = 0 and print error
		PIN_FLAG_HEIGHT_MAX = 0
		print("No TopHeight marker found, using collision height: 0")

# Returns the Y-sorting reference point (base of pin)
func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("YSortPoint")
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

func _on_gimme_area_entered(area: Area2D):
	"""Handle collisions with the gimme area (for gimme detection)"""
	print("=== GIMME AREA ENTERED ===")
	print("Area that entered:", area.name)
	print("Area parent:", area.get_parent().name if area.get_parent() else "null")
	
	# Check if the area belongs to a golf ball
	if area.get_parent() and area.get_parent().has_method("get_height"):
		var golf_ball = area.get_parent()
		
		# Check if this is actually a golf ball (not a player character)
		if not golf_ball.is_in_group("golf_balls"):
			print("Ignoring non-golf ball object:", golf_ball.name)
			return
		
		var ball_height = golf_ball.get_height()
		
		# Check if this is a ghost ball (ghost balls have is_ghost property set to true)
		if "is_ghost" in golf_ball and golf_ball.is_ghost:
			return
		
		# Track that this ball is in the gimme area
		ball_in_gimme_area = true
		current_gimme_ball = golf_ball
		print("Ball entered gimme area:", golf_ball.name, "ball height:", ball_height)
		
		# Always check if the ball is NOT in the hole area (regardless of height)
		var hole_area = get_node_or_null("HoleArea")
		if hole_area:
			# Get the hole area's collision shape to check if ball is inside it
			var hole_shape = hole_area.get_node_or_null("CollisionShape2D")
			if hole_shape and hole_shape.shape:
				# Check if the ball's position is within the hole area
				var ball_pos = golf_ball.global_position
				var hole_center = hole_area.global_position
				var hole_radius = hole_shape.shape.radius * hole_shape.scale.x  # Assuming circular hole
				
				var distance_to_hole_center = ball_pos.distance_to(hole_center)
				
				if distance_to_hole_center > hole_radius:
					# Ball is in gimme area but NOT in the hole - trigger gimme
					print("=== GIMME AREA TRIGGERED ===")
					print("Ball in gimme area but outside hole - ball height:", ball_height, "distance to hole center:", distance_to_hole_center, "hole radius:", hole_radius, "golf ball:", golf_ball.name)
					
					# Emit signal for gimme detection
					gimme_triggered.emit(golf_ball)
				else:
					print("Ball in gimme area but INSIDE hole - not triggering gimme")
			else:
				print("ERROR: Could not get hole shape for gimme check")
		else:
			print("ERROR: No HoleArea found for gimme check")

func _on_gimme_area_exited(area: Area2D):
	"""Handle when ball exits the gimme area"""
	print("=== GIMME AREA EXITED ===")
	print("Area that exited:", area.name)
	print("Area parent:", area.get_parent().name if area.get_parent() else "null")
	
	# Check if the area belongs to a golf ball
	if area.get_parent() and area.get_parent().has_method("get_height"):
		var golf_ball = area.get_parent()
		
		# Check if this is actually a golf ball (not a player character)
		if not golf_ball.is_in_group("golf_balls"):
			print("Ignoring non-golf ball object exit:", golf_ball.name)
			return
		
		# Check if this is the ball we were tracking
		if golf_ball == current_gimme_ball:
			ball_in_gimme_area = false
			current_gimme_ball = null
			print("Ball exited gimme area:", golf_ball.name, "- gimme tracking cleared")
			
			# Emit signal to notify course that ball is no longer in gimme range
			gimme_ball_exited.emit(golf_ball)
		else:
			print("Ball exited gimme area but wasn't the tracked ball:", golf_ball.name)
	else:
		print("Area that exited was not a golf ball - ignoring")

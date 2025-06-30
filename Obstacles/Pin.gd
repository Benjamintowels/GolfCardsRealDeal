extends BaseObstacle

signal hole_in_one(score: int)
signal pin_flag_hit(ball: Node2D)  # New signal for pin flag hits

# Pin flag reflection settings
const HOLE_IN_HEIGHT_MAX = 5.0  # Maximum height for hole-in
const PIN_FLAG_HEIGHT_MAX = 200.0  # Maximum height for pin flag reflection (increased from 100.0)

func _ready():
	# Connect to the Area2D's area_entered signal
	var area2d = $Area2D
	if area2d:
		# Set collision layer to 1 so golf balls can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		area2d.collision_mask = 1
		
		area2d.connect("area_entered", _on_area_entered)

func _process(delta):
	# Debug: Check for overlapping areas more frequently
	if Engine.get_process_frames() % 60 == 0:  # Every 1 second at 60fps
		var area2d = $Area2D
		if area2d:
			var overlapping_areas = area2d.get_overlapping_areas()
			if overlapping_areas.size() > 0:
				print("Pin detected overlapping areas:", overlapping_areas.size())
				for area in overlapping_areas:
					print("  - Area:", area, "Parent:", area.get_parent().name if area.get_parent() else "No parent")
					if area.get_parent() and area.get_parent().has_method("get_height"):
						var ball_height = area.get_parent().get_height()
						print("    Ball height:", ball_height)
	
	# Y-sort: set z_index based on global y position, but ensure it's above ground
	# REMOVED: z_index = int(global_position.y) + 10  # This was overriding the fixed z_index = 1000

func _on_area_entered(area: Area2D):
	print("Pin _on_area_entered called with area:", area)
	print("Area parent:", area.get_parent())
	
	# Check if the area belongs to a golf ball
	if area.get_parent() and area.get_parent().has_method("get_height"):
		var golf_ball = area.get_parent()
		var ball_height = golf_ball.get_height()
		
		# Check if this is a ghost ball (ghost balls have is_ghost property set to true)
		if "is_ghost" in golf_ball and golf_ball.is_ghost:
			print("Pin detected ghost ball collision - ignoring")
			return
		
		print("Pin detected real ball collision. Ball height:", ball_height)
		
		# Check if the ball is in the hole-in height range (0-5) for all shots
		if ball_height >= 0.0 and ball_height <= HOLE_IN_HEIGHT_MAX:
			print("Hole in one! Ball height is in range 0-5, triggering hole completion")
			
			# Check if this is a scramble ball
			var is_scramble_ball = golf_ball.is_in_group("scramble_balls")
			print("Is scramble ball:", is_scramble_ball)
			
			if is_scramble_ball:
				# Handle scramble ball hole completion
				print("Scramble ball went in the hole - clearing other balls immediately")
				
				# Get the CardEffectHandler reference from metadata
				var card_effect_handler = get_meta("card_effect_handler", null)
				
				if card_effect_handler and card_effect_handler.has_method("handle_scramble_ball_hole_completion"):
					# Call the CardEffectHandler to handle scramble ball hole completion
					card_effect_handler.handle_scramble_ball_hole_completion(golf_ball)
				else:
					print("Warning: Could not find CardEffectHandler for scramble ball hole completion")
					# Fallback to normal hole completion
					hole_in_one.emit(0)
			else:
				# Normal ball hole completion
				print("Normal ball went in the hole")
				
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
		elif ball_height > HOLE_IN_HEIGHT_MAX and ball_height <= PIN_FLAG_HEIGHT_MAX:
			# Ball hit the pin flag - apply reflection effect
			print("Pin flag hit! Ball height:", ball_height, "applying 75% velocity reduction")
			
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
				print("Pin flag reflection applied - velocity reduced from", current_velocity.length(), "to", reduced_velocity.length())
			else:
				print("Warning: Golf ball doesn't have set_velocity method")
		else:
			print("Ball collision detected but height not in range for hole-in or pin flag reflection:", ball_height)
	else:
		print("Area entered but parent doesn't have get_height method or is not a golf ball") 

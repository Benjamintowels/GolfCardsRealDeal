extends Node2D

# Test script for the new launch flow
# This will help verify that the height selection → power charge → launch flow works correctly

var launch_manager: LaunchManager
var test_phase := 0
var test_results := []

func _ready():
	print("=== Testing New Launch Flow ===")
	print("Expected flow: Height Selection → Power Charge → Launch")
	
	# Create a test launch manager
	launch_manager = LaunchManager.new()
	add_child(launch_manager)
	
	# Set up test data
	launch_manager.camera = Camera2D.new()
	launch_manager.ui_layer = Control.new()
	launch_manager.player_node = Node2D.new()
	launch_manager.cell_size = 48
	launch_manager.chosen_landing_spot = Vector2(500, 300)
	launch_manager.selected_club = "Driver"
	launch_manager.club_data = {
		"Driver": {
			"max_distance": 1200.0,
			"min_distance": 300.0,
			"trailoff_forgiveness": 0.8,
			"is_putter": false
		}
	}
	launch_manager.player_stats = {"strength": 0}
	
	# Start the test
	start_test()

func start_test():
	print("\n--- Test Phase 1: Enter Launch Phase ---")
	launch_manager.enter_launch_phase()
	
	# Check if height selection phase started
	if launch_manager.is_selecting_height:
		print("✓ Height selection phase started correctly")
		test_results.append("Height selection phase started")
	else:
		print("✗ Height selection phase did not start")
		test_results.append("Height selection phase failed to start")
	
	# Simulate height selection
	print("\n--- Test Phase 2: Height Selection ---")
	simulate_height_selection()

func simulate_height_selection():
	# Simulate mouse movement to set height
	var mouse_motion_event = InputEventMouseMotion.new()
	mouse_motion_event.relative = Vector2(0, -50)  # Move mouse up
	
	# Process the event
	var handled = launch_manager.handle_input(mouse_motion_event)
	if handled:
		print("✓ Height selection input handled correctly")
		print("  Current height: ", launch_manager.launch_height)
		test_results.append("Height selection input handled")
	else:
		print("✗ Height selection input not handled")
		test_results.append("Height selection input failed")
	
	# Simulate left click to confirm height
	var mouse_click_event = InputEventMouseButton.new()
	mouse_click_event.button_index = MOUSE_BUTTON_LEFT
	mouse_click_event.pressed = true
	
	handled = launch_manager.handle_input(mouse_click_event)
	if handled and launch_manager.is_charging and not launch_manager.is_selecting_height:
		print("✓ Height confirmed, power charging started")
		test_results.append("Height confirmed, power charging started")
	else:
		print("✗ Height confirmation failed")
		test_results.append("Height confirmation failed")

func _process(delta):
	if test_phase == 0 and launch_manager.is_charging:
		test_phase = 1
		print("\n--- Test Phase 3: Power Charging ---")
		simulate_power_charging()
	elif test_phase == 1 and not launch_manager.is_charging and not launch_manager.is_selecting_height:
		test_phase = 2
		print("\n--- Test Complete ---")
		print_test_results()

func simulate_power_charging():
	# Let power charge for a bit
	await get_tree().create_timer(0.5).timeout
	
	# Simulate releasing left click to finish charging
	var mouse_release_event = InputEventMouseButton.new()
	mouse_release_event.button_index = MOUSE_BUTTON_LEFT
	mouse_release_event.pressed = false
	
	var handled = launch_manager.handle_input(mouse_release_event)
	if handled:
		print("✓ Power charging completed, launch should have occurred")
		test_results.append("Power charging completed")
	else:
		print("✗ Power charging completion failed")
		test_results.append("Power charging completion failed")

func print_test_results():
	print("\n=== Test Results ===")
	for result in test_results:
		print("• ", result)
	
	var success_count = test_results.size()
	print("\nTotal test phases completed: ", success_count, "/3")
	
	if success_count == 3:
		print("🎉 All tests passed! New launch flow is working correctly.")
	else:
		print("❌ Some tests failed. Check the implementation.")
	
	# Clean up
	launch_manager.queue_free()
	queue_free() 
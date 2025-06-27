extends Node2D

# This is an invisible obstacle that blocks movement
# but doesn't affect the visual appearance of the ground tile underneath

func blocks() -> bool:
	return true 
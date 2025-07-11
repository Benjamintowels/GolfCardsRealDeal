# WorldTurnManager Setup Instructions

## Adding WorldTurnManager to Course1 Scene

### Step 1: Add WorldTurnManager Scene to Course1

1. Open your `Course1.tscn` scene in Godot
2. In the Scene tree, right-click on the root node (Course1)
3. Select "Instance Child Scene"
4. Navigate to `res://NPC/WorldTurnManager.tscn`
5. Select it and click "Open"
6. The WorldTurnManager should now appear as a child of Course1

### Step 2: Verify Scene Structure

Your scene tree should look like this:
```
Course1 (course_1.gd)
├── UILayer
├── GameCamera
├── Player
├── NPC
│   ├── Animals
│   ├── Gang
│   └── ...
├── WorldTurnManager (world_turn_manager.gd)  ← This should be here
└── ... (other nodes)
```

### Step 3: Test the Integration

1. Run the game
2. Look for these debug messages in the console:
   - "=== WORLD TURN MANAGER INITIALIZED ==="
   - "Found course reference: Course1"
   - "✓ Connected to player_turn_ended signal"
   - "NPC REGISTRATION ATTEMPT" (when NPCs load)

### Step 4: Test World Turn

1. Play the game until you can end a turn
2. Press the "End Turn" button
3. You should see:
   - "=== STARTING WORLD TURN SEQUENCE ==="
   - "WorldTurnManager found: WorldTurnManager"
   - "=== PLAYER TURN ENDED - STARTING WORLD TURN ==="
   - NPC turn processing messages

## Troubleshooting

### If WorldTurnManager is not found:
- Check that the WorldTurnManager scene is properly instanced in Course1
- Verify the path in course_1.gd: `@onready var world_turn_manager: Node = $WorldTurnManager`

### If NPCs are not registering:
- Check that NPCs can find the WorldTurnManager at the correct path
- Look for "Found WorldTurnManager at path:" messages in console
- Verify NPC scripts are updated to use the new registration system

### If world turn doesn't start:
- Check that the `player_turn_ended` signal is being emitted
- Verify the signal connection in WorldTurnManager
- Look for "WorldTurnManager received player_turn_ended signal" message

### If camera transitions don't work:
- Verify that `transition_camera_to_npc()` and `transition_camera_to_player()` methods exist in course_1.gd
- Check that the camera reference is properly set in WorldTurnManager

## Expected Debug Output

When working correctly, you should see:
```
=== WORLD TURN MANAGER INITIALIZED ===
Found course reference: Course1
Setting up signal connections with course: Course1
✓ Connected to player_turn_ended signal
Camera reference: GameCamera
End turn button: EndTurnButton
Turn message display: None
WorldTurnManager ready

=== NPC REGISTRATION ATTEMPT ===
NPC: Squirrel1
NPC valid: true
Already registered: false
✓ Registered NPC: Squirrel1 (Total NPCs: 1)
✓ Connected to turn_completed signal
=== END NPC REGISTRATION ===

=== STARTING WORLD TURN SEQUENCE ===
WorldTurnManager found: WorldTurnManager
=== PLAYER TURN ENDED - STARTING WORLD TURN ===
WorldTurnManager received player_turn_ended signal
Current registered NPCs: 1
  - Squirrel1 (valid)
=== STARTING WORLD TURN SEQUENCE ===
```

## Fallback System

If the WorldTurnManager is not found, the system will automatically fall back to the old NPC turn system (`start_npc_turn_sequence()`), so your game will continue to work even if there are setup issues. 
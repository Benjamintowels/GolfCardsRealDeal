# Manager Architecture Writeup

## Overview

The GolfCards game uses a comprehensive manager-based architecture where each manager handles specific aspects of the game. This document outlines how all managers are wired together, their responsibilities, and tips for setup and maintenance.

## Core Manager Hierarchy

### 1. Course1.gd (Main Controller)
**Location**: `course_1.gd`  
**Role**: Central orchestrator that initializes and coordinates all other managers  
**Key Responsibilities**:
- Initializes all managers in the correct order
- Provides cross-manager communication
- Handles the main game loop and state transitions
- Manages the scene tree structure

**Initialization Order** (critical for proper setup):
1. GameStateManager (needed by other managers)
2. SoundManager
3. CardEffectHandler
4. MovementController
5. AttackHandler
6. WeaponHandler
7. GridManager
8. PlayerManager
9. CameraManager
10. UIManager
11. EquipmentManager
12. DeckManager

### 2. GameStateManager
**Location**: `GameStateManager.gd`  
**Role**: Central game state and phase management  
**Key Responsibilities**:
- Tracks current game phase (tee_select, draw_cards, club_selection, aiming, launch, ball_flying, move)
- Manages hole progression and scoring
- Handles shot tracking and ball landing positions
- Manages club selection and cycling
- Tracks puzzle types and shop interactions
- Coordinates with other managers for state transitions

**Special Cases**:
- Must be initialized first as other managers depend on it
- Handles the complex interaction between aiming, launching, and movement phases
- Manages the gimme mechanic and ball reach system

### 3. PlayerManager
**Location**: `PlayerManager.gd`  
**Role**: Player character and stats management  
**Key Responsibilities**:
- Manages player position and grid coordinates
- Handles player stats (health, mobility, etc.)
- Manages special modes (ghost, vampire, dodge)
- Coordinates with health bars and block system
- Handles character selection and base stats

**Setup Requirements**:
- Requires grid_size, cell_size, obstacle_map, ysort_objects, shop_grid_pos
- Needs references to health_bar and block_health_bar
- Must be set up after GridManager but before CameraManager

### 4. GridManager
**Location**: `GridManager.gd`  
**Role**: Grid system and tile management  
**Key Responsibilities**:
- Creates and manages the game grid
- Handles tile highlighting (movement, attack, general)
- Manages flashlight effect system
- Provides grid coordinate utilities
- Manages camera container positioning

**Key Features**:
- Creates grid tiles with multiple highlight layers (red, green, orange)
- Implements flashlight effect for visibility
- Provides camera offset calculations
- Manages tile input events

### 5. CameraManager
**Location**: `CameraManager.gd`  
**Role**: Camera control and positioning  
**Key Responsibilities**:
- Manages camera following and panning
- Handles camera transitions between phases
- Manages aiming camera tracking
- Coordinates with background parallax
- Handles pin-to-tee transitions

**Special Features**:
- Implements smooth camera following with tweens
- Manages camera panning with mouse input
- Handles stationary camera mode (middle mouse)
- Coordinates with aiming circle system

### 6. UIManager
**Location**: `UIManager.gd`  
**Role**: User interface coordination  
**Key Responsibilities**:
- Manages all UI dialogs and overlays
- Handles button states and interactions
- Coordinates movement and card UI
- Manages shop and inventory interfaces
- Handles character display and selection

**Setup Requirements**:
- Requires references to all other managers for UI coordination
- Must be set up after other managers are initialized
- Manages complex UI state transitions

### 7. DeckManager
**Location**: `DeckManager.gd`  
**Role**: Card deck and hand management  
**Key Responsibilities**:
- Manages separate club and action card piles
- Handles card drawing, discarding, and recycling
- Coordinates with CurrentDeckManager for persistence
- Manages hand state and card availability
- Handles deck synchronization

**Special Features**:
- Implements ordered deck system for proper card tracking
- Maintains separate discard piles for clubs and actions
- Syncs with CurrentDeckManager for deck persistence
- Handles card recycling mechanics

### 8. MovementController
**Location**: `MovementController.gd`  
**Role**: Player movement and card interaction  
**Key Responsibilities**:
- Handles movement card selection and execution
- Manages movement range calculations
- Coordinates with AttackHandler and WeaponHandler
- Handles card button creation and management
- Manages movement mode state

**Key Integration**:
- Routes attack cards to AttackHandler
- Routes weapon cards to WeaponHandler
- Manages movement card execution
- Coordinates with GridManager for tile highlighting

### 9. AttackHandler
**Location**: `AttackHandler.gd`  
**Role**: Attack card execution and combat  
**Key Responsibilities**:
- Handles attack card selection and execution
- Manages attack range and targeting
- Handles different attack types (single, AOE, special)
- Coordinates with NPC damage system
- Manages attack animations and effects

**Special Features**:
- Supports multiple attack types (Kick, Punch, BurstShot, etc.)
- Implements AOE attack patterns
- Handles special attack mechanics (AssassinDash, etc.)
- Coordinates with sound effects and animations

### 10. WeaponHandler
**Location**: `WeaponHandler.gd`  
**Role**: Weapon card execution and aiming  
**Key Responsibilities**:
- Handles weapon card selection and execution
- Manages weapon aiming and targeting
- Handles different weapon types (pistol, knife, grenade, etc.)
- Coordinates with LaunchManager for projectile weapons
- Manages weapon-specific UI and effects

**Special Features**:
- Supports multiple weapon types with different mechanics
- Implements aiming systems for different weapons
- Handles projectile weapons through LaunchManager
- Manages weapon-specific sound effects and animations

### 11. LaunchManager
**Location**: `LaunchManager.gd`  
**Role**: Ball and projectile launching system  
**Key Responsibilities**:
- Manages golf ball launching mechanics
- Handles power and height charging
- Coordinates with weapon projectiles
- Manages launch animations and effects
- Handles different launch modes (ball, knife, grenade, spear)

**Special Features**:
- Implements power meter system
- Handles height selection for arc shots
- Supports multiple projectile types
- Coordinates with camera for aiming

### 12. EquipmentManager
**Location**: `EquipmentManager.gd`  
**Role**: Equipment and clothing system  
**Key Responsibilities**:
- Manages equipped items and their effects
- Handles clothing slots (head, neck, body)
- Applies equipment bonuses (mobility, strength, card draw)
- Manages drone zoom effects
- Coordinates with player visualization

**Special Features**:
- Implements clothing slot system
- Manages equipment effects and bonuses
- Handles drone zoom functionality
- Coordinates with player sprite for clothing display

### 13. SoundManager
**Location**: `SoundManager.gd`  
**Role**: Audio system coordination  
**Key Responsibilities**:
- Manages all game audio
- Handles UI sounds, swing sounds, collision sounds
- Coordinates player sound effects
- Manages card stack sounds
- Handles global audio events

**Setup Requirements**:
- Requires references to various AudioStreamPlayer2D nodes
- Must be set up early as other systems depend on sound
- Manages complex audio state across different game phases

### 14. MapManager
**Location**: `MapManager.gd`  
**Role**: Map data and tile state management  
**Key Responsibilities**:
- Loads and manages map layout data
- Tracks tile states (scorched, iced)
- Provides tile type queries
- Manages map modifications
- Coordinates with obstacle system

**Special Features**:
- Tracks fire damage tiles (scorched)
- Tracks ice effect tiles
- Provides tile state queries for effects
- Manages map data persistence

### 15. BackgroundManager
**Location**: `BackgroundManager.gd`  
**Role**: Background theme and parallax management  
**Key Responsibilities**:
- Manages different background themes
- Handles parallax layer setup
- Coordinates background transitions
- Manages background scaling and positioning
- Handles theme-specific effects

**Special Features**:
- Supports multiple background themes
- Implements parallax scrolling
- Handles background layer management
- Coordinates with camera movement

### 16. WorldTurnManager
**Location**: `NPC/world_turn_manager.gd`  
**Role**: NPC turn management and coordination  
**Key Responsibilities**:
- Manages all NPC turns with priority system
- Handles turn validation and sequencing
- Coordinates camera transitions during NPC turns
- Manages together mode for simultaneous NPC actions
- Handles turn completion tracking

**Special Features**:
- Implements priority-based turn order
- Supports together mode for simultaneous actions
- Handles frozen NPC state management
- Coordinates with camera for NPC turn viewing

### 17. MoneyManager
**Location**: `Money/moneymanager.gd`  
**Role**: Currency system management  
**Key Responsibilities**:
- Manages $Looty currency
- Handles currency transactions
- Provides hole completion rewards
- Manages currency persistence
- Coordinates with shop system

**Special Features**:
- Implements starting currency system
- Provides random reward generation
- Handles currency validation
- Coordinates with shop purchases

## Manager Wiring and Dependencies

### Initialization Chain
```gdscript
# In course_1.gd _ready() function
1. game_state_manager = GameStateManager.new()
2. sound_manager = SoundManager.new()
3. card_effect_handler = CardEffectHandler.new()
4. movement_controller = MovementController.new()
5. attack_handler = AttackHandler.new()
6. weapon_handler = WeaponHandler.new()
7. grid_manager = GridManager.new()
8. player_manager = PlayerManager.new()
9. camera_manager = CameraManager.new()
10. ui_manager = UIManager.new()
11. equipment_manager = EquipmentManager.new()
12. deck_manager = DeckManager.new()
```

### Cross-Manager References
Each manager receives references to other managers it needs to coordinate with:

```gdscript
# Example: UIManager setup
ui_manager.setup($UILayer, self, player_manager, grid_manager, 
                camera_manager, deck_manager, movement_controller, 
                attack_handler, weapon_handler, launch_manager)

# Example: GameStateManager setup
game_state_manager.setup(self, ui_manager, map_manager, build_map, 
                        player_manager, grid_manager, camera_manager, 
                        deck_manager, movement_controller, attack_handler, 
                        weapon_handler, launch_manager)
```

### Signal Connections
Managers communicate through signals for loose coupling:

```gdscript
# Example signal connections
deck_manager.deck_updated.connect(ui_manager.update_deck_display)
deck_manager.discard_recycled.connect(card_stack_display.animate_card_recycle)
world_turn_manager.npc_turn_started.connect(_on_turn_started)
world_turn_manager.npc_turn_ended.connect(_on_turn_ended)
```

## Special Cases and Tips

### 1. Initialization Order is Critical
- GameStateManager must be first (others depend on it)
- SoundManager should be early (used by many systems)
- UIManager should be late (depends on other managers)
- EquipmentManager and DeckManager can be last

### 2. Manager References
- Always use the setup() pattern for manager initialization
- Pass references explicitly rather than using get_node() calls
- Use signals for cross-manager communication when possible
- Avoid circular dependencies

### 3. State Management
- GameStateManager is the source of truth for game phases
- Other managers should query GameStateManager for current state
- Use signals to notify state changes rather than direct calls

### 4. Performance Considerations
- SmartPerformanceOptimizer coordinates expensive operations
- Managers should defer expensive operations when possible
- Use call_deferred() for operations that depend on scene tree setup

### 5. Debug and Testing
- Each manager should have clear debug output
- Use print statements for initialization confirmation
- Test manager interactions in isolation when possible
- Verify signal connections are working

### 6. Adding New Managers
When adding a new manager:

1. **Create the manager class** with proper setup() method
2. **Add initialization** in course_1.gd _ready() function
3. **Pass required references** in setup() call
4. **Connect signals** if needed
5. **Update other managers** that need to reference the new manager
6. **Test integration** thoroughly

### 7. Common Pitfalls
- **Circular dependencies**: Avoid managers that depend on each other
- **Late initialization**: Don't access managers before they're set up
- **Missing references**: Always verify all required references are passed
- **Signal disconnection**: Remember to disconnect signals when cleaning up
- **State inconsistency**: Keep manager states synchronized

### 8. Debugging Tips
- Use print statements to track initialization order
- Check signal connections are working
- Verify all required references are passed
- Test manager interactions in isolation
- Use Godot's debugger to inspect manager states

## File Structure
```
golfcards/
├── course_1.gd                    # Main controller
├── GameStateManager.gd            # Game state management
├── PlayerManager.gd               # Player management
├── GridManager.gd                 # Grid system
├── CameraManager.gd               # Camera control
├── UIManager.gd                   # UI coordination
├── DeckManager.gd                 # Card deck management
├── MovementController.gd          # Movement system
├── AttackHandler.gd               # Attack system
├── WeaponHandler.gd               # Weapon system
├── LaunchManager.gd               # Launch system
├── EquipmentManager.gd            # Equipment system
├── SoundManager.gd                # Audio system
├── MapManager.gd                  # Map management
├── BackgroundManager.gd           # Background system
├── NPC/
│   └── world_turn_manager.gd      # NPC turn management
├── Money/
│   └── moneymanager.gd            # Currency system
└── current_deck_manager.gd        # Deck persistence
```

This architecture provides a clean separation of concerns while maintaining the flexibility needed for a complex game like GolfCards. Each manager handles its specific domain while coordinating with others through well-defined interfaces. 
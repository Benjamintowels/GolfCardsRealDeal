# Block Card System

## Overview

The Block card system provides defensive capabilities to the player by creating a temporary shield that absorbs damage before it affects the player's actual health. When the Block card is played, a blue health bar appears above the regular green health bar, representing 25 block points that must be depleted before damage affects the player's real health.

## Components

### 1. BlockB Card
- **Location**: `res://Cards/BlockB.tres`
- **Effect Type**: "Block"
- **Base Block Points**: 25 (multiplied by card strength)
- **Card Image**: `res://Cards/BlockB.png`
- **Purpose**: Activates the block system when played

### 2. BlockHealthBar
- **Script**: `res://BlockHealthBar.gd`
- **Scene**: `res://BlockHealthBar.tscn`
- **Visual**: Blue progress bar positioned above the regular health bar
- **Default State**: Hidden (visible = false)
- **Purpose**: Displays current block points to the player

### 3. Block Sprite System
- **Block Sprite**: `res://Characters/Block.png`
- **Scene Integration**: Added to `BennyChar.tscn` as "BennyBlock" node
- **Default State**: Hidden (visible = false)
- **Purpose**: Shows the blocking pose when block is active (Benny character only)

### 4. Course Integration
The course script (`course_1.gd`) manages the block system:
- **Variables**: `block_active`, `block_amount`
- **Methods**: `activate_block()`, `clear_block()`, `has_block()`, `get_block_amount()`
- **Sprite Switching**: `switch_to_block_sprite()`, `switch_to_normal_sprite()`

## How It Works

### Block Activation
1. **Card Played**: Player uses BlockB card from hand or bag
2. **Effect Handler**: `CardEffectHandler.handle_block_effect()` processes the card
3. **Block Calculation**: Block points = 25 × card strength
4. **Course Activation**: `course.activate_block(amount)` is called
5. **Visual Updates**: 
   - BlockHealthBar becomes visible and shows block points
   - Benny character switches to Block sprite (if playing as Benny)
6. **Card Discard**: Block card is discarded from hand

### Damage Absorption
1. **Damage Taken**: Player takes damage from any source
2. **Block Check**: `course.take_damage()` checks if block is active
3. **Block Absorption**: Damage is applied to block points first
4. **Remaining Damage**: Any damage exceeding block points goes to real health
5. **Block Depletion**: If block reaches 0, it's automatically cleared

### Block Clearing
1. **End of Turn**: Block is automatically cleared at the end of each turn
2. **Manual Clearing**: Block can be manually cleared via `clear_block()`
3. **Visual Reset**: 
   - BlockHealthBar becomes hidden
   - Benny character switches back to normal sprite
4. **State Reset**: `block_active = false`, `block_amount = 0`

## Implementation Details

### BlockHealthBar.gd
```gdscript
# Key methods:
func set_block(current: int, maximum: int)  # Set block points
func take_block_damage(amount: int) -> int  # Take damage, return remaining
func clear_block()  # Clear all block points
func has_block() -> bool  # Check if block is active
```

### course_1.gd Block Methods
```gdscript
func activate_block(amount: int)  # Activate block system
func switch_to_block_sprite()  # Switch Benny to block sprite
func switch_to_normal_sprite()  # Switch Benny back to normal
func clear_block()  # Clear block and reset sprites
func has_block() -> bool  # Check if block is active
func get_block_amount() -> int  # Get current block points
```

### Damage Handling
```gdscript
func take_damage(amount: int) -> void:
    var damage_to_health = amount
    
    # Check if block is active and apply damage to block first
    if block_active and block_health_bar and block_health_bar.has_block():
        damage_to_health = block_health_bar.take_block_damage(amount)
        block_amount = block_health_bar.get_block_amount()
        
        # If block is depleted, clear it
        if not block_health_bar.has_block():
            clear_block()
    
    # Apply remaining damage to health
    if health_bar and damage_to_health > 0:
        health_bar.take_damage(damage_to_health)
```

## Visual Elements

### Health Bar Layout
```
┌─────────────────────────────────┐
│ BlockHealthBar (Blue) - 25/25   │  ← Block points
├─────────────────────────────────┤
│ HealthBar (Green) - 100/100     │  ← Real health
└─────────────────────────────────┘
```

### Character Sprite Switching
- **Normal State**: Shows regular character sprite
- **Block Active**: Shows Block sprite (Benny only)
- **Automatic**: Switches back when block is cleared

## Testing

### Test Scene
- **File**: `test_block_system.tscn`
- **Script**: `test_block_system.gd`
- **Usage**: Test block activation, damage absorption, and clearing

### Manual Testing
1. Load the test scene
2. Click "Test Block (25 pts)" to activate block
3. Click "Take 15 Damage" to test damage absorption
4. Click "Clear Block" to manually clear block
5. Observe the blue health bar and sprite changes

### In-Game Testing
1. Start a round with Benny character
2. Draw a BlockB card
3. Use the BlockB card to activate block
4. Take damage from enemies or hazards
5. Observe block absorbing damage before health
6. Verify block clears at end of turn

## Configuration

### Block Points
- **Base Amount**: 25 points
- **Scaling**: Multiplied by card strength
- **Location**: `CardEffectHandler.handle_block_effect()`

### Health Bar Positioning
- **BlockHealthBar**: `offset_top = 375.53`
- **HealthBar**: `offset_top = 415.53`
- **Location**: `Course1.tscn`

### Sprite Detection
The system automatically finds sprites by:
1. Searching for "Sprite2D" (normal sprite)
2. Searching for "BennyBlock" (block sprite)
3. Switching visibility between them

## Future Enhancements

### Multi-Character Support
- Add block sprites for Layla and Clark characters
- Modify sprite detection to work with all character types
- Create character-specific block animations

### Block Variations
- Add different block types (fire block, ice block, etc.)
- Implement block regeneration over time
- Add block-breaking effects for certain attacks

### Visual Effects
- Add block activation/deactivation animations
- Implement block damage visual feedback
- Add particle effects for block absorption 
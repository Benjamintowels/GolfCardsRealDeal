# Driving Range Minigame

## Overview

The Driving Range is a standalone minigame that allows players to practice their golf shots in a simplified environment. Players take 10 shots per session, trying to achieve the longest drive distance possible.

## Features

### Core Gameplay
- **Player Placement**: Player automatically starts on the tee (far left of the range)
- **Random Club Selection**: Each shot offers 2 random clubs from the full club pool
- **Auto-Aiming**: Aiming circle is automatically placed at the club's max distance to the right
- **Power & Height Charging**: Standard power meter and height selection system
- **Distance Tracking**: Each shot's distance is measured and displayed
- **Record System**: Persistent record keeping for longest drive
- **Session Management**: 10 shots per session with session completion dialog

### Visual Elements
- **Wide Layout**: 250 tiles wide, 10 tiles tall for maximum driving distance
- **Parallax Background**: Same background system as main game
- **Aiming Circle**: Red circle shows target distance with distance label
- **Camera Following**: Camera follows ball flight and returns to player
- **Distance Dialog**: Shows shot distance, record status, and shot counter

### UI Components
- **Draw Club Cards Button**: Appears at start of each shot
- **Power Meter**: Standard power charging system
- **HUD Display**: Shows current shot counter and record distance
- **Return Button**: Allows early exit to main menu
- **Session Complete Dialog**: Shows final results

## File Structure

### Main Files
- `Stages/DrivingRange.tscn` - Main driving range scene
- `Stages/driving_range.gd` - Driving range logic script
- `Maps/DrivingRangeLayout.gd` - Layout definition (250x10 grid)
- `UI/DrivingRangeDistanceDialog.tscn` - Distance display dialog
- `UI/DrivingRangeDistanceDialog.gd` - Dialog logic script

### Test Files
- `test_driving_range.tscn` - Test scene for development

## Game Flow

### Session Start
1. Player is placed on tee position (8, 0)
2. Camera positioned on player
3. Background parallax system initialized
4. First shot begins

### Shot Sequence
1. **Draw Clubs**: Player clicks "Draw Club Cards" button
2. **Club Selection**: 2 random clubs displayed, player selects one
3. **Auto-Aiming**: Aiming circle placed at club's max distance
4. **Height Selection**: Player sets shot height (mouse up/down)
5. **Power Charging**: Player charges power (hold left click)
6. **Ball Launch**: Ball flies toward target
7. **Distance Calculation**: Distance measured from tee to landing
8. **Distance Dialog**: Shows results and record status
9. **Next Shot**: Camera returns to player, new ball placed

### Session End
1. After 10 shots, session complete dialog appears
2. Shows total shots, best distance, and current record
3. Player can return to main menu

## Club System

### Available Clubs
- **Driver**: 1200px max distance
- **Hybrid**: 1050px max distance  
- **Wood**: 800px max distance
- **Iron**: 600px max distance
- **Wooden**: 350px max distance
- **Putter**: 200px max distance
- **PitchingWedge**: 200px max distance
- **FireClub**: 800px max distance
- **IceClub**: 800px max distance
- **GrenadeLauncherClubCard**: 2000px max distance

### Club Selection
- 2 random clubs offered per shot
- All clubs have equal chance of appearing
- No deck management - pure random selection

## Record System

### Persistence
- Records saved to `user://driving_range_record.save`
- Simple float value storage
- Automatically loads on session start

### Record Updates
- New record detected when shot distance > current record
- "NEW RECORD!" message displayed in distance dialog
- Record automatically saved to file

## Technical Implementation

### Scene Structure
```
DrivingRange (Control)
├── CameraContainer (Control)
│   ├── GridContainer (Control)
│   ├── Player1 (CharacterBody2D)
│   └── GolfBall (Node2D)
├── GameCamera (Camera2D)
├── MapManager (Node)
├── BuildMap (Node)
├── LaunchManager (Node)
├── BackgroundManager (Node)
└── UILayer (CanvasLayer)
    ├── DrawClubCards (Control)
    ├── PowerMeter (Control)
    ├── HUD (VBoxContainer)
    ├── ReturnToClubhouseButton (Button)
    └── DrivingRangeDistanceDialog (Control)
```

### Key Systems
- **Map Building**: Uses DrivingRangeLayout for 250x10 grid
- **Player Management**: Standard player setup with tee positioning
- **Launch System**: Reuses existing LaunchManager for consistency
- **Camera Control**: Follows ball flight and returns to player
- **UI Management**: Modular dialog system for distance display

## Usage

### Running the Minigame
1. Open `test_driving_range.tscn` in Godot
2. Press F5 to run the test scene
3. Or load `Stages/DrivingRange.tscn` directly

### Integration with Main Game
- Add button to main menu to access driving range
- Use `get_tree().change_scene_to_file("res://Stages/DrivingRange.tscn")`
- Return to main menu with `get_tree().change_scene_to_file("res://Main.tscn")`

## Customization

### Layout Changes
- Modify `Maps/DrivingRangeLayout.gd` to change grid size
- Update `grid_size` variable in driving range script
- Adjust player starting position as needed

### Session Length
- Change `max_shots` variable in driving range script
- Default is 10 shots per session

### Club Pool
- Modify `available_club_cards` array in driving range script
- Add or remove club cards as needed

### Visual Styling
- Update `UI/DrivingRangeDistanceDialog.tscn` for dialog appearance
- Modify HUD layout in driving range scene
- Adjust camera positioning and tweening

## Future Enhancements

### Potential Features
- **Multiple Difficulty Levels**: Different club pools or layouts
- **Achievement System**: Distance milestones and rewards
- **Statistics Tracking**: Average distance, consistency metrics
- **Weather Effects**: Wind, rain affecting ball flight
- **Target Practice**: Specific distance targets for accuracy
- **Multiplayer**: Compare distances with other players

### Technical Improvements
- **Performance Optimization**: Large layout may need optimization
- **Save System**: More comprehensive statistics saving
- **Audio Integration**: Club-specific sound effects
- **Particle Effects**: Ball trail, impact effects
- **Mobile Support**: Touch controls for mobile devices 
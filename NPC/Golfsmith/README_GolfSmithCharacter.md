### GolfSmithCharacter Integration

Summary
- Scene: `res://NPC/Golfsmith/GolfSmithCharacter.tscn`
- Script: `res://NPC/Golfsmith/golf_smith_character.gd`
- Purpose: Friendly NPC that appears on random holes (if quest not complete) and always in FightRoom for testing. Takes a WorldTurn with highest priority, can block for 30, and attacks enemies for 45 when within 2 tiles.

Collision with GolfBall
- The scene uses `BodyArea2D` for the body collision area so `GolfBall.gd` will route collisions to `_handle_ball_collision`.
- The script sets `BodyArea2D` to collision layer/mask 1 and connects `area_entered/area_exited`.
- Collision handling first delegates to `Entities.handle_npc_ball_collision` for unified behavior; falls back to velocity damage/reflect.

Y-Sort
- The scene includes `TopHeight` and `YSortPoint` markers.
- The script implements `get_height()` and `get_y_sort_point()` and calls `Global.update_object_y_sort(self, "characters")` on move.

WorldTurn and Priority
- In `_ready()`, the node registers with `NPC/world_turn_manager.gd` and `Entities`.
- `take_turn()` implements simple AI and emits `turn_completed`.
- For highest priority, ensure your priority function returns the max for GolfSmith (see `GameStateManager.get_npc_priority`).

AI Rules
- If the nearest enemy (GangMember/ZombieGolfer/Police) is within 2 tiles, move one tile toward them and apply 45 damage to enemies overlapping/adjacent.
- Otherwise, greedily step away from the nearest enemy up to 3 tiles.
- At end of turn, activates block for 30.

Blocking
- The script manages a `BlockHealthBar` instance, switching the default sprite to `GolfSmithBlockSprite` while block is active.
- `world_turn_started` clears block at the start of each world turn.

Spawning
- Use `GolfSmithCharacter.should_spawn_this_round()` to decide if GolfSmith appears on hole start (false if Golfsmith quest is completed).
- For testing, spawn GolfSmith on FightRoom maps regardless of quest state.



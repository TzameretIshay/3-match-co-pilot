# Match-3 Game: Phase 1 Complete - Booster & Win/Lose System

## ✅ Booster Inventory System

### Features:
- **Per-Game Inventory**: Each selected booster starts with **3 uses** per game
- **Real-time Tracking**: Uses are decremented immediately when activated
- **Visual Feedback**: 
  - Booster buttons show remaining uses (e.g., "Color Bomb (3)")
  - Buttons auto-disable when depleted
  - Text updates dynamically during gameplay

### Implementation:
- **Initialization** (`Grid.gd` `set_run_boosters()`):
  - Booster inventory initialized when start screen confirms selection
  - Each selected booster gets 3 uses in `booster_inventory` dictionary

- **Usage** (`Grid.gd` `_on_booster_ui_pressed()`):
  - Player clicks booster button
  - System checks remaining uses
  - Deducts one use and updates UI
  - Applies booster to random valid tile on board
  - Triggers full clear/refill/cascade flow

- **UI Updates** (`Grid.gd` `_update_booster_ui()`):
  - Called after each booster activation
  - Finds booster button in UI
  - Updates text with new remaining uses
  - Disables button if uses reach 0

---

## ✅ Win/Lose Conditions System

### Victory Condition:
- **Default Goal**: 1000 points
- **Triggering**: After any match clears and no more cascades occur
- **Messaging**: "VICTORY! Congratulations!"
- **Button**: "Next Level" appears (increase difficulty)

### Defeat Condition:
- **Trigger**: Moves exhausted (0 moves remaining)
- **Checked After**: Each turn completes, matches settle
- **Messaging**: "GAME OVER - You ran out of moves!"
- **Button**: "Restart" only (replay current level)

### Game Over Screen ([GameOverScreen.gd](GameOverScreen.gd)):

#### Display Information:
- **Title**: "VICTORY!" (green) or "GAME OVER" (red)
- **Message**: Context-specific message
- **Stats**:
  - Current Score / Goal Score
  - Score % of goal
  - Moves Used / Total Moves
  
Example: 
```
VICTORY!
Congratulations! You reached the goal!
Score: 1250 / 1000 (125%)
Moves used: 18 / 30
```

#### Actions:
- **Restart**: Replay current level with same difficulty
- **Next Level**: Increase difficulty:
  - Goal score increases by 1.5×
  - Moves decrease by 2 (minimum 20)

### Implementation Details:

**Checking** ([Grid.gd](Grid.gd) `_check_game_over()`):
```gdscript
func _check_game_over() -> void:
    var is_victory = score >= goal_score
    var is_defeat = moves_left <= 0
    
    if is_victory or is_defeat:
        _show_game_over_screen(is_victory)
```

**Triggering Points** ([Grid.gd](Grid.gd)):
1. After swaps complete and matches settle (line 667)
2. After booster clears and cascades settle (line 762)

**Screen Creation** ([Grid.gd](Grid.gd) `_show_game_over_screen()`):
- Instantiates GameOverScreen
- Passes: score, goal, victory flag, moves used/total
- Connects restart/next level signals to Grid

**Progression** ([Grid.gd](Grid.gd) `_on_next_level_requested()`):
```gdscript
goal_score = int(goal_score * 1.5)      # 1000 → 1500 → 2250...
moves_limit = max(20, moves_limit - 2)   # 30 → 28 → 26... (min 20)
reset_game()
```

---

## 🎮 Gameplay Flow

```
Start Screen
    ↓
Select 0-3 Boosters (3 uses each)
    ↓
Game Starts
    ├─ Make Matches → Score Points
    ├─ Use Boosters (up to 3 times each)
    └─ Continue Until:
        ├─ Score ≥ Goal → VICTORY
        └─ Moves = 0 → DEFEAT
            ↓
        Game Over Screen
        ├─ Restart → Same Level, Reset Score
        └─ Next Level → Harder Goal, Fewer Moves
```

---

## 📊 Configuration

**Exported Variables** ([Grid.gd](Grid.gd)):
- `goal_score`: Target points to win (default 1000)
- `moves_limit`: Starting moves per level (default 30)

**Booster Uses**: Hardcoded to 3 per game (can be made configurable)

**Difficulty Scaling**:
- Level 1: 1000 points, 30 moves
- Level 2: 1500 points, 28 moves
- Level 3: 2250 points, 26 moves
- Level 4: 3375 points, 24 moves (minimum moves = 20)

---

## 🐛 Testing Checklist

- [ ] Start game, select boosters, verify they appear on right panel
- [ ] Use a booster, see uses decrement (3→2→1→0)
- [ ] Booster button disables when out of uses
- [ ] Score updates on matches
- [ ] Reach goal score → Victory screen appears
- [ ] Run out of moves → Defeat screen appears
- [ ] Click Restart → Same level, score resets to 0
- [ ] Click Next Level → Goal increases, moves decrease
- [ ] Victory screen shows percentage (125% = exceeding goal)
- [ ] Defeat screen shows moves used / total

---

## 📝 Files Modified

1. **Grid.gd** - Booster inventory, game over checking
2. **GameOverScreen.gd** - Enhanced messaging with stats
3. **GameOverScreen.tscn** - Updated UI with stats label
4. **UI.gd** - No changes (already displays score/moves)


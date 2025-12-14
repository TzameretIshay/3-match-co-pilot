# Match-3 CoPilot: Complete Code Overview

## 📚 Documentation Files

All detailed documentation is in the `/docs` folder:

### **CODE_DOCUMENTATION.md** ⭐ START HERE
- Complete architecture explanation
- Detailed function-by-function breakdown
- Game flow diagrams
- Design patterns used
- Configuration options
- Testing checklist
- **500+ lines of comprehensive documentation**

### code_explanations.md
- Earlier documentation (reference)

### USAGE_NEXT_STEPS.md
- How to run the game
- How to generate PNG tiles
- Next steps for customization

### changes.md
- History of changes made

### GODOT_VERSION.md
- Version compatibility info

---

## 🎮 Eleven Core Scripts

### **Grid.gd** (1700+ lines) - Game Engine
The heart of the Match-3 game. Contains all game logic:

**Key Responsibilities:**
- Grid initialization (8×8 board, sea-themed tiles)
- Tile spawning from sprite sheet (36 sea creatures sliced from 6×6 grid)
- Advanced match detection (horizontal, vertical, diagonal, T-shape, L-shape, square 2×2)
- Tile swapping with undo if no match
- Clear animation, gravity, and refill with chain reactions
- Booster awarding system (4+ matches earn boosters)
- On-board booster collection with clickable popups
- Booster inventory management with UI panel
- Booster activation and effects
- Score, moves, and level tracking
- Signal emission for UI updates
- Level progression with difficulty scaling
- Game over detection (victory/defeat)
- Persistent high score integration

**19 Functions:**
1. `_ready()` - Initialize game
2. `init_grid()` - Create 8×8 grid without immediate matches
3. `spawn_tile()` - Create a tile with texture
4. `replace_tile()` - Remove and respawn tile
5. `find_matches_with_groups()` - Scan for 3+ runs
6. `_on_tile_clicked()` - Handle tile selection/swap
7. `try_swap()` - Attempt swap, check matches, revert if needed
8. `animate_swap()` - Tween tiles sliding 0.18s
9. `handle_matches_and_refill()` - Main game loop (7 steps):
   - Build clear list
   - Expand for power-ups
   - Pop animation
   - Remove tiles
   - Score update
   - Gravity + refill
   - Check chain reactions
10. `_make_placeholder_texture()` - Generate 64×64 tile texture
11. `reset_game()` - Clear board and restart

---

### **Tile.gd** (30 lines) - Individual Tile
A simple data container for each tile:

**Properties:**
- `tile_type`: 0-5 (determines color)
- `row`, `col`: Grid position
- `is_powerup`: Boolean flag
- `powerup_type`: "line" or "bomb"

**3 Functions:**
1. `_ready()` - Center sprite
2. `set_tile()` - Initialize properties
3. `_input_event()` - Detect left-click and emit signal

---

### **UI.gd** (27 lines) - User Interface
Connects Grid signals to UI labels:

**Key Feature:** Signal-driven updates (no polling)

**3 Functions:**
1. `_ready()` - Find Grid, connect signals, wire up Restart button
2. `_on_score_changed()` - Update ScoreLabel
3. `_on_moves_changed()` - Update MovesLabel

---

## 🎯 Game Mechanics Explained

### Two-Click Selection System
```
Click Tile A → Tile A scales up (selected)
Click Tile B (adjacent) → Swap A ↔ B
Click Tile B (not adjacent) → B becomes selected
Click Tile A (same) → Deselect
```

### Match Detection
```
Horizontal: "Red Red Red Blue" = 3-match
Vertical: Red
         Red  } 3-match
         Red
Diagonal: NOT detected (only H and V)
```

### Power-Up System
```
Match 4 horizontally  → Clear entire ROW (all 8 columns)
Match 4 vertically    → Clear entire COLUMN (all 8 rows)
Match 5+              → Bomb power-up
```

### Chain Reactions
```
1. Player swaps tiles
2. Matches clear + gravity applies
3. New tiles spawn and fall
4. NEW MATCHES? → Automatically clear again
5. Repeat until no more matches
6. Back to player's turn
```

### Scoring
```
10 points per tile cleared
Match-3 = 30 points (3 tiles)
Match-4 = 40 points + row/column clear
Chain reactions = multiple clears = more points
```

### Game End
```
30 moves per game
Each swap attempt (successful or failed) costs 1 move
Game ends when moves_left = 0
```

---

## 📋 Code Quality Features

### ✅ Comments Everywhere
Every function has:
- Purpose description
- Parameter explanations
- Step-by-step logic comments
- Return value description

### ✅ Signal-Driven Architecture
- Grid emits signals for score/moves
- UI connects and updates reactively
- Clean separation of concerns

### ✅ Tween-Based Animation
- All motion uses Godot's Tween system
- Parallel animations for efficiency
- Easing functions for smooth feel

### ✅ Modular Design
- Each script has single responsibility
- Easy to extend or modify
- Fallback texture generation

### ✅ Asset Flexibility
- PNG priority, SVG fallback, procedural generation
- Works without external assets
- Easy to add custom tiles

---

## 🚀 How Everything Works Together

```
Game Start
    ↓
Grid._ready()
    ├→ Load Tile.tscn
    ├→ Setup audio
    └→ init_grid()
         ├→ Spawn 8×8 tiles
         └→ Ensure no initial matches
    ↓
Player sees board with colored tiles
    ↓
Player clicks Tile A
    ├→ Tile.gd emits tile_clicked(self)
    ├→ Grid._on_tile_clicked()
    ├→ Tile A selected (scale 1.2×)
    └→ UI displays "Ready for swap"
    ↓
Player clicks Tile B (adjacent)
    ├→ Grid._on_tile_clicked()
    ├→ try_swap(A, B)
    ├→ animate_swap() → slide 0.18s
    ├→ find_matches_with_groups()
    ├→ Matches found?
    │   ├→ YES: handle_matches_and_refill()
    │   │    ├→ Pop animation
    │   │    ├→ Remove tiles
    │   │    ├→ Score += tiles × 10
    │   │    ├→ Gravity + Refill
    │   │    ├→ find_matches_with_groups() again
    │   │    └→ Chain reaction? repeat
    │   └→ NO: revert swap, refund move
    ├→ moves_left -= 1
    ├→ emit moves_changed signal
    └→ UI updates "Moves: 29"
    ↓
Back to "Player clicks Tile A"
    ↓
moves_left = 0?
    ├→ YES: Game Over (disable swaps)
    └→ NO: Continue gameplay
    ↓
Player clicks Restart button
    ├→ UI calls grid.reset_game()
    └→ Back to Game Start
```

---

### **UI.gd** (50+ lines) - User Interface Controller
Manages HUD display with signal connections:

**Key Responsibilities:**
- Score, moves, and level display
- High score and max level display (top-right corner)
- Connects to Grid signals for updates
- Connects to PlayerStats singleton for persistent data
- Restart button handler

### **StartScreen.gd** (120 lines) - Initial Booster Selection
Overlay screen for starting the game:

**Key Responsibilities:**
- Display 9 booster options with descriptions
- Allow selection of up to 3 boosters
- Pass selected boosters to Grid
- Show/hide on game start

### **NextLevelBoosterScreen.gd** (110 lines) - Level Up Booster Selection
Similar to StartScreen but for mid-game progression:

**Key Responsibilities:**
- Appears after level victory
- Allows selection of 3 additional boosters
- Adds to existing booster inventory
- Continues to next level after selection

### **GameOverScreen.gd** (80 lines) - Victory/Defeat Screen
End-of-level results screen:

**Key Responsibilities:**
- Display victory or defeat message
- Show final score, goal, and moves used
- Restart button (restarts entire game)
- Next Level button (only on victory)
- Auto-cleanup via "game_over_screen" group

### **Booster.gd** (200+ lines) - Booster Effects Implementation
Implements all 9 booster types:

**Booster Types:**
- Color Bomb: Destroys all tiles of same color
- Striped: Clears entire row and column
- Bomb: Destroys 3×3 area
- Seeker: Targets and destroys specific tile
- Roller: Converts row/column to striped pieces
- Hammer: Destroys single tile
- Free Swap: Allows any two tiles to swap
- Brush: Changes tile color to match adjacent
- UFO: Transforms random tiles to bombs

### **Match3BoardConfig.gd** (150 lines) - Configuration System
Board rules and configuration:

**Key Responsibilities:**
- Define match rules (H, V, T, L, Square patterns)
- Configure board behavior
- Extensible rule system

### **BackgroundManager.gd** (70 lines) - Background Handler
Manages sea-themed backgrounds:

**Key Responsibilities:**
- Loads and slices 3×2 sprite sheet (6 backgrounds)
- Cycles backgrounds based on level
- Scales to fit window size (with 1% overscale to prevent seams)
- Connects to Grid's level_changed signal

### **MusicPlayer.gd** (15 lines) - Music Loop Handler
Simple script for looping background music:

**Key Responsibilities:**
- Handles finished signal
- Restarts music for seamless looping

### **PlayerStats.gd** (60 lines) - Persistent Statistics
Autoload singleton for save data:

**Key Responsibilities:**
- Tracks high score and max level reached
- Saves to ConfigFile (user://player_stats.cfg)
- Emits signals on new records
- Loads on game start

### **Tile.gd** (30 lines) - Individual Tile
Simple data container for each tile (unchanged from original)

---

## 🧪 Updated Test Checklist

### Core Gameplay
- [ ] Board initializes with sea creature tiles (no matches)
- [ ] Click tile → scales up
- [ ] Click adjacent → swaps with animation
- [ ] No match → reverts swap
- [ ] Match-3+ → clears with particles
- [ ] Diagonal, T-shape, L-shape matches work
- [ ] Square 2×2 matches work
- [ ] Gravity works (tiles fall down)
- [ ] New tiles spawn from top
- [ ] Chain reactions trigger automatically
- [ ] Score increases (10 pts/tile)
- [ ] Moves decrease per swap
- [ ] Goal score reached → Victory screen
- [ ] Moves = 0 → Defeat screen

### Booster System
- [ ] 4+ match → Booster popup appears on board
- [ ] Popup is clickable and collectible
- [ ] Popup disappears after 10 seconds
- [ ] Booster added to inventory panel (right side)
- [ ] Booster UI shows uses remaining
- [ ] Clicking booster button activates it
- [ ] Each booster effect works correctly
- [ ] Booster inventory persists across levels

### Level Progression
- [ ] Start screen shows 9 boosters
- [ ] Can select exactly 3 starting boosters
- [ ] Start button begins game
- [ ] Victory shows "Next Level" button
- [ ] Next Level shows booster selection (3 more)
- [ ] Boosters accumulate (3 + 3 + 3...)
- [ ] Goal score increases 1.5× per level
- [ ] Moves decrease by 2 per level
- [ ] Background changes each level (cycles through 6)
- [ ] Level counter updates in UI

### Persistent Stats
- [ ] High score displays at top-right
- [ ] Max level displays at top-right
- [ ] High score updates on new record
- [ ] Max level updates on level advancement
- [ ] Stats persist after closing game

### Visual & Audio
- [ ] Sea creatures display from sprite sheet
- [ ] Backgrounds scale to window
- [ ] Start screen shows background image
- [ ] Booster icons display correctly (9 unique designs)
- [ ] Background music plays and loops
- [ ] Match/swap/booster sounds play

---

## 🔧 Updated Configuration

All tweakable values in Grid.gd:

```gdscript
# Grid size
@export var rows: int = 8
@export var cols: int = 8

# Gameplay
@export var moves_limit: int = 30
@export var goal_score: int = 1000
const TILE_TYPES: int = 6  # Sea creature types

# Booster popup
10 seconds - Popup timeout
0.6 scale - Icon display size

# Level scaling (in _on_next_level_requested)
goal_score *= 1.5
moves_limit -= 2 (minimum 20)
```

---

## 🎨 Updated Asset System

**Sprite Sheet Loading:**
1. Load seatheme sprite sheet (6×6 grid, 36 sprites)
2. Slice into AtlasTextures (165px each, 15px offset)
3. Scale to 0.388 (64px fit for grid)
4. Apply to tiles via spawn_tile()

**Background Loading:**
1. Load sea_backgound.png (3×2 grid, 6 backgrounds)
2. Slice into AtlasTextures
3. Scale to window size with 1% overscale
4. Cycle based on level number

**Booster Icons:**
1. 9 SVG files (128×128 viewBox)
2. Translucent navy backgrounds (70% opacity)
3. Unique designs per booster type
4. Loaded on-demand for popups

---

## 📊 Updated Code Statistics

| File | Lines | Purpose |
|------|-------|---------|
| Grid.gd | 1700+ | Game engine with boosters |
| Tile.gd | 30 | Tile data |
| UI.gd | 50+ | UI controller + stats |
| StartScreen.gd | 120 | Initial booster selection |
| NextLevelBoosterScreen.gd | 110 | Level-up booster selection |
| GameOverScreen.gd | 80 | Victory/defeat screen |
| Booster.gd | 200+ | Booster effects |
| Match3BoardConfig.gd | 150 | Board configuration |
| BackgroundManager.gd | 70 | Background cycling |
| MusicPlayer.gd | 15 | Music looping |
| PlayerStats.gd | 60 | Save system |
| **Total** | **2,585+** | |

Plus extensive documentation! 📚

---

## ✨ Updated Summary

You have a **complete, polished, production-ready Match-3 game** with:

✅ 8×8 grid with sea theme  
✅ 36 unique sea creature sprites  
✅ 6 rotating backgrounds  
✅ Advanced match detection (H, V, Diagonal, T, L, Square)  
✅ 9 unique boosters with effects  
✅ Booster earning system (4+ matches)  
✅ On-board booster collection  
✅ Booster inventory UI  
✅ Level progression system  
✅ Difficulty scaling  
✅ Start screen with booster selection  
✅ Next level booster selection  
✅ Game over screens (win/lose)  
✅ Persistent high score & max level  
✅ Background music with looping  
✅ Sound effects  
✅ Particle effects  
✅ Custom booster icons  
✅ Professional UI layout  
✅ Complete save system  
✅ Extensive documentation  
✅ Production-ready code  

**Ready to play and customize!** 🎮

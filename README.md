# 🌊 Match-3 CoPilot - Sea Adventure Game (Godot 4.5.1)

A fully-featured Match-3 puzzle game with booster system, progression mechanics, and beautiful sea-themed visuals.

## 🎮 Features

### Core Gameplay
- **8×8 Match-3 Grid** with sea creature tiles (whale, octopus, anchor, fish, turtle, treasure chest)
- **Advanced Match Detection**: Horizontal, Vertical, Diagonal, T-shapes, L-shapes, Square 2×2
- **Chain Reactions**: Automatic cascade system with gravity and refill
- **Score & Moves System**: Goal-based progression with move limits
- **Level Progression**: Increasing difficulty with higher goal scores and fewer moves

### Booster System
- **9 Unique Boosters**: Color Bomb, Striped, Bomb, Seeker, Roller, Hammer, Free Swap, Brush, UFO
- **Earn Boosters**: Get boosters by making 4+ tile matches
- **On-Board Collection**: Clickable booster popups appear at match locations
- **Inventory System**: Manage 3 uses per booster, displayed on right panel
- **Level Progression**: Select 3 starting boosters + 3 more each level

### Visual Polish
- **Sea Backgrounds**: 6 rotating underwater scenes from sprite sheet
- **Custom Booster Icons**: 9 unique SVG icons with translucent backgrounds
- **Sea Creature Sprites**: 36 sea-themed tiles sliced from sprite sheet
- **Particle Effects**: Match explosions and visual feedback
- **Start Screen**: Custom background image with booster selection

### Progression & Stats
- **Persistent High Score**: Saves across sessions
- **Max Level Tracking**: Records highest level reached
- **PlayerStats Singleton**: ConfigFile-based save system
- **Level Difficulty Scaling**: 1.5× score requirement, -2 moves per level

### Audio
- **Background Music**: Looping MP3 music throughout gameplay
- **Sound Effects**: Match, swap, and booster activation sounds

## 📁 Project Structure

### Scenes (`scenes/`)
- `Main.tscn` - Root scene with background, grid, UI, start screen, music player
- `Grid.tscn` - Game board (8×8 tile container)
- `Tile.tscn` - Individual tile template
- `UI.tscn` - HUD with score, moves, level, high score, max level
- `StartScreen.tscn` - Booster selection overlay with background image
- `GameOverScreen.tscn` - Victory/defeat screen with stats
- `NextLevelBoosterScreen.tscn` - Mid-game booster selection for level ups
- `MatchParticles.tscn` - Particle effects for matches

### Scripts (`scripts/`)
- `Grid.gd` (1700+ lines) - Core game engine with match detection, boosters, gravity
- `Tile.gd` - Individual tile data (type, position, powerup status)
- `UI.gd` - HUD controller connected to Grid signals and PlayerStats
- `StartScreen.gd` - Initial booster selection (max 3)
- `NextLevelBoosterScreen.gd` - Level advancement booster selection
- `GameOverScreen.gd` - Win/lose screen with restart/next level buttons
- `Booster.gd` - Booster effects implementation
- `Match3BoardConfig.gd` - Board configuration and rules
- `BackgroundManager.gd` - Cycles through 6 sea backgrounds per level
- `MusicPlayer.gd` - Handles looping background music
- `PlayerStats.gd` - Persistent stats singleton (high score, max level)

### Assets (`assets/`)
- `SeaTheme/Gemini_Generated_Image_2beqog2beqog2beq.png` - 6×6 tile sprite sheet (36 sprites)
- `SeaTheme/sea_backgound.png` - 3×2 background sprite sheet (6 backgrounds)
- `SeaTheme/start_Screen.png` - Start screen background image
- `SeaTheme/music/music.mp3` - Looping background music
- `booster_*.svg` - 9 custom booster icons (64×64 → 128×128 scaled)

## 🚀 How to Run

1. **Install Godot 4.5.1** from [godotengine.org](https://godotengine.org/)
2. **Open Project**: Import or open this folder in Godot
3. **Run Game**: Open `scenes/Main.tscn` and press F5
4. **Select Boosters**: Choose 3 starting boosters on the start screen
5. **Play**: Match 3+ tiles, earn boosters, reach the goal score!

## 🎯 How to Play

1. **Match Tiles**: Click two adjacent tiles to swap them
2. **Make Matches**: Create lines of 3+ matching sea creatures
3. **Earn Boosters**: Match 4+ tiles to earn a collectible booster
4. **Collect Boosters**: Click the booster popup to add to inventory
5. **Use Boosters**: Click booster buttons on the right panel
6. **Reach Goal**: Score 1000+ points before moves run out
7. **Next Level**: Select 3 more boosters and continue!

## 🛠️ Key Systems

### Match Detection
- Scans all directions for 3+ consecutive matching tiles
- Detects special patterns (T-shape, L-shape, 2×2 squares)
- Diagonal matching support
- Chain reaction cascading

### Booster Awarding
- 4+ matches award a random booster
- Popup appears at match location (10-second timeout)
- Clickable collection adds to inventory
- Blocker system prevents gravity overwrites

### Level Progression
- Goal score increases 1.5× per level
- Moves decrease by 2 per level (minimum 20)
- Background cycles through 6 sea themes
- Cumulative booster inventory (keeps previous + adds 3 new)

### Save System
- High score and max level persist to `user://player_stats.cfg`
- Updates automatically on new records
- Displays at top-right corner of screen

## 📝 Documentation

Detailed documentation available in `/docs`:
- `CODE_DOCUMENTATION.md` - Architecture and function breakdown
- `USAGE_NEXT_STEPS.md` - How to customize and extend
- `changes.md` - Development history
- `GODOT_VERSION.md` - Version compatibility

## 🎨 Customization

### Add New Tiles
Edit `assets/SeaTheme/Gemini_Generated_Image_2beqog2beqog2beq.png` (6×6 grid, 165px sprites)

### Add New Backgrounds
Edit `assets/SeaTheme/sea_backgound.png` (3×2 grid)

### Adjust Difficulty
Modify in `Grid.gd`:
- `goal_score` - Initial score requirement (default: 1000)
- `moves_limit` - Initial move count (default: 30)
- Level scaling in `_on_next_level_requested()`

### Add New Boosters
1. Create SVG icon in `assets/booster_[name].svg`
2. Add to `_booster_defs` array in `StartScreen.gd`
3. Implement effect in `Booster.gd`

## 🐛 Known Features
- Booster popups appear at bottom-left of matched tiles
- Backgrounds scale to window size (1152×648 default)
- Music loops continuously via MusicPlayer script
- High score UI at top-right corner

## 🙏 Credits
- **Engine**: Godot 4.5.1
- **Art Assets**: Sea-themed sprite sheets
- **Music**: Background music MP3
- **Development**: Built with GitHub Copilot assistance

## 📄 License
Match-3 CoPilot is provided as-is for educational and personal use.

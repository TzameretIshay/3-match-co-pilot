# Assets Directory

This folder contains all visual and audio assets for the Match-3 CoPilot game.

## 🎨 Current Asset Structure

### SeaTheme/
Sea-themed visual assets:

#### Sprite Sheets
- **`Gemini_Generated_Image_2beqog2beqog2beq.png`** - 6×6 tile sprite sheet
  - 36 unique sea creature sprites (165px each)
  - 15px offset between sprites
  - Sliced into AtlasTextures at runtime
  - Scaled to 64px (0.388 scale) for grid display
  - Contains: whales, octopuses, anchors, fish, turtles, treasure chests

- **`sea_backgound.png`** - 3×2 background sprite sheet
  - 6 unique underwater backgrounds
  - Cycles through backgrounds as player advances levels
  - Auto-scaled to window size (1152×648)
  - 1% overscale applied to prevent edge seams

#### Individual Images
- **`start_Screen.png`** - Start screen background image
  - Displayed behind booster selection panel
  - Full-screen coverage with expand mode

#### Music
- **`music/music.mp3`** - Background music
  - Loops continuously throughout gameplay
  - Managed by MusicPlayer.gd script
  - Auto-plays on game start

### Booster Icons (Root)
Custom SVG booster icons (128×128 viewBox):

- `booster_color_bomb.svg` - Purple core with multicolor orbiting dots
- `booster_striped.svg` - Blue with diagonal stripes
- `booster_bomb.svg` - Dark bomb with lit fuse
- `booster_seeker.svg` - Blue targeting reticle with arrow
- `booster_roller.svg` - Orange paint roller with wheels
- `booster_hammer.svg` - Gray hammer with purple handle
- `booster_brush.svg` - Pink/purple paintbrush
- `booster_free_swap.svg` - Cyan/purple swapping arrows
- `booster_ufo.svg` - Blue UFO saucer with light beam

**Icon Design:**
- 128×128 viewBox for high quality
- Translucent navy backgrounds (70% opacity: `fill-opacity="0.7"`)
- Rounded corners (18px radius)
- Unique visual for each booster type
- Displayed at 60% scale in-game popups

## 📁 Directory Structure

```
assets/
├── SeaTheme/
│   ├── Gemini_Generated_Image_2beqog2beqog2beq.png (Tile sprites)
│   ├── sea_backgound.png (Backgrounds)
│   ├── start_Screen.png (Start screen)
│   └── music/
│       └── music.mp3 (Background music)
├── booster_color_bomb.svg
├── booster_striped.svg
├── booster_bomb.svg
├── booster_seeker.svg
├── booster_roller.svg
├── booster_hammer.svg
├── booster_brush.svg
├── booster_free_swap.svg
├── booster_ufo.svg
└── README.md (This file)
```

## 🔧 Technical Details

### Sprite Sheet Processing
Grid.gd loads and processes sprite sheets automatically:
```gdscript
# Tile sprites: 6×6 grid, 165px sprites, 15px offset
var atlas = AtlasTexture.new()
atlas.region = Rect2(col * 165 + 15, row * 165 + 15, 165, 165)
sprite.scale = Vector2(0.388, 0.388)  # 165px → 64px

# Backgrounds: 3×2 grid
var bg_width = sheet_width / 3
var bg_height = sheet_height / 2
```

### Music Looping
MusicPlayer.gd handles seamless looping:
```gdscript
func _on_music_finished() -> void:
    play()  # Restart for continuous loop
```

### Icon Loading
Booster icons loaded on-demand:
```gdscript
var icon_path = "res://assets/booster_%s.svg" % booster_key
sprite.texture = load(icon_path)
sprite.scale = Vector2(0.6, 0.6)  # 60% size
```

## 🎨 Customization Guide

### Adding New Tiles
1. Edit `SeaTheme/Gemini_Generated_Image_2beqog2beqog2beq.png`
2. Maintain 6×6 grid layout
3. Keep 165px sprite size
4. Preserve 15px offset
5. Game will auto-slice on next run

### Adding New Backgrounds
1. Edit `SeaTheme/sea_backgound.png`
2. Maintain 3×2 grid layout
3. Backgrounds cycle: Level 1→BG0, Level 2→BG1, etc.
4. Wraps after level 6

### Adding New Booster Icons
1. Create SVG with 128×128 viewBox
2. Use naming pattern: `booster_[name].svg`
3. Add translucent background: `fill="#0f172a" fill-opacity="0.7"`
4. Add booster definition to StartScreen.gd:
```gdscript
{
    "key": "new_booster",
    "label": "New Booster",
    "description": "Does something awesome"
}
```
5. Implement effect in Booster.gd

### Changing Music
1. Replace `SeaTheme/music/music.mp3`
2. Supports MP3, OGG, WAV formats
3. Automatically loops
4. No code changes needed

## 📝 Asset Credits

- **Tile Sprites**: Sea-themed creature collection
- **Backgrounds**: Underwater scene variations
- **Booster Icons**: Custom SVG designs
- **Music**: Background soundtrack

## 🚀 Performance Notes

- **Sprite Sheets**: Loaded once, sliced into 36/6 AtlasTextures
- **Icons**: Loaded on-demand when booster earned
- **Music**: Single stream, loops via signal
- **Backgrounds**: Only current level background active
- **Total Asset Memory**: Optimized for smooth gameplay

# Scene Setup Instructions for Custom Chess

Since Godot scenes are best created using the editor, follow these instructions to create the required scenes.

## Required Scenes

### 1. Main Scene (`res://scenes/main.tscn`)

1. Create a new scene with a **Node** as root
2. Rename it to "Main"
3. Attach script: `res://scripts/main.gd`
4. Add children:
   - **Control** node named "MainMenu" (anchor: Full Rect)
     - Attach script: `res://scripts/ui/main_menu.gd`
     - Add child **VBoxContainer** (centered)
       - Add **Label** with text "Custom Chess" (title)
       - Add **Button** named "NewGameButton" with text "New Game (2 Players)"
       - Add **Button** named "VsAIButton" with text "Play vs AI"
       - Add **Button** named "LoadGameButton" with text "Load Game"
       - Add **Button** named "MultiplayerButton" with text "Multiplayer"
       - Add **Button** named "SettingsButton" with text "Settings"
       - Add **Button** named "QuitButton" with text "Quit"
   - **Node2D** named "GameContainer"

### 2. Game Scene (`res://scenes/game/game.tscn`)

1. Create a new scene with **Node2D** as root
2. Rename it to "GameScene"
3. Attach script: `res://scripts/ui/game_scene.gd`
4. Add children:
   - **Node2D** named "Board"
     - Attach script: `res://scripts/boards/standard_board.gd`
     - Add child **Node2D** named "PiecesContainer"
     - Add child **Node2D** named "HighlightsContainer"
   - **Camera2D** named "Camera2D" (set as current)
   - **CanvasLayer** named "CanvasLayer"
     - Add child **Control** named "HUD" (Full Rect)
       - Attach script: `res://scripts/ui/game_hud.gd`
       - Design HUD layout with turn indicator, move history, etc.
     - Add child **Control** named "PromotionDialog" (centered popup)
       - Attach script: `res://scripts/ui/promotion_dialog.gd`
       - Add Panel with 4 buttons: Queen, Rook, Bishop, Knight
     - Add child **Control** named "PauseMenu" (Full Rect, hidden by default)

### 3. Chess Piece Scene (`res://scenes/pieces/chess_piece.tscn`)

1. Create a new scene with **Node2D** as root
2. Rename it to "ChessPiece"
3. Add child **Sprite2D** named "Sprite2D"
4. This scene is instantiated and the piece scripts are attached dynamically

## Quick Setup Script

After creating the scenes, you can use this setup to quickly test:

1. Open Godot
2. Create scenes as described above
3. Set `res://scenes/main.tscn` as the main scene (already configured in project.godot)
4. Run the project

## Notes

- The board renders itself using `_draw()` - no separate sprites needed for squares
- Piece textures are loaded from `res://assets/pixel chess_v1.2/16x32 pieces/`
- UI styling can be customized using Godot's Theme system


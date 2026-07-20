# Custom Chess - Godot 4.5

A highly extensible and modular chess game built with Godot 4.5, featuring AI opponents, multiplayer support, and a comprehensive framework for custom pieces, boards, events, and game modes.

## Features

### Core Features
- **Standard Chess**: Full implementation of classic chess rules including castling, en passant, and pawn promotion
- **Move Validation**: Complete rules engine with check, checkmate, and stalemate detection
- **Save/Load System**: Save and load games with full state preservation

### Multiplayer
- **Peer-to-Peer Networking**: Room-based multiplayer using Godot's high-level networking
- **Room Codes**: Create and join games using shareable room codes
- **Reconnection Support**: Automatic reconnection handling for dropped connections

### AI System
- **Multiple Difficulty Levels**: Easy, Medium, Hard, and Expert
- **Alpha-Beta Search**: Minimax with alpha-beta pruning, iterative deepening
- **Move Ordering**: MVV-LVA, killer moves, and history heuristic for efficient search
- **Position Evaluation**: Material count, piece-square tables, mobility, king safety, and pawn structure

### Custom Content System

#### Custom Pieces
- Extensible `BasePiece` class with:
  - Configurable movement patterns via `MovePattern` resources
  - Ability system with cooldowns (turn-based or real-time)
  - Modifier system for buffs/debuffs
  - Rarity tiers (Common → Ancient)

#### Custom Boards
- Dynamic grid system supporting:
  - Non-standard dimensions
  - Blocked/special squares
  - Square modifiers (teleporters, hazards, buff zones)

#### Events System
- **Piece Events**: Transform, buff, freeze, curse, clone pieces
- **Board Events**: Hazards, teleporters, obstacles, wind effects
- **Global Events**: Rule changes, win condition modifications

#### Game Modes
- **Classic Chess**: Standard rules
- **King of the Hill**: Win by placing king in center
- **Three-Check**: Win by giving check 3 times
- **Atomic Chess**: Captures cause explosions
- **Kung Fu Chess**: Real-time with piece cooldowns

#### Player Abilities
- Teleport, Transform, Freeze, Shield, Trap, and more
- Resource-based ability system with cooldowns

## Project Structure

```
res://
├── autoloads/
│   ├── event_bus.gd       # Central signal hub
│   ├── game_manager.gd    # Main game controller
│   ├── saves_manager.gd   # Save/load system
│   └── network_manager.gd # Multiplayer networking
├── scripts/
│   ├── core/
│   │   ├── base_piece.gd      # Base piece class
│   │   ├── base_board.gd      # Base board class
│   │   ├── base_game_mode.gd  # Base game mode
│   │   ├── rules_engine.gd    # Move validation
│   │   ├── modifier_system.gd # Piece modifiers
│   │   ├── player_ability.gd  # Player abilities
│   │   ├── event_manager.gd   # Event system
│   │   └── rarity_system.gd   # Rarity calculations
│   ├── pieces/
│   │   ├── king.gd, queen.gd, rook.gd, etc.
│   │   └── custom/            # Custom pieces
│   ├── boards/
│   │   └── standard_board.gd
│   ├── game_modes/
│   │   ├── classic_mode.gd
│   │   ├── king_of_hill_mode.gd
│   │   ├── three_check_mode.gd
│   │   ├── atomic_mode.gd
│   │   └── kung_fu_chess_mode.gd
│   ├── events/
│   │   ├── base_event.gd
│   │   ├── piece_event.gd
│   │   ├── board_event.gd
│   │   └── global_event.gd
│   ├── ai/
│   │   ├── ai_player.gd
│   │   ├── evaluator.gd
│   │   └── search_algorithms.gd
│   └── ui/
│       ├── main_menu.gd
│       ├── game_hud.gd
│       ├── game_scene.gd
│       ├── lobby_menu.gd
│       └── promotion_dialog.gd
├── resources/
│   └── piece_data/
│       ├── move_pattern.gd
│       ├── piece_modifier.gd
│       ├── piece_ability.gd
│       └── square_modifier.gd
└── assets/
    └── pixel chess_v1.2/    # Chess piece sprites
```

## Getting Started

### Prerequisites
- Godot 4.5 or later

### Setup
1. Clone or download this repository
2. Open the project in Godot 4.5
3. Create the required scenes following `SCENE_SETUP_INSTRUCTIONS.md`
4. Run the project

### Creating Scenes
See `SCENE_SETUP_INSTRUCTIONS.md` for detailed instructions on creating:
- Main scene
- Game scene
- Chess piece scene

## Architecture

### Design Principles
1. **Composition over Inheritance**: Pieces use modifiers and abilities as components
2. **Resource-Based Configuration**: Game content defined as `.tres` files
3. **Signal-Based Communication**: Loose coupling via `EventBus` autoload
4. **Strategy Pattern for AI**: AI queries `RulesEngine` interface, not specific rules
5. **Game Mode Abstraction**: All game logic flows through `BaseGameMode` virtual methods

### Key Classes

#### BasePiece
Base class for all chess pieces. Override `get_legal_moves()` for custom movement.

```gdscript
class_name CustomPiece
extends BasePiece

func _init() -> void:
    piece_type = PieceType.CUSTOM
    piece_name = "Custom Piece"
    piece_value = 5

func get_legal_moves() -> Array[Vector2i]:
    # Custom movement logic
    return moves
```

#### BaseGameMode
Base class for game modes. Override win conditions and rules.

```gdscript
class_name CustomMode
extends BaseGameMode

func _init() -> void:
    mode_id = "custom"
    primary_win_condition = WinCondition.CUSTOM

func check_win_condition() -> Dictionary:
    # Custom win logic
    return {"game_over": false, "winner": NONE, "reason": ""}
```

#### BaseEvent
Base class for game events. Override `execute()` for custom effects.

```gdscript
class_name CustomEvent
extends BaseEvent

func execute(board: BaseBoard, game_mode: BaseGameMode) -> bool:
    # Custom event logic
    return true
```

## Future Expansion

The architecture supports:
- Custom pieces with unique abilities
- Non-rectangular boards
- New game modes (Risk-style, resource-based, etc.)
- Player progression/unlocks
- Tournament systems

## Credits

- Pixel art chess pieces from `pixel chess_v1.2` asset pack

## License

[Your license here]


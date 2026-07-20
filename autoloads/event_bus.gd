extends Node
## EventBus Autoload - Central signal hub for decoupled communication
## Accessed globally as EventBus (autoload singleton - do not add class_name)
## All global signals should be defined here to enable loose coupling between systems
##
## NOTE: These signals are intentionally declared but not used within this class.
## They are designed to be emitted and connected to by other parts of the codebase.
@warning_ignore("unused_signal")

# =============================================================================
# GAME STATE SIGNALS
# =============================================================================

## Emitted when the game state changes
signal game_state_changed(old_state: int, new_state: int)

## Emitted when a new game starts
signal game_started(game_mode: Resource)

## Emitted when the game ends
signal game_ended(winner: int, reason: String)

## Emitted when the game is paused/unpaused
signal game_paused(is_paused: bool)

# =============================================================================
# TURN SIGNALS
# =============================================================================

## Emitted when a turn starts
signal turn_started(player_color: int, turn_number: int)

## Emitted when a turn ends
signal turn_ended(player_color: int, turn_number: int)

## Emitted when the current player changes
signal current_player_changed(player_color: int)

# =============================================================================
# PIECE SIGNALS
# =============================================================================

## Emitted when a piece is selected
signal piece_selected(piece: Node, board_position: Vector2i)

## Emitted when a piece is deselected
signal piece_deselected(piece: Node)

## Emitted when a piece moves
signal piece_moved(piece: Node, from_pos: Vector2i, to_pos: Vector2i)

## Emitted when a piece is captured
signal piece_captured(captured_piece: Node, capturing_piece: Node, position: Vector2i)

## Emitted when a piece is promoted
signal piece_promoted(piece: Node, new_piece_type: int, position: Vector2i)

## Emitted when a piece spawns on the board
signal piece_spawned(piece: Node, position: Vector2i)

## Emitted when a piece is removed from the board
signal piece_removed(piece: Node, position: Vector2i)

## Emitted when a piece's modifiers change
signal piece_modifiers_changed(piece: Node, modifiers: Array)

## Emitted when a piece ability is activated
signal piece_ability_activated(piece: Node, ability: Resource)

## Emitted when a piece ability goes on cooldown
signal piece_ability_cooldown_started(piece: Node, ability: Resource, duration: float)

## Emitted when a piece ability comes off cooldown
signal piece_ability_cooldown_ended(piece: Node, ability: Resource)

# =============================================================================
# BOARD SIGNALS
# =============================================================================

## Emitted when the board state changes
signal board_state_changed(board: Node)

## Emitted when a square is modified
signal square_modified(position: Vector2i, modifier: Resource)

## Emitted when a square modifier is removed
signal square_modifier_removed(position: Vector2i, modifier: Resource)

## Emitted when the board shape changes
signal board_shape_changed(new_shape: Dictionary)

# =============================================================================
# RULES SIGNALS
# =============================================================================

## Emitted when a player is in check
signal check_declared(player_color: int, checking_pieces: Array)

## Emitted when checkmate occurs
signal checkmate_declared(losing_color: int)

## Emitted when stalemate occurs
signal stalemate_declared()

## Emitted when castling happens
signal castling_performed(player_color: int, side: String)

## Emitted when en passant capture happens
signal en_passant_performed(capturing_pawn: Node, captured_pawn: Node)

## Emitted when legal moves are calculated for a piece
signal legal_moves_calculated(piece: Node, moves: Array)

# =============================================================================
# EVENT SYSTEM SIGNALS
# =============================================================================

## Emitted when a game event is triggered
signal game_event_triggered(event: Resource)

## Emitted when a game event ends
signal game_event_ended(event: Resource)

## Emitted when an event affects pieces
signal event_affected_pieces(event: Resource, pieces: Array)

## Emitted when an event affects the board
signal event_affected_board(event: Resource, squares: Array)

# =============================================================================
# UI SIGNALS
# =============================================================================

## Emitted when a move hint should be shown
signal show_move_hints(positions: Array)

## Emitted when move hints should be hidden
signal hide_move_hints()

## Emitted when the move history updates
signal move_history_updated(move_notation: String)

## Emitted when a dialog should be shown
signal show_dialog(dialog_type: String, data: Dictionary)

## Emitted when promotion UI should be shown
signal show_promotion_ui(pawn: Node, position: Vector2i)

# =============================================================================
# SAVE/LOAD SIGNALS
# =============================================================================

## Emitted when a game is saved
signal game_saved(save_path: String)

## Emitted when a game is loaded
signal game_loaded(save_path: String)

## Emitted when save/load fails
signal save_load_error(error_message: String)

# =============================================================================
# NETWORK SIGNALS
# =============================================================================

## Emitted when connected to server
signal connected_to_server()

## Emitted when disconnected from server
signal disconnected_from_server()

## Emitted when a player joins the room
signal player_joined(player_id: int, player_data: Dictionary)

## Emitted when a player leaves the room
signal player_left(player_id: int)

## Emitted when receiving a move from network
signal network_move_received(from_pos: Vector2i, to_pos: Vector2i, player_id: int)

## Emitted when room state changes
signal room_state_changed(room_data: Dictionary)

# =============================================================================
# AI SIGNALS
# =============================================================================

## Emitted when AI starts thinking
signal ai_thinking_started(player_color: int)

## Emitted when AI finishes thinking
signal ai_thinking_finished(player_color: int, move: Dictionary)

## Emitted when AI evaluation updates (for visualization)
signal ai_evaluation_updated(evaluation: float, depth: int)


func _ready() -> void:
	print("[EventBus] Initialized")

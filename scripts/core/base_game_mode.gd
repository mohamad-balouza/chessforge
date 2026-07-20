class_name BaseGameMode
extends Resource
## Base class for game modes
## Defines win conditions, turn structure, and special rules

# =============================================================================
# ENUMS
# =============================================================================

enum GameState {
	SETUP = 0,
	PLAYING = 1,
	PAUSED = 2,
	ENDED = 3
}

enum WinCondition {
	CHECKMATE = 0,
	KING_CAPTURE = 1,
	KING_OF_HILL = 2,
	THREE_CHECK = 3,
	CUSTOM = 100
}

enum TurnType {
	ALTERNATING = 0,  ## Standard turn-based
	SIMULTANEOUS = 1, ## Both players move at once
	REAL_TIME = 2,    ## No turns, cooldown-based
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var mode_id: String = "classic"
@export var mode_name: String = "Classic Chess"
@export var description: String = "Standard chess rules"

@export_group("Win Conditions")
@export var primary_win_condition: WinCondition = WinCondition.CHECKMATE
@export var enable_check: bool = true
@export var enable_checkmate: bool = true
@export var enable_stalemate_draw: bool = true

@export_group("Turn Structure")
@export var turn_type: TurnType = TurnType.ALTERNATING
@export var time_per_turn: float = -1.0  ## -1 for no limit

@export_group("Special Rules")
@export var enable_castling: bool = true
@export var enable_en_passant: bool = true
@export var enable_pawn_promotion: bool = true
@export var enable_fifty_move_rule: bool = true
@export var enable_threefold_repetition: bool = true

# =============================================================================
# PROPERTIES
# =============================================================================

## Current game state
var game_state: GameState = GameState.SETUP

## Current player to move
var current_player: BasePiece.PieceColor = BasePiece.PieceColor.WHITE

## Turn number
var turn_number: int = 1

## Check counts per player (for three-check variant)
var check_counts: Dictionary = {
	BasePiece.PieceColor.WHITE: 0,
	BasePiece.PieceColor.BLACK: 0
}

## Move history for threefold repetition
var position_history: Array[String] = []

## Fifty-move rule counter (half-moves since pawn move or capture)
var half_move_clock: int = 0

## Reference to rules engine
var rules_engine: RulesEngine = null

## Reference to board
var board: BaseBoard = null

# =============================================================================
# INITIALIZATION
# =============================================================================

func initialize(game_board: BaseBoard, engine: RulesEngine) -> void:
	board = game_board
	rules_engine = engine
	_reset_state()


func _reset_state() -> void:
	game_state = GameState.SETUP
	current_player = BasePiece.PieceColor.WHITE
	turn_number = 1
	check_counts = {
		BasePiece.PieceColor.WHITE: 0,
		BasePiece.PieceColor.BLACK: 0
	}
	position_history.clear()
	half_move_clock = 0

# =============================================================================
# GAME FLOW (Override in subclasses)
# =============================================================================

## Called when the game starts
func on_game_start() -> void:
	game_state = GameState.PLAYING
	current_player = BasePiece.PieceColor.WHITE
	turn_number = 1


## Called at the start of each turn
func on_turn_start(player: BasePiece.PieceColor) -> void:
	current_player = player


## Called at the end of each turn
func on_turn_end(_player: BasePiece.PieceColor) -> void:
	# Switch players
	if turn_type == TurnType.ALTERNATING:
		if current_player == BasePiece.PieceColor.BLACK:
			turn_number += 1
		current_player = BasePiece.get_opposite_color(current_player)


## Called when a move is made
func on_move_made(piece: BasePiece, _from_pos: Vector2i, _to_pos: Vector2i, result: Dictionary) -> void:
	# Update fifty-move clock
	if piece.piece_type == BasePiece.PieceType.PAWN or result.captured:
		half_move_clock = 0
	else:
		half_move_clock += 1
	
	# Update check counts
	if result.gives_check:
		var opponent := BasePiece.get_opposite_color(piece.piece_color)
		check_counts[opponent] += 1
	
	# Record position for repetition detection
	if enable_threefold_repetition:
		var position_hash := _get_position_hash()
		position_history.append(position_hash)

# =============================================================================
# WIN CONDITION CHECKS (Override in subclasses)
# =============================================================================

## Check if the game has ended, returns winner color or NONE for draw/ongoing
func check_win_condition() -> Dictionary:
	var result := {
		"game_over": false,
		"winner": BasePiece.PieceColor.NONE,
		"reason": ""
	}
	
	match primary_win_condition:
		WinCondition.CHECKMATE:
			result = _check_checkmate_win()
		WinCondition.KING_CAPTURE:
			result = _check_king_capture_win()
		WinCondition.KING_OF_HILL:
			result = _check_king_of_hill_win()
		WinCondition.THREE_CHECK:
			result = _check_three_check_win()
		WinCondition.CUSTOM:
			result = _check_custom_win()
	
	# Check draw conditions if game not over
	if not result.game_over:
		result = _check_draw_conditions(result)
	
	if result.game_over:
		game_state = GameState.ENDED
	
	return result


## Standard checkmate win check
func _check_checkmate_win() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	if not rules_engine:
		return result
	
	# Check for checkmate
	if rules_engine.is_checkmate(current_player):
		result.game_over = true
		result.winner = BasePiece.get_opposite_color(current_player)
		result.reason = "Checkmate"
	elif rules_engine.is_stalemate(current_player) and enable_stalemate_draw:
		result.game_over = true
		result.winner = BasePiece.PieceColor.NONE
		result.reason = "Stalemate"
	
	return result


## King capture win check (for variants without check)
func _check_king_capture_win() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	if not board:
		return result
	
	# Check if either king is missing
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		var king := board.get_king(color)
		if not king or not king.is_alive:
			result.game_over = true
			result.winner = BasePiece.get_opposite_color(color)
			result.reason = "King captured"
			break
	
	return result


## King of the hill win check
func _check_king_of_hill_win() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	if not board:
		return result
	
	# Define center squares (for 8x8 board: d4, d5, e4, e5)
	@warning_ignore("integer_division")
	var center_x1 := board.columns / 2 - 1
	@warning_ignore("integer_division")
	var center_x2 := board.columns / 2
	@warning_ignore("integer_division")
	var center_y1 := board.rows / 2 - 1
	@warning_ignore("integer_division")
	var center_y2 := board.rows / 2
	var center_squares: Array[Vector2i] = [
		Vector2i(center_x1, center_y1),
		Vector2i(center_x1, center_y2),
		Vector2i(center_x2, center_y1),
		Vector2i(center_x2, center_y2)
	]
	
	# Check if either king is in the center
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		var king := board.get_king(color)
		if king and king.board_position in center_squares:
			result.game_over = true
			result.winner = color
			result.reason = "King of the Hill"
			break
	
	# Also check for checkmate
	if not result.game_over and enable_checkmate:
		result = _check_checkmate_win()
	
	return result


## Three-check win condition
func _check_three_check_win() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		if check_counts.get(color, 0) >= 3:
			result.game_over = true
			result.winner = BasePiece.get_opposite_color(color)
			result.reason = "Three checks"
			break
	
	# Also check for checkmate
	if not result.game_over and enable_checkmate:
		result = _check_checkmate_win()
	
	return result


## Custom win condition (override in subclasses)
func _check_custom_win() -> Dictionary:
	return {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}


## Check draw conditions
func _check_draw_conditions(result: Dictionary) -> Dictionary:
	# Fifty-move rule
	if enable_fifty_move_rule and half_move_clock >= 100:  # 50 full moves = 100 half moves
		result.game_over = true
		result.winner = BasePiece.PieceColor.NONE
		result.reason = "Fifty-move rule"
		return result
	
	# Threefold repetition
	if enable_threefold_repetition:
		var position_hash := _get_position_hash()
		var count := position_history.count(position_hash)
		if count >= 3:
			result.game_over = true
			result.winner = BasePiece.PieceColor.NONE
			result.reason = "Threefold repetition"
			return result
	
	# Insufficient material (simplified)
	if _is_insufficient_material():
		result.game_over = true
		result.winner = BasePiece.PieceColor.NONE
		result.reason = "Insufficient material"
		return result
	
	return result


## Check for insufficient mating material
func _is_insufficient_material() -> bool:
	if not board:
		return false
	
	var pieces := board.get_all_pieces()
	
	# King vs King
	if pieces.size() == 2:
		return true
	
	# King + minor piece vs King
	if pieces.size() == 3:
		for piece in pieces:
			if piece.piece_type in [BasePiece.PieceType.BISHOP, BasePiece.PieceType.KNIGHT]:
				return true
	
	# King + Bishop vs King + Bishop (same color bishops)
	if pieces.size() == 4:
		var bishops: Array[BasePiece] = []
		for piece in pieces:
			if piece.piece_type == BasePiece.PieceType.BISHOP:
				bishops.append(piece)
		
		if bishops.size() == 2:
			# Check if same color squares
			var color1 := (bishops[0].board_position.x + bishops[0].board_position.y) % 2
			var color2 := (bishops[1].board_position.x + bishops[1].board_position.y) % 2
			return color1 == color2
	
	return false


## Generate a hash of the current position for repetition detection
func _get_position_hash() -> String:
	if not board:
		return ""
	
	var hash_str := ""
	
	for x in range(board.columns):
		for y in range(board.rows):
			var piece: BasePiece = board.get_piece_at(Vector2i(x, y))
			if piece:
				hash_str += str(piece.piece_type) + str(piece.piece_color)
			else:
				hash_str += "00"
	
	# Include castling rights and en passant in hash
	if rules_engine:
		hash_str += str(rules_engine.castling_rights)
		hash_str += str(rules_engine.en_passant_target)
	
	return hash_str

# =============================================================================
# MOVE VALIDATION HOOKS
# =============================================================================

## Additional validation for moves (called by rules engine)
func is_move_valid(_piece: BasePiece, _target_pos: Vector2i, _game_board: BaseBoard) -> bool:
	# Override in subclasses for custom validation
	return true


## Modify available moves for a piece
func modify_available_moves(_piece: BasePiece, moves: Array[Vector2i]) -> Array[Vector2i]:
	# Override in subclasses to add/remove moves
	return moves

# =============================================================================
# AI SUPPORT
# =============================================================================

## Evaluate the current position (for AI)
## Positive values favor white, negative favor black
func evaluate_position(_game_board: BaseBoard) -> float:
	# Override in subclasses for mode-specific evaluation
	return 0.0


## Get the AI evaluator for this game mode
func get_ai_evaluator() -> Resource:
	# Override to return a custom evaluator for complex modes
	return null

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"mode_id": mode_id,
		"game_state": game_state,
		"current_player": current_player,
		"turn_number": turn_number,
		"check_counts": check_counts.duplicate(),
		"half_move_clock": half_move_clock,
		"position_history": position_history.duplicate()
	}


func from_dict(data: Dictionary) -> void:
	game_state = data.get("game_state", GameState.SETUP)
	current_player = data.get("current_player", BasePiece.PieceColor.WHITE)
	turn_number = data.get("turn_number", 1)
	check_counts = data.get("check_counts", {}).duplicate()
	half_move_clock = data.get("half_move_clock", 0)
	position_history = data.get("position_history", []).duplicate()


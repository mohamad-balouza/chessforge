class_name GlobalEvent
extends BaseEvent
## Events that affect game rules or modes globally

# =============================================================================
# ENUMS
# =============================================================================

enum GlobalEffect {
	RULE_CHANGE = 0,       ## Modify existing rules
	WIN_CONDITION = 1,     ## Change win condition
	TIME_CONTROL = 2,      ## Modify time/turns
	PIECE_RULES = 3,       ## Change how pieces work globally
	BOARD_TRANSFORM = 4,   ## Major board changes
	RESOURCE_CHANGE = 5    ## Modify player resources (for custom modes)
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var effect_type: GlobalEffect = GlobalEffect.RULE_CHANGE

@export_group("Rule Changes")
@export var disable_castling: bool = false
@export var disable_en_passant: bool = false
@export var allow_king_capture: bool = false
@export var disable_check_rules: bool = false
@export var reverse_piece_movement: bool = false

@export_group("Win Condition")
@export var new_win_condition: BaseGameMode.WinCondition = BaseGameMode.WinCondition.CHECKMATE
@export var check_count_to_win: int = 3
@export var center_squares_for_hill: Array[Vector2i] = []

@export_group("Time Control")
@export var add_turns: int = 0
@export var time_multiplier: float = 1.0
@export var freeze_time: bool = false

@export_group("Global Piece Rules")
@export var all_pieces_can_jump: bool = false
@export var all_pieces_atomic: bool = false  ## Explode on capture
@export var swap_piece_movements: bool = false

# =============================================================================
# PROPERTIES
# =============================================================================

var original_rules: Dictionary = {}
var original_win_condition: BaseGameMode.WinCondition = BaseGameMode.WinCondition.CHECKMATE

# =============================================================================
# EXECUTION
# =============================================================================

func execute(board: BaseBoard, game_mode: BaseGameMode = null) -> bool:
	if not game_mode:
		return false
	
	# Store original values for restoration
	_store_original_rules(game_mode)
	
	match effect_type:
		GlobalEffect.RULE_CHANGE:
			return _execute_rule_change(game_mode)
		GlobalEffect.WIN_CONDITION:
			return _execute_win_condition_change(game_mode)
		GlobalEffect.TIME_CONTROL:
			return _execute_time_control(game_mode)
		GlobalEffect.PIECE_RULES:
			return _execute_piece_rules(board)
		GlobalEffect.BOARD_TRANSFORM:
			return _execute_board_transform(board)
		_:
			return false


func _store_original_rules(game_mode: BaseGameMode) -> void:
	original_rules = {
		"enable_castling": game_mode.enable_castling,
		"enable_en_passant": game_mode.enable_en_passant,
		"enable_check": game_mode.enable_check,
	}
	original_win_condition = game_mode.primary_win_condition


func _execute_rule_change(game_mode: BaseGameMode) -> bool:
	if disable_castling:
		game_mode.enable_castling = false
	if disable_en_passant:
		game_mode.enable_en_passant = false
	if disable_check_rules:
		game_mode.enable_check = false
	
	return true


func _execute_win_condition_change(game_mode: BaseGameMode) -> bool:
	game_mode.primary_win_condition = new_win_condition
	
	# Set additional parameters
	if new_win_condition == BaseGameMode.WinCondition.THREE_CHECK:
		game_mode.check_counts = {
			BasePiece.PieceColor.WHITE: 0,
			BasePiece.PieceColor.BLACK: 0
		}
	
	return true


func _execute_time_control(game_mode: BaseGameMode) -> bool:
	if add_turns > 0:
		# Would modify turn count tracking
		pass
	
	if time_multiplier != 1.0:
		# Would modify time tracking
		pass
	
	return true


func _execute_piece_rules(board: BaseBoard) -> bool:
	if all_pieces_can_jump:
		for piece in board.get_all_pieces():
			piece.can_jump = true
			piece.custom_data["original_can_jump"] = false
	
	if all_pieces_atomic:
		for piece in board.get_all_pieces():
			piece.custom_data["atomic"] = true
	
	return true


func _execute_board_transform(board: BaseBoard) -> bool:
	# Major board transformations would go here
	# e.g., expanding board, rotating, etc.
	return true

# =============================================================================
# CLEANUP
# =============================================================================

func _cleanup(board: BaseBoard) -> void:
	# Restore original rules
	if GameManager and GameManager.game_mode:
		var game_mode := GameManager.game_mode
		
		if original_rules.has("enable_castling"):
			game_mode.enable_castling = original_rules.enable_castling
		if original_rules.has("enable_en_passant"):
			game_mode.enable_en_passant = original_rules.enable_en_passant
		if original_rules.has("enable_check"):
			game_mode.enable_check = original_rules.enable_check
		
		game_mode.primary_win_condition = original_win_condition
	
	# Restore piece rules
	if all_pieces_can_jump:
		for piece in board.get_all_pieces():
			if piece.custom_data.has("original_can_jump"):
				piece.can_jump = piece.custom_data["original_can_jump"]
				piece.custom_data.erase("original_can_jump")
	
	if all_pieces_atomic:
		for piece in board.get_all_pieces():
			piece.custom_data.erase("atomic")
	
	original_rules.clear()
	super._cleanup(board)


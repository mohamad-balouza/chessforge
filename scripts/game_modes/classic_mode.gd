class_name ClassicMode
extends BaseGameMode
## Classic chess game mode with standard rules

func _init() -> void:
	mode_id = "classic"
	mode_name = "Classic Chess"
	description = "Standard chess rules with checkmate victory condition"
	
	# Standard rules
	primary_win_condition = WinCondition.CHECKMATE
	enable_check = true
	enable_checkmate = true
	enable_stalemate_draw = true
	turn_type = TurnType.ALTERNATING
	
	# Special moves
	enable_castling = true
	enable_en_passant = true
	enable_pawn_promotion = true
	
	# Draw rules
	enable_fifty_move_rule = true
	enable_threefold_repetition = true


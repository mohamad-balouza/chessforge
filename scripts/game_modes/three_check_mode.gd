class_name ThreeCheckMode
extends BaseGameMode
## Three Check - Win by giving check 3 times

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	mode_id = "three_check"
	mode_name = "Three Check"
	description = "Give check 3 times to win, or checkmate"
	
	primary_win_condition = WinCondition.THREE_CHECK
	enable_check = true
	enable_checkmate = true
	enable_stalemate_draw = true
	turn_type = TurnType.ALTERNATING
	
	enable_castling = true
	enable_en_passant = true
	enable_pawn_promotion = true

# =============================================================================
# MOVE HANDLING
# =============================================================================

func on_move_made(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary) -> void:
	super.on_move_made(piece, from_pos, to_pos, result)
	
	# Track checks
	if result.gives_check:
		var checked_color := BasePiece.get_opposite_color(piece.piece_color)
		check_counts[checked_color] = check_counts.get(checked_color, 0) + 1

# =============================================================================
# WIN CONDITION
# =============================================================================

func _check_three_check_win() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	# Check if either player has been checked 3 times
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		if check_counts.get(color, 0) >= 3:
			result.game_over = true
			result.winner = BasePiece.get_opposite_color(color)
			result.reason = "Three Checks (%d-0)" % [check_counts.get(color, 0)]
			return result
	
	# Also check for checkmate
	if enable_checkmate:
		result = _check_checkmate_win()
	
	return result

# =============================================================================
# AI EVALUATION
# =============================================================================

func evaluate_position(game_board: BaseBoard) -> float:
	var score: float = 0.0
	
	# Value checks given
	var white_checks: int = check_counts.get(BasePiece.PieceColor.BLACK, 0)  # Checks on black
	var black_checks: int = check_counts.get(BasePiece.PieceColor.WHITE, 0)  # Checks on white
	
	score += white_checks * 300.0  # Each check is valuable
	score -= black_checks * 300.0
	
	# Bonus for threatening check
	if rules_engine:
		# Check if any white piece can give check
		for piece in game_board.get_pieces_by_color(BasePiece.PieceColor.WHITE):
			var moves := rules_engine.get_legal_moves(piece)
			for move in moves:
				if _move_gives_check(piece, move, BasePiece.PieceColor.WHITE):
					score += 100.0
		
		# Same for black
		for piece in game_board.get_pieces_by_color(BasePiece.PieceColor.BLACK):
			var moves := rules_engine.get_legal_moves(piece)
			for move in moves:
				if _move_gives_check(piece, move, BasePiece.PieceColor.BLACK):
					score -= 100.0
	
	return score


func _move_gives_check(piece: BasePiece, move: Vector2i, color: BasePiece.PieceColor) -> bool:
	# Simplified check detection - in practice use rules engine
	if not board:
		return false
	
	var enemy_king := board.get_king(BasePiece.get_opposite_color(color))
	if not enemy_king:
		return false
	
	# This is a simplification - real implementation would simulate the move
	return false

# =============================================================================
# UI DISPLAY
# =============================================================================

func get_check_display() -> String:
	var white_on: int = check_counts.get(BasePiece.PieceColor.WHITE, 0)
	var black_on: int = check_counts.get(BasePiece.PieceColor.BLACK, 0)
	return "Checks: W(%d) B(%d)" % [black_on, white_on]


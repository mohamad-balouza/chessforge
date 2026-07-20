class_name KingOfHillMode
extends BaseGameMode
## King of the Hill - Win by placing your king in the center

# =============================================================================
# PROPERTIES
# =============================================================================

## Center squares that count as "the hill"
var hill_squares: Array[Vector2i] = []

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	mode_id = "king_of_hill"
	mode_name = "King of the Hill"
	description = "Win by placing your king on one of the center squares, or by checkmate"
	
	primary_win_condition = WinCondition.KING_OF_HILL
	enable_check = true
	enable_checkmate = true
	enable_stalemate_draw = true
	turn_type = TurnType.ALTERNATING
	
	enable_castling = true
	enable_en_passant = true
	enable_pawn_promotion = true


func initialize(game_board: BaseBoard, engine: RulesEngine) -> void:
	super.initialize(game_board, engine)
	_setup_hill_squares(game_board)


func _setup_hill_squares(game_board: BaseBoard) -> void:
	hill_squares.clear()
	
	# For 8x8 board: d4, d5, e4, e5 (center 4 squares)
	var center_x := game_board.columns / 2
	var center_y := game_board.rows / 2
	
	hill_squares.append(Vector2i(center_x - 1, center_y - 1))
	hill_squares.append(Vector2i(center_x - 1, center_y))
	hill_squares.append(Vector2i(center_x, center_y - 1))
	hill_squares.append(Vector2i(center_x, center_y))

# =============================================================================
# WIN CONDITION
# =============================================================================

func _check_king_of_hill_win() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	if not board:
		return result
	
	# Check if either king is on the hill
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		var king := board.get_king(color)
		if king and king.board_position in hill_squares:
			result.game_over = true
			result.winner = color
			result.reason = "King of the Hill"
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
	
	# Evaluate king distance to center
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		var king := game_board.get_king(color)
		if king:
			var min_dist := 100.0
			for hill_sq in hill_squares:
				var dist := _manhattan_distance(king.board_position, hill_sq)
				min_dist = min(min_dist, dist)
			
			# Closer to center is better (lower distance = higher score)
			var center_score := (10.0 - min_dist) * 50.0
			
			if color == BasePiece.PieceColor.WHITE:
				score += center_score
			else:
				score -= center_score
	
	return score


func _manhattan_distance(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)


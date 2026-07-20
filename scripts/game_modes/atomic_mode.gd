class_name AtomicMode
extends BaseGameMode
## Atomic Chess - Captures cause explosions

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	mode_id = "atomic"
	mode_name = "Atomic Chess"
	description = "Captures cause explosions that destroy all adjacent pieces (except pawns)"
	
	primary_win_condition = WinCondition.KING_CAPTURE  # King can be exploded
	enable_check = false  # No check in atomic (can explode your own king)
	enable_checkmate = false
	enable_stalemate_draw = true
	turn_type = TurnType.ALTERNATING
	
	enable_castling = true
	enable_en_passant = true
	enable_pawn_promotion = true

# =============================================================================
# MOVE HANDLING - EXPLOSION LOGIC
# =============================================================================

func on_move_made(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary) -> void:
	if result.captured:
		_trigger_explosion(to_pos, piece)
	
	super.on_move_made(piece, from_pos, to_pos, result)


func _trigger_explosion(position: Vector2i, capturer: BasePiece) -> void:
	if not board:
		return
	
	var explosion_squares: Array[Vector2i] = [position]
	
	# Add all adjacent squares
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var adj := Vector2i(position.x + dx, position.y + dy)
			if board.is_valid_square(adj):
				explosion_squares.append(adj)
	
	# Destroy all non-pawn pieces in explosion radius
	var destroyed_pieces: Array = []
	
	for sq in explosion_squares:
		var piece: BasePiece = board.get_piece_at(sq)
		if piece and piece.piece_type != BasePiece.PieceType.PAWN:
			destroyed_pieces.append({"piece": piece, "pos": sq})
	
	# Remove destroyed pieces
	for data in destroyed_pieces:
		var piece: BasePiece = data.piece
		var pos: Vector2i = data.pos
		
		board.pieces[pos.x][pos.y] = null
		piece.on_death(capturer)
		
		# Emit explosion event
		if EventBus:
			EventBus.piece_removed.emit(piece, pos)

# =============================================================================
# WIN CONDITION
# =============================================================================

func check_win_condition() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	if not board:
		return result
	
	# Check if either king is destroyed
	var white_king := board.get_king(BasePiece.PieceColor.WHITE)
	var black_king := board.get_king(BasePiece.PieceColor.BLACK)
	
	if not white_king or not white_king.is_alive:
		result.game_over = true
		result.winner = BasePiece.PieceColor.BLACK
		result.reason = "King exploded"
		return result
	
	if not black_king or not black_king.is_alive:
		result.game_over = true
		result.winner = BasePiece.PieceColor.WHITE
		result.reason = "King exploded"
		return result
	
	# Check for stalemate
	if enable_stalemate_draw and not _has_legal_moves(current_player):
		result.game_over = true
		result.winner = BasePiece.PieceColor.NONE
		result.reason = "Stalemate"
	
	return result

# =============================================================================
# MOVE VALIDATION
# =============================================================================

func is_move_valid(piece: BasePiece, target_pos: Vector2i, game_board: BaseBoard) -> bool:
	# In atomic, you cannot explode your own king
	var captured := game_board.get_piece_at(target_pos)
	if not captured:
		return true  # Non-capture moves are always valid
	
	# Check if explosion would destroy own king
	var own_king := game_board.get_king(piece.piece_color)
	if not own_king:
		return true
	
	var king_pos := own_king.board_position
	var distance := max(abs(king_pos.x - target_pos.x), abs(king_pos.y - target_pos.y))
	
	# King is in explosion radius (adjacent to capture square)
	if distance <= 1:
		return false
	
	return true

# =============================================================================
# AI EVALUATION
# =============================================================================

func evaluate_position(game_board: BaseBoard) -> float:
	var score: float = 0.0
	
	# Standard material evaluation, but king safety is paramount
	for piece in game_board.get_all_pieces():
		var value: float = Evaluator.PIECE_VALUES.get(piece.piece_type, 0)
		
		if piece.piece_color == BasePiece.PieceColor.WHITE:
			score += value
		else:
			score -= value
	
	# Bonus for king safety (distance from enemy pieces that can capture)
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		var king := game_board.get_king(color)
		if king:
			var safety := _evaluate_king_explosion_safety(king, game_board)
			if color == BasePiece.PieceColor.WHITE:
				score += safety
			else:
				score -= safety
	
	return score


func _evaluate_king_explosion_safety(king: BasePiece, game_board: BaseBoard) -> float:
	var safety: float = 0.0
	var king_pos := king.board_position
	var enemy_color := BasePiece.get_opposite_color(king.piece_color)
	
	# Check each enemy piece
	for enemy in game_board.get_pieces_by_color(enemy_color):
		# Can this piece capture adjacent to our king?
		var enemy_moves := enemy.get_attack_squares()
		
		for move in enemy_moves:
			# Check if capture at this square would explode our king
			if game_board.get_piece_at(move) != null:
				var dist := max(abs(king_pos.x - move.x), abs(king_pos.y - move.y))
				if dist <= 1:
					safety -= 500.0  # Very dangerous
	
	return safety


class_name KungFuChessMode
extends BaseGameMode
## Kung Fu Chess - Real-time chess with piece cooldowns

# =============================================================================
# PROPERTIES
# =============================================================================

## Cooldown time per piece in seconds
var piece_cooldown: float = 2.0

## Piece cooldown timers (piece -> remaining time)
var piece_cooldowns: Dictionary = {}

## Whether the game is currently running
var game_running: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	mode_id = "kung_fu_chess"
	mode_name = "Kung Fu Chess"
	description = "Real-time chess - no turns! Each piece has a cooldown after moving."
	
	primary_win_condition = WinCondition.KING_CAPTURE
	enable_check = false  # No check - must capture king
	enable_checkmate = false
	enable_stalemate_draw = false
	turn_type = TurnType.REAL_TIME
	
	enable_castling = false  # Disabled for real-time
	enable_en_passant = false  # Disabled for real-time
	enable_pawn_promotion = true

# =============================================================================
# GAME FLOW
# =============================================================================

func on_game_start() -> void:
	super.on_game_start()
	game_running = true
	piece_cooldowns.clear()


func on_turn_start(player: BasePiece.PieceColor) -> void:
	# No turns in real-time mode
	pass


func on_turn_end(player: BasePiece.PieceColor) -> void:
	# No turns in real-time mode
	pass

# =============================================================================
# REAL-TIME UPDATE
# =============================================================================

## Called every frame to update cooldowns
func update_realtime(delta: float) -> void:
	if not game_running:
		return
	
	# Update all piece cooldowns
	var to_remove: Array = []
	
	for piece in piece_cooldowns:
		piece_cooldowns[piece] -= delta
		
		if piece_cooldowns[piece] <= 0:
			to_remove.append(piece)
			
			# Notify that piece can move again
			if EventBus:
				EventBus.piece_ability_cooldown_ended.emit(piece, null)
	
	for piece in to_remove:
		piece_cooldowns.erase(piece)

# =============================================================================
# MOVE HANDLING
# =============================================================================

func on_move_made(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary) -> void:
	# Start cooldown for this piece
	piece_cooldowns[piece] = piece_cooldown
	piece.movement_cooldown = piece_cooldown
	
	if EventBus:
		EventBus.piece_ability_cooldown_started.emit(piece, null, piece_cooldown)


## Check if a piece can move (not on cooldown)
func can_piece_move(piece: BasePiece) -> bool:
	if piece_cooldowns.has(piece) and piece_cooldowns[piece] > 0:
		return false
	return true


## Get remaining cooldown for a piece
func get_piece_cooldown(piece: BasePiece) -> float:
	return piece_cooldowns.get(piece, 0.0)

# =============================================================================
# WIN CONDITION
# =============================================================================

func check_win_condition() -> Dictionary:
	var result := {"game_over": false, "winner": BasePiece.PieceColor.NONE, "reason": ""}
	
	if not board:
		return result
	
	# Check if either king is captured
	var white_king := board.get_king(BasePiece.PieceColor.WHITE)
	var black_king := board.get_king(BasePiece.PieceColor.BLACK)
	
	if not white_king or not white_king.is_alive:
		result.game_over = true
		result.winner = BasePiece.PieceColor.BLACK
		result.reason = "King captured"
		game_running = false
		return result
	
	if not black_king or not black_king.is_alive:
		result.game_over = true
		result.winner = BasePiece.PieceColor.WHITE
		result.reason = "King captured"
		game_running = false
		return result
	
	return result

# =============================================================================
# MOVE VALIDATION
# =============================================================================

func is_move_valid(piece: BasePiece, target_pos: Vector2i, game_board: BaseBoard) -> bool:
	# Check cooldown
	if not can_piece_move(piece):
		return false
	
	return true

# =============================================================================
# AI SUPPORT
# =============================================================================

func evaluate_position(game_board: BaseBoard) -> float:
	var score: float = 0.0
	
	# Material evaluation
	for piece in game_board.get_all_pieces():
		var value: float = Evaluator.PIECE_VALUES.get(piece.piece_type, 0)
		
		# Discount pieces on cooldown slightly
		if piece_cooldowns.has(piece) and piece_cooldowns[piece] > 0:
			value *= 0.9
		
		if piece.piece_color == BasePiece.PieceColor.WHITE:
			score += value
		else:
			score -= value
	
	# King proximity bonus (important when you need to capture)
	var white_king := game_board.get_king(BasePiece.PieceColor.WHITE)
	var black_king := game_board.get_king(BasePiece.PieceColor.BLACK)
	
	if white_king and black_king:
		# Bonus for having pieces close to enemy king
		for piece in game_board.get_pieces_by_color(BasePiece.PieceColor.WHITE):
			if piece.piece_type != BasePiece.PieceType.KING:
				var dist := abs(piece.board_position.x - black_king.board_position.x) + \
							abs(piece.board_position.y - black_king.board_position.y)
				score += (14.0 - dist) * 5.0
		
		for piece in game_board.get_pieces_by_color(BasePiece.PieceColor.BLACK):
			if piece.piece_type != BasePiece.PieceType.KING:
				var dist := abs(piece.board_position.x - white_king.board_position.x) + \
							abs(piece.board_position.y - white_king.board_position.y)
				score -= (14.0 - dist) * 5.0
	
	return score

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	var base := super.to_dict()
	
	var cooldowns: Dictionary = {}
	for piece in piece_cooldowns:
		if piece and piece.is_alive:
			var pos := piece.board_position
			cooldowns["%d,%d" % [pos.x, pos.y]] = piece_cooldowns[piece]
	
	base["piece_cooldowns"] = cooldowns
	base["game_running"] = game_running
	
	return base


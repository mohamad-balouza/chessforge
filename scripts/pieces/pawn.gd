class_name Pawn
extends BasePiece
## Pawn piece - moves forward, captures diagonally, can promote

func _init() -> void:
	piece_type = PieceType.PAWN
	piece_name = "Pawn"
	piece_value = 1
	can_jump = false
	max_range = 2  # Double move on first move


func _ready() -> void:
	super._ready()
	# Pawn patterns are handled in get_legal_moves due to complexity


func get_legal_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	if not board:
		return moves
	
	# Direction depends on color (white moves up/negative y, black moves down/positive y)
	var forward := -1 if piece_color == PieceColor.WHITE else 1
	
	# Forward move (one square)
	var one_forward := board_position + Vector2i(0, forward)
	if board.is_valid_square(one_forward) and board.is_square_empty(one_forward):
		moves.append(one_forward)
		
		# Double move on first move
		if not has_moved:
			var two_forward := board_position + Vector2i(0, forward * 2)
			if board.is_valid_square(two_forward) and board.is_square_empty(two_forward):
				moves.append(two_forward)
	
	# Diagonal captures
	var capture_left := board_position + Vector2i(-1, forward)
	var capture_right := board_position + Vector2i(1, forward)
	
	for capture_pos in [capture_left, capture_right]:
		if board.is_valid_square(capture_pos):
			var target_piece: BasePiece = board.get_piece_at(capture_pos)
			if target_piece and target_piece.piece_color != piece_color:
				moves.append(capture_pos)
	
	# En passant is handled by the rules engine and added separately
	
	return _apply_movement_modifiers(moves)


## Pawns attack diagonally (different from their move squares)
func get_attack_squares() -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	
	if not board:
		return squares
	
	var forward := -1 if piece_color == PieceColor.WHITE else 1
	
	var attack_left := board_position + Vector2i(-1, forward)
	var attack_right := board_position + Vector2i(1, forward)
	
	for pos in [attack_left, attack_right]:
		if board.is_valid_square(pos):
			squares.append(pos)
	
	return squares


## Check if pawn can be promoted at current position
func can_promote() -> bool:
	if not board:
		return false
	
	var promotion_rank: int = 0 if piece_color == PieceColor.WHITE else board.rows - 1
	return board_position.y == promotion_rank


## Get the starting rank for this pawn's color
func get_starting_rank() -> int:
	if not board:
		return -1
	
	if piece_color == PieceColor.WHITE:
		return board.rows - 2  # Second row from bottom
	else:
		return 1  # Second row from top


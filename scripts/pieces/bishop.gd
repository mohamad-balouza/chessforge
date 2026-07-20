class_name Bishop
extends BasePiece
## Bishop piece - moves diagonally

func _init() -> void:
	piece_type = PieceType.BISHOP
	piece_name = "Bishop"
	piece_value = 3
	can_jump = false
	max_range = -1


func _ready() -> void:
	super._ready()
	_setup_move_patterns()


func _setup_move_patterns() -> void:
	var bishop_pattern := MovePattern.new()
	bishop_pattern.directions = [
		Vector2i(1, 1),   # Down-right
		Vector2i(1, -1),  # Up-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	bishop_pattern.max_range = -1
	bishop_pattern.mirror_for_black = false
	
	move_patterns = [bishop_pattern]


func get_legal_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	if not board:
		return moves
	
	var directions := [
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for dir in directions:
		moves.append_array(_get_sliding_moves(dir))
	
	return _apply_movement_modifiers(moves)


func _get_sliding_moves(direction: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var current := board_position + direction
	
	while board.is_valid_square(current):
		var piece_at_target: BasePiece = board.get_piece_at(current)
		
		if piece_at_target:
			if piece_at_target.piece_color != piece_color:
				moves.append(current)
			break
		else:
			moves.append(current)
		
		current += direction
	
	return moves


func get_attack_squares() -> Array[Vector2i]:
	return get_legal_moves()


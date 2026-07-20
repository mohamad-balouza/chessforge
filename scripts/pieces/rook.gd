class_name Rook
extends BasePiece
## Rook piece - moves horizontally and vertically

func _init() -> void:
	piece_type = PieceType.ROOK
	piece_name = "Rook"
	piece_value = 5
	can_jump = false
	max_range = -1


func _ready() -> void:
	super._ready()
	_setup_move_patterns()


func _setup_move_patterns() -> void:
	var rook_pattern := MovePattern.new()
	rook_pattern.directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1),  # Up
	]
	rook_pattern.max_range = -1
	rook_pattern.mirror_for_black = false
	
	move_patterns = [rook_pattern]


func get_legal_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	if not board:
		return moves
	
	var directions := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
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


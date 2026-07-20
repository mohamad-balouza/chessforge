class_name Knight
extends BasePiece
## Knight piece - moves in L-shape and jumps over pieces

func _init() -> void:
	piece_type = PieceType.KNIGHT
	piece_name = "Knight"
	piece_value = 3
	can_jump = true
	max_range = 1  # Fixed range


func _ready() -> void:
	super._ready()
	_setup_move_patterns()


func _setup_move_patterns() -> void:
	# Knight has 8 possible moves in L-shape
	var knight_pattern := MovePattern.new()
	knight_pattern.directions = [
		Vector2i(2, 1),   # Right 2, down 1
		Vector2i(2, -1),  # Right 2, up 1
		Vector2i(-2, 1),  # Left 2, down 1
		Vector2i(-2, -1), # Left 2, up 1
		Vector2i(1, 2),   # Right 1, down 2
		Vector2i(1, -2),  # Right 1, up 2
		Vector2i(-1, 2),  # Left 1, down 2
		Vector2i(-1, -2)  # Left 1, up 2
	]
	knight_pattern.max_range = 1
	knight_pattern.min_range = 1
	knight_pattern.can_jump = true
	knight_pattern.mirror_for_black = false
	
	move_patterns = [knight_pattern]


func get_legal_moves() -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	if not board:
		return moves
	
	var knight_moves := [
		Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1),
		Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)
	]
	
	for move_offset in knight_moves:
		var target: Vector2i = board_position + move_offset
		
		if not board.is_valid_square(target):
			continue
		
		var piece_at_target: BasePiece = board.get_piece_at(target)
		
		# Can move if empty or enemy piece
		if not piece_at_target or piece_at_target.piece_color != piece_color:
			moves.append(target)
	
	return _apply_movement_modifiers(moves)


func get_attack_squares() -> Array[Vector2i]:
	return get_legal_moves()


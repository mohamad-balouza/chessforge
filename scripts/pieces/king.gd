class_name King
extends BasePiece
## King piece - moves one square in any direction, can castle

func _init() -> void:
	piece_type = PieceType.KING
	piece_name = "King"
	piece_value = 0  # King is invaluable (used 0 or very high number)
	can_jump = false
	max_range = 1


func _ready() -> void:
	super._ready()
	_setup_move_patterns()


func _setup_move_patterns() -> void:
	# King moves one square in any direction
	var king_pattern := MovePattern.new()
	king_pattern.directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1),  # Up
		Vector2i(1, 1),   # Down-right
		Vector2i(1, -1),  # Up-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	king_pattern.max_range = 1
	king_pattern.mirror_for_black = false  # King moves same for both colors
	
	move_patterns = [king_pattern]


## Override get_attack_squares for the king
## King attacks all adjacent squares
func get_attack_squares() -> Array[Vector2i]:
	var squares: Array[Vector2i] = []
	
	if not board:
		return squares
	
	var directions := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for dir: Vector2i in directions:
		var target: Vector2i = board_position + dir
		if board.is_valid_square(target):
			squares.append(target)
	
	return squares


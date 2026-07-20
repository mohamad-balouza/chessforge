class_name MovePattern
extends Resource
## Resource defining a movement pattern for chess pieces
## Supports sliding moves, jumping moves, and conditional movement

# =============================================================================
# ENUMS
# =============================================================================

enum MoveCondition {
	ALWAYS = 0,           ## Can always use this move
	FIRST_MOVE_ONLY = 1,  ## Only on first move (e.g., pawn double move)
	MUST_CAPTURE = 2,     ## Only when capturing (e.g., pawn diagonal)
	CANNOT_CAPTURE = 3,   ## Only when not capturing (e.g., pawn forward)
	SPECIFIC_RANK = 4,    ## Only on specific rank
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export_group("Movement Direction")
## Direction vector(s) for this pattern
@export var directions: Array[Vector2i] = []

@export_group("Range")
## Maximum range (-1 for unlimited, like bishop/rook)
@export var max_range: int = -1
## Minimum range (usually 1, but could be higher)
@export var min_range: int = 1

@export_group("Special Properties")
## Whether this movement can jump over pieces
@export var can_jump: bool = false
## Whether this movement can capture
@export var can_capture: bool = true
## Whether this movement can move without capturing
@export var can_move_without_capture: bool = true

@export_group("Conditions")
## Condition for when this pattern is available
@export var condition: MoveCondition = MoveCondition.ALWAYS
## For SPECIFIC_RANK condition: which rank (0-indexed from piece's perspective)
@export var required_rank: int = -1

@export_group("Symmetry")
## If true, automatically mirror directions for the opposite color
@export var mirror_for_black: bool = true

# =============================================================================
# METHODS
# =============================================================================

## Get all possible moves for this pattern given a piece and board
func get_moves(piece: BasePiece, board: BaseBoard) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	
	if not piece or not board:
		return moves
	
	# Check condition
	if not _check_condition(piece, board):
		return moves
	
	var actual_directions := _get_directions_for_piece(piece)
	
	for direction in actual_directions:
		var pattern_moves := _get_moves_in_direction(piece, board, direction)
		for move in pattern_moves:
			if move not in moves:
				moves.append(move)
	
	return moves


## Get directions adjusted for piece color
func _get_directions_for_piece(piece: BasePiece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	
	for dir in directions:
		var adjusted_dir := dir
		
		# Mirror Y direction for black pieces (they move "down" the board)
		if mirror_for_black and piece.piece_color == BasePiece.PieceColor.BLACK:
			adjusted_dir = Vector2i(dir.x, -dir.y)
		
		result.append(adjusted_dir)
	
	return result


## Get moves in a specific direction
func _get_moves_in_direction(piece: BasePiece, board: BaseBoard, direction: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	var start_pos := piece.board_position
	var range_limit: int = max_range if max_range > 0 else max(board.columns, board.rows)
	
	for distance in range(min_range, range_limit + 1):
		var target_pos := start_pos + direction * distance
		
		# Check if position is valid
		if not board.is_valid_square(target_pos):
			break
		
		var target_piece: BasePiece = board.get_piece_at(target_pos)
		
		if target_piece:
			# There's a piece at the target
			if can_capture and target_piece.piece_color != piece.piece_color:
				# Can capture enemy piece
				if _check_capture_condition():
					moves.append(target_pos)
			
			# Stop here unless we can jump
			if not can_jump:
				break
		else:
			# Empty square
			if can_move_without_capture:
				if _check_move_condition():
					moves.append(target_pos)
	
	return moves


## Check if the main condition is met
func _check_condition(piece: BasePiece, board: BaseBoard) -> bool:
	match condition:
		MoveCondition.ALWAYS:
			return true
		MoveCondition.FIRST_MOVE_ONLY:
			return not piece.has_moved
		MoveCondition.SPECIFIC_RANK:
			return _check_rank_condition(piece, board)
		_:
			return true


## Check rank condition
func _check_rank_condition(piece: BasePiece, board: BaseBoard) -> bool:
	var current_rank: int
	
	if piece.piece_color == BasePiece.PieceColor.WHITE:
		current_rank = board.rows - 1 - piece.board_position.y
	else:
		current_rank = piece.board_position.y
	
	return current_rank == required_rank


## Check if capture is allowed based on condition
func _check_capture_condition() -> bool:
	return condition != MoveCondition.CANNOT_CAPTURE


## Check if non-capture move is allowed
func _check_move_condition() -> bool:
	return condition != MoveCondition.MUST_CAPTURE


# =============================================================================
# FACTORY METHODS
# =============================================================================

## Create a sliding pattern (like rook, bishop, queen)
static func create_sliding(dirs: Array[Vector2i], jump: bool = false) -> MovePattern:
	var pattern := MovePattern.new()
	pattern.directions = dirs
	pattern.max_range = -1  # Unlimited
	pattern.can_jump = jump
	return pattern


## Create a fixed-range pattern (like knight, king)
static func create_fixed(dirs: Array[Vector2i], range_val: int = 1, jump: bool = false) -> MovePattern:
	var pattern := MovePattern.new()
	pattern.directions = dirs
	pattern.max_range = range_val
	pattern.min_range = range_val
	pattern.can_jump = jump
	return pattern


## Create a pawn forward pattern
static func create_pawn_forward() -> MovePattern:
	var pattern := MovePattern.new()
	pattern.directions = [Vector2i(0, -1)]  # White moves up
	pattern.max_range = 1
	pattern.can_capture = false
	pattern.condition = MoveCondition.CANNOT_CAPTURE
	return pattern


## Create a pawn double-move pattern (first move)
static func create_pawn_double() -> MovePattern:
	var pattern := MovePattern.new()
	pattern.directions = [Vector2i(0, -1)]
	pattern.max_range = 2
	pattern.min_range = 2
	pattern.can_capture = false
	pattern.condition = MoveCondition.FIRST_MOVE_ONLY
	return pattern


## Create a pawn capture pattern
static func create_pawn_capture() -> MovePattern:
	var pattern := MovePattern.new()
	pattern.directions = [Vector2i(-1, -1), Vector2i(1, -1)]
	pattern.max_range = 1
	pattern.can_move_without_capture = false
	pattern.condition = MoveCondition.MUST_CAPTURE
	return pattern


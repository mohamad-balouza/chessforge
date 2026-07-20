class_name Evaluator
extends RefCounted
## Chess position evaluator
## Uses material count and positional factors for evaluation

# =============================================================================
# CONSTANTS
# =============================================================================

## Standard piece values in centipawns
const PIECE_VALUES := {
	BasePiece.PieceType.PAWN: 100,
	BasePiece.PieceType.KNIGHT: 320,
	BasePiece.PieceType.BISHOP: 330,
	BasePiece.PieceType.ROOK: 500,
	BasePiece.PieceType.QUEEN: 900,
	BasePiece.PieceType.KING: 20000  # Very high to prioritize king safety
}

## Piece-square tables for positional evaluation (from White's perspective)
## Values in centipawns, should be mirrored for Black

const PAWN_TABLE := [
	[0,  0,  0,  0,  0,  0,  0,  0],
	[50, 50, 50, 50, 50, 50, 50, 50],
	[10, 10, 20, 30, 30, 20, 10, 10],
	[5,  5, 10, 25, 25, 10,  5,  5],
	[0,  0,  0, 20, 20,  0,  0,  0],
	[5, -5,-10,  0,  0,-10, -5,  5],
	[5, 10, 10,-20,-20, 10, 10,  5],
	[0,  0,  0,  0,  0,  0,  0,  0]
]

const KNIGHT_TABLE := [
	[-50,-40,-30,-30,-30,-30,-40,-50],
	[-40,-20,  0,  0,  0,  0,-20,-40],
	[-30,  0, 10, 15, 15, 10,  0,-30],
	[-30,  5, 15, 20, 20, 15,  5,-30],
	[-30,  0, 15, 20, 20, 15,  0,-30],
	[-30,  5, 10, 15, 15, 10,  5,-30],
	[-40,-20,  0,  5,  5,  0,-20,-40],
	[-50,-40,-30,-30,-30,-30,-40,-50]
]

const BISHOP_TABLE := [
	[-20,-10,-10,-10,-10,-10,-10,-20],
	[-10,  0,  0,  0,  0,  0,  0,-10],
	[-10,  0,  5, 10, 10,  5,  0,-10],
	[-10,  5,  5, 10, 10,  5,  5,-10],
	[-10,  0, 10, 10, 10, 10,  0,-10],
	[-10, 10, 10, 10, 10, 10, 10,-10],
	[-10,  5,  0,  0,  0,  0,  5,-10],
	[-20,-10,-10,-10,-10,-10,-10,-20]
]

const ROOK_TABLE := [
	[0,  0,  0,  0,  0,  0,  0,  0],
	[5, 10, 10, 10, 10, 10, 10,  5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[-5,  0,  0,  0,  0,  0,  0, -5],
	[0,  0,  0,  5,  5,  0,  0,  0]
]

const QUEEN_TABLE := [
	[-20,-10,-10, -5, -5,-10,-10,-20],
	[-10,  0,  0,  0,  0,  0,  0,-10],
	[-10,  0,  5,  5,  5,  5,  0,-10],
	[-5,  0,  5,  5,  5,  5,  0, -5],
	[0,  0,  5,  5,  5,  5,  0, -5],
	[-10,  5,  5,  5,  5,  5,  0,-10],
	[-10,  0,  5,  0,  0,  0,  0,-10],
	[-20,-10,-10, -5, -5,-10,-10,-20]
]

const KING_MIDDLE_TABLE := [
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-30,-40,-40,-50,-50,-40,-40,-30],
	[-20,-30,-30,-40,-40,-30,-30,-20],
	[-10,-20,-20,-20,-20,-20,-20,-10],
	[20, 20,  0,  0,  0,  0, 20, 20],
	[20, 30, 10,  0,  0, 10, 30, 20]
]

const KING_END_TABLE := [
	[-50,-40,-30,-20,-20,-30,-40,-50],
	[-30,-20,-10,  0,  0,-10,-20,-30],
	[-30,-10, 20, 30, 30, 20,-10,-30],
	[-30,-10, 30, 40, 40, 30,-10,-30],
	[-30,-10, 30, 40, 40, 30,-10,-30],
	[-30,-10, 20, 30, 30, 20,-10,-30],
	[-30,-30,  0,  0,  0,  0,-30,-30],
	[-50,-30,-30,-30,-30,-30,-30,-50]
]

# =============================================================================
# PROPERTIES
# =============================================================================

## Custom piece values (can be modified for custom pieces)
var custom_piece_values: Dictionary = {}

## Evaluation weights
var mobility_weight: float = 10.0
var king_safety_weight: float = 20.0
var pawn_structure_weight: float = 15.0

## Game phase detection
var endgame_material_threshold: int = 1300  # When total material falls below this

# =============================================================================
# MAIN EVALUATION
# =============================================================================

## Evaluate the position from White's perspective
## Positive = White is better, Negative = Black is better
func evaluate(board: BaseBoard, rules_engine: RulesEngine = null) -> float:
	var score: float = 0.0
	
	# Material evaluation
	score += _evaluate_material(board)
	
	# Positional evaluation
	score += _evaluate_positions(board)
	
	# Mobility evaluation
	if rules_engine:
		score += _evaluate_mobility(board, rules_engine)
	
	# King safety
	score += _evaluate_king_safety(board)
	
	# Pawn structure
	score += _evaluate_pawn_structure(board)
	
	return score


## Quick evaluation for move ordering
func evaluate_quick(board: BaseBoard) -> float:
	return _evaluate_material(board) + _evaluate_positions(board) * 0.5

# =============================================================================
# MATERIAL EVALUATION
# =============================================================================

func _evaluate_material(board: BaseBoard) -> float:
	var white_material: float = 0.0
	var black_material: float = 0.0
	
	for piece in board.get_all_pieces():
		var value := _get_piece_value(piece)
		
		if piece.piece_color == BasePiece.PieceColor.WHITE:
			white_material += value
		else:
			black_material += value
	
	return white_material - black_material


func _get_piece_value(piece: BasePiece) -> float:
	# Check for custom piece value first
	if custom_piece_values.has(piece.piece_type):
		return custom_piece_values[piece.piece_type]
	
	# Check piece's own value property
	if piece.piece_value > 0:
		return piece.piece_value * 100  # Convert to centipawns
	
	# Fall back to standard values
	return PIECE_VALUES.get(piece.piece_type, 0)


## Get total material on the board (for game phase detection)
func get_total_material(board: BaseBoard) -> int:
	var total: int = 0
	
	for piece in board.get_all_pieces():
		if piece.piece_type != BasePiece.PieceType.KING:
			total += PIECE_VALUES.get(piece.piece_type, 0)
	
	return total

# =============================================================================
# POSITIONAL EVALUATION
# =============================================================================

func _evaluate_positions(board: BaseBoard) -> float:
	var score: float = 0.0
	var is_endgame := get_total_material(board) < endgame_material_threshold
	
	for piece in board.get_all_pieces():
		var pos_score := _get_position_score(piece, board, is_endgame)
		
		if piece.piece_color == BasePiece.PieceColor.WHITE:
			score += pos_score
		else:
			score -= pos_score
	
	return score


func _get_position_score(piece: BasePiece, board: BaseBoard, is_endgame: bool) -> float:
	var pos := piece.board_position
	var table: Array
	
	# Get the appropriate piece-square table
	match piece.piece_type:
		BasePiece.PieceType.PAWN:
			table = PAWN_TABLE
		BasePiece.PieceType.KNIGHT:
			table = KNIGHT_TABLE
		BasePiece.PieceType.BISHOP:
			table = BISHOP_TABLE
		BasePiece.PieceType.ROOK:
			table = ROOK_TABLE
		BasePiece.PieceType.QUEEN:
			table = QUEEN_TABLE
		BasePiece.PieceType.KING:
			table = KING_END_TABLE if is_endgame else KING_MIDDLE_TABLE
		_:
			return 0.0
	
	# Mirror for black pieces
	var y := pos.y if piece.piece_color == BasePiece.PieceColor.WHITE else (board.rows - 1 - pos.y)
	var x := pos.x
	
	if x >= 0 and x < 8 and y >= 0 and y < 8:
		return table[y][x]
	
	return 0.0

# =============================================================================
# MOBILITY EVALUATION
# =============================================================================

func _evaluate_mobility(board: BaseBoard, rules_engine: RulesEngine) -> float:
	var white_mobility: float = 0.0
	var black_mobility: float = 0.0
	
	for piece in board.get_all_pieces():
		var moves := rules_engine.get_legal_moves(piece)
		var mobility := moves.size() * mobility_weight
		
		if piece.piece_color == BasePiece.PieceColor.WHITE:
			white_mobility += mobility
		else:
			black_mobility += mobility
	
	return white_mobility - black_mobility

# =============================================================================
# KING SAFETY
# =============================================================================

func _evaluate_king_safety(board: BaseBoard) -> float:
	var score: float = 0.0
	
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		var king := board.get_king(color)
		if not king:
			continue
		
		var safety := _calculate_king_safety(king, board)
		
		if color == BasePiece.PieceColor.WHITE:
			score += safety * king_safety_weight
		else:
			score -= safety * king_safety_weight
	
	return score


func _calculate_king_safety(king: BasePiece, board: BaseBoard) -> float:
	var safety: float = 0.0
	var pos := king.board_position
	
	# Check pawn shield
	var pawn_shield_bonus := 0.0
	var forward := -1 if king.piece_color == BasePiece.PieceColor.WHITE else 1
	
	for dx in [-1, 0, 1]:
		var shield_pos := pos + Vector2i(dx, forward)
		if board.is_valid_square(shield_pos):
			var piece: BasePiece = board.get_piece_at(shield_pos)
			if piece and piece.piece_type == BasePiece.PieceType.PAWN and piece.piece_color == king.piece_color:
				pawn_shield_bonus += 10.0
	
	safety += pawn_shield_bonus
	
	# Penalty for open files near king
	var king_file := pos.x
	for dx in [-1, 0, 1]:
		var file := king_file + dx
		if file < 0 or file >= board.columns:
			continue
		
		var has_own_pawn := false
		for y in range(board.rows):
			var piece: BasePiece = board.get_piece_at(Vector2i(file, y))
			if piece and piece.piece_type == BasePiece.PieceType.PAWN and piece.piece_color == king.piece_color:
				has_own_pawn = true
				break
		
		if not has_own_pawn:
			safety -= 15.0  # Open file penalty
	
	return safety

# =============================================================================
# PAWN STRUCTURE
# =============================================================================

func _evaluate_pawn_structure(board: BaseBoard) -> float:
	var score: float = 0.0
	
	for color in [BasePiece.PieceColor.WHITE, BasePiece.PieceColor.BLACK]:
		var pawns := board.get_pieces_by_type(BasePiece.PieceType.PAWN).filter(
			func(p): return p.piece_color == color
		)
		
		var structure_score := _evaluate_pawns_structure(pawns, board, color)
		
		if color == BasePiece.PieceColor.WHITE:
			score += structure_score * pawn_structure_weight
		else:
			score -= structure_score * pawn_structure_weight
	
	return score


func _evaluate_pawns_structure(pawns: Array, board: BaseBoard, color: BasePiece.PieceColor) -> float:
	var score: float = 0.0
	var pawn_files: Dictionary = {}
	
	# Track pawns by file
	for pawn in pawns:
		var file := pawn.board_position.x
		if not pawn_files.has(file):
			pawn_files[file] = []
		pawn_files[file].append(pawn)
	
	for file in pawn_files:
		var pawns_on_file: Array = pawn_files[file]
		
		# Doubled pawns penalty
		if pawns_on_file.size() > 1:
			score -= 20.0 * (pawns_on_file.size() - 1)
		
		# Isolated pawns penalty
		var has_neighbor := pawn_files.has(file - 1) or pawn_files.has(file + 1)
		if not has_neighbor:
			score -= 15.0 * pawns_on_file.size()
	
	# Passed pawns bonus
	for pawn in pawns:
		if _is_passed_pawn(pawn, board):
			var advancement := 0
			if color == BasePiece.PieceColor.WHITE:
				advancement = board.rows - 1 - pawn.board_position.y
			else:
				advancement = pawn.board_position.y
			
			score += 20.0 + (advancement * 10.0)
	
	return score


func _is_passed_pawn(pawn: BasePiece, board: BaseBoard) -> bool:
	var pos := pawn.board_position
	var color := pawn.piece_color
	var forward := -1 if color == BasePiece.PieceColor.WHITE else 1
	var end_rank := 0 if color == BasePiece.PieceColor.WHITE else board.rows - 1
	
	# Check if there are any enemy pawns blocking or attacking
	var y := pos.y + forward
	while y != end_rank + forward:
		for dx in [-1, 0, 1]:
			var check_pos := Vector2i(pos.x + dx, y)
			if board.is_valid_square(check_pos):
				var piece: BasePiece = board.get_piece_at(check_pos)
				if piece and piece.piece_type == BasePiece.PieceType.PAWN and piece.piece_color != color:
					return false
		y += forward
	
	return true


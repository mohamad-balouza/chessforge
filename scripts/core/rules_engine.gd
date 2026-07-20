class_name RulesEngine
extends RefCounted
## Rules engine for validating moves and enforcing chess rules
## Designed to be extensible for custom game modes and variants

# =============================================================================
# SIGNALS (via EventBus)
# =============================================================================
# This class is a RefCounted, so it uses EventBus for signals

# =============================================================================
# PROPERTIES
# =============================================================================

## Reference to the current board
var board: BaseBoard = null

## Reference to current game mode for custom rule checks
var game_mode: Resource = null

## Track whether we're in check calculation (to prevent recursion)
var _checking_for_check: bool = false

## En passant target square (set after pawn double move)
var en_passant_target: Vector2i = Vector2i(-1, -1)

## Castling rights tracking
var castling_rights: Dictionary = {
	BasePiece.PieceColor.WHITE: {"kingside": true, "queenside": true},
	BasePiece.PieceColor.BLACK: {"kingside": true, "queenside": true}
}

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(game_board: BaseBoard = null, mode: Resource = null) -> void:
	board = game_board
	game_mode = mode


func set_board(new_board: BaseBoard) -> void:
	board = new_board
	_reset_game_state()


func set_game_mode(mode: Resource) -> void:
	game_mode = mode


func _reset_game_state() -> void:
	en_passant_target = Vector2i(-1, -1)
	castling_rights = {
		BasePiece.PieceColor.WHITE: {"kingside": true, "queenside": true},
		BasePiece.PieceColor.BLACK: {"kingside": true, "queenside": true}
	}

# =============================================================================
# MOVE VALIDATION
# =============================================================================

## Get all legal moves for a piece (considering check)
func get_legal_moves(piece: BasePiece) -> Array[Vector2i]:
	if not piece or not board:
		return []
	
	var raw_moves := piece.get_raw_moves()
	var legal_moves: Array[Vector2i] = []
	
	# Add special moves
	_add_special_moves(piece, raw_moves)
	
	# Filter moves that would leave king in check
	for move in raw_moves:
		if is_move_legal(piece, move):
			legal_moves.append(move)
	
	return legal_moves


## Check if a specific move is legal
func is_move_legal(piece: BasePiece, target_pos: Vector2i) -> bool:
	if not piece or not board:
		return false
	
	# Basic validation
	if not board.is_valid_square(target_pos):
		return false
	
	# Can't capture own pieces
	var target_piece: BasePiece = board.get_piece_at(target_pos)
	if target_piece and target_piece.piece_color == piece.piece_color:
		return false
	
	# Check if move would leave own king in check
	if _would_move_cause_check(piece, piece.board_position, target_pos):
		return false
	
	# Check game mode specific rules
	if game_mode and game_mode.has_method("is_move_valid"):
		if not game_mode.is_move_valid(piece, target_pos, board):
			return false
	
	return true


## Add special moves (castling, en passant) to the move list
func _add_special_moves(piece: BasePiece, moves: Array) -> void:
	# Castling for king
	if piece.piece_type == BasePiece.PieceType.KING and not piece.has_moved:
		_add_castling_moves(piece, moves)
	
	# En passant for pawns
	if piece.piece_type == BasePiece.PieceType.PAWN:
		_add_en_passant_moves(piece, moves)


## Add castling moves if available
func _add_castling_moves(king: BasePiece, moves: Array) -> void:
	var color := king.piece_color
	var rights: Dictionary = castling_rights.get(color, {})
	var king_pos := king.board_position
	
	# Don't castle out of check
	if is_in_check(color):
		return
	
	# Kingside castling
	if rights.get("kingside", false):
		if _can_castle_kingside(king):
			var castle_pos := Vector2i(king_pos.x + 2, king_pos.y)
			if castle_pos not in moves:
				moves.append(castle_pos)
	
	# Queenside castling
	if rights.get("queenside", false):
		if _can_castle_queenside(king):
			var castle_pos := Vector2i(king_pos.x - 2, king_pos.y)
			if castle_pos not in moves:
				moves.append(castle_pos)


## Check if kingside castling is possible
func _can_castle_kingside(king: BasePiece) -> bool:
	var king_pos := king.board_position
	var rook_pos := Vector2i(board.columns - 1, king_pos.y)
	
	# Check rook exists and hasn't moved
	var rook: BasePiece = board.get_piece_at(rook_pos)
	if not rook or rook.piece_type != BasePiece.PieceType.ROOK or rook.has_moved:
		return false
	
	# Check squares between are empty
	for x in range(king_pos.x + 1, rook_pos.x):
		if not board.is_square_empty(Vector2i(x, king_pos.y)):
			return false
	
	# Check king doesn't pass through check
	for x in range(king_pos.x, king_pos.x + 3):
		if _is_square_attacked(Vector2i(x, king_pos.y), king.piece_color):
			return false
	
	return true


## Check if queenside castling is possible
func _can_castle_queenside(king: BasePiece) -> bool:
	var king_pos := king.board_position
	var rook_pos := Vector2i(0, king_pos.y)
	
	# Check rook exists and hasn't moved
	var rook: BasePiece = board.get_piece_at(rook_pos)
	if not rook or rook.piece_type != BasePiece.PieceType.ROOK or rook.has_moved:
		return false
	
	# Check squares between are empty
	for x in range(rook_pos.x + 1, king_pos.x):
		if not board.is_square_empty(Vector2i(x, king_pos.y)):
			return false
	
	# Check king doesn't pass through check
	for x in range(king_pos.x - 2, king_pos.x + 1):
		if _is_square_attacked(Vector2i(x, king_pos.y), king.piece_color):
			return false
	
	return true


## Add en passant moves if available
func _add_en_passant_moves(pawn: BasePiece, moves: Array) -> void:
	if en_passant_target == Vector2i(-1, -1):
		return
	
	var pawn_pos := pawn.board_position
	var capture_dir := -1 if pawn.piece_color == BasePiece.PieceColor.WHITE else 1
	
	# Check if pawn is adjacent to en passant target
	if abs(pawn_pos.x - en_passant_target.x) == 1:
		# En passant target is on the same rank as where the enemy pawn moved to
		var enemy_pawn_rank := en_passant_target.y - capture_dir
		if pawn_pos.y == enemy_pawn_rank:
			if en_passant_target not in moves:
				moves.append(en_passant_target)

# =============================================================================
# CHECK DETECTION
# =============================================================================

## Check if a color is in check
func is_in_check(color: BasePiece.PieceColor) -> bool:
	if _checking_for_check:
		return false
	
	var king := board.get_king(color)
	if not king:
		return false
	
	return _is_square_attacked(king.board_position, color)


## Check if a square is attacked by the opponent
func _is_square_attacked(square: Vector2i, defending_color: BasePiece.PieceColor) -> bool:
	var attacking_color := BasePiece.get_opposite_color(defending_color)
	var attackers := board.get_pieces_by_color(attacking_color)
	
	_checking_for_check = true
	
	for attacker in attackers:
		var attack_squares := attacker.get_attack_squares()
		if square in attack_squares:
			_checking_for_check = false
			return true
	
	_checking_for_check = false
	return false


## Get all pieces attacking a square
func get_attackers(square: Vector2i, attacking_color: BasePiece.PieceColor) -> Array[BasePiece]:
	var attackers: Array[BasePiece] = []
	var pieces := board.get_pieces_by_color(attacking_color)
	
	_checking_for_check = true
	
	for piece in pieces:
		var attack_squares := piece.get_attack_squares()
		if square in attack_squares:
			attackers.append(piece)
	
	_checking_for_check = false
	return attackers


## Check if a move would leave the king in check
func _would_move_cause_check(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if _checking_for_check:
		return false
	
	# Simulate the move
	var captured_piece: BasePiece = board.get_piece_at(to_pos)
	
	# Temporarily make the move
	board.pieces[from_pos.x][from_pos.y] = null
	board.pieces[to_pos.x][to_pos.y] = piece
	var old_pos := piece.board_position
	piece.board_position = to_pos
	
	# Check if king is in check
	var in_check := is_in_check(piece.piece_color)
	
	# Undo the move
	board.pieces[from_pos.x][from_pos.y] = piece
	board.pieces[to_pos.x][to_pos.y] = captured_piece
	piece.board_position = old_pos
	
	return in_check

# =============================================================================
# CHECKMATE / STALEMATE DETECTION
# =============================================================================

## Check if a color is in checkmate
func is_checkmate(color: BasePiece.PieceColor) -> bool:
	if not is_in_check(color):
		return false
	
	return not _has_legal_moves(color)


## Check if a color is in stalemate
func is_stalemate(color: BasePiece.PieceColor) -> bool:
	if is_in_check(color):
		return false
	
	return not _has_legal_moves(color)


## Check if a color has any legal moves
func _has_legal_moves(color: BasePiece.PieceColor) -> bool:
	var pieces := board.get_pieces_by_color(color)
	
	for piece in pieces:
		var moves := get_legal_moves(piece)
		if moves.size() > 0:
			return true
	
	return false

# =============================================================================
# MOVE EXECUTION
# =============================================================================

## Execute a move and handle special cases
func execute_move(piece: BasePiece, to_pos: Vector2i) -> Dictionary:
	var result := {
		"success": false,
		"captured": null,
		"is_castling": false,
		"is_en_passant": false,
		"is_promotion": false,
		"gives_check": false,
		"is_checkmate": false,
		"is_stalemate": false,
		"notation": ""
	}
	
	if not is_move_legal(piece, to_pos):
		return result
	
	var from_pos := piece.board_position
	
	# Check for special moves
	if piece.piece_type == BasePiece.PieceType.KING:
		result = _handle_king_move(piece, from_pos, to_pos, result)
	elif piece.piece_type == BasePiece.PieceType.PAWN:
		result = _handle_pawn_move(piece, from_pos, to_pos, result)
	else:
		# Regular move
		result.captured = board.get_piece_at(to_pos)
		board.move_piece(from_pos, to_pos)
	
	# Update castling rights
	_update_castling_rights(piece, from_pos)
	
	# Update en passant target
	_update_en_passant_target(piece, from_pos, to_pos)
	
	# Check game state
	var opponent_color := BasePiece.get_opposite_color(piece.piece_color)
	result.gives_check = is_in_check(opponent_color)
	result.is_checkmate = is_checkmate(opponent_color)
	result.is_stalemate = is_stalemate(opponent_color)
	
	# Generate notation
	result.notation = _generate_notation(piece, from_pos, to_pos, result)
	
	result.success = true
	return result


## Handle king moves (including castling)
func _handle_king_move(_king: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary) -> Dictionary:
	var dx := to_pos.x - from_pos.x
	
	# Check for castling
	if abs(dx) == 2:
		result.is_castling = true
		
		# Determine rook positions
		var rook_from: Vector2i
		var rook_to: Vector2i
		
		if dx > 0:  # Kingside
			rook_from = Vector2i(board.columns - 1, from_pos.y)
			rook_to = Vector2i(to_pos.x - 1, to_pos.y)
		else:  # Queenside
			rook_from = Vector2i(0, from_pos.y)
			rook_to = Vector2i(to_pos.x + 1, to_pos.y)
		
		# Move king and rook
		board.move_piece(from_pos, to_pos)
		board.move_piece(rook_from, rook_to)
	else:
		# Regular king move
		result.captured = board.get_piece_at(to_pos)
		board.move_piece(from_pos, to_pos)
	
	return result


## Handle pawn moves (including en passant and promotion)
func _handle_pawn_move(pawn: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary) -> Dictionary:
	# Check for en passant
	if to_pos == en_passant_target:
		result.is_en_passant = true
		var captured_pawn_pos := Vector2i(to_pos.x, from_pos.y)
		result.captured = board.get_piece_at(captured_pawn_pos)
		board.remove_piece(captured_pawn_pos)
		if result.captured:
			result.captured.on_death(pawn)
	else:
		result.captured = board.get_piece_at(to_pos)
	
	board.move_piece(from_pos, to_pos)
	
	# Check for promotion
	var promotion_rank := 0 if pawn.piece_color == BasePiece.PieceColor.WHITE else board.rows - 1
	if to_pos.y == promotion_rank:
		result.is_promotion = true
		# Promotion will be handled by the caller
	
	return result


## Update castling rights after a move
func _update_castling_rights(piece: BasePiece, from_pos: Vector2i) -> void:
	var color := piece.piece_color
	
	# King move removes all castling rights
	if piece.piece_type == BasePiece.PieceType.KING:
		castling_rights[color]["kingside"] = false
		castling_rights[color]["queenside"] = false
	
	# Rook move removes corresponding castling right
	if piece.piece_type == BasePiece.PieceType.ROOK:
		if from_pos.x == 0:
			castling_rights[color]["queenside"] = false
		elif from_pos.x == board.columns - 1:
			castling_rights[color]["kingside"] = false


## Update en passant target after a move
func _update_en_passant_target(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i) -> void:
	# Reset en passant target
	en_passant_target = Vector2i(-1, -1)
	
	# Set new en passant target if pawn double move
	if piece.piece_type == BasePiece.PieceType.PAWN:
		if abs(to_pos.y - from_pos.y) == 2:
			# En passant square is the square the pawn passed through
			@warning_ignore("integer_division")
			var ep_y := (from_pos.y + to_pos.y) / 2
			en_passant_target = Vector2i(to_pos.x, ep_y)


## Generate algebraic notation for a move
func _generate_notation(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary) -> String:
	var notation := ""
	
	# Castling
	if result.is_castling:
		if to_pos.x > from_pos.x:
			notation = "O-O"  # Kingside
		else:
			notation = "O-O-O"  # Queenside
	else:
		# Piece notation
		notation = piece.get_notation()
		
		# Add disambiguation if needed (file or rank)
		# TODO: Add disambiguation for same piece type moves
		
		# Capture notation
		if result.captured or result.is_en_passant:
			if piece.piece_type == BasePiece.PieceType.PAWN:
				notation += board.get_algebraic_notation(from_pos)[0]  # Add file for pawn captures
			notation += "x"
		
		# Destination square
		notation += board.get_algebraic_notation(to_pos)
		
		# Promotion
		if result.is_promotion:
			notation += "=Q"  # Default to queen, can be modified
		
		# En passant
		if result.is_en_passant:
			notation += " e.p."
	
	# Check/checkmate
	if result.is_checkmate:
		notation += "#"
	elif result.gives_check:
		notation += "+"
	
	return notation

# =============================================================================
# UTILITY
# =============================================================================

## Get the current game state as a dictionary
func get_state() -> Dictionary:
	return {
		"en_passant_target": {"x": en_passant_target.x, "y": en_passant_target.y},
		"castling_rights": castling_rights.duplicate(true)
	}


## Restore state from a dictionary
func restore_state(state: Dictionary) -> void:
	var ep: Dictionary = state.get("en_passant_target", {"x": -1, "y": -1})
	en_passant_target = Vector2i(ep.x, ep.y)
	var restored_rights: Dictionary = state.get("castling_rights", castling_rights)
	castling_rights = restored_rights.duplicate(true)


## Reset to initial game state
func reset() -> void:
	_reset_game_state()

class_name SearchAlgorithms
extends RefCounted
## Chess search algorithms implementation
## Based on Chess Programming Wiki recommendations

# =============================================================================
# CONSTANTS
# =============================================================================

const INFINITY: float = 1000000.0
const CHECKMATE_SCORE: float = 100000.0
const STALEMATE_SCORE: float = 0.0

## Transposition table entry types
enum TTEntryType {
	EXACT = 0,
	LOWER_BOUND = 1,
	UPPER_BOUND = 2
}

# =============================================================================
# PROPERTIES
# =============================================================================

## Board reference
var board: BaseBoard = null

## Rules engine reference
var rules_engine: RulesEngine = null

## Evaluator reference
var evaluator: Evaluator = null

## Game mode reference (for custom win conditions)
var game_mode: BaseGameMode = null

## Search statistics
var nodes_searched: int = 0
var max_depth_reached: int = 0

## Transposition table
var transposition_table: Dictionary = {}
const TT_SIZE := 100000

## Killer moves (for move ordering)
var killer_moves: Array = []  # [depth][0-1]
const MAX_KILLER_DEPTH := 32

## History heuristic
var history_table: Dictionary = {}  # [piece_type][to_square] = score

## Search control
var should_stop: bool = false
var time_limit_ms: int = 0
var start_time_ms: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	_init_killer_moves()


func _init_killer_moves() -> void:
	killer_moves.clear()
	for i in range(MAX_KILLER_DEPTH):
		killer_moves.append([null, null])


func setup(b: BaseBoard, re: RulesEngine, ev: Evaluator, gm: BaseGameMode = null) -> void:
	board = b
	rules_engine = re
	evaluator = ev
	game_mode = gm

# =============================================================================
# MAIN SEARCH INTERFACE
# =============================================================================

## Find the best move using iterative deepening
func find_best_move(color: BasePiece.PieceColor, max_depth: int = 6, time_limit: int = 5000) -> Dictionary:
	should_stop = false
	nodes_searched = 0
	max_depth_reached = 0
	start_time_ms = Time.get_ticks_msec()
	time_limit_ms = time_limit
	
	var best_move: Dictionary = {}
	var best_score: float = -INFINITY
	
	# Iterative deepening
	for depth in range(1, max_depth + 1):
		if should_stop:
			break
		
		var result := _search_root(color, depth)
		
		if not should_stop and result.size() > 0:
			best_move = result
			best_score = result.score
			max_depth_reached = depth
			
			# Early exit on checkmate found
			if abs(best_score) > CHECKMATE_SCORE - 100:
				break
		
		# Check time
		if _is_time_up():
			break
	
	return best_move


## Root search - generates all moves and searches each
func _search_root(color: BasePiece.PieceColor, depth: int) -> Dictionary:
	var best_move: Dictionary = {}
	var best_score: float = -INFINITY
	var alpha: float = -INFINITY
	var beta: float = INFINITY
	
	var moves := _get_ordered_moves(color, 0)
	
	for move in moves:
		if should_stop or _is_time_up():
			break
		
		# Make move
		var captured := _make_move(move)
		
		# Search
		var score := -_alpha_beta(-beta, -alpha, depth - 1, 1, not _is_maximizing(color))
		
		# Unmake move
		_unmake_move(move, captured)
		
		if score > best_score:
			best_score = score
			best_move = move.duplicate()
			best_move.score = score
		
		alpha = max(alpha, score)
	
	return best_move

# =============================================================================
# ALPHA-BETA SEARCH
# =============================================================================

## Alpha-Beta search with various enhancements
func _alpha_beta(alpha: float, beta: float, depth: int, ply: int, is_maximizing: bool) -> float:
	nodes_searched += 1
	
	# Check time periodically
	if nodes_searched % 1000 == 0 and _is_time_up():
		should_stop = true
		return 0.0
	
	# Check for terminal state
	var color := BasePiece.PieceColor.WHITE if is_maximizing else BasePiece.PieceColor.BLACK
	
	if rules_engine.is_checkmate(color):
		return -CHECKMATE_SCORE + ply  # Prefer shorter checkmates
	
	if rules_engine.is_stalemate(color):
		return STALEMATE_SCORE
	
	# Depth 0 - quiescence search
	if depth <= 0:
		return _quiescence_search(alpha, beta, is_maximizing)
	
	# Transposition table lookup
	var tt_key := _get_position_hash()
	var tt_entry: Dictionary = transposition_table.get(tt_key, {})
	
	if not tt_entry.is_empty() and tt_entry.depth >= depth:
		match tt_entry.type:
			TTEntryType.EXACT:
				return tt_entry.score
			TTEntryType.LOWER_BOUND:
				alpha = max(alpha, tt_entry.score)
			TTEntryType.UPPER_BOUND:
				beta = min(beta, tt_entry.score)
		
		if alpha >= beta:
			return tt_entry.score
	
	# Generate and order moves
	var moves := _get_ordered_moves(color, ply)
	
	if moves.is_empty():
		# No legal moves - check for game over
		if rules_engine.is_in_check(color):
			return -CHECKMATE_SCORE + ply
		return STALEMATE_SCORE
	
	var best_score := -INFINITY
	var best_move: Dictionary = {}
	var tt_type := TTEntryType.UPPER_BOUND
	
	for move in moves:
		if should_stop:
			break
		
		var captured := _make_move(move)
		var score := -_alpha_beta(-beta, -alpha, depth - 1, ply + 1, not is_maximizing)
		_unmake_move(move, captured)
		
		if score > best_score:
			best_score = score
			best_move = move
		
		if score > alpha:
			alpha = score
			tt_type = TTEntryType.EXACT
		
		if alpha >= beta:
			# Beta cutoff - update killer moves
			if not move.get("is_capture", false):
				_update_killers(move, ply)
				_update_history(move, depth)
			tt_type = TTEntryType.LOWER_BOUND
			break
	
	# Store in transposition table
	_store_tt(tt_key, depth, best_score, tt_type, best_move)
	
	return best_score

# =============================================================================
# QUIESCENCE SEARCH
# =============================================================================

## Search only captures to avoid horizon effect
func _quiescence_search(alpha: float, beta: float, is_maximizing: bool) -> float:
	nodes_searched += 1
	
	var color := BasePiece.PieceColor.WHITE if is_maximizing else BasePiece.PieceColor.BLACK
	
	# Stand-pat score
	var stand_pat := evaluator.evaluate(board, rules_engine)
	if not is_maximizing:
		stand_pat = -stand_pat
	
	if stand_pat >= beta:
		return beta
	
	if stand_pat > alpha:
		alpha = stand_pat
	
	# Generate capture moves only
	var captures := _get_captures(color)
	captures = _order_captures(captures)
	
	for move in captures:
		var captured := _make_move(move)
		var score := -_quiescence_search(-beta, -alpha, not is_maximizing)
		_unmake_move(move, captured)
		
		if score >= beta:
			return beta
		
		if score > alpha:
			alpha = score
	
	return alpha

# =============================================================================
# MOVE GENERATION AND ORDERING
# =============================================================================

## Get ordered moves for a given color
func _get_ordered_moves(color: BasePiece.PieceColor, ply: int) -> Array:
	var moves: Array = []
	var pieces := board.get_pieces_by_color(color)
	
	for piece in pieces:
		var legal_moves := rules_engine.get_legal_moves(piece)
		for target in legal_moves:
			moves.append({
				"piece": piece,
				"from": piece.board_position,
				"to": target,
				"is_capture": board.get_piece_at(target) != null
			})
	
	return _order_moves(moves, ply)


## Order moves for better alpha-beta pruning
func _order_moves(moves: Array, ply: int) -> Array:
	var scored_moves: Array = []
	
	for move in moves:
		var score := 0
		
		# MVV-LVA for captures
		if move.is_capture:
			var captured: BasePiece = board.get_piece_at(move.to)
			var attacker: BasePiece = move.piece
			if captured:
				score += _get_mvv_lva_score(attacker, captured)
		
		# Killer moves
		if ply < MAX_KILLER_DEPTH:
			if _is_killer_move(move, ply, 0):
				score += 9000
			elif _is_killer_move(move, ply, 1):
				score += 8000
		
		# History heuristic
		score += _get_history_score(move)
		
		scored_moves.append({"move": move, "score": score})
	
	# Sort by score descending
	scored_moves.sort_custom(func(a, b): return a.score > b.score)
	
	var result: Array = []
	for sm in scored_moves:
		result.append(sm.move)
	
	return result


## Get capture moves only
func _get_captures(color: BasePiece.PieceColor) -> Array:
	var captures: Array = []
	var pieces := board.get_pieces_by_color(color)
	
	for piece in pieces:
		var legal_moves := rules_engine.get_legal_moves(piece)
		for target in legal_moves:
			if board.get_piece_at(target) != null:
				captures.append({
					"piece": piece,
					"from": piece.board_position,
					"to": target,
					"is_capture": true
				})
	
	return captures


func _order_captures(captures: Array) -> Array:
	var scored: Array = []
	
	for cap in captures:
		var captured: BasePiece = board.get_piece_at(cap.to)
		var attacker: BasePiece = cap.piece
		var score := _get_mvv_lva_score(attacker, captured) if captured else 0
		scored.append({"move": cap, "score": score})
	
	scored.sort_custom(func(a, b): return a.score > b.score)
	
	var result: Array = []
	for s in scored:
		result.append(s.move)
	
	return result


## Most Valuable Victim - Least Valuable Attacker
func _get_mvv_lva_score(attacker: BasePiece, victim: BasePiece) -> int:
	var victim_value: int = Evaluator.PIECE_VALUES.get(victim.piece_type, 100)
	var attacker_value: int = Evaluator.PIECE_VALUES.get(attacker.piece_type, 100)
	return victim_value * 10 - attacker_value

# =============================================================================
# MOVE EXECUTION
# =============================================================================

func _make_move(move: Dictionary) -> BasePiece:
	var piece: BasePiece = move.piece
	var from_pos: Vector2i = move.from
	var to_pos: Vector2i = move.to
	
	var captured: BasePiece = board.get_piece_at(to_pos)
	
	# Move piece
	board.pieces[from_pos.x][from_pos.y] = null
	board.pieces[to_pos.x][to_pos.y] = piece
	piece.board_position = to_pos
	
	return captured


func _unmake_move(move: Dictionary, captured: BasePiece) -> void:
	var piece: BasePiece = move.piece
	var from_pos: Vector2i = move.from
	var to_pos: Vector2i = move.to
	
	board.pieces[to_pos.x][to_pos.y] = captured
	board.pieces[from_pos.x][from_pos.y] = piece
	piece.board_position = from_pos

# =============================================================================
# KILLER MOVES
# =============================================================================

func _update_killers(move: Dictionary, ply: int) -> void:
	if ply >= MAX_KILLER_DEPTH:
		return
	
	# Don't add if already killer
	if _is_killer_move(move, ply, 0):
		return
	
	# Shift and add new killer
	killer_moves[ply][1] = killer_moves[ply][0]
	killer_moves[ply][0] = {
		"from": move.from,
		"to": move.to,
		"piece_type": move.piece.piece_type
	}


func _is_killer_move(move: Dictionary, ply: int, slot: int) -> bool:
	if ply >= MAX_KILLER_DEPTH:
		return false
	
	var killer: Dictionary = killer_moves[ply][slot]
	if killer == null:
		return false
	
	return (killer.from == move.from and 
			killer.to == move.to and 
			killer.piece_type == move.piece.piece_type)

# =============================================================================
# HISTORY HEURISTIC
# =============================================================================

func _update_history(move: Dictionary, depth: int) -> void:
	var key := _get_history_key(move)
	if not history_table.has(key):
		history_table[key] = 0
	history_table[key] += depth * depth


func _get_history_score(move: Dictionary) -> int:
	var key := _get_history_key(move)
	return history_table.get(key, 0)


func _get_history_key(move: Dictionary) -> String:
	return str(move.piece.piece_type) + "_" + str(move.to.x) + "_" + str(move.to.y)

# =============================================================================
# TRANSPOSITION TABLE
# =============================================================================

func _get_position_hash() -> int:
	# Simple hash based on piece positions
	# In production, use Zobrist hashing
	var hash_val := 0
	for piece in board.get_all_pieces():
		hash_val ^= hash(str(piece.piece_type) + str(piece.piece_color) + str(piece.board_position))
	return hash_val


func _store_tt(key: int, depth: int, score: float, type: TTEntryType, best_move: Dictionary) -> void:
	if transposition_table.size() > TT_SIZE:
		# Simple replacement - clear oldest entries
		transposition_table.clear()
	
	transposition_table[key] = {
		"depth": depth,
		"score": score,
		"type": type,
		"best_move": best_move
	}

# =============================================================================
# UTILITY
# =============================================================================

func _is_maximizing(color: BasePiece.PieceColor) -> bool:
	return color == BasePiece.PieceColor.WHITE


func _is_time_up() -> bool:
	if time_limit_ms <= 0:
		return false
	return Time.get_ticks_msec() - start_time_ms >= time_limit_ms


func clear_tables() -> void:
	transposition_table.clear()
	history_table.clear()
	_init_killer_moves()


class_name AIPlayer
extends RefCounted
## AI player that uses search and evaluation to find the best move

# =============================================================================
# ENUMS
# =============================================================================

enum Difficulty {
	EASY = 0,
	MEDIUM = 1,
	HARD = 2,
	EXPERT = 3
}

# =============================================================================
# SIGNALS (forwarded via EventBus)
# =============================================================================

# AI thinking progress is communicated via EventBus

# =============================================================================
# PROPERTIES
# =============================================================================

## AI difficulty level
var difficulty: Difficulty = Difficulty.MEDIUM

## The color this AI plays as
var color: BasePiece.PieceColor = BasePiece.PieceColor.BLACK

## Search algorithm instance
var search: SearchAlgorithms = null

## Evaluator instance
var evaluator: Evaluator = null

## Board reference
var board: BaseBoard = null

## Rules engine reference
var rules_engine: RulesEngine = null

## Game mode reference
var game_mode: BaseGameMode = null

## Difficulty settings
var difficulty_settings: Dictionary = {
	Difficulty.EASY: {"depth": 2, "time_ms": 1000, "noise": 50},
	Difficulty.MEDIUM: {"depth": 4, "time_ms": 3000, "noise": 20},
	Difficulty.HARD: {"depth": 5, "time_ms": 5000, "noise": 5},
	Difficulty.EXPERT: {"depth": 6, "time_ms": 10000, "noise": 0}
}

## Is currently thinking
var is_thinking: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _init(ai_color: BasePiece.PieceColor = BasePiece.PieceColor.BLACK, 
		   ai_difficulty: Difficulty = Difficulty.MEDIUM) -> void:
	color = ai_color
	difficulty = ai_difficulty
	evaluator = Evaluator.new()
	search = SearchAlgorithms.new()


func setup(game_board: BaseBoard, engine: RulesEngine, mode: BaseGameMode = null) -> void:
	board = game_board
	rules_engine = engine
	game_mode = mode
	search.setup(board, rules_engine, evaluator, game_mode)
	
	# Configure evaluator based on game mode
	if game_mode and game_mode.has_method("get_ai_evaluator"):
		var custom_eval: Resource = game_mode.get_ai_evaluator()
		if custom_eval:
			# Use custom evaluator from game mode
			pass

# =============================================================================
# MAIN INTERFACE
# =============================================================================

## Calculate and return the best move for this AI
func get_best_move() -> Dictionary:
	if not board or not rules_engine:
		push_error("AI not properly set up")
		return {}
	
	is_thinking = true
	
	# Emit thinking started signal via EventBus
	if EventBus:
		EventBus.ai_thinking_started.emit(color)
	
	var settings: Dictionary = difficulty_settings.get(difficulty, difficulty_settings[Difficulty.MEDIUM])
	var depth: int = settings.depth
	var time_ms: int = settings.time_ms
	var noise: int = settings.noise
	
	# Find best move
	var result := search.find_best_move(color, depth, time_ms)
	
	# Add noise for lower difficulties
	if noise > 0 and result.size() > 0:
		result = _add_evaluation_noise(result, noise)
	
	is_thinking = false
	
	# Emit thinking finished signal
	if EventBus:
		EventBus.ai_thinking_finished.emit(color, result)
		EventBus.ai_evaluation_updated.emit(result.get("score", 0.0), search.max_depth_reached)
	
	return result


## Async version for use with signals/await
func calculate_move_async() -> Dictionary:
	# Run on a separate thread if needed
	# For now, just call synchronously
	return get_best_move()


## Make the AI's move on the board
func make_move() -> Dictionary:
	var move := get_best_move()
	
	if move.is_empty():
		push_warning("AI could not find a legal move")
		return {}
	
	# Execute the move through the rules engine
	var piece: BasePiece = move.piece
	var to_pos: Vector2i = move.to
	
	var result := rules_engine.execute_move(piece, to_pos)
	result.ai_evaluation = move.get("score", 0.0)
	
	return result

# =============================================================================
# DIFFICULTY ADJUSTMENT
# =============================================================================

func set_difficulty(new_difficulty: Difficulty) -> void:
	difficulty = new_difficulty
	search.clear_tables()  # Clear cached search data


func set_custom_difficulty(depth: int, time_ms: int, noise: int) -> void:
	difficulty_settings[difficulty] = {
		"depth": depth,
		"time_ms": time_ms,
		"noise": noise
	}


## Add random noise to evaluation for easier difficulties
func _add_evaluation_noise(move: Dictionary, noise_factor: int) -> Dictionary:
	if noise_factor <= 0:
		return move
	
	# Get all legal moves with their evaluations
	var pieces := board.get_pieces_by_color(color)
	var all_moves: Array = []
	
	for piece in pieces:
		var legal_moves := rules_engine.get_legal_moves(piece)
		for target in legal_moves:
			# Quick evaluation
			var temp_captured: BasePiece = board.get_piece_at(target)
			board.pieces[piece.board_position.x][piece.board_position.y] = null
			board.pieces[target.x][target.y] = piece
			var old_pos := piece.board_position
			piece.board_position = target
			
			var score := evaluator.evaluate_quick(board)
			if color == BasePiece.PieceColor.BLACK:
				score = -score
			
			# Restore
			board.pieces[target.x][target.y] = temp_captured
			board.pieces[old_pos.x][old_pos.y] = piece
			piece.board_position = old_pos
			
			# Add noise
			score += randf_range(-noise_factor, noise_factor)
			
			all_moves.append({
				"piece": piece,
				"from": old_pos,
				"to": target,
				"score": score,
				"is_capture": temp_captured != null
			})
	
	if all_moves.is_empty():
		return move
	
	# Sort by noisy score
	all_moves.sort_custom(func(a, b): return a.score > b.score)
	
	# Return the "best" move after noise
	return all_moves[0]

# =============================================================================
# OPENING BOOK (Placeholder)
# =============================================================================

## Check if there's a book move available
func get_book_move() -> Dictionary:
	# Opening book implementation would go here
	# For now, return empty (no book)
	return {}


func _get_opening_moves() -> Array:
	# Common opening moves could be stored here
	# e.g., 1.e4, 1.d4, 1.Nf3, 1.c4
	return []

# =============================================================================
# GAME MODE ADAPTATION
# =============================================================================

## Get evaluation for custom game modes
func get_mode_evaluation() -> float:
	if game_mode and game_mode.has_method("evaluate_position"):
		return game_mode.evaluate_position(board)
	return evaluator.evaluate(board, rules_engine)


## Check if the AI should prioritize different factors based on game mode
func adapt_to_game_mode() -> void:
	if not game_mode:
		return
	
	# Adapt evaluation weights based on game mode
	match game_mode.mode_id:
		"king_of_hill":
			# Prioritize king activity
			evaluator.king_safety_weight = 5.0  # Lower, as king needs to be active
		"three_check":
			# Prioritize checking the opponent
			evaluator.mobility_weight = 15.0
		"atomic":
			# Be more careful with captures
			pass
		_:
			# Default weights
			pass

# =============================================================================
# STATISTICS
# =============================================================================

func get_search_stats() -> Dictionary:
	return {
		"nodes_searched": search.nodes_searched,
		"max_depth": search.max_depth_reached,
		"difficulty": difficulty,
		"color": "White" if color == BasePiece.PieceColor.WHITE else "Black"
	}


func get_last_evaluation() -> float:
	# Return the evaluation of the last calculated move
	return 0.0  # Would need to store this from the search


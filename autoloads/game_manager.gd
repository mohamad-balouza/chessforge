extends Node
## GameManager Autoload - Central controller for game state and logic
## Accessed globally as GameManager (autoload singleton - do not add class_name)
## GameManager Autoload - Central controller for game state and logic

# =============================================================================
# ENUMS
# =============================================================================

enum GameState {
	MENU = 0,
	SETUP = 1,
	PLAYING = 2,
	PAUSED = 3,
	ENDED = 4
}

enum PlayerType {
	HUMAN = 0,
	AI = 1,
	NETWORK = 2
}

# =============================================================================
# SIGNALS
# =============================================================================

signal state_changed(old_state: GameState, new_state: GameState)
signal game_started()
signal game_ended(result: Dictionary)
signal turn_changed(player_color: BasePiece.PieceColor)
signal move_made(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary)
signal piece_selected(piece: BasePiece)
signal piece_deselected()
signal promotion_required(pawn: BasePiece, position: Vector2i)
signal check_declared(color: BasePiece.PieceColor)

# =============================================================================
# PROPERTIES
# =============================================================================

## Current game state
var current_state: GameState = GameState.MENU

## Reference to the active board
var board: BaseBoard = null

## Reference to the rules engine
var rules_engine: RulesEngine = null

## Reference to the current game mode
var game_mode: BaseGameMode = null

## Current player to move
var current_player: BasePiece.PieceColor = BasePiece.PieceColor.WHITE

## Player types
var player_types: Dictionary = {
	BasePiece.PieceColor.WHITE: PlayerType.HUMAN,
	BasePiece.PieceColor.BLACK: PlayerType.HUMAN
}

## Currently selected piece
var selected_piece: BasePiece = null

## Move history
var move_history: Array[Dictionary] = []

## Turn number
var turn_number: int = 1

## Captured pieces
var captured_pieces: Dictionary = {
	BasePiece.PieceColor.WHITE: [],  # Pieces captured by white
	BasePiece.PieceColor.BLACK: []   # Pieces captured by black
}

# AI references (will be set when AI is implemented)
var ai_players: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	print("[GameManager] Initialized")
	_connect_signals()


func _connect_signals() -> void:
	# Connect to EventBus signals if available
	# EventBus is an autoload, signals will be connected as needed
	pass

# =============================================================================
# GAME INITIALIZATION
# =============================================================================

## Initialize a new game
func new_game(game_board: BaseBoard, mode: BaseGameMode = null) -> void:
	# Clear previous game
	_cleanup_game()
	
	# Set up references
	board = game_board
	
	# Create default classic mode if none provided
	if mode:
		game_mode = mode
	else:
		game_mode = _create_classic_mode()
	
	# Create rules engine
	rules_engine = RulesEngine.new(board, game_mode)
	game_mode.initialize(board, rules_engine)
	
	# Set up initial position
	_setup_initial_position()
	
	# Reset state
	current_player = BasePiece.PieceColor.WHITE
	turn_number = 1
	move_history.clear()
	captured_pieces = {
		BasePiece.PieceColor.WHITE: [],
		BasePiece.PieceColor.BLACK: []
	}
	
	# Start game
	_change_state(GameState.PLAYING)
	game_mode.on_game_start()
	game_started.emit()
	turn_changed.emit(current_player)


func _create_classic_mode() -> BaseGameMode:
	var mode := BaseGameMode.new()
	mode.mode_id = "classic"
	mode.mode_name = "Classic Chess"
	mode.primary_win_condition = BaseGameMode.WinCondition.CHECKMATE
	return mode


func _cleanup_game() -> void:
	if board:
		# Clear all pieces
		for piece in board.get_all_pieces():
			piece.queue_free()
	
	selected_piece = null
	rules_engine = null


## Set up the standard chess starting position
func _setup_initial_position() -> void:
	if not board:
		return
	
	# Clear board first
	for x in range(board.columns):
		for y in range(board.rows):
			board.pieces[x][y] = null
	
	# White pieces (row 7 and 6 for 0-indexed 8x8 board)
	_place_back_rank(BasePiece.PieceColor.WHITE, 7)
	_place_pawn_rank(BasePiece.PieceColor.WHITE, 6)
	
	# Black pieces (row 0 and 1)
	_place_back_rank(BasePiece.PieceColor.BLACK, 0)
	_place_pawn_rank(BasePiece.PieceColor.BLACK, 1)


func _place_back_rank(color: BasePiece.PieceColor, rank: int) -> void:
	var piece_order := [
		BasePiece.PieceType.ROOK,
		BasePiece.PieceType.KNIGHT,
		BasePiece.PieceType.BISHOP,
		BasePiece.PieceType.QUEEN,
		BasePiece.PieceType.KING,
		BasePiece.PieceType.BISHOP,
		BasePiece.PieceType.KNIGHT,
		BasePiece.PieceType.ROOK
	]
	
	for file in range(8):
		var piece := _create_piece(piece_order[file], color)
		if piece:
			board.place_piece(piece, Vector2i(file, rank))


func _place_pawn_rank(color: BasePiece.PieceColor, rank: int) -> void:
	for file in range(8):
		var piece := _create_piece(BasePiece.PieceType.PAWN, color)
		if piece:
			board.place_piece(piece, Vector2i(file, rank))


func _create_piece(type: BasePiece.PieceType, color: BasePiece.PieceColor) -> BasePiece:
	var piece: BasePiece = null
	
	match type:
		BasePiece.PieceType.KING:
			piece = King.new()
		BasePiece.PieceType.QUEEN:
			piece = Queen.new()
		BasePiece.PieceType.ROOK:
			piece = Rook.new()
		BasePiece.PieceType.BISHOP:
			piece = Bishop.new()
		BasePiece.PieceType.KNIGHT:
			piece = Knight.new()
		BasePiece.PieceType.PAWN:
			piece = Pawn.new()
	
	if piece:
		piece.piece_color = color
		# Add sprite node for visual
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		piece.add_child(sprite)
	
	return piece

# =============================================================================
# STATE MANAGEMENT
# =============================================================================

func _change_state(new_state: GameState) -> void:
	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		_change_state(GameState.PAUSED)


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		_change_state(GameState.PLAYING)


func end_game(result: Dictionary) -> void:
	_change_state(GameState.ENDED)
	game_ended.emit(result)

# =============================================================================
# MOVE HANDLING
# =============================================================================

## Handle a square click from the board
func on_square_clicked(position: Vector2i) -> void:
	if current_state != GameState.PLAYING:
		return
	
	# Check if it's a human player's turn
	if player_types.get(current_player) != PlayerType.HUMAN:
		return
	
	var piece_at_pos: BasePiece = board.get_piece_at(position)
	
	if selected_piece:
		# A piece is already selected
		if piece_at_pos and piece_at_pos.piece_color == current_player:
			# Clicked on own piece - select it instead
			_select_piece(piece_at_pos)
		elif position in rules_engine.get_legal_moves(selected_piece):
			# Valid move - execute it
			_execute_move(selected_piece, position)
		else:
			# Invalid move - deselect
			_deselect_piece()
	else:
		# No piece selected
		if piece_at_pos and piece_at_pos.piece_color == current_player:
			_select_piece(piece_at_pos)


func _select_piece(piece: BasePiece) -> void:
	selected_piece = piece
	
	# Get legal moves and show them on board
	var legal_moves := rules_engine.get_legal_moves(piece)
	board.select_piece(piece)
	board.highlighted_squares = legal_moves
	
	# Mark attack squares
	board.attack_squares.clear()
	for pos in legal_moves:
		if not board.is_square_empty(pos):
			board.attack_squares.append(pos)
	
	board.queue_redraw()
	piece_selected.emit(piece)


func _deselect_piece() -> void:
	selected_piece = null
	board.clear_selection()
	piece_deselected.emit()


func _execute_move(piece: BasePiece, to_pos: Vector2i) -> void:
	var from_pos := piece.board_position
	
	# Execute move through rules engine
	var result := rules_engine.execute_move(piece, to_pos)
	
	if not result.success:
		_deselect_piece()
		return
	
	# Record move
	_record_move(piece, from_pos, to_pos, result)
	
	# Handle captured piece
	if result.captured:
		captured_pieces[current_player].append(result.captured)
	
	# Handle promotion
	if result.is_promotion:
		_deselect_piece()
		promotion_required.emit(piece, to_pos)
		return  # Wait for promotion choice before continuing
	
	# Check for check
	var opponent := BasePiece.get_opposite_color(current_player)
	if result.gives_check:
		var king := board.get_king(opponent)
		if king:
			board.set_check_square(king.board_position)
		check_declared.emit(opponent)
	else:
		board.clear_check_square()
	
	# Notify game mode
	game_mode.on_move_made(piece, from_pos, to_pos, result)
	
	# Emit signal
	move_made.emit(piece, from_pos, to_pos, result)
	
	# Check game end
	var win_result := game_mode.check_win_condition()
	if win_result.game_over:
		end_game(win_result)
		return
	
	# Next turn
	_next_turn()


func _record_move(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i, result: Dictionary) -> void:
	move_history.append({
		"turn": turn_number,
		"player": current_player,
		"piece_type": piece.piece_type,
		"from": from_pos,
		"to": to_pos,
		"notation": result.notation,
		"captured": result.captured != null,
		"castling": result.is_castling,
		"en_passant": result.is_en_passant,
		"promotion": result.is_promotion,
		"check": result.gives_check,
		"checkmate": result.is_checkmate
	})


## Complete a pawn promotion
func complete_promotion(pawn: BasePiece, new_type: BasePiece.PieceType) -> void:
	if not pawn or new_type == BasePiece.PieceType.PAWN:
		return
	
	var pos := pawn.board_position
	var color := pawn.piece_color
	
	# Remove pawn
	board.remove_piece(pos)
	pawn.queue_free()
	
	# Create new piece
	var new_piece := _create_piece(new_type, color)
	if new_piece:
		board.place_piece(new_piece, pos)
		new_piece.has_moved = true
	
	# Update last move notation
	if move_history.size() > 0:
		var last_move := move_history[-1]
		var type_char := ""
		match new_type:
			BasePiece.PieceType.QUEEN: type_char = "Q"
			BasePiece.PieceType.ROOK: type_char = "R"
			BasePiece.PieceType.BISHOP: type_char = "B"
			BasePiece.PieceType.KNIGHT: type_char = "N"
		last_move.notation = last_move.notation.replace("=Q", "=" + type_char)
	
	# Continue to next turn
	_next_turn()


func _next_turn() -> void:
	_deselect_piece()
	
	# Reduce cooldowns for current player's pieces
	for piece in board.get_pieces_by_color(current_player):
		piece.reduce_turn_cooldowns()
	
	# Switch player
	if current_player == BasePiece.PieceColor.BLACK:
		turn_number += 1
	current_player = BasePiece.get_opposite_color(current_player)
	
	# Update game mode
	game_mode.on_turn_end(BasePiece.get_opposite_color(current_player))
	game_mode.on_turn_start(current_player)
	
	turn_changed.emit(current_player)
	
	# Trigger AI if needed
	if player_types.get(current_player) == PlayerType.AI:
		_trigger_ai_move()


func _trigger_ai_move() -> void:
	# AI move will be handled by the AI system (Phase 3)
	# For now, just a placeholder
	pass

# =============================================================================
# GAME QUERIES
# =============================================================================

## Get the current game state as a dictionary (for saving)
func get_game_state() -> Dictionary:
	return {
		"turn_number": turn_number,
		"current_player": current_player,
		"move_history": move_history.duplicate(true),
		"captured_pieces": {
			"white": captured_pieces[BasePiece.PieceColor.WHITE].map(func(p): return p.to_dict()),
			"black": captured_pieces[BasePiece.PieceColor.BLACK].map(func(p): return p.to_dict())
		},
		"board_state": board.to_dict() if board else {},
		"rules_state": rules_engine.get_state() if rules_engine else {},
		"game_mode": game_mode.to_dict() if game_mode else {},
		"player_types": player_types.duplicate()
	}


## Check if it's a specific player's turn
func is_player_turn(color: BasePiece.PieceColor) -> bool:
	return current_state == GameState.PLAYING and current_player == color


## Get legal moves for a piece at position
func get_legal_moves_at(position: Vector2i) -> Array[Vector2i]:
	if not board or not rules_engine:
		return []
	
	var piece: BasePiece = board.get_piece_at(position)
	if not piece:
		return []
	
	return rules_engine.get_legal_moves(piece)

# =============================================================================
# PLAYER MANAGEMENT
# =============================================================================

## Set player type
func set_player_type(color: BasePiece.PieceColor, type: PlayerType) -> void:
	player_types[color] = type


## Check if current player is human
func is_current_player_human() -> bool:
	return player_types.get(current_player) == PlayerType.HUMAN


class_name BaseBoard
extends Node2D
## Base class for chess boards
## Provides flexible grid system, square management, and piece placement

# =============================================================================
# ENUMS
# =============================================================================

enum SquareState {
	NORMAL = 0,
	BLOCKED = 1,
	SPECIAL = 2,
	HAZARD = 3,
	BUFF_ZONE = 4
}

enum SquareColor {
	LIGHT = 0,
	DARK = 1
}

# =============================================================================
# SIGNALS
# =============================================================================

signal piece_placed(piece: BasePiece, position: Vector2i)
signal piece_removed(piece: BasePiece, position: Vector2i)
signal piece_moved(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i)
signal square_clicked(position: Vector2i)
signal square_state_changed(position: Vector2i, old_state: SquareState, new_state: SquareState)
signal board_resized(old_size: Vector2i, new_size: Vector2i)

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export_group("Board Dimensions")
## Number of columns (files) - standard chess is 8
@export var columns: int = 8
## Number of rows (ranks) - standard chess is 8
@export var rows: int = 8

@export_group("Visual Settings")
## Size of each square in pixels
@export var square_size: Vector2 = Vector2(64, 64)
## Light square color
@export var light_square_color: Color = Color(0.93, 0.86, 0.71)
## Dark square color
@export var dark_square_color: Color = Color(0.71, 0.53, 0.39)
## Highlight color for selected squares
@export var highlight_color: Color = Color(0.3, 0.7, 0.3, 0.5)
## Move hint color
@export var move_hint_color: Color = Color(0.2, 0.5, 0.8, 0.4)
## Attack hint color (for captures)
@export var attack_hint_color: Color = Color(0.8, 0.2, 0.2, 0.4)
## Check indicator color
@export var check_color: Color = Color(1.0, 0.3, 0.3, 0.6)

# =============================================================================
# PROPERTIES
# =============================================================================

## 2D array storing pieces: pieces[x][y] = BasePiece or null
var pieces: Array = []

## 2D array storing square states: square_states[x][y] = SquareState
var square_states: Array = []

## 2D array storing square modifiers: square_modifiers[x][y] = Array[Resource]
var square_modifiers: Array = []

## Dictionary of valid squares (for non-rectangular boards)
## Key: Vector2i, Value: bool
var valid_squares: Dictionary = {}

## Currently selected piece
var selected_piece: BasePiece = null

## Currently highlighted squares for legal moves
var highlighted_squares: Array[Vector2i] = []

## Squares marked as under attack
var attack_squares: Array[Vector2i] = []

## Square in check state
var check_square: Vector2i = Vector2i(-1, -1)

## En passant target square (for en passant captures)
var en_passant_square: Vector2i = Vector2i(-1, -1)

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var pieces_container: Node2D = $PiecesContainer if has_node("PiecesContainer") else null
@onready var highlights_container: Node2D = $HighlightsContainer if has_node("HighlightsContainer") else null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_initialize_board()
	_setup_input()


func _initialize_board() -> void:
	# Initialize arrays
	_resize_arrays()
	
	# Mark all squares as valid by default
	for x in range(columns):
		for y in range(rows):
			valid_squares[Vector2i(x, y)] = true
	
	# Create containers if they don't exist
	if not pieces_container:
		pieces_container = Node2D.new()
		pieces_container.name = "PiecesContainer"
		add_child(pieces_container)
	
	if not highlights_container:
		highlights_container = Node2D.new()
		highlights_container.name = "HighlightsContainer"
		add_child(highlights_container)
		# Make sure highlights are behind pieces
		move_child(highlights_container, 0)


func _resize_arrays() -> void:
	pieces.clear()
	square_states.clear()
	square_modifiers.clear()
	
	for x in range(columns):
		var piece_column: Array = []
		var state_column: Array = []
		var modifier_column: Array = []
		
		for y in range(rows):
			piece_column.append(null)
			state_column.append(SquareState.NORMAL)
			modifier_column.append([])
		
		pieces.append(piece_column)
		square_states.append(state_column)
		square_modifiers.append(modifier_column)


func _setup_input() -> void:
	# Enable input processing
	set_process_input(true)


func _draw() -> void:
	_draw_board()
	_draw_highlights()


func _draw_board() -> void:
	for x in range(columns):
		for y in range(rows):
			var pos := Vector2i(x, y)
			if not is_valid_square(pos):
				continue
			
			var rect_pos := Vector2(x * square_size.x, y * square_size.y)
			var rect := Rect2(rect_pos, square_size)
			
			# Determine square color
			var color: Color
			if get_square_color(pos) == SquareColor.LIGHT:
				color = light_square_color
			else:
				color = dark_square_color
			
			# Draw base square
			draw_rect(rect, color)
			
			# Draw check indicator
			if pos == check_square:
				draw_rect(rect, check_color)


func _draw_highlights() -> void:
	# Draw selected piece highlight
	if selected_piece and selected_piece.board_position != Vector2i(-1, -1):
		var rect_pos := Vector2(selected_piece.board_position.x * square_size.x, 
								selected_piece.board_position.y * square_size.y)
		var rect := Rect2(rect_pos, square_size)
		draw_rect(rect, highlight_color)
	
	# Draw legal move hints
	for pos in highlighted_squares:
		var rect_pos := Vector2(pos.x * square_size.x, pos.y * square_size.y)
		var rect := Rect2(rect_pos, square_size)
		
		# Use different color for captures
		if pos in attack_squares:
			draw_rect(rect, attack_hint_color)
		else:
			draw_rect(rect, move_hint_color)

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_click(event.position)


func _handle_click(click_pos: Vector2) -> void:
	# Convert to local coordinates
	var local_pos := to_local(click_pos)
	var board_pos := world_to_board(local_pos)
	
	if is_valid_square(board_pos):
		square_clicked.emit(board_pos)

# =============================================================================
# PIECE MANAGEMENT
# =============================================================================

## Place a piece on the board
func place_piece(piece: BasePiece, board_pos: Vector2i) -> bool:
	if not is_valid_square(board_pos):
		return false
	
	if not is_square_empty(board_pos):
		push_warning("Cannot place piece: square is occupied")
		return false
	
	# Set piece position
	pieces[board_pos.x][board_pos.y] = piece
	piece.board_position = board_pos
	piece.board = self
	
	# Add to visual container
	if pieces_container and piece.get_parent() != pieces_container:
		if piece.get_parent():
			piece.get_parent().remove_child(piece)
		pieces_container.add_child(piece)
	
	# Update visual position
	piece.position = board_to_world(board_pos)
	
	piece_placed.emit(piece, board_pos)
	return true


## Remove a piece from the board
func remove_piece(board_pos: Vector2i) -> BasePiece:
	if not is_valid_square(board_pos):
		return null
	
	var piece: BasePiece = pieces[board_pos.x][board_pos.y]
	if not piece:
		return null
	
	pieces[board_pos.x][board_pos.y] = null
	piece.board_position = Vector2i(-1, -1)
	
	piece_removed.emit(piece, board_pos)
	return piece


## Move a piece from one position to another
func move_piece(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not is_valid_square(from_pos) or not is_valid_square(to_pos):
		return false
	
	var piece: BasePiece = get_piece_at(from_pos)
	if not piece:
		return false
	
	# Check for capture
	var captured_piece: BasePiece = get_piece_at(to_pos)
	if captured_piece:
		_capture_piece(captured_piece, piece)
	
	# Move the piece
	pieces[from_pos.x][from_pos.y] = null
	pieces[to_pos.x][to_pos.y] = piece
	piece.board_position = to_pos
	
	# Update visual position
	piece.position = board_to_world(to_pos)
	
	# Notify the piece
	piece.on_move(from_pos, to_pos)
	
	piece_moved.emit(piece, from_pos, to_pos)
	return true


## Capture a piece
func _capture_piece(captured: BasePiece, capturer: BasePiece) -> void:
	var capture_pos := captured.board_position
	
	# Remove from board array
	pieces[capture_pos.x][capture_pos.y] = null
	
	# Notify pieces
	captured.on_death(capturer)
	capturer.on_capture(captured)
	
	# Remove from scene (but don't free - might be needed for UI)
	if captured.get_parent():
		captured.get_parent().remove_child(captured)

# =============================================================================
# SQUARE QUERIES
# =============================================================================

## Get the piece at a specific position
func get_piece_at(board_pos: Vector2i) -> BasePiece:
	if not is_valid_square(board_pos):
		return null
	return pieces[board_pos.x][board_pos.y]


## Check if a square is empty
func is_square_empty(board_pos: Vector2i) -> bool:
	return get_piece_at(board_pos) == null


## Check if a square is valid (within bounds and not blocked)
func is_valid_square(board_pos: Vector2i) -> bool:
	if board_pos.x < 0 or board_pos.x >= columns:
		return false
	if board_pos.y < 0 or board_pos.y >= rows:
		return false
	return valid_squares.get(board_pos, false)


## Get the state of a square
func get_square_state(board_pos: Vector2i) -> SquareState:
	if not is_valid_square(board_pos):
		return SquareState.BLOCKED
	return square_states[board_pos.x][board_pos.y]


## Set the state of a square
func set_square_state(board_pos: Vector2i, state: SquareState) -> void:
	if not is_within_bounds(board_pos):
		return
	
	var old_state: SquareState = square_states[board_pos.x][board_pos.y]
	square_states[board_pos.x][board_pos.y] = state
	
	# Update valid squares
	valid_squares[board_pos] = (state != SquareState.BLOCKED)
	
	square_state_changed.emit(board_pos, old_state, state)
	queue_redraw()


## Check if position is within board bounds
func is_within_bounds(board_pos: Vector2i) -> bool:
	return board_pos.x >= 0 and board_pos.x < columns and board_pos.y >= 0 and board_pos.y < rows


## Get the color of a square (for visual alternation)
func get_square_color(board_pos: Vector2i) -> SquareColor:
	if (board_pos.x + board_pos.y) % 2 == 0:
		return SquareColor.LIGHT
	else:
		return SquareColor.DARK

# =============================================================================
# COORDINATE CONVERSION
# =============================================================================

## Convert board coordinates to world position
func board_to_world(board_pos: Vector2i) -> Vector2:
	return Vector2(
		board_pos.x * square_size.x + square_size.x / 2,
		board_pos.y * square_size.y + square_size.y / 2
	)


## Convert world position to board coordinates
func world_to_board(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / square_size.x),
		int(world_pos.y / square_size.y)
	)


## Get the world rect of a square
func get_square_rect(board_pos: Vector2i) -> Rect2:
	var world_pos := Vector2(board_pos.x * square_size.x, board_pos.y * square_size.y)
	return Rect2(world_pos, square_size)

# =============================================================================
# HIGHLIGHTS AND VISUAL FEEDBACK
# =============================================================================

## Set the selected piece and show legal moves
func select_piece(piece: BasePiece) -> void:
	selected_piece = piece
	if piece:
		highlighted_squares = piece.get_legal_moves()
		# Determine which are captures
		attack_squares.clear()
		for pos in highlighted_squares:
			if not is_square_empty(pos):
				attack_squares.append(pos)
	queue_redraw()


## Clear selection and highlights
func clear_selection() -> void:
	selected_piece = null
	highlighted_squares.clear()
	attack_squares.clear()
	queue_redraw()


## Set the check indicator square
func set_check_square(board_pos: Vector2i) -> void:
	check_square = board_pos
	queue_redraw()


## Clear the check indicator
func clear_check_square() -> void:
	check_square = Vector2i(-1, -1)
	queue_redraw()

# =============================================================================
# SQUARE MODIFIERS
# =============================================================================

## Add a modifier to a square
func add_square_modifier(board_pos: Vector2i, modifier: Resource) -> void:
	if not is_within_bounds(board_pos):
		return
	
	var mods: Array = square_modifiers[board_pos.x][board_pos.y]
	if modifier not in mods:
		mods.append(modifier)
		
		if modifier.has_method("on_added_to_square"):
			modifier.on_added_to_square(self, board_pos)


## Remove a modifier from a square
func remove_square_modifier(board_pos: Vector2i, modifier: Resource) -> void:
	if not is_within_bounds(board_pos):
		return
	
	var mods: Array = square_modifiers[board_pos.x][board_pos.y]
	if modifier in mods:
		mods.erase(modifier)
		
		if modifier.has_method("on_removed_from_square"):
			modifier.on_removed_from_square(self, board_pos)


## Get all modifiers on a square
func get_square_modifiers(board_pos: Vector2i) -> Array:
	if not is_within_bounds(board_pos):
		return []
	return square_modifiers[board_pos.x][board_pos.y].duplicate()

# =============================================================================
# PIECE QUERIES
# =============================================================================

## Get all pieces of a specific color
func get_pieces_by_color(color: BasePiece.PieceColor) -> Array[BasePiece]:
	var result: Array[BasePiece] = []
	for x in range(columns):
		for y in range(rows):
			var piece: BasePiece = pieces[x][y]
			if piece and piece.piece_color == color:
				result.append(piece)
	return result


## Get all pieces of a specific type
func get_pieces_by_type(type: BasePiece.PieceType) -> Array[BasePiece]:
	var result: Array[BasePiece] = []
	for x in range(columns):
		for y in range(rows):
			var piece: BasePiece = pieces[x][y]
			if piece and piece.piece_type == type:
				result.append(piece)
	return result


## Get the king of a specific color
func get_king(color: BasePiece.PieceColor) -> BasePiece:
	for x in range(columns):
		for y in range(rows):
			var piece: BasePiece = pieces[x][y]
			if piece and piece.piece_type == BasePiece.PieceType.KING and piece.piece_color == color:
				return piece
	return null


## Get all pieces on the board
func get_all_pieces() -> Array[BasePiece]:
	var result: Array[BasePiece] = []
	for x in range(columns):
		for y in range(rows):
			var piece: BasePiece = pieces[x][y]
			if piece:
				result.append(piece)
	return result

# =============================================================================
# BOARD RESIZING
# =============================================================================

## Resize the board (clears all pieces)
func resize(new_columns: int, new_rows: int) -> void:
	var old_size := Vector2i(columns, rows)
	
	columns = new_columns
	rows = new_rows
	
	# Clear existing pieces
	for piece in get_all_pieces():
		if piece.get_parent():
			piece.get_parent().remove_child(piece)
		piece.queue_free()
	
	_resize_arrays()
	
	# Update valid squares
	valid_squares.clear()
	for x in range(columns):
		for y in range(rows):
			valid_squares[Vector2i(x, y)] = true
	
	board_resized.emit(old_size, Vector2i(columns, rows))
	queue_redraw()

# =============================================================================
# SERIALIZATION
# =============================================================================

## Create a dictionary representation for saving
func to_dict() -> Dictionary:
	var pieces_data: Array = []
	
	for piece in get_all_pieces():
		var piece_data := piece.to_dict()
		pieces_data.append(piece_data)
	
	var states_data: Array = []
	for x in range(columns):
		var column_data: Array = []
		for y in range(rows):
			column_data.append(square_states[x][y])
		states_data.append(column_data)
	
	var valid_squares_data: Dictionary = {}
	for pos in valid_squares:
		valid_squares_data["%d,%d" % [pos.x, pos.y]] = valid_squares[pos]
	
	return {
		"columns": columns,
		"rows": rows,
		"pieces": pieces_data,
		"square_states": states_data,
		"valid_squares": valid_squares_data,
		"en_passant_square": {"x": en_passant_square.x, "y": en_passant_square.y}
	}


## Get algebraic notation for a position (e.g., "e4")
func get_algebraic_notation(board_pos: Vector2i) -> String:
	if not is_within_bounds(board_pos):
		return ""
	
	var file := char(ord("a") + board_pos.x)
	var rank := str(rows - board_pos.y)  # Standard chess notation (1-8 from bottom)
	return file + rank


## Get position from algebraic notation
func get_position_from_notation(notation: String) -> Vector2i:
	if notation.length() != 2:
		return Vector2i(-1, -1)
	
	var file := ord(notation[0].to_lower()) - ord("a")
	var rank := rows - int(notation[1])
	
	var pos := Vector2i(file, rank)
	if is_within_bounds(pos):
		return pos
	return Vector2i(-1, -1)


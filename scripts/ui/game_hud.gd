class_name GameHUD
extends Control
## In-game HUD showing game information

# =============================================================================
# SIGNALS
# =============================================================================

signal pause_requested()
signal resign_requested()
signal draw_offered()
signal save_requested()
signal menu_requested()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var turn_label: Label = $TopBar/TurnLabel if has_node("TopBar/TurnLabel") else null
@onready var player_white_label: Label = $LeftPanel/WhitePlayer if has_node("LeftPanel/WhitePlayer") else null
@onready var player_black_label: Label = $RightPanel/BlackPlayer if has_node("RightPanel/BlackPlayer") else null
@onready var move_history: ItemList = $BottomPanel/MoveHistory if has_node("BottomPanel/MoveHistory") else null
@onready var captured_white: HBoxContainer = $LeftPanel/CapturedPieces if has_node("LeftPanel/CapturedPieces") else null
@onready var captured_black: HBoxContainer = $RightPanel/CapturedPieces if has_node("RightPanel/CapturedPieces") else null
@onready var game_status_label: Label = $TopBar/StatusLabel if has_node("TopBar/StatusLabel") else null

@onready var pause_button: Button = $TopBar/PauseButton if has_node("TopBar/PauseButton") else null
@onready var menu_button: Button = $TopBar/MenuButton if has_node("TopBar/MenuButton") else null

# =============================================================================
# PROPERTIES
# =============================================================================

var current_turn: BasePiece.PieceColor = BasePiece.PieceColor.WHITE
var move_count: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_connect_signals()
	_connect_buttons()


func _connect_signals() -> void:
	# Connect to GameManager signals
	if GameManager:
		GameManager.turn_changed.connect(_on_turn_changed)
		GameManager.move_made.connect(_on_move_made)
		GameManager.game_ended.connect(_on_game_ended)
		GameManager.check_declared.connect(_on_check_declared)


func _connect_buttons() -> void:
	if pause_button:
		pause_button.pressed.connect(func(): pause_requested.emit())
	if menu_button:
		menu_button.pressed.connect(func(): menu_requested.emit())

# =============================================================================
# DISPLAY UPDATES
# =============================================================================

func update_turn_display(color: BasePiece.PieceColor) -> void:
	current_turn = color
	if turn_label:
		var color_name := "White" if color == BasePiece.PieceColor.WHITE else "Black"
		turn_label.text = color_name + "'s Turn"


func add_move_to_history(notation: String, turn_number: int, is_white: bool) -> void:
	if not move_history:
		return
	
	if is_white:
		move_count = turn_number
		move_history.add_item(str(turn_number) + ". " + notation)
	else:
		# Append black's move to the same line
		var last_idx := move_history.item_count - 1
		if last_idx >= 0:
			var current_text := move_history.get_item_text(last_idx)
			move_history.set_item_text(last_idx, current_text + "  " + notation)


func update_captured_pieces(color: BasePiece.PieceColor, pieces: Array) -> void:
	var container := captured_white if color == BasePiece.PieceColor.WHITE else captured_black
	if not container:
		return
	
	# Clear existing
	for child in container.get_children():
		child.queue_free()
	
	# Add captured piece icons
	for piece in pieces:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		# TODO: Set texture based on piece type
		container.add_child(icon)


func show_status(message: String, duration: float = 2.0) -> void:
	if game_status_label:
		game_status_label.text = message
		game_status_label.show()
		
		if duration > 0:
			await get_tree().create_timer(duration).timeout
			game_status_label.hide()


func show_check_indicator(color: BasePiece.PieceColor) -> void:
	var color_name := "White" if color == BasePiece.PieceColor.WHITE else "Black"
	show_status(color_name + " is in check!")


func show_game_end(result: Dictionary) -> void:
	var message := ""
	
	if result.winner == BasePiece.PieceColor.NONE:
		message = "Draw - " + result.reason
	else:
		var winner_name := "White" if result.winner == BasePiece.PieceColor.WHITE else "Black"
		message = winner_name + " wins by " + result.reason
	
	show_status(message, -1)  # Don't auto-hide

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_turn_changed(color: BasePiece.PieceColor) -> void:
	update_turn_display(color)


func _on_move_made(piece: BasePiece, _from_pos: Vector2i, _to_pos: Vector2i, result: Dictionary) -> void:
	var is_white := piece.piece_color == BasePiece.PieceColor.WHITE
	add_move_to_history(result.notation, GameManager.turn_number, is_white)
	
	# Update captured pieces display
	if result.captured:
		var capturer_color := piece.piece_color
		update_captured_pieces(capturer_color, GameManager.captured_pieces[capturer_color])


func _on_game_ended(result: Dictionary) -> void:
	show_game_end(result)


func _on_check_declared(color: BasePiece.PieceColor) -> void:
	show_check_indicator(color)

# =============================================================================
# RESET
# =============================================================================

func reset() -> void:
	if move_history:
		move_history.clear()
	
	move_count = 0
	current_turn = BasePiece.PieceColor.WHITE
	update_turn_display(current_turn)
	
	if captured_white:
		for child in captured_white.get_children():
			child.queue_free()
	
	if captured_black:
		for child in captured_black.get_children():
			child.queue_free()
	
	if game_status_label:
		game_status_label.hide()


class_name GameScene
extends Node2D
## Main game scene controller

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var board: BaseBoard = $Board if has_node("Board") else null
@onready var hud: GameHUD = $CanvasLayer/HUD if has_node("CanvasLayer/HUD") else null
@onready var promotion_dialog: PromotionDialog = $CanvasLayer/PromotionDialog if has_node("CanvasLayer/PromotionDialog") else null
@onready var pause_menu: Control = $CanvasLayer/PauseMenu if has_node("CanvasLayer/PauseMenu") else null
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null

# =============================================================================
# PROPERTIES
# =============================================================================

var is_paused: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_connect_signals()
	_setup_camera()
	_start_new_game()


func _connect_signals() -> void:
	# Connect board signals
	if board:
		board.square_clicked.connect(_on_square_clicked)
	
	# Connect GameManager signals
	if GameManager:
		GameManager.promotion_required.connect(_on_promotion_required)
		GameManager.game_ended.connect(_on_game_ended)
	
	# Connect HUD signals
	if hud:
		hud.pause_requested.connect(_on_pause_requested)
		hud.menu_requested.connect(_on_menu_requested)


func _setup_camera() -> void:
	if camera and board:
		# Center camera on board
		var board_center := Vector2(
			board.columns * board.square_size.x / 2,
			board.rows * board.square_size.y / 2
		)
		camera.position = board_center


func _start_new_game() -> void:
	if not board:
		# Create default board
		board = StandardBoard.new()
		add_child(board)
	
	if GameManager:
		GameManager.new_game(board)
		
		if hud:
			hud.reset()

# =============================================================================
# INPUT
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_square_clicked(click_position: Vector2i) -> void:
	if is_paused:
		return
	
	if GameManager:
		GameManager.on_square_clicked(click_position)


func _on_promotion_required(pawn: BasePiece, promo_position: Vector2i) -> void:
	if promotion_dialog:
		promotion_dialog.show_promotion(pawn, promo_position)


func _on_game_ended(result: Dictionary) -> void:
	# Show game over UI
	if hud:
		hud.show_game_end(result)
	
	# Could show a game over dialog here


func _on_pause_requested() -> void:
	_toggle_pause()


func _on_menu_requested() -> void:
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# =============================================================================
# PAUSE
# =============================================================================

func _toggle_pause() -> void:
	is_paused = not is_paused
	
	if GameManager:
		if is_paused:
			GameManager.pause_game()
		else:
			GameManager.resume_game()
	
	if pause_menu:
		pause_menu.visible = is_paused

# =============================================================================
# PUBLIC METHODS
# =============================================================================

func start_new_game_vs_player() -> void:
	if GameManager:
		GameManager.set_player_type(BasePiece.PieceColor.WHITE, GameManager.PlayerType.HUMAN)
		GameManager.set_player_type(BasePiece.PieceColor.BLACK, GameManager.PlayerType.HUMAN)
	_start_new_game()


func start_new_game_vs_ai(ai_color: BasePiece.PieceColor, _difficulty: int) -> void:
	if GameManager:
		var human_color := BasePiece.get_opposite_color(ai_color)
		GameManager.set_player_type(human_color, GameManager.PlayerType.HUMAN)
		GameManager.set_player_type(ai_color, GameManager.PlayerType.AI)
	_start_new_game()


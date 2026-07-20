extends Node
## Main scene controller - Entry point for the game

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var main_menu: Control = $MainMenu if has_node("MainMenu") else null
@onready var game_container: Node2D = $GameContainer if has_node("GameContainer") else null

# =============================================================================
# PROPERTIES
# =============================================================================

var current_game_scene: GameScene = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_connect_signals()
	_show_main_menu()


func _connect_signals() -> void:
	if main_menu:
		main_menu.new_game_requested.connect(_on_new_game_requested)
		main_menu.load_game_requested.connect(_on_load_game_requested)
		main_menu.multiplayer_requested.connect(_on_multiplayer_requested)
		main_menu.settings_requested.connect(_on_settings_requested)
		main_menu.quit_requested.connect(_on_quit_requested)

# =============================================================================
# MENU NAVIGATION
# =============================================================================

func _show_main_menu() -> void:
	if main_menu:
		main_menu.show()
	
	if current_game_scene:
		current_game_scene.queue_free()
		current_game_scene = null


func _start_game(vs_ai: bool, ai_difficulty: int = 1) -> void:
	if main_menu:
		main_menu.hide()
	
	# Create game scene
	var game_scene := GameScene.new()
	game_scene.name = "GameScene"
	
	# Create board
	var board := StandardBoard.new()
	board.name = "Board"
	game_scene.add_child(board)
	
	# Add to container
	if game_container:
		game_container.add_child(game_scene)
	else:
		add_child(game_scene)
	
	current_game_scene = game_scene
	
	# Start the game
	if vs_ai:
		game_scene.start_new_game_vs_ai(BasePiece.PieceColor.BLACK, ai_difficulty)
	else:
		game_scene.start_new_game_vs_player()

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_new_game_requested(vs_ai: bool, ai_difficulty: int) -> void:
	_start_game(vs_ai, ai_difficulty)


func _on_load_game_requested(save_name: String) -> void:
	if SavesManager:
		if SavesManager.load_game(save_name):
			# Start game with loaded state
			_start_game(false)
		else:
			push_error("Failed to load game: " + save_name)


func _on_multiplayer_requested() -> void:
	# Will be implemented in Phase 2
	push_warning("Multiplayer not yet implemented")


func _on_settings_requested() -> void:
	# Open settings menu
	pass


func _on_quit_requested() -> void:
	get_tree().quit()


class_name MainMenu
extends Control
## Main menu UI controller

# =============================================================================
# SIGNALS
# =============================================================================

signal new_game_requested(vs_ai: bool, ai_difficulty: int)
signal load_game_requested(save_name: String)
signal multiplayer_requested()
signal settings_requested()
signal quit_requested()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var vs_ai_button: Button = $VBoxContainer/VsAIButton
@onready var load_game_button: Button = $VBoxContainer/LoadGameButton
@onready var multiplayer_button: Button = $VBoxContainer/MultiplayerButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var load_game_panel: Control = $LoadGamePanel if has_node("LoadGamePanel") else null
@onready var ai_difficulty_panel: Control = $AIDifficultyPanel if has_node("AIDifficultyPanel") else null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_connect_buttons()
	_hide_panels()


func _connect_buttons() -> void:
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if vs_ai_button:
		vs_ai_button.pressed.connect(_on_vs_ai_pressed)
	if load_game_button:
		load_game_button.pressed.connect(_on_load_game_pressed)
	if multiplayer_button:
		multiplayer_button.pressed.connect(_on_multiplayer_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)


func _hide_panels() -> void:
	if load_game_panel:
		load_game_panel.hide()
	if ai_difficulty_panel:
		ai_difficulty_panel.hide()

# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_new_game_pressed() -> void:
	new_game_requested.emit(false, 0)


func _on_vs_ai_pressed() -> void:
	if ai_difficulty_panel:
		ai_difficulty_panel.show()
	else:
		new_game_requested.emit(true, 1)  # Default medium difficulty


func _on_load_game_pressed() -> void:
	if load_game_panel:
		_populate_load_game_list()
		load_game_panel.show()


func _on_multiplayer_pressed() -> void:
	multiplayer_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()

# =============================================================================
# LOAD GAME PANEL
# =============================================================================

func _populate_load_game_list() -> void:
	# Will be populated from SavesManager
	pass


func _on_load_save_selected(save_name: String) -> void:
	load_game_requested.emit(save_name)
	if load_game_panel:
		load_game_panel.hide()


func _on_load_panel_cancelled() -> void:
	if load_game_panel:
		load_game_panel.hide()

# =============================================================================
# AI DIFFICULTY PANEL
# =============================================================================

func _on_ai_difficulty_selected(difficulty: int) -> void:
	new_game_requested.emit(true, difficulty)
	if ai_difficulty_panel:
		ai_difficulty_panel.hide()


func _on_ai_panel_cancelled() -> void:
	if ai_difficulty_panel:
		ai_difficulty_panel.hide()


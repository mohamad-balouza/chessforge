extends Node
## SavesManager Autoload - Handles saving and loading game states
## Accessed globally as SavesManager (autoload singleton - do not add class_name)
## SavesManager Autoload - Handles saving and loading game states

# =============================================================================
# CONSTANTS
# =============================================================================

const SAVE_DIR := "user://saves/"
const SAVE_EXTENSION := ".chess"
const AUTOSAVE_NAME := "autosave"
const MAX_AUTOSAVES := 3

# =============================================================================
# SIGNALS
# =============================================================================

signal game_saved(save_name: String)
signal game_loaded(save_name: String)
signal save_failed(error: String)
signal load_failed(error: String)
signal saves_list_updated(saves: Array)

# =============================================================================
# PROPERTIES
# =============================================================================

## List of available saves
var available_saves: Array[Dictionary] = []

## Current save name (if loaded from save)
var current_save_name: String = ""

## Auto-save enabled
var autosave_enabled: bool = true

## Auto-save interval in seconds
var autosave_interval: float = 60.0

## Timer for autosave
var _autosave_timer: float = 0.0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	print("[SavesManager] Initialized")
	_ensure_save_directory()
	refresh_saves_list()


func _process(delta: float) -> void:
	if autosave_enabled and GameManager and GameManager.current_state == GameManager.GameState.PLAYING:
		_autosave_timer += delta
		if _autosave_timer >= autosave_interval:
			_autosave_timer = 0.0
			autosave()

# =============================================================================
# SAVE OPERATIONS
# =============================================================================

## Save the current game
func save_game(save_name: String = "") -> bool:
	if not GameManager or GameManager.current_state == GameManager.GameState.MENU:
		save_failed.emit("No active game to save")
		return false
	
	var final_name := save_name if save_name else _generate_save_name()
	var save_path := SAVE_DIR + final_name + SAVE_EXTENSION
	
	var save_data := _create_save_data(final_name)
	
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		var error := "Failed to open file for writing: " + save_path
		save_failed.emit(error)
		return false
	
	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	current_save_name = final_name
	refresh_saves_list()
	game_saved.emit(final_name)
	
	print("[SavesManager] Game saved: ", final_name)
	return true


## Auto-save the current game
func autosave() -> void:
	if not GameManager or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Rotate autosaves
	_rotate_autosaves()
	
	save_game(AUTOSAVE_NAME + "_1")


func _rotate_autosaves() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return
	
	# Shift existing autosaves
	for i in range(MAX_AUTOSAVES, 1, -1):
		var old_name := AUTOSAVE_NAME + "_" + str(i - 1) + SAVE_EXTENSION
		var new_name := AUTOSAVE_NAME + "_" + str(i) + SAVE_EXTENSION
		
		if dir.file_exists(old_name):
			if i == MAX_AUTOSAVES:
				dir.remove(old_name)
			else:
				dir.rename(old_name, new_name)


## Create save data dictionary
func _create_save_data(save_name: String) -> Dictionary:
	var game_state := GameManager.get_game_state()
	
	return {
		"version": "1.0",
		"save_name": save_name,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_state": game_state
	}

# =============================================================================
# LOAD OPERATIONS
# =============================================================================

## Load a game from save
func load_game(save_name: String) -> bool:
	var save_path := SAVE_DIR + save_name + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		load_failed.emit("Save file not found: " + save_name)
		return false
	
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		load_failed.emit("Failed to open save file: " + save_name)
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		load_failed.emit("Failed to parse save file: " + json.get_error_message())
		return false
	
	var save_data: Dictionary = json.data
	
	if not _validate_save_data(save_data):
		load_failed.emit("Invalid save file format")
		return false
	
	# Apply save data
	if not _apply_save_data(save_data):
		load_failed.emit("Failed to apply save data")
		return false
	
	current_save_name = save_name
	game_loaded.emit(save_name)
	
	print("[SavesManager] Game loaded: ", save_name)
	return true


## Validate save data structure
func _validate_save_data(data: Dictionary) -> bool:
	return data.has("version") and data.has("game_state")


## Apply save data to restore game state
func _apply_save_data(data: Dictionary) -> bool:
	# This will be implemented when loading is fully supported
	# For now, just validate the structure
	var game_state: Dictionary = data.get("game_state", {})
	
	if game_state.is_empty():
		return false
	
	# TODO: Implement full state restoration
	# This requires:
	# 1. Creating a new board
	# 2. Placing pieces from saved positions
	# 3. Restoring game mode state
	# 4. Restoring rules engine state
	
	return true

# =============================================================================
# SAVE MANAGEMENT
# =============================================================================

## Refresh the list of available saves
func refresh_saves_list() -> void:
	available_saves.clear()
	
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(SAVE_EXTENSION):
			var save_info := _get_save_info(file_name.trim_suffix(SAVE_EXTENSION))
			if not save_info.is_empty():
				available_saves.append(save_info)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort by timestamp (newest first)
	available_saves.sort_custom(func(a, b): return a.timestamp > b.timestamp)
	
	saves_list_updated.emit(available_saves)


## Get information about a specific save
func _get_save_info(save_name: String) -> Dictionary:
	var save_path := SAVE_DIR + save_name + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		return {}
	
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var data: Dictionary = json.data
	
	return {
		"name": save_name,
		"timestamp": data.get("timestamp", "Unknown"),
		"version": data.get("version", "Unknown"),
		"is_autosave": save_name.begins_with(AUTOSAVE_NAME)
	}


## Delete a save file
func delete_save(save_name: String) -> bool:
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return false
	
	if dir.file_exists(save_name + SAVE_EXTENSION):
		var error := dir.remove(save_name + SAVE_EXTENSION)
		if error == OK:
			refresh_saves_list()
			return true
	
	return false


## Check if a save exists
func save_exists(save_name: String) -> bool:
	var save_path := SAVE_DIR + save_name + SAVE_EXTENSION
	return FileAccess.file_exists(save_path)

# =============================================================================
# UTILITY
# =============================================================================

func _ensure_save_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _generate_save_name() -> String:
	var datetime := Time.get_datetime_dict_from_system()
	return "save_%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]


## Get the most recent save
func get_most_recent_save() -> Dictionary:
	if available_saves.is_empty():
		return {}
	return available_saves[0]


## Get all non-autosave saves
func get_manual_saves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for save in available_saves:
		if not save.is_autosave:
			result.append(save)
	return result


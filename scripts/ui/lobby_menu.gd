class_name LobbyMenu
extends Control
## Multiplayer lobby menu

# =============================================================================
# SIGNALS
# =============================================================================

signal back_pressed()

# =============================================================================
# NODE REFERENCES (to be connected in editor)
# =============================================================================

@onready var host_button: Button = $VBoxContainer/HostButton if has_node("VBoxContainer/HostButton") else null
@onready var join_button: Button = $VBoxContainer/JoinButton if has_node("VBoxContainer/JoinButton") else null
@onready var back_button: Button = $VBoxContainer/BackButton if has_node("VBoxContainer/BackButton") else null

@onready var player_name_input: LineEdit = $VBoxContainer/NameInput if has_node("VBoxContainer/NameInput") else null
@onready var host_address_input: LineEdit = $JoinPanel/AddressInput if has_node("JoinPanel/AddressInput") else null
@onready var room_code_label: Label = $RoomPanel/RoomCodeLabel if has_node("RoomPanel/RoomCodeLabel") else null

@onready var join_panel: Control = $JoinPanel if has_node("JoinPanel") else null
@onready var room_panel: Control = $RoomPanel if has_node("RoomPanel") else null
@onready var waiting_panel: Control = $WaitingPanel if has_node("WaitingPanel") else null

@onready var player_list: ItemList = $RoomPanel/PlayerList if has_node("RoomPanel/PlayerList") else null
@onready var ready_button: Button = $RoomPanel/ReadyButton if has_node("RoomPanel/ReadyButton") else null
@onready var start_button: Button = $RoomPanel/StartButton if has_node("RoomPanel/StartButton") else null
@onready var leave_button: Button = $RoomPanel/LeaveButton if has_node("RoomPanel/LeaveButton") else null

@onready var status_label: Label = $StatusLabel if has_node("StatusLabel") else null
@onready var chat_input: LineEdit = $RoomPanel/ChatInput if has_node("RoomPanel/ChatInput") else null
@onready var chat_display: RichTextLabel = $RoomPanel/ChatDisplay if has_node("RoomPanel/ChatDisplay") else null

# =============================================================================
# PROPERTIES
# =============================================================================

var is_ready: bool = false
var is_host: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_connect_buttons()
	_connect_network_signals()
	_hide_all_panels()


func _connect_buttons() -> void:
	if host_button:
		host_button.pressed.connect(_on_host_pressed)
	if join_button:
		join_button.pressed.connect(_on_join_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if ready_button:
		ready_button.pressed.connect(_on_ready_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if leave_button:
		leave_button.pressed.connect(_on_leave_pressed)
	if chat_input:
		chat_input.text_submitted.connect(_on_chat_submitted)


func _connect_network_signals() -> void:
	if NetworkManager:
		NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
		NetworkManager.room_created.connect(_on_room_created)
		NetworkManager.connected_to_server.connect(_on_connected)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.player_joined.connect(_on_player_joined)
		NetworkManager.player_left.connect(_on_player_left)
		NetworkManager.player_ready_changed.connect(_on_player_ready_changed)
		NetworkManager.room_state_updated.connect(_on_room_state_updated)
		NetworkManager.game_started.connect(_on_game_started)
		NetworkManager.chat_message_received.connect(_on_chat_received)
		NetworkManager.room_left.connect(_on_room_left)


func _hide_all_panels() -> void:
	if join_panel:
		join_panel.hide()
	if room_panel:
		room_panel.hide()
	if waiting_panel:
		waiting_panel.hide()

# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_host_pressed() -> void:
	var player_name := _get_player_name()
	
	var room_code := NetworkManager.create_room(player_name)
	if room_code:
		is_host = true
		_show_room_panel()
		_update_start_button()
	else:
		_show_status("Failed to create room")


func _on_join_pressed() -> void:
	if join_panel:
		join_panel.show()


func _on_join_confirm_pressed(address: String) -> void:
	var player_name := _get_player_name()
	
	if address.strip_edges().is_empty():
		_show_status("Please enter a host address")
		return
	
	is_host = false
	
	if NetworkManager.join_room(address, player_name):
		_show_waiting_panel()
	else:
		_show_status("Failed to connect")


func _on_back_pressed() -> void:
	_hide_all_panels()
	back_pressed.emit()


func _on_ready_pressed() -> void:
	is_ready = not is_ready
	NetworkManager.set_ready(is_ready)
	
	if ready_button:
		ready_button.text = "Not Ready" if is_ready else "Ready"


func _on_start_pressed() -> void:
	if not is_host:
		return
	
	if not NetworkManager.start_game():
		_show_status("Cannot start game - not all players ready")


func _on_leave_pressed() -> void:
	NetworkManager.leave_room()


func _on_chat_submitted(message: String) -> void:
	if message.strip_edges().is_empty():
		return
	
	NetworkManager.send_chat_message(message)
	
	if chat_input:
		chat_input.clear()

# =============================================================================
# NETWORK CALLBACKS
# =============================================================================

func _on_connection_state_changed(old_state: int, new_state: int) -> void:
	match new_state:
		NetworkManager.ConnectionState.DISCONNECTED:
			_hide_all_panels()
		NetworkManager.ConnectionState.CONNECTING:
			_show_waiting_panel()
		NetworkManager.ConnectionState.IN_ROOM:
			_show_room_panel()


func _on_room_created(room_code: String) -> void:
	if room_code_label:
		room_code_label.text = "Room Code: " + room_code
	_show_status("Room created! Share the code with your opponent.")


func _on_connected() -> void:
	_show_room_panel()
	_show_status("Connected!")


func _on_connection_failed(reason: String) -> void:
	_hide_all_panels()
	_show_status("Connection failed: " + reason)


func _on_player_joined(player_id: int, player_data: Dictionary) -> void:
	_update_player_list()
	_add_chat_system_message(player_data.get("name", "Player") + " joined")


func _on_player_left(player_id: int) -> void:
	_update_player_list()
	_add_chat_system_message("A player left")


func _on_player_ready_changed(player_id: int, ready: bool) -> void:
	_update_player_list()
	_update_start_button()


func _on_room_state_updated(room_data: Dictionary) -> void:
	_update_player_list()
	_update_start_button()


func _on_game_started(game_data: Dictionary) -> void:
	# Transition to game scene
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_chat_received(player_id: int, message: String) -> void:
	var player_data: Dictionary = NetworkManager.get_player_data(player_id)
	var player_name: String = player_data.get("name", "Player " + str(player_id))
	_add_chat_message(player_name, message)


func _on_room_left() -> void:
	is_ready = false
	is_host = false
	_hide_all_panels()

# =============================================================================
# UI HELPERS
# =============================================================================

func _show_room_panel() -> void:
	_hide_all_panels()
	if room_panel:
		room_panel.show()
	_update_player_list()
	_update_start_button()


func _show_waiting_panel() -> void:
	_hide_all_panels()
	if waiting_panel:
		waiting_panel.show()


func _show_status(message: String) -> void:
	if status_label:
		status_label.text = message
		status_label.show()
		
		# Auto-hide after a few seconds
		await get_tree().create_timer(3.0).timeout
		if status_label.text == message:
			status_label.hide()


func _update_player_list() -> void:
	if not player_list:
		return
	
	player_list.clear()
	
	for player_id in NetworkManager.connected_players:
		var data: Dictionary = NetworkManager.connected_players[player_id]
		var name: String = data.get("name", "Player")
		var ready: bool = data.get("is_ready", false)
		var color: int = data.get("color", 0)
		
		var color_str := " (White)" if color == BasePiece.PieceColor.WHITE else " (Black)"
		var ready_str := " [Ready]" if ready else ""
		
		player_list.add_item(name + color_str + ready_str)


func _update_start_button() -> void:
	if not start_button:
		return
	
	start_button.visible = is_host
	
	if is_host:
		var can_start := true
		var player_count := NetworkManager.connected_players.size()
		
		if player_count < 2:
			can_start = false
		else:
			for player_id in NetworkManager.connected_players:
				if player_id != 1:  # Not the host
					if not NetworkManager.connected_players[player_id].get("is_ready", false):
						can_start = false
						break
		
		start_button.disabled = not can_start


func _add_chat_message(sender: String, message: String) -> void:
	if chat_display:
		chat_display.append_text("[b]" + sender + ":[/b] " + message + "\n")


func _add_chat_system_message(message: String) -> void:
	if chat_display:
		chat_display.append_text("[i]" + message + "[/i]\n")


func _get_player_name() -> String:
	if player_name_input:
		var player_name := player_name_input.text.strip_edges()
		if not player_name.is_empty():
			return player_name
	return "Player"


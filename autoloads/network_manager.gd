extends Node
## NetworkManager Autoload - Handles multiplayer networking
## Accessed globally as NetworkManager (autoload singleton - do not add class_name)
## NetworkManager Autoload - Handles multiplayer networking
## Full implementation for Phase 2

# =============================================================================
# CONSTANTS
# =============================================================================

const DEFAULT_PORT := 28960
const MAX_PLAYERS := 2
const ROOM_CODE_LENGTH := 6
const HEARTBEAT_INTERVAL := 5.0
const CONNECTION_TIMEOUT := 30.0

# =============================================================================
# ENUMS
# =============================================================================

enum ConnectionState {
	DISCONNECTED = 0,
	CONNECTING = 1,
	CONNECTED = 2,
	IN_LOBBY = 3,
	IN_ROOM = 4,
	IN_GAME = 5
}

enum PlayerRole {
	NONE = 0,
	HOST = 1,
	CLIENT = 2,
	SPECTATOR = 3
}

enum MessageType {
	HANDSHAKE = 0,
	ROOM_CREATE = 1,
	ROOM_JOIN = 2,
	ROOM_LEAVE = 3,
	ROOM_STATE = 4,
	GAME_START = 5,
	GAME_MOVE = 6,
	GAME_STATE = 7,
	CHAT = 8,
	HEARTBEAT = 9,
	DISCONNECT = 10
}

# =============================================================================
# SIGNALS
# =============================================================================

signal connection_state_changed(old_state: ConnectionState, new_state: ConnectionState)
signal connected_to_server()
signal disconnected_from_server()
signal connection_failed(reason: String)

signal room_created(room_code: String)
signal room_joined(room_code: String)
signal room_join_failed(reason: String)
signal room_left()
signal room_state_updated(room_data: Dictionary)

signal player_joined(player_id: int, player_data: Dictionary)
signal player_left(player_id: int)
signal player_ready_changed(player_id: int, is_ready: bool)

signal game_starting()
signal game_started(game_data: Dictionary)
signal move_received(from_pos: Vector2i, to_pos: Vector2i, player_id: int)
signal promotion_received(position: Vector2i, piece_type: int, player_id: int)
signal game_sync_received(game_state: Dictionary)

signal chat_message_received(player_id: int, message: String)
signal rematch_requested(player_id: int)
signal rematch_accepted()

# =============================================================================
# PROPERTIES
# =============================================================================

## Current connection state
var connection_state: ConnectionState = ConnectionState.DISCONNECTED

## Player role
var player_role: PlayerRole = PlayerRole.NONE

## Current room code
var current_room_code: String = ""

## Local player data
var local_player_data: Dictionary = {
	"name": "Player",
	"color": BasePiece.PieceColor.NONE,
	"is_ready": false
}

## Connected players (id -> data)
var connected_players: Dictionary = {}

## Assigned color for local player
var local_player_color: BasePiece.PieceColor = BasePiece.PieceColor.NONE

## Room settings
var room_settings: Dictionary = {
	"time_control": -1,  # -1 for no time limit
	"increment": 0,
	"game_mode": "classic"
}

## Heartbeat timer
var _heartbeat_timer: float = 0.0

## Reconnection data
var _reconnection_data: Dictionary = {}
var _reconnection_attempts: int = 0
const MAX_RECONNECTION_ATTEMPTS := 5

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	print("[NetworkManager] Initialized")
	_setup_multiplayer_signals()


func _process(delta: float) -> void:
	if connection_state >= ConnectionState.CONNECTED:
		_heartbeat_timer += delta
		if _heartbeat_timer >= HEARTBEAT_INTERVAL:
			_heartbeat_timer = 0.0
			_send_heartbeat()


func _setup_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# =============================================================================
# HOST FUNCTIONS
# =============================================================================

## Create a room as host (peer-to-peer)
func create_room(player_name: String = "Host") -> String:
	local_player_data.name = player_name
	
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	
	if error != OK:
		connection_failed.emit("Failed to create server: " + str(error))
		return ""
	
	multiplayer.multiplayer_peer = peer
	player_role = PlayerRole.HOST
	current_room_code = _generate_room_code()
	
	# Add self as first player
	connected_players[1] = local_player_data.duplicate()
	local_player_color = BasePiece.PieceColor.WHITE  # Host is always white
	local_player_data.color = local_player_color
	
	_change_connection_state(ConnectionState.IN_ROOM)
	room_created.emit(current_room_code)
	
	print("[NetworkManager] Room created: ", current_room_code)
	return current_room_code


## Start the game (host only)
func start_game() -> bool:
	if player_role != PlayerRole.HOST:
		push_error("Only host can start the game")
		return false
	
	if connected_players.size() < 2:
		push_error("Need at least 2 players to start")
		return false
	
	# Check all players are ready
	for player_id in connected_players:
		if player_id != 1 and not connected_players[player_id].get("is_ready", false):
			push_error("Not all players are ready")
			return false
	
	# Notify all clients
	_rpc_game_starting.rpc()
	
	# Prepare game data
	var game_data := {
		"room_code": current_room_code,
		"players": connected_players.duplicate(true),
		"settings": room_settings.duplicate()
	}
	
	# Start game for all
	_rpc_game_start.rpc(game_data)
	
	_change_connection_state(ConnectionState.IN_GAME)
	game_started.emit(game_data)
	
	return true

# =============================================================================
# CLIENT FUNCTIONS
# =============================================================================

## Join a room by address and port (for peer-to-peer)
func join_room(host_address: String, player_name: String = "Player", port: int = DEFAULT_PORT) -> bool:
	local_player_data.name = player_name
	
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_address, port)
	
	if error != OK:
		connection_failed.emit("Failed to connect: " + str(error))
		return false
	
	multiplayer.multiplayer_peer = peer
	player_role = PlayerRole.CLIENT
	
	_change_connection_state(ConnectionState.CONNECTING)
	
	# Save for potential reconnection
	_reconnection_data = {
		"address": host_address,
		"port": port,
		"player_name": player_name
	}
	
	return true


## Set ready status
func set_ready(is_ready: bool) -> void:
	local_player_data.is_ready = is_ready
	_rpc_player_ready.rpc(is_ready)


## Leave the current room
func leave_room() -> void:
	if connection_state == ConnectionState.DISCONNECTED:
		return
	
	_rpc_player_leaving.rpc()
	
	await get_tree().create_timer(0.1).timeout  # Brief delay for message to send
	
	disconnect_from_server()
	room_left.emit()


## Disconnect from server
func disconnect_from_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	_change_connection_state(ConnectionState.DISCONNECTED)
	player_role = PlayerRole.NONE
	current_room_code = ""
	connected_players.clear()
	local_player_color = BasePiece.PieceColor.NONE
	_reconnection_attempts = 0

# =============================================================================
# GAME SYNCHRONIZATION
# =============================================================================

## Send a move to the opponent
func send_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if connection_state != ConnectionState.IN_GAME:
		return
	
	_rpc_move.rpc(from_pos.x, from_pos.y, to_pos.x, to_pos.y)


## Send promotion choice
func send_promotion(position: Vector2i, piece_type: BasePiece.PieceType) -> void:
	if connection_state != ConnectionState.IN_GAME:
		return
	
	_rpc_promotion.rpc(position.x, position.y, piece_type)


## Sync full game state (for reconnection)
func sync_game_state(game_state: Dictionary) -> void:
	if player_role != PlayerRole.HOST:
		return
	
	_rpc_game_sync.rpc(game_state)

# =============================================================================
# CHAT
# =============================================================================

## Send a chat message
func send_chat_message(message: String) -> void:
	if connection_state < ConnectionState.IN_ROOM:
		return
	
	if message.strip_edges().is_empty():
		return
	
	_rpc_chat_message.rpc(message)

# =============================================================================
# RPC METHODS
# =============================================================================

@rpc("any_peer", "call_local", "reliable")
func _rpc_move(from_x: int, from_y: int, to_x: int, to_y: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	move_received.emit(Vector2i(from_x, from_y), Vector2i(to_x, to_y), sender_id)


@rpc("any_peer", "call_local", "reliable")
func _rpc_promotion(pos_x: int, pos_y: int, piece_type: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	promotion_received.emit(Vector2i(pos_x, pos_y), piece_type, sender_id)


@rpc("authority", "call_local", "reliable")
func _rpc_game_starting() -> void:
	game_starting.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_game_start(game_data: Dictionary) -> void:
	_change_connection_state(ConnectionState.IN_GAME)
	game_started.emit(game_data)


@rpc("authority", "call_local", "reliable")
func _rpc_game_sync(game_state: Dictionary) -> void:
	game_sync_received.emit(game_state)


@rpc("any_peer", "call_local", "reliable")
func _rpc_chat_message(message: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	chat_message_received.emit(sender_id, message)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_ready(is_ready: bool) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if connected_players.has(sender_id):
		connected_players[sender_id].is_ready = is_ready
		player_ready_changed.emit(sender_id, is_ready)
		
		# Broadcast updated room state
		if player_role == PlayerRole.HOST:
			_broadcast_room_state()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_leaving() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if connected_players.has(sender_id):
		connected_players.erase(sender_id)
		player_left.emit(sender_id)
		
		if player_role == PlayerRole.HOST:
			_broadcast_room_state()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_info(player_data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	connected_players[sender_id] = player_data
	player_joined.emit(sender_id, player_data)
	
	# Host assigns color and sends room state
	if player_role == PlayerRole.HOST:
		# Assign black to joining player
		connected_players[sender_id].color = BasePiece.PieceColor.BLACK
		_broadcast_room_state()


@rpc("authority", "call_remote", "reliable")
func _rpc_room_state(room_data: Dictionary) -> void:
	connected_players = room_data.get("players", {})
	room_settings = room_data.get("settings", {})
	current_room_code = room_data.get("room_code", "")
	
	# Find our color
	var my_id := multiplayer.get_unique_id()
	if connected_players.has(my_id):
		local_player_color = connected_players[my_id].get("color", BasePiece.PieceColor.NONE)
	
	room_state_updated.emit(room_data)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_heartbeat() -> void:
	# Just acknowledge we're alive
	pass


@rpc("any_peer", "call_remote", "reliable")
func _rpc_rematch_request() -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	rematch_requested.emit(sender_id)


@rpc("authority", "call_local", "reliable")
func _rpc_rematch_accepted() -> void:
	rematch_accepted.emit()

# =============================================================================
# REMATCH
# =============================================================================

## Request a rematch
func request_rematch() -> void:
	_rpc_rematch_request.rpc()


## Accept rematch request (host only)
func accept_rematch() -> void:
	if player_role == PlayerRole.HOST:
		_rpc_rematch_accepted.rpc()
		# Restart game with swapped colors
		for player_id in connected_players:
			var current_color: int = connected_players[player_id].get("color", 0)
			connected_players[player_id].color = BasePiece.get_opposite_color(current_color)
		
		local_player_color = BasePiece.get_opposite_color(local_player_color)
		start_game()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _broadcast_room_state() -> void:
	if player_role != PlayerRole.HOST:
		return
	
	var room_data := {
		"room_code": current_room_code,
		"players": connected_players.duplicate(true),
		"settings": room_settings.duplicate()
	}
	
	_rpc_room_state.rpc(room_data)


func _send_heartbeat() -> void:
	_rpc_heartbeat.rpc()


func _attempt_reconnection() -> void:
	if _reconnection_attempts >= MAX_RECONNECTION_ATTEMPTS:
		connection_failed.emit("Max reconnection attempts reached")
		disconnect_from_server()
		return
	
	_reconnection_attempts += 1
	print("[NetworkManager] Reconnection attempt ", _reconnection_attempts)
	
	var address: String = _reconnection_data.get("address", "")
	var port: int = _reconnection_data.get("port", DEFAULT_PORT)
	var name: String = _reconnection_data.get("player_name", "Player")
	
	if address:
		join_room(address, name, port)

# =============================================================================
# CALLBACKS
# =============================================================================

func _on_peer_connected(peer_id: int) -> void:
	print("[NetworkManager] Peer connected: ", peer_id)
	
	if player_role == PlayerRole.CLIENT:
		# Send our info to the host
		_rpc_player_info.rpc_id(1, local_player_data)


func _on_peer_disconnected(peer_id: int) -> void:
	print("[NetworkManager] Peer disconnected: ", peer_id)
	
	if connected_players.has(peer_id):
		connected_players.erase(peer_id)
		player_left.emit(peer_id)
		
		if player_role == PlayerRole.HOST:
			_broadcast_room_state()


func _on_connected_to_server() -> void:
	print("[NetworkManager] Connected to server")
	_change_connection_state(ConnectionState.IN_ROOM)
	connected_to_server.emit()
	_reconnection_attempts = 0


func _on_connection_failed() -> void:
	print("[NetworkManager] Connection failed")
	
	if _reconnection_data.size() > 0 and _reconnection_attempts < MAX_RECONNECTION_ATTEMPTS:
		# Try to reconnect
		await get_tree().create_timer(2.0).timeout
		_attempt_reconnection()
	else:
		_change_connection_state(ConnectionState.DISCONNECTED)
		connection_failed.emit("Failed to connect to server")


func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected")
	
	if connection_state == ConnectionState.IN_GAME:
		# Try to reconnect if we were in a game
		if _reconnection_data.size() > 0:
			await get_tree().create_timer(1.0).timeout
			_attempt_reconnection()
			return
	
	_change_connection_state(ConnectionState.DISCONNECTED)
	disconnected_from_server.emit()

# =============================================================================
# UTILITY
# =============================================================================

func _change_connection_state(new_state: ConnectionState) -> void:
	var old_state := connection_state
	connection_state = new_state
	connection_state_changed.emit(old_state, new_state)


func _generate_room_code() -> String:
	var chars := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var code := ""
	for i in range(ROOM_CODE_LENGTH):
		code += chars[randi() % chars.length()]
	return code


## Check if currently in a multiplayer game
func is_in_multiplayer_game() -> bool:
	return connection_state == ConnectionState.IN_GAME


## Check if this instance is the host
func is_host() -> bool:
	return player_role == PlayerRole.HOST


## Get the local player's network ID
func get_local_player_id() -> int:
	return multiplayer.get_unique_id()


## Get player data by ID
func get_player_data(player_id: int) -> Dictionary:
	return connected_players.get(player_id, {})


## Get opponent's network ID
func get_opponent_id() -> int:
	var my_id := get_local_player_id()
	for player_id in connected_players:
		if player_id != my_id:
			return player_id
	return -1

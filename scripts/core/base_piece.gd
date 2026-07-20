class_name BasePiece
extends Node2D
## Base class for all chess pieces
## Provides extensible movement patterns, modifiers, and ability support

# =============================================================================
# ENUMS
# =============================================================================

enum PieceType {
	NONE = 0,
	KING = 1,
	QUEEN = 2,
	ROOK = 3,
	BISHOP = 4,
	KNIGHT = 5,
	PAWN = 6,
	CUSTOM = 100  # For custom pieces starting at 100
}

enum PieceColor {
	NONE = 0,
	WHITE = 1,
	BLACK = 2
}

enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4,
	ANCIENT = 5
}

# =============================================================================
# SIGNALS
# =============================================================================

signal moved(from_pos: Vector2i, to_pos: Vector2i)
signal captured(capturing_piece: BasePiece)
signal died(killer: BasePiece)
signal promoted(new_type: PieceType)
signal modifier_added(modifier: Resource)
signal modifier_removed(modifier: Resource)
signal ability_activated(ability: Resource)

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var piece_type: PieceType = PieceType.NONE
@export var piece_color: PieceColor = PieceColor.NONE
@export var piece_name: String = "Unknown Piece"
@export var piece_value: int = 0  # Material value for AI evaluation
@export var rarity: Rarity = Rarity.COMMON

@export_group("Movement")
## Array of MovePattern resources defining how this piece moves
@export var move_patterns: Array[Resource] = []
## Whether this piece can jump over other pieces
@export var can_jump: bool = false
## Maximum range (-1 for unlimited)
@export var max_range: int = -1

@export_group("Visual")
@export var sprite_texture: Texture2D
@export var sprite_scale: Vector2 = Vector2.ONE

# =============================================================================
# PROPERTIES
# =============================================================================

## Current board position (in grid coordinates)
var board_position: Vector2i = Vector2i(-1, -1)

## Reference to the board this piece is on
var board: Node = null

## Whether this piece has moved (important for castling, pawn double move)
var has_moved: bool = false

## Number of moves this piece has made
var move_count: int = 0

## Array of active modifiers affecting this piece
var modifiers: Array[Resource] = []

## Array of abilities this piece has
var abilities: Array[Resource] = []

## Whether this piece is currently alive
var is_alive: bool = true

## Cooldowns for abilities (ability_id -> turns remaining)
var ability_cooldowns: Dictionary = {}

## For real-time modes: time until piece can move again
var movement_cooldown: float = 0.0

## Custom data dictionary for extensibility
var custom_data: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_setup_sprite()
	_initialize_abilities()


func _process(delta: float) -> void:
	_update_cooldowns(delta)


func _setup_sprite() -> void:
	if sprite and sprite_texture:
		sprite.texture = sprite_texture
		sprite.scale = sprite_scale


func _initialize_abilities() -> void:
	for ability in abilities:
		if ability.has_method("initialize"):
			ability.initialize(self)

# =============================================================================
# MOVEMENT
# =============================================================================

## Get all legal moves for this piece (to be overridden by specific pieces)
## Returns an array of Vector2i positions
func get_legal_moves() -> Array[Vector2i]:
	if not board:
		return []
	
	var moves: Array[Vector2i] = []
	
	for pattern in move_patterns:
		if pattern and pattern.has_method("get_moves"):
			var pattern_moves: Array = pattern.get_moves(self, board)
			for move in pattern_moves:
				if move is Vector2i:
					moves.append(move)
	
	# Apply modifiers that affect movement
	moves = _apply_movement_modifiers(moves)
	
	return moves


## Get raw moves without considering check (for check detection)
func get_raw_moves() -> Array[Vector2i]:
	return get_legal_moves()


## Get attack squares (squares this piece threatens)
## By default same as legal moves, but can differ (e.g., pawn attacks diagonally)
func get_attack_squares() -> Array[Vector2i]:
	return get_legal_moves()


## Check if this piece can move to a specific position
func can_move_to(target: Vector2i) -> bool:
	return target in get_legal_moves()


## Apply movement modifiers to a list of moves
func _apply_movement_modifiers(moves: Array[Vector2i]) -> Array[Vector2i]:
	var modified_moves := moves.duplicate()
	
	for modifier in modifiers:
		if modifier and modifier.has_method("modify_moves"):
			modified_moves = modifier.modify_moves(self, modified_moves)
	
	return modified_moves

# =============================================================================
# MOVEMENT EXECUTION
# =============================================================================

## Called when this piece moves to a new position
func on_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var _old_pos := board_position  # Stored for potential future use by modifiers
	board_position = to_pos
	has_moved = true
	move_count += 1
	
	# Notify modifiers
	for modifier in modifiers:
		if modifier and modifier.has_method("on_piece_moved"):
			modifier.on_piece_moved(self, from_pos, to_pos)
	
	# Trigger on_move abilities
	_trigger_abilities("on_move", {"from": from_pos, "to": to_pos})
	
	moved.emit(from_pos, to_pos)


## Called when this piece captures another piece
func on_capture(captured_piece: BasePiece) -> void:
	# Notify modifiers
	for modifier in modifiers:
		if modifier and modifier.has_method("on_piece_captured"):
			modifier.on_piece_captured(self, captured_piece)
	
	# Trigger on_kill abilities
	_trigger_abilities("on_kill", {"victim": captured_piece})
	
	captured.emit(captured_piece)


## Called when this piece is captured
func on_death(killer: BasePiece) -> void:
	is_alive = false
	
	# Notify modifiers
	for modifier in modifiers:
		if modifier and modifier.has_method("on_piece_died"):
			modifier.on_piece_died(self, killer)
	
	# Trigger on_death abilities
	_trigger_abilities("on_death", {"killer": killer})
	
	died.emit(killer)


## Called when this piece is promoted
func on_promote(new_type: PieceType) -> void:
	var old_type := piece_type
	piece_type = new_type
	
	# Trigger abilities
	_trigger_abilities("on_promote", {"old_type": old_type, "new_type": new_type})
	
	promoted.emit(new_type)

# =============================================================================
# MODIFIERS
# =============================================================================

## Add a modifier to this piece
func add_modifier(modifier: Resource) -> void:
	if modifier and modifier not in modifiers:
		modifiers.append(modifier)
		
		if modifier.has_method("on_added"):
			modifier.on_added(self)
		
		modifier_added.emit(modifier)


## Remove a modifier from this piece
func remove_modifier(modifier: Resource) -> void:
	if modifier in modifiers:
		modifiers.erase(modifier)
		
		if modifier.has_method("on_removed"):
			modifier.on_removed(self)
		
		modifier_removed.emit(modifier)


## Check if this piece has a specific modifier type
func has_modifier_of_type(modifier_type: String) -> bool:
	for modifier in modifiers:
		if modifier and modifier.has_method("get_type"):
			if modifier.get_type() == modifier_type:
				return true
	return false


## Get all modifiers of a specific type
func get_modifiers_of_type(modifier_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for modifier in modifiers:
		if modifier and modifier.has_method("get_type"):
			if modifier.get_type() == modifier_type:
				result.append(modifier)
	return result

# =============================================================================
# ABILITIES
# =============================================================================

## Activate an ability by index
func activate_ability(ability_index: int) -> bool:
	if ability_index < 0 or ability_index >= abilities.size():
		return false
	
	var ability: Resource = abilities[ability_index]
	if not ability:
		return false
	
	# Check cooldown
	var ability_id: String = str(ability.get_instance_id())
	if ability_cooldowns.has(ability_id) and ability_cooldowns[ability_id] > 0:
		return false
	
	# Execute ability
	if ability.has_method("execute"):
		var success: bool = ability.execute(self, board)
		if success:
			# Start cooldown
			if ability.has_method("get_cooldown"):
				ability_cooldowns[ability_id] = ability.get_cooldown()
			ability_activated.emit(ability)
			return true
	
	return false


## Get ability cooldown remaining
func get_ability_cooldown(ability_index: int) -> int:
	if ability_index < 0 or ability_index >= abilities.size():
		return 0
	
	var ability: Resource = abilities[ability_index]
	if not ability:
		return 0
	
	var ability_id: String = str(ability.get_instance_id())
	return ability_cooldowns.get(ability_id, 0)


## Trigger abilities of a specific type
func _trigger_abilities(trigger_type: String, data: Dictionary = {}) -> void:
	for ability in abilities:
		if ability and ability.has_method("get_trigger_type"):
			if ability.get_trigger_type() == trigger_type:
				if ability.has_method("execute"):
					ability.execute(self, board, data)


## Update cooldowns (called each frame for real-time, each turn for turn-based)
func _update_cooldowns(delta: float) -> void:
	# Real-time movement cooldown
	if movement_cooldown > 0:
		movement_cooldown = max(0, movement_cooldown - delta)


## Reduce turn-based cooldowns (called at turn end)
func reduce_turn_cooldowns() -> void:
	var to_remove: Array[String] = []
	
	for ability_id in ability_cooldowns:
		ability_cooldowns[ability_id] -= 1
		if ability_cooldowns[ability_id] <= 0:
			to_remove.append(ability_id)
	
	for ability_id in to_remove:
		ability_cooldowns.erase(ability_id)

# =============================================================================
# UTILITY
# =============================================================================

## Get the opposite color
static func get_opposite_color(color: PieceColor) -> PieceColor:
	match color:
		PieceColor.WHITE:
			return PieceColor.BLACK
		PieceColor.BLACK:
			return PieceColor.WHITE
		_:
			return PieceColor.NONE


## Get piece notation (e.g., "K" for King, "Q" for Queen)
func get_notation() -> String:
	match piece_type:
		PieceType.KING:
			return "K"
		PieceType.QUEEN:
			return "Q"
		PieceType.ROOK:
			return "R"
		PieceType.BISHOP:
			return "B"
		PieceType.KNIGHT:
			return "N"
		PieceType.PAWN:
			return ""
		_:
			return piece_name.substr(0, 1).to_upper() if piece_name else "?"


## Create a dictionary representation for saving
func to_dict() -> Dictionary:
	return {
		"piece_type": piece_type,
		"piece_color": piece_color,
		"board_position": {"x": board_position.x, "y": board_position.y},
		"has_moved": has_moved,
		"move_count": move_count,
		"is_alive": is_alive,
		"ability_cooldowns": ability_cooldowns.duplicate(),
		"custom_data": custom_data.duplicate()
	}


## Load from dictionary
func from_dict(data: Dictionary) -> void:
	piece_type = data.get("piece_type", PieceType.NONE)
	piece_color = data.get("piece_color", PieceColor.NONE)
	var pos_data: Dictionary = data.get("board_position", {"x": -1, "y": -1})
	board_position = Vector2i(pos_data.x, pos_data.y)
	has_moved = data.get("has_moved", false)
	move_count = data.get("move_count", 0)
	is_alive = data.get("is_alive", true)
	ability_cooldowns = data.get("ability_cooldowns", {}).duplicate()
	custom_data = data.get("custom_data", {}).duplicate()


## Get color name as string
func get_color_name() -> String:
	match piece_color:
		PieceColor.WHITE:
			return "White"
		PieceColor.BLACK:
			return "Black"
		_:
			return "None"


## Get piece type name as string
func get_type_name() -> String:
	match piece_type:
		PieceType.KING:
			return "King"
		PieceType.QUEEN:
			return "Queen"
		PieceType.ROOK:
			return "Rook"
		PieceType.BISHOP:
			return "Bishop"
		PieceType.KNIGHT:
			return "Knight"
		PieceType.PAWN:
			return "Pawn"
		_:
			return piece_name if piece_name else "Unknown"


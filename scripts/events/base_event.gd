class_name BaseEvent
extends Resource
## Base class for game events
## Events can affect pieces, squares, or the entire game

# =============================================================================
# ENUMS
# =============================================================================

enum EventType {
	PIECE = 0,     ## Affects specific pieces
	BOARD = 1,     ## Affects the board/squares
	GLOBAL = 2,    ## Affects game rules or modes
	PLAYER = 3     ## Affects players (abilities, resources)
}

enum TriggerCondition {
	RANDOM = 0,        ## Random chance each turn
	TURN_BASED = 1,    ## Triggers on specific turn
	POSITION = 2,      ## Triggers when piece reaches position
	PLAYER_ACTION = 3, ## Player triggers manually
	PIECE_COUNT = 4,   ## Triggers based on piece count
	CHECK = 5,         ## Triggers on check
	CAPTURE = 6,       ## Triggers on capture
	TIMER = 7          ## Triggers after time (real-time)
}

enum Duration {
	INSTANT = 0,    ## Happens once
	TIMED = 1,      ## Lasts for X turns
	PERMANENT = 2,  ## Lasts until removed
	CONDITIONAL = 3 ## Lasts until condition met
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
# EXPORTED PROPERTIES
# =============================================================================

@export var event_id: String = ""
@export var event_name: String = "Unnamed Event"
@export var description: String = ""
@export var icon: Texture2D

@export_group("Event Type")
@export var event_type: EventType = EventType.GLOBAL
@export var rarity: Rarity = Rarity.COMMON

@export_group("Trigger")
@export var trigger_condition: TriggerCondition = TriggerCondition.RANDOM
@export var trigger_chance: float = 0.1  ## For RANDOM trigger
@export var trigger_turn: int = 1        ## For TURN_BASED trigger
@export var trigger_position: Vector2i = Vector2i(-1, -1)  ## For POSITION trigger
@export var trigger_timer: float = 30.0  ## For TIMER trigger (seconds)

@export_group("Duration")
@export var duration_type: Duration = Duration.INSTANT
@export var duration_turns: int = 3      ## For TIMED duration
@export var duration_seconds: float = 10.0  ## For real-time TIMED

@export_group("Targeting")
@export var affects_both_players: bool = true
@export var target_piece_types: Array[BasePiece.PieceType] = []
@export var target_count: int = 1  ## How many targets

# =============================================================================
# PROPERTIES
# =============================================================================

var is_active: bool = false
var remaining_turns: int = 0
var remaining_time: float = 0.0
var affected_targets: Array = []  # Pieces, squares, or players affected

# =============================================================================
# LIFECYCLE
# =============================================================================

## Called when event is triggered
func activate(board: BaseBoard, game_mode: BaseGameMode = null) -> bool:
	is_active = true
	
	# Set duration
	match duration_type:
		Duration.TIMED:
			remaining_turns = duration_turns
		Duration.INSTANT:
			remaining_turns = 0
	
	# Execute the event effect
	var success := execute(board, game_mode)
	
	# If instant, deactivate immediately
	if duration_type == Duration.INSTANT:
		is_active = false
	
	return success


## Called to execute the event effect (override in subclasses)
func execute(board: BaseBoard, game_mode: BaseGameMode = null) -> bool:
	# Override in subclass
	return true


## Called at end of each turn while active
func on_turn_end(board: BaseBoard, current_player: BasePiece.PieceColor) -> void:
	if not is_active:
		return
	
	if duration_type == Duration.TIMED:
		remaining_turns -= 1
		if remaining_turns <= 0:
			deactivate(board)


## Called each frame for real-time events
func update(delta: float, board: BaseBoard) -> void:
	if not is_active:
		return
	
	if duration_type == Duration.TIMED and remaining_time > 0:
		remaining_time -= delta
		if remaining_time <= 0:
			deactivate(board)


## Called when event ends
func deactivate(board: BaseBoard) -> void:
	is_active = false
	_cleanup(board)


## Cleanup event effects (override in subclasses)
func _cleanup(board: BaseBoard) -> void:
	affected_targets.clear()

# =============================================================================
# TRIGGER CHECKING
# =============================================================================

## Check if event should trigger based on game state
func should_trigger(board: BaseBoard, game_mode: BaseGameMode, context: Dictionary = {}) -> bool:
	match trigger_condition:
		TriggerCondition.RANDOM:
			return randf() < trigger_chance
		TriggerCondition.TURN_BASED:
			return context.get("turn_number", 0) == trigger_turn
		TriggerCondition.POSITION:
			return _check_position_trigger(board, context)
		TriggerCondition.PIECE_COUNT:
			return _check_piece_count_trigger(board, context)
		TriggerCondition.CHECK:
			return context.get("is_check", false)
		TriggerCondition.CAPTURE:
			return context.get("is_capture", false)
		_:
			return false


func _check_position_trigger(board: BaseBoard, context: Dictionary) -> bool:
	if trigger_position == Vector2i(-1, -1):
		return false
	
	var piece: BasePiece = board.get_piece_at(trigger_position)
	return piece != null


func _check_piece_count_trigger(board: BaseBoard, context: Dictionary) -> bool:
	# Example: trigger when less than X pieces remain
	var threshold: int = context.get("piece_threshold", 10)
	return board.get_all_pieces().size() <= threshold

# =============================================================================
# TARGET SELECTION
# =============================================================================

## Get valid targets for this event
func get_valid_targets(board: BaseBoard, player_color: BasePiece.PieceColor) -> Array:
	var targets: Array = []
	
	match event_type:
		EventType.PIECE:
			targets = _get_piece_targets(board, player_color)
		EventType.BOARD:
			targets = _get_square_targets(board)
		_:
			pass
	
	return targets


func _get_piece_targets(board: BaseBoard, player_color: BasePiece.PieceColor) -> Array:
	var pieces: Array = []
	
	if affects_both_players:
		pieces = board.get_all_pieces()
	else:
		pieces = board.get_pieces_by_color(player_color)
	
	# Filter by type if specified
	if not target_piece_types.is_empty():
		pieces = pieces.filter(func(p): return p.piece_type in target_piece_types)
	
	# Limit count
	if target_count > 0 and pieces.size() > target_count:
		pieces.shuffle()
		pieces = pieces.slice(0, target_count)
	
	return pieces


func _get_square_targets(board: BaseBoard) -> Array:
	var squares: Array = []
	
	for x in range(board.columns):
		for y in range(board.rows):
			var pos := Vector2i(x, y)
			if board.is_valid_square(pos):
				squares.append(pos)
	
	if target_count > 0 and squares.size() > target_count:
		squares.shuffle()
		squares = squares.slice(0, target_count)
	
	return squares

# =============================================================================
# UTILITY
# =============================================================================

func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "Common"
		Rarity.UNCOMMON: return "Uncommon"
		Rarity.RARE: return "Rare"
		Rarity.EPIC: return "Epic"
		Rarity.LEGENDARY: return "Legendary"
		Rarity.ANCIENT: return _get_ancient_text()
		_: return "Unknown"


func _get_ancient_text() -> String:
	# Generate "incomprehensible" text for Ancient rarity
	var chars := "Z̴̧̛A̷̢̕L̶̨̛G̴̢̕O̷̧̕"
	return chars


func to_dict() -> Dictionary:
	return {
		"event_id": event_id,
		"is_active": is_active,
		"remaining_turns": remaining_turns,
		"affected_targets": affected_targets.map(func(t): 
			if t is BasePiece:
				return {"type": "piece", "position": {"x": t.board_position.x, "y": t.board_position.y}}
			elif t is Vector2i:
				return {"type": "square", "position": {"x": t.x, "y": t.y}}
			return {}
		)
	}


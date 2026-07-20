class_name EventManager
extends Node
## Manages game events - triggers, active events, and cleanup

# =============================================================================
# SIGNALS
# =============================================================================

signal event_triggered(event: BaseEvent)
signal event_ended(event: BaseEvent)
signal event_tick(active_events: Array)

# =============================================================================
# PROPERTIES
# =============================================================================

## Pool of available events
var event_pool: Array[BaseEvent] = []

## Currently active events
var active_events: Array[BaseEvent] = []

## Events scheduled for future turns
var scheduled_events: Array[Dictionary] = []  # [{event, trigger_turn}]

## Board reference
var board: BaseBoard = null

## Game mode reference
var game_mode: BaseGameMode = null

## Current turn number
var current_turn: int = 0

## Random event settings
var random_events_enabled: bool = false
var random_event_chance: float = 0.1
var max_active_events: int = 3

# =============================================================================
# INITIALIZATION
# =============================================================================

func setup(game_board: BaseBoard, mode: BaseGameMode) -> void:
	board = game_board
	game_mode = mode


func reset() -> void:
	# Deactivate all events
	for event in active_events:
		event.deactivate(board)
	
	active_events.clear()
	scheduled_events.clear()
	current_turn = 0

# =============================================================================
# EVENT REGISTRATION
# =============================================================================

## Add an event to the pool
func register_event(event: BaseEvent) -> void:
	if event not in event_pool:
		event_pool.append(event)


## Remove an event from the pool
func unregister_event(event: BaseEvent) -> void:
	event_pool.erase(event)


## Schedule an event for a specific turn
func schedule_event(event: BaseEvent, turn: int) -> void:
	scheduled_events.append({"event": event, "trigger_turn": turn})


## Trigger an event immediately
func trigger_event(event: BaseEvent) -> bool:
	if active_events.size() >= max_active_events:
		return false
	
	var success := event.activate(board, game_mode)
	
	if success:
		if event.is_active:
			active_events.append(event)
		event_triggered.emit(event)
	
	return success

# =============================================================================
# TURN PROCESSING
# =============================================================================

## Process events at turn start
func on_turn_start(turn_number: int, current_player: BasePiece.PieceColor) -> void:
	current_turn = turn_number
	
	# Check scheduled events
	_process_scheduled_events(turn_number)
	
	# Check random events
	if random_events_enabled:
		_try_random_event(current_player)


## Process events at turn end
func on_turn_end(current_player: BasePiece.PieceColor) -> void:
	var expired_events: Array[BaseEvent] = []
	
	for event in active_events:
		event.on_turn_end(board, current_player)
		
		if not event.is_active:
			expired_events.append(event)
	
	# Remove expired events
	for event in expired_events:
		active_events.erase(event)
		event_ended.emit(event)
	
	event_tick.emit(active_events)


## Process events each frame (for real-time modes)
func update(delta: float) -> void:
	for event in active_events:
		event.update(delta, board)


## Check and trigger scheduled events
func _process_scheduled_events(turn_number: int) -> void:
	var to_trigger: Array = []
	var to_remove: Array = []
	
	for data in scheduled_events:
		if data.trigger_turn <= turn_number:
			to_trigger.append(data.event)
			to_remove.append(data)
	
	for data in to_remove:
		scheduled_events.erase(data)
	
	for event in to_trigger:
		trigger_event(event)


## Try to trigger a random event
func _try_random_event(current_player: BasePiece.PieceColor) -> void:
	if randf() > random_event_chance:
		return
	
	if active_events.size() >= max_active_events:
		return
	
	# Select a random event from pool
	var eligible_events: Array[BaseEvent] = []
	
	for event in event_pool:
		if event.should_trigger(board, game_mode, {"turn_number": current_turn}):
			eligible_events.append(event)
	
	if eligible_events.is_empty():
		return
	
	# Weight by rarity (rarer = less likely)
	var weighted_events: Array = []
	for event in eligible_events:
		var weight: int
		match event.rarity:
			BaseEvent.Rarity.COMMON: weight = 100
			BaseEvent.Rarity.UNCOMMON: weight = 50
			BaseEvent.Rarity.RARE: weight = 20
			BaseEvent.Rarity.EPIC: weight = 8
			BaseEvent.Rarity.LEGENDARY: weight = 3
			BaseEvent.Rarity.ANCIENT: weight = 1
			_: weight = 50
		
		for i in range(weight):
			weighted_events.append(event)
	
	if not weighted_events.is_empty():
		var selected: BaseEvent = weighted_events[randi() % weighted_events.size()]
		trigger_event(selected.duplicate())

# =============================================================================
# QUERIES
# =============================================================================

## Get all active events
func get_active_events() -> Array[BaseEvent]:
	return active_events.duplicate()


## Get active events of a specific type
func get_active_events_of_type(event_type: BaseEvent.EventType) -> Array[BaseEvent]:
	var result: Array[BaseEvent] = []
	for event in active_events:
		if event.event_type == event_type:
			result.append(event)
	return result


## Check if a specific event is active
func is_event_active(event_id: String) -> bool:
	for event in active_events:
		if event.event_id == event_id:
			return true
	return false


## Get event by ID
func get_event(event_id: String) -> BaseEvent:
	for event in active_events:
		if event.event_id == event_id:
			return event
	return null

# =============================================================================
# EVENT INTERACTION
# =============================================================================

## Force end an event early
func end_event(event: BaseEvent) -> void:
	if event in active_events:
		event.deactivate(board)
		active_events.erase(event)
		event_ended.emit(event)


## Clear all active events
func clear_all_events() -> void:
	for event in active_events:
		event.deactivate(board)
	
	active_events.clear()
	scheduled_events.clear()

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"current_turn": current_turn,
		"active_events": active_events.map(func(e): return e.to_dict()),
		"scheduled_events": scheduled_events.map(func(d): return {
			"event_id": d.event.event_id,
			"trigger_turn": d.trigger_turn
		}),
		"random_events_enabled": random_events_enabled,
		"random_event_chance": random_event_chance
	}


class_name ModifierSystem
extends Node
## System for managing piece and square modifiers
## Handles modifier lifecycle, stacking, and application

# =============================================================================
# SIGNALS
# =============================================================================

signal modifier_applied(target: Node, modifier: Resource)
signal modifier_removed(target: Node, modifier: Resource)
signal modifier_expired(target: Node, modifier: Resource)
signal modifier_stacked(target: Node, modifier: Resource, new_stacks: int)

# =============================================================================
# PROPERTIES
# =============================================================================

## All active modifiers tracked by this system
## Key: target node instance_id, Value: Array of modifier resources
var active_modifiers: Dictionary = {}

## Modifier duration tracking (for timed modifiers)
## Key: modifier instance_id, Value: remaining duration (turns or seconds)
var modifier_durations: Dictionary = {}

## Modifier stack counts
## Key: modifier instance_id, Value: stack count
var modifier_stacks: Dictionary = {}

# =============================================================================
# MODIFIER APPLICATION
# =============================================================================

## Apply a modifier to a piece
func apply_to_piece(piece: BasePiece, modifier: Resource, duration: int = -1, stacks: int = 1) -> bool:
	if not piece or not modifier:
		return false
	
	var target_id := piece.get_instance_id()
	
	# Check if modifier can be stacked
	if _is_modifier_active(target_id, modifier):
		if modifier.has_method("can_stack") and modifier.can_stack():
			return _add_stacks(target_id, modifier, stacks)
		else:
			# Refresh duration if can't stack
			if duration > 0:
				modifier_durations[modifier.get_instance_id()] = duration
			return true
	
	# Initialize tracking array if needed
	if not active_modifiers.has(target_id):
		active_modifiers[target_id] = []
	
	# Add modifier
	active_modifiers[target_id].append(modifier)
	piece.add_modifier(modifier)
	
	# Set duration if specified
	if duration > 0:
		modifier_durations[modifier.get_instance_id()] = duration
	
	# Set initial stacks
	modifier_stacks[modifier.get_instance_id()] = stacks
	
	modifier_applied.emit(piece, modifier)
	return true


## Apply a modifier to a board square
func apply_to_square(board: BaseBoard, position: Vector2i, modifier: Resource, duration: int = -1) -> bool:
	if not board or not modifier:
		return false
	
	if not board.is_within_bounds(position):
		return false
	
	# Use a unique key for square modifiers
	var target_id := _get_square_id(board, position)
	
	# Initialize tracking array if needed
	if not active_modifiers.has(target_id):
		active_modifiers[target_id] = []
	
	# Add modifier
	active_modifiers[target_id].append(modifier)
	board.add_square_modifier(position, modifier)
	
	# Set duration if specified
	if duration > 0:
		modifier_durations[modifier.get_instance_id()] = duration
	
	modifier_applied.emit(board, modifier)
	return true


## Remove a modifier from a piece
func remove_from_piece(piece: BasePiece, modifier: Resource) -> bool:
	if not piece or not modifier:
		return false
	
	var target_id := piece.get_instance_id()
	
	if not active_modifiers.has(target_id):
		return false
	
	var mods: Array = active_modifiers[target_id]
	if modifier not in mods:
		return false
	
	mods.erase(modifier)
	piece.remove_modifier(modifier)
	
	# Clean up duration tracking
	modifier_durations.erase(modifier.get_instance_id())
	modifier_stacks.erase(modifier.get_instance_id())
	
	# Clean up empty arrays
	if mods.is_empty():
		active_modifiers.erase(target_id)
	
	modifier_removed.emit(piece, modifier)
	return true


## Remove a modifier from a square
func remove_from_square(board: BaseBoard, position: Vector2i, modifier: Resource) -> bool:
	if not board or not modifier:
		return false
	
	var target_id := _get_square_id(board, position)
	
	if not active_modifiers.has(target_id):
		return false
	
	var mods: Array = active_modifiers[target_id]
	if modifier not in mods:
		return false
	
	mods.erase(modifier)
	board.remove_square_modifier(position, modifier)
	
	# Clean up
	modifier_durations.erase(modifier.get_instance_id())
	
	if mods.is_empty():
		active_modifiers.erase(target_id)
	
	modifier_removed.emit(board, modifier)
	return true

# =============================================================================
# DURATION MANAGEMENT
# =============================================================================

## Process turn-based modifier durations
func process_turn_end() -> void:
	var to_expire: Array = []
	
	for modifier_id in modifier_durations:
		modifier_durations[modifier_id] -= 1
		if modifier_durations[modifier_id] <= 0:
			to_expire.append(modifier_id)
	
	# Expire modifiers
	for modifier_id in to_expire:
		_expire_modifier_by_id(modifier_id)


## Process real-time modifier durations
func process_delta(delta: float) -> void:
	var to_expire: Array = []
	
	for modifier_id in modifier_durations:
		if modifier_durations[modifier_id] is float:
			modifier_durations[modifier_id] -= delta
			if modifier_durations[modifier_id] <= 0:
				to_expire.append(modifier_id)
	
	for modifier_id in to_expire:
		_expire_modifier_by_id(modifier_id)


## Expire a modifier by its instance ID
func _expire_modifier_by_id(modifier_id: int) -> void:
	# Find and remove the modifier
	for target_id in active_modifiers:
		var mods: Array = active_modifiers[target_id]
		for modifier in mods:
			if modifier.get_instance_id() == modifier_id:
				# Find the target and remove properly
				var target := instance_from_id(target_id)
				if target:
					if target is BasePiece:
						remove_from_piece(target, modifier)
					modifier_expired.emit(target, modifier)
				return

# =============================================================================
# STACKING
# =============================================================================

## Add stacks to an existing modifier
func _add_stacks(target_id: int, modifier: Resource, stacks: int) -> bool:
	var modifier_id := modifier.get_instance_id()
	
	if not modifier_stacks.has(modifier_id):
		modifier_stacks[modifier_id] = 0
	
	var max_stacks: int = 99
	if modifier.has_method("get_max_stacks"):
		max_stacks = modifier.get_max_stacks()
	
	var new_stacks: int = min(modifier_stacks[modifier_id] + stacks, max_stacks)
	modifier_stacks[modifier_id] = new_stacks
	
	# Notify the modifier
	if modifier.has_method("on_stack_added"):
		modifier.on_stack_added(new_stacks)
	
	var target := instance_from_id(target_id)
	if target:
		modifier_stacked.emit(target, modifier, new_stacks)
	
	return true


## Get current stack count for a modifier
func get_stacks(modifier: Resource) -> int:
	if not modifier:
		return 0
	return modifier_stacks.get(modifier.get_instance_id(), 0)

# =============================================================================
# QUERIES
# =============================================================================

## Check if a modifier is active on a target
func _is_modifier_active(target_id: int, modifier: Resource) -> bool:
	if not active_modifiers.has(target_id):
		return false
	
	# Check by type if modifier has get_type method
	if modifier.has_method("get_modifier_id"):
		var check_id: String = modifier.get_modifier_id()
		for active_mod in active_modifiers[target_id]:
			if active_mod.has_method("get_modifier_id"):
				if active_mod.get_modifier_id() == check_id:
					return true
	
	return modifier in active_modifiers[target_id]


## Get all active modifiers on a piece
func get_piece_modifiers(piece: BasePiece) -> Array:
	if not piece:
		return []
	return active_modifiers.get(piece.get_instance_id(), []).duplicate()


## Get all active modifiers on a square
func get_square_modifiers(board: BaseBoard, position: Vector2i) -> Array:
	if not board:
		return []
	return active_modifiers.get(_get_square_id(board, position), []).duplicate()


## Get remaining duration of a modifier
func get_remaining_duration(modifier: Resource) -> float:
	if not modifier:
		return -1.0
	return modifier_durations.get(modifier.get_instance_id(), -1.0)

# =============================================================================
# CLEANUP
# =============================================================================

## Remove all modifiers from a piece
func clear_piece_modifiers(piece: BasePiece) -> void:
	if not piece:
		return
	
	var target_id := piece.get_instance_id()
	if not active_modifiers.has(target_id):
		return
	
	var mods: Array = active_modifiers[target_id].duplicate()
	for modifier in mods:
		remove_from_piece(piece, modifier)


## Remove all modifiers from the system
func clear_all() -> void:
	for target_id in active_modifiers.keys():
		var target := instance_from_id(target_id)
		if target and target is BasePiece:
			clear_piece_modifiers(target)
	
	active_modifiers.clear()
	modifier_durations.clear()
	modifier_stacks.clear()

# =============================================================================
# UTILITY
# =============================================================================

## Generate a unique ID for a board square
func _get_square_id(board: BaseBoard, position: Vector2i) -> int:
	# Combine board instance ID with position for unique square identification
	return hash(str(board.get_instance_id()) + ":" + str(position.x) + "," + str(position.y))


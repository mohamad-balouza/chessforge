class_name PieceModifier
extends Resource
## Base class for piece modifiers
## Modifiers can affect movement, stats, abilities, and behavior

# =============================================================================
# ENUMS
# =============================================================================

enum ModifierType {
	MOVEMENT = 0,    ## Affects how the piece moves
	STAT = 1,        ## Affects piece stats (value, etc.)
	ABILITY = 2,     ## Grants or modifies abilities
	BEHAVIOR = 3,    ## Changes piece behavior
	VISUAL = 4,      ## Visual-only modifier
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var modifier_id: String = ""
@export var modifier_name: String = "Unnamed Modifier"
@export var description: String = ""
@export var modifier_type: ModifierType = ModifierType.BEHAVIOR
@export var icon: Texture2D

@export_group("Stacking")
@export var stackable: bool = false
@export var max_stacks: int = 1

@export_group("Duration")
## -1 for permanent, otherwise number of turns
@export var base_duration: int = -1

# =============================================================================
# PROPERTIES
# =============================================================================

var current_stacks: int = 1

# =============================================================================
# LIFECYCLE METHODS (Override in subclasses)
# =============================================================================

## Called when modifier is added to a piece
func on_added(piece: BasePiece) -> void:
	pass


## Called when modifier is removed from a piece
func on_removed(piece: BasePiece) -> void:
	pass


## Called when the piece moves
func on_piece_moved(piece: BasePiece, from_pos: Vector2i, to_pos: Vector2i) -> void:
	pass


## Called when the piece captures another piece
func on_piece_captured(piece: BasePiece, captured: BasePiece) -> void:
	pass


## Called when the piece dies
func on_piece_died(piece: BasePiece, killer: BasePiece) -> void:
	pass

# =============================================================================
# MOVEMENT MODIFICATION (Override for movement modifiers)
# =============================================================================

## Modify the list of legal moves
## Return the modified array of moves
func modify_moves(piece: BasePiece, moves: Array[Vector2i]) -> Array[Vector2i]:
	return moves

# =============================================================================
# STAT MODIFICATION (Override for stat modifiers)
# =============================================================================

## Get the value modification (added to base piece value)
func get_value_modifier() -> int:
	return 0

# =============================================================================
# STACKING
# =============================================================================

func can_stack() -> bool:
	return stackable


func get_max_stacks() -> int:
	return max_stacks


func on_stack_added(new_total: int) -> void:
	current_stacks = new_total

# =============================================================================
# QUERIES
# =============================================================================

func get_type() -> String:
	return modifier_id


func get_modifier_id() -> String:
	return modifier_id


func get_display_name() -> String:
	return modifier_name


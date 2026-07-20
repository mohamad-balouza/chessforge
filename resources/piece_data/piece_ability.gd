class_name PieceAbility
extends Resource
## Base class for piece abilities
## Abilities can be active (player-triggered) or passive (automatic)

# =============================================================================
# ENUMS
# =============================================================================

enum TriggerType {
	ACTIVE = 0,       ## Player must activate manually
	PASSIVE = 1,      ## Always active
	ON_MOVE = 2,      ## Triggers when piece moves
	ON_CAPTURE = 3,   ## Triggers when piece captures
	ON_DEATH = 4,     ## Triggers when piece dies
	ON_KILL = 5,      ## Triggers when piece kills another
	ON_TURN_START = 6, ## Triggers at start of owner's turn
	ON_TURN_END = 7,   ## Triggers at end of owner's turn
	ON_PROMOTE = 8,    ## Triggers when piece promotes
}

enum CooldownType {
	TURNS = 0,        ## Cooldown in turns
	SECONDS = 1,      ## Cooldown in real-time seconds
	CHARGES = 2,      ## Limited number of uses
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var ability_id: String = ""
@export var ability_name: String = "Unnamed Ability"
@export var description: String = ""
@export var icon: Texture2D

@export_group("Trigger")
@export var trigger_type: TriggerType = TriggerType.ACTIVE

@export_group("Cooldown")
@export var cooldown_type: CooldownType = CooldownType.TURNS
## Cooldown duration (turns or seconds)
@export var cooldown_duration: float = 1.0
## Maximum charges (for CHARGES type)
@export var max_charges: int = 1

@export_group("Targeting")
## Whether this ability requires a target square
@export var requires_target: bool = false
## Maximum range for targeting (-1 for unlimited)
@export var target_range: int = -1

# =============================================================================
# PROPERTIES
# =============================================================================

## Current charges remaining (for CHARGES type)
var current_charges: int = 1

# =============================================================================
# INITIALIZATION
# =============================================================================

## Called when ability is added to a piece
func initialize(piece: BasePiece) -> void:
	current_charges = max_charges


# =============================================================================
# EXECUTION (Override in subclasses)
# =============================================================================

## Execute the ability
## Returns true if execution was successful
func execute(piece: BasePiece, board: BaseBoard, data: Dictionary = {}) -> bool:
	# Override in subclass
	return false


## Check if ability can be used
func can_use(piece: BasePiece, board: BaseBoard) -> bool:
	if cooldown_type == CooldownType.CHARGES:
		return current_charges > 0
	return true


## Get valid target squares for this ability
func get_valid_targets(piece: BasePiece, board: BaseBoard) -> Array[Vector2i]:
	# Override in subclass
	return []

# =============================================================================
# COOLDOWN
# =============================================================================

func get_cooldown() -> float:
	return cooldown_duration


func get_trigger_type() -> String:
	match trigger_type:
		TriggerType.ACTIVE:
			return "active"
		TriggerType.PASSIVE:
			return "passive"
		TriggerType.ON_MOVE:
			return "on_move"
		TriggerType.ON_CAPTURE:
			return "on_capture"
		TriggerType.ON_DEATH:
			return "on_death"
		TriggerType.ON_KILL:
			return "on_kill"
		TriggerType.ON_TURN_START:
			return "on_turn_start"
		TriggerType.ON_TURN_END:
			return "on_turn_end"
		TriggerType.ON_PROMOTE:
			return "on_promote"
		_:
			return "unknown"


## Use a charge (for CHARGES type)
func use_charge() -> void:
	if cooldown_type == CooldownType.CHARGES:
		current_charges = max(0, current_charges - 1)


## Restore a charge
func restore_charge(amount: int = 1) -> void:
	if cooldown_type == CooldownType.CHARGES:
		current_charges = min(max_charges, current_charges + amount)


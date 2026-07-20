class_name PlayerAbility
extends Resource
## Player abilities that can affect the game
## These are abilities the player can use, separate from piece abilities

# =============================================================================
# ENUMS
# =============================================================================

enum AbilityType {
	INSTANT = 0,      ## Executes immediately
	TARGETED = 1,     ## Requires selecting a target (piece or square)
	GLOBAL = 2        ## Affects entire board/game
}

enum TargetType {
	PIECE = 0,        ## Target a specific piece
	SQUARE = 1,       ## Target a board square
	OWN_PIECE = 2,    ## Target own piece only
	ENEMY_PIECE = 3,  ## Target enemy piece only
	AREA = 4          ## Target an area (multiple squares)
}

enum CooldownType {
	TURNS = 0,
	SECONDS = 1,
	CHARGES = 2
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var ability_id: String = ""
@export var ability_name: String = "Unnamed Ability"
@export var description: String = ""
@export var icon: Texture2D

@export_group("Type")
@export var ability_type: AbilityType = AbilityType.INSTANT
@export var target_type: TargetType = TargetType.PIECE

@export_group("Cooldown")
@export var cooldown_type: CooldownType = CooldownType.TURNS
@export var cooldown_value: float = 3.0
@export var max_charges: int = 1
@export var charges_per_game: int = -1  ## -1 for unlimited

@export_group("Cost")
@export var mana_cost: int = 0  ## For resource-based modes
@export var sacrifice_piece: bool = false  ## Requires sacrificing a piece

@export_group("Targeting")
@export var target_range: int = -1  ## -1 for unlimited
@export var area_size: int = 1  ## For AREA targeting

@export_group("Rarity")
@export var rarity: BaseEvent.Rarity = BaseEvent.Rarity.COMMON

# =============================================================================
# PROPERTIES
# =============================================================================

var current_cooldown: float = 0.0
var current_charges: int = 1
var total_uses: int = 0

# =============================================================================
# INITIALIZATION
# =============================================================================

func initialize() -> void:
	current_charges = max_charges
	current_cooldown = 0.0
	total_uses = 0

# =============================================================================
# USAGE CHECKS
# =============================================================================

## Check if ability can be used
func can_use(player_color: BasePiece.PieceColor, board: BaseBoard, game_mode: BaseGameMode = null) -> bool:
	# Check cooldown
	if cooldown_type == CooldownType.CHARGES:
		if current_charges <= 0:
			return false
	elif current_cooldown > 0:
		return false
	
	# Check total uses
	if charges_per_game > 0 and total_uses >= charges_per_game:
		return false
	
	# Check mana cost (if applicable)
	if mana_cost > 0:
		# Would check player's mana resource
		pass
	
	return true


## Get valid targets for this ability
func get_valid_targets(player_color: BasePiece.PieceColor, board: BaseBoard) -> Array:
	var targets: Array = []
	
	match target_type:
		TargetType.PIECE:
			targets = board.get_all_pieces()
		TargetType.OWN_PIECE:
			targets = board.get_pieces_by_color(player_color)
		TargetType.ENEMY_PIECE:
			targets = board.get_pieces_by_color(BasePiece.get_opposite_color(player_color))
		TargetType.SQUARE:
			for x in range(board.columns):
				for y in range(board.rows):
					var pos := Vector2i(x, y)
					if board.is_valid_square(pos):
						targets.append(pos)
		TargetType.AREA:
			# Return center points for areas
			for x in range(board.columns):
				for y in range(board.rows):
					targets.append(Vector2i(x, y))
	
	# Filter by range if needed
	if target_range > 0:
		# Would filter based on distance from some reference point
		pass
	
	return targets

# =============================================================================
# EXECUTION
# =============================================================================

## Execute the ability (override in subclasses)
func execute(player_color: BasePiece.PieceColor, board: BaseBoard, target = null, game_mode: BaseGameMode = null) -> bool:
	if not can_use(player_color, board, game_mode):
		return false
	
	# Execute specific ability effect (override in subclass)
	var success := _do_execute(player_color, board, target, game_mode)
	
	if success:
		_apply_cooldown()
		total_uses += 1
	
	return success


## Override this in subclasses to implement ability effect
func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
	return true


func _apply_cooldown() -> void:
	match cooldown_type:
		CooldownType.TURNS, CooldownType.SECONDS:
			current_cooldown = cooldown_value
		CooldownType.CHARGES:
			current_charges -= 1

# =============================================================================
# COOLDOWN MANAGEMENT
# =============================================================================

## Reduce turn-based cooldown
func reduce_turn_cooldown() -> void:
	if cooldown_type == CooldownType.TURNS:
		current_cooldown = max(0, current_cooldown - 1)


## Update real-time cooldown
func update_cooldown(delta: float) -> void:
	if cooldown_type == CooldownType.SECONDS:
		current_cooldown = max(0, current_cooldown - delta)


## Get remaining cooldown
func get_remaining_cooldown() -> float:
	return current_cooldown


## Restore a charge
func restore_charge(amount: int = 1) -> void:
	if cooldown_type == CooldownType.CHARGES:
		current_charges = min(max_charges, current_charges + amount)

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"ability_id": ability_id,
		"current_cooldown": current_cooldown,
		"current_charges": current_charges,
		"total_uses": total_uses
	}


func from_dict(data: Dictionary) -> void:
	current_cooldown = data.get("current_cooldown", 0.0)
	current_charges = data.get("current_charges", max_charges)
	total_uses = data.get("total_uses", 0)


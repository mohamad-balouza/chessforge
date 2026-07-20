class_name RaritySystem
extends RefCounted
## System for managing rarity-based content (pieces, events, abilities)

# =============================================================================
# CONSTANTS
# =============================================================================

## Base drop weights for each rarity
const RARITY_WEIGHTS := {
	BaseEvent.Rarity.COMMON: 100,
	BaseEvent.Rarity.UNCOMMON: 50,
	BaseEvent.Rarity.RARE: 20,
	BaseEvent.Rarity.EPIC: 8,
	BaseEvent.Rarity.LEGENDARY: 3,
	BaseEvent.Rarity.ANCIENT: 1
}

## Colors for each rarity tier
const RARITY_COLORS := {
	BaseEvent.Rarity.COMMON: Color(0.7, 0.7, 0.7),       # Gray
	BaseEvent.Rarity.UNCOMMON: Color(0.3, 0.8, 0.3),    # Green
	BaseEvent.Rarity.RARE: Color(0.3, 0.5, 0.9),        # Blue
	BaseEvent.Rarity.EPIC: Color(0.6, 0.3, 0.8),        # Purple
	BaseEvent.Rarity.LEGENDARY: Color(1.0, 0.6, 0.0),   # Orange
	BaseEvent.Rarity.ANCIENT: Color(0.9, 0.1, 0.1)      # Red (with special effects)
}

## Display names for rarities
const RARITY_NAMES := {
	BaseEvent.Rarity.COMMON: "Common",
	BaseEvent.Rarity.UNCOMMON: "Uncommon",
	BaseEvent.Rarity.RARE: "Rare",
	BaseEvent.Rarity.EPIC: "Epic",
	BaseEvent.Rarity.LEGENDARY: "Legendary",
	BaseEvent.Rarity.ANCIENT: "A̷͚̔ṇ̶͝c̷̱͂i̶̘̍e̷̮͌n̷̰̈́t̵̰͠"  # Zalgo text
}

# =============================================================================
# PROPERTIES
# =============================================================================

## Luck modifier (higher = better drops)
var luck_modifier: float = 1.0

## Pity counter (increases rare drop chance after unlucky streak)
var pity_counter: int = 0
var pity_threshold: int = 10

# =============================================================================
# DROP CALCULATION
# =============================================================================

## Roll for a rarity based on weights
func roll_rarity(min_rarity: BaseEvent.Rarity = BaseEvent.Rarity.COMMON, 
				 max_rarity: BaseEvent.Rarity = BaseEvent.Rarity.ANCIENT) -> BaseEvent.Rarity:
	var total_weight: int = 0
	var weight_map: Dictionary = {}
	
	for rarity_int in range(min_rarity, max_rarity + 1):
		var rarity: BaseEvent.Rarity = rarity_int as BaseEvent.Rarity
		var weight: int = _get_modified_weight(rarity)
		weight_map[rarity] = weight
		total_weight += weight
	
	var roll := randi() % total_weight
	var cumulative: int = 0
	
	for rarity in weight_map:
		cumulative += weight_map[rarity]
		if roll < cumulative:
			_update_pity(rarity)
			return rarity
	
	return min_rarity


func _get_modified_weight(rarity: BaseEvent.Rarity) -> int:
	var base_weight: int = RARITY_WEIGHTS.get(rarity, 50)
	var modified_weight: float = base_weight
	
	# Apply luck modifier
	if rarity >= BaseEvent.Rarity.RARE:
		modified_weight *= luck_modifier
	
	# Apply pity bonus
	if pity_counter > 0 and rarity >= BaseEvent.Rarity.EPIC:
		var pity_bonus: float = float(pity_counter) / float(pity_threshold)
		modified_weight *= (1.0 + pity_bonus)
	
	return int(max(1, modified_weight))


func _update_pity(result_rarity: BaseEvent.Rarity) -> void:
	if result_rarity >= BaseEvent.Rarity.EPIC:
		pity_counter = 0  # Reset on good roll
	else:
		pity_counter += 1

# =============================================================================
# ITEM SELECTION
# =============================================================================

## Select a random item from a pool based on rarity
func select_from_pool(pool: Array, filter_func: Callable = Callable()) -> Resource:
	if pool.is_empty():
		return null
	
	# Filter pool if filter function provided
	var filtered_pool: Array = pool
	if filter_func.is_valid():
		filtered_pool = pool.filter(filter_func)
	
	if filtered_pool.is_empty():
		return null
	
	# Roll for rarity first
	var target_rarity := roll_rarity()
	
	# Find items of that rarity
	var rarity_matches: Array = filtered_pool.filter(func(item):
		if item is Resource and item.has_method("get") and item.get("rarity") != null:
			return item.rarity == target_rarity
		return false
	)
	
	# If no matches, try lower rarities
	while rarity_matches.is_empty() and target_rarity > BaseEvent.Rarity.COMMON:
		target_rarity = (target_rarity - 1) as BaseEvent.Rarity
		rarity_matches = filtered_pool.filter(func(item):
			if item is Resource and item.has_method("get") and item.get("rarity") != null:
				return item.rarity == target_rarity
			return false
		)
	
	if rarity_matches.is_empty():
		return filtered_pool[randi() % filtered_pool.size()]
	
	return rarity_matches[randi() % rarity_matches.size()]


## Select multiple items ensuring rarity distribution
func select_multiple(pool: Array, count: int, allow_duplicates: bool = false) -> Array:
	var results: Array = []
	var remaining_pool := pool.duplicate()
	
	for i in range(count):
		if remaining_pool.is_empty():
			break
		
		var selected := select_from_pool(remaining_pool)
		if selected:
			results.append(selected)
			
			if not allow_duplicates:
				remaining_pool.erase(selected)
	
	return results

# =============================================================================
# DISPLAY UTILITIES
# =============================================================================

## Get the color for a rarity
func get_rarity_color(rarity: BaseEvent.Rarity) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


## Get the display name for a rarity
func get_rarity_name(rarity: BaseEvent.Rarity) -> String:
	return RARITY_NAMES.get(rarity, "Unknown")


## Check if rarity should have special effects
func has_special_effects(rarity: BaseEvent.Rarity) -> bool:
	return rarity >= BaseEvent.Rarity.LEGENDARY


## Get the rarity frame/border style
func get_rarity_border_width(rarity: BaseEvent.Rarity) -> int:
	match rarity:
		BaseEvent.Rarity.COMMON: return 1
		BaseEvent.Rarity.UNCOMMON: return 2
		BaseEvent.Rarity.RARE: return 2
		BaseEvent.Rarity.EPIC: return 3
		BaseEvent.Rarity.LEGENDARY: return 4
		BaseEvent.Rarity.ANCIENT: return 5
		_: return 1

# =============================================================================
# AI DIFFICULTY SCALING
# =============================================================================

## Get difficulty modifier based on rarity
func get_ai_difficulty_modifier(rarity: BaseEvent.Rarity) -> float:
	match rarity:
		BaseEvent.Rarity.COMMON: return 1.0
		BaseEvent.Rarity.UNCOMMON: return 1.1
		BaseEvent.Rarity.RARE: return 1.25
		BaseEvent.Rarity.EPIC: return 1.5
		BaseEvent.Rarity.LEGENDARY: return 2.0
		BaseEvent.Rarity.ANCIENT: return 3.0
		_: return 1.0

# =============================================================================
# SERIALIZATION
# =============================================================================

func to_dict() -> Dictionary:
	return {
		"luck_modifier": luck_modifier,
		"pity_counter": pity_counter
	}


func from_dict(data: Dictionary) -> void:
	luck_modifier = data.get("luck_modifier", 1.0)
	pity_counter = data.get("pity_counter", 0)


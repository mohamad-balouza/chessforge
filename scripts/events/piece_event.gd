class_name PieceEvent
extends BaseEvent
## Events that affect pieces

# =============================================================================
# ENUMS
# =============================================================================

enum PieceEffect {
	TRANSFORM = 0,    ## Change piece type
	BUFF = 1,         ## Add positive modifier
	DEBUFF = 2,       ## Add negative modifier
	FREEZE = 3,       ## Prevent movement
	CURSE = 4,        ## Death timer
	EMPOWER = 5,      ## Enhance abilities
	CLONE = 6,        ## Duplicate piece
	SWAP = 7,         ## Swap positions
	PROMOTE = 8,      ## Force promotion
	DEMOTE = 9        ## Force demotion
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var effect_type: PieceEffect = PieceEffect.BUFF

@export_group("Transform Settings")
@export var transform_to: BasePiece.PieceType = BasePiece.PieceType.QUEEN

@export_group("Modifier Settings")
@export var modifier_to_apply: Resource  # PieceModifier

@export_group("Curse Settings")
@export var curse_turns: int = 3  ## Turns until piece dies

# =============================================================================
# PROPERTIES
# =============================================================================

var cursed_pieces: Dictionary = {}  # piece -> turns remaining

# =============================================================================
# EXECUTION
# =============================================================================

func execute(board: BaseBoard, game_mode: BaseGameMode = null) -> bool:
	var targets := get_valid_targets(board, BasePiece.PieceColor.WHITE)  # Both colors if affects_both
	
	if targets.is_empty():
		return false
	
	affected_targets = targets
	
	match effect_type:
		PieceEffect.TRANSFORM:
			return _execute_transform(board, targets)
		PieceEffect.BUFF, PieceEffect.DEBUFF:
			return _execute_modifier(targets)
		PieceEffect.FREEZE:
			return _execute_freeze(targets)
		PieceEffect.CURSE:
			return _execute_curse(targets)
		PieceEffect.CLONE:
			return _execute_clone(board, targets)
		PieceEffect.SWAP:
			return _execute_swap(board, targets)
		_:
			return false


func _execute_transform(board: BaseBoard, targets: Array) -> bool:
	for piece in targets:
		if piece is BasePiece:
			# Store original type for potential reversal
			piece.custom_data["original_type"] = piece.piece_type
			piece.piece_type = transform_to
			
			# Update visuals would happen here
	
	return true


func _execute_modifier(targets: Array) -> bool:
	if not modifier_to_apply:
		return false
	
	for piece in targets:
		if piece is BasePiece:
			piece.add_modifier(modifier_to_apply.duplicate())
	
	return true


func _execute_freeze(targets: Array) -> bool:
	# Create freeze modifier
	var freeze_mod := PieceModifier.new()
	freeze_mod.modifier_id = "freeze"
	freeze_mod.modifier_name = "Frozen"
	freeze_mod.base_duration = duration_turns
	
	for piece in targets:
		if piece is BasePiece:
			piece.add_modifier(freeze_mod)
			# The modifier's modify_moves would return empty array
	
	return true


func _execute_curse(targets: Array) -> bool:
	for piece in targets:
		if piece is BasePiece:
			cursed_pieces[piece] = curse_turns
			piece.custom_data["cursed"] = true
	
	return true


func _execute_clone(board: BaseBoard, targets: Array) -> bool:
	for piece in targets:
		if piece is BasePiece:
			# Find adjacent empty square
			var clone_pos := _find_clone_position(board, piece.board_position)
			if clone_pos != Vector2i(-1, -1):
				# Create clone - would need piece factory
				# For now just mark the position
				pass
	
	return true


func _execute_swap(board: BaseBoard, targets: Array) -> bool:
	if targets.size() < 2:
		return false
	
	var piece1: BasePiece = targets[0]
	var piece2: BasePiece = targets[1]
	
	var pos1 := piece1.board_position
	var pos2 := piece2.board_position
	
	# Swap positions
	board.pieces[pos1.x][pos1.y] = piece2
	board.pieces[pos2.x][pos2.y] = piece1
	piece1.board_position = pos2
	piece2.board_position = pos1
	
	# Update visual positions
	piece1.position = board.board_to_world(pos2)
	piece2.position = board.board_to_world(pos1)
	
	return true


func _find_clone_position(board: BaseBoard, origin: Vector2i) -> Vector2i:
	var directions := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for dir in directions:
		var pos := origin + dir
		if board.is_valid_square(pos) and board.is_square_empty(pos):
			return pos
	
	return Vector2i(-1, -1)

# =============================================================================
# TURN HANDLING
# =============================================================================

func on_turn_end(board: BaseBoard, current_player: BasePiece.PieceColor) -> void:
	super.on_turn_end(board, current_player)
	
	# Handle curse countdown
	if effect_type == PieceEffect.CURSE:
		var to_remove: Array = []
		
		for piece in cursed_pieces:
			cursed_pieces[piece] -= 1
			if cursed_pieces[piece] <= 0:
				# Kill the piece
				piece.on_death(null)
				to_remove.append(piece)
		
		for piece in to_remove:
			cursed_pieces.erase(piece)
			var pos := piece.board_position
			board.remove_piece(pos)

# =============================================================================
# CLEANUP
# =============================================================================

func _cleanup(board: BaseBoard) -> void:
	# Revert transformations if needed
	if effect_type == PieceEffect.TRANSFORM:
		for piece in affected_targets:
			if piece is BasePiece and piece.custom_data.has("original_type"):
				piece.piece_type = piece.custom_data["original_type"]
				piece.custom_data.erase("original_type")
	
	# Remove freeze modifiers
	if effect_type == PieceEffect.FREEZE:
		for piece in affected_targets:
			if piece is BasePiece:
				var freeze_mods := piece.get_modifiers_of_type("freeze")
				for mod in freeze_mods:
					piece.remove_modifier(mod)
	
	# Clear curses
	if effect_type == PieceEffect.CURSE:
		for piece in cursed_pieces:
			if piece.custom_data.has("cursed"):
				piece.custom_data.erase("cursed")
		cursed_pieces.clear()
	
	super._cleanup(board)


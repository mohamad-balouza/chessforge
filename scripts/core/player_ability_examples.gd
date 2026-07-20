## Example player abilities for Custom Chess

# =============================================================================
# TELEPORT ABILITY
# =============================================================================

class TeleportAbility extends PlayerAbility:
	func _init() -> void:
		ability_id = "teleport"
		ability_name = "Teleport"
		description = "Move one of your pieces to any empty square"
		ability_type = AbilityType.TARGETED
		target_type = TargetType.OWN_PIECE
		cooldown_type = CooldownType.TURNS
		cooldown_value = 5
		rarity = BaseEvent.Rarity.RARE
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		if not target is BasePiece:
			return false
		
		# Find destination (would need UI selection)
		# For now, just demonstrate the pattern
		return true


# =============================================================================
# TRANSFORM PAWN ABILITY
# =============================================================================

class TransformPawnAbility extends PlayerAbility:
	@export var transform_to: BasePiece.PieceType = BasePiece.PieceType.KNIGHT
	
	func _init() -> void:
		ability_id = "transform_pawn"
		ability_name = "Pawn Transformation"
		description = "Transform one of your pawns into a knight"
		ability_type = AbilityType.TARGETED
		target_type = TargetType.OWN_PIECE
		cooldown_type = CooldownType.CHARGES
		max_charges = 2
		charges_per_game = 2
		rarity = BaseEvent.Rarity.UNCOMMON
	
	
	func get_valid_targets(player_color: BasePiece.PieceColor, board: BaseBoard) -> Array:
		# Only target own pawns
		var pawns: Array = []
		for piece in board.get_pieces_by_color(player_color):
			if piece.piece_type == BasePiece.PieceType.PAWN:
				pawns.append(piece)
		return pawns
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		if not target is BasePiece:
			return false
		
		if target.piece_type != BasePiece.PieceType.PAWN:
			return false
		
		# Transform the pawn
		target.piece_type = transform_to
		return true


# =============================================================================
# FREEZE ABILITY
# =============================================================================

class FreezeAbility extends PlayerAbility:
	@export var freeze_duration: int = 2
	
	func _init() -> void:
		ability_id = "freeze"
		ability_name = "Freeze"
		description = "Freeze an enemy piece for 2 turns"
		ability_type = AbilityType.TARGETED
		target_type = TargetType.ENEMY_PIECE
		cooldown_type = CooldownType.TURNS
		cooldown_value = 4
		rarity = BaseEvent.Rarity.RARE
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		if not target is BasePiece:
			return false
		
		# Create and apply freeze modifier
		var freeze_mod := PieceModifier.new()
		freeze_mod.modifier_id = "freeze"
		freeze_mod.modifier_name = "Frozen"
		freeze_mod.base_duration = freeze_duration
		
		target.add_modifier(freeze_mod)
		target.custom_data["frozen_turns"] = freeze_duration
		
		return true


# =============================================================================
# SWAP ABILITY
# =============================================================================

class SwapAbility extends PlayerAbility:
	var first_target: BasePiece = null
	
	func _init() -> void:
		ability_id = "swap"
		ability_name = "Swap"
		description = "Swap positions of two of your pieces"
		ability_type = AbilityType.TARGETED
		target_type = TargetType.OWN_PIECE
		cooldown_type = CooldownType.TURNS
		cooldown_value = 3
		rarity = BaseEvent.Rarity.UNCOMMON
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		if not target is BasePiece:
			return false
		
		if not first_target:
			# First selection
			first_target = target
			return false  # Not complete yet
		else:
			# Second selection - do the swap
			var pos1 := first_target.board_position
			var pos2 := target.board_position
			
			board.pieces[pos1.x][pos1.y] = target
			board.pieces[pos2.x][pos2.y] = first_target
			
			first_target.board_position = pos2
			target.board_position = pos1
			
			first_target.position = board.board_to_world(pos2)
			target.position = board.board_to_world(pos1)
			
			first_target = null
			return true


# =============================================================================
# SHIELD ABILITY
# =============================================================================

class ShieldAbility extends PlayerAbility:
	@export var shield_duration: int = 3
	
	func _init() -> void:
		ability_id = "shield"
		ability_name = "Shield"
		description = "Protect one of your pieces from being captured for 3 turns"
		ability_type = AbilityType.TARGETED
		target_type = TargetType.OWN_PIECE
		cooldown_type = CooldownType.TURNS
		cooldown_value = 6
		rarity = BaseEvent.Rarity.EPIC
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		if not target is BasePiece:
			return false
		
		# Apply shield modifier
		var shield_mod := PieceModifier.new()
		shield_mod.modifier_id = "shield"
		shield_mod.modifier_name = "Shielded"
		shield_mod.base_duration = shield_duration
		
		target.add_modifier(shield_mod)
		target.custom_data["shielded"] = true
		
		return true


# =============================================================================
# REVEAL ABILITY
# =============================================================================

class RevealAbility extends PlayerAbility:
	func _init() -> void:
		ability_id = "reveal"
		ability_name = "Reveal"
		description = "Show all legal moves for enemy pieces for one turn"
		ability_type = AbilityType.INSTANT
		cooldown_type = CooldownType.TURNS
		cooldown_value = 3
		rarity = BaseEvent.Rarity.COMMON
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		# This would need UI integration to show enemy moves
		# For now, just mark it as used
		return true


# =============================================================================
# TRAP ABILITY
# =============================================================================

class TrapAbility extends PlayerAbility:
	func _init() -> void:
		ability_id = "trap"
		ability_name = "Place Trap"
		description = "Place a trap on an empty square that captures any piece that lands on it"
		ability_type = AbilityType.TARGETED
		target_type = TargetType.SQUARE
		cooldown_type = CooldownType.TURNS
		cooldown_value = 5
		rarity = BaseEvent.Rarity.RARE
	
	
	func get_valid_targets(player_color: BasePiece.PieceColor, board: BaseBoard) -> Array:
		# Only empty squares
		var squares: Array = []
		for x in range(board.columns):
			for y in range(board.rows):
				var pos := Vector2i(x, y)
				if board.is_valid_square(pos) and board.is_square_empty(pos):
					squares.append(pos)
		return squares
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		if not target is Vector2i:
			return false
		
		if not board.is_square_empty(target):
			return false
		
		# Place trap modifier on square
		var trap_mod := SquareModifier.new()
		trap_mod.modifier_id = "trap_" + str(player_color)
		trap_mod.modifier_name = "Trap"
		
		board.add_square_modifier(target, trap_mod)
		board.set_square_state(target, BaseBoard.SquareState.SPECIAL)
		
		return true


# =============================================================================
# SUMMON ABILITY
# =============================================================================

class SummonAbility extends PlayerAbility:
	@export var summon_type: BasePiece.PieceType = BasePiece.PieceType.PAWN
	
	func _init() -> void:
		ability_id = "summon"
		ability_name = "Summon Pawn"
		description = "Summon a pawn on any empty square on your first two ranks"
		ability_type = AbilityType.TARGETED
		target_type = TargetType.SQUARE
		cooldown_type = CooldownType.CHARGES
		max_charges = 2
		charges_per_game = 4
		rarity = BaseEvent.Rarity.LEGENDARY
	
	
	func get_valid_targets(player_color: BasePiece.PieceColor, board: BaseBoard) -> Array:
		var squares: Array = []
		var valid_ranks: Array
		
		if player_color == BasePiece.PieceColor.WHITE:
			valid_ranks = [board.rows - 1, board.rows - 2]
		else:
			valid_ranks = [0, 1]
		
		for x in range(board.columns):
			for y in valid_ranks:
				var pos := Vector2i(x, y)
				if board.is_valid_square(pos) and board.is_square_empty(pos):
					squares.append(pos)
		
		return squares
	
	
	func _do_execute(player_color: BasePiece.PieceColor, board: BaseBoard, target, game_mode: BaseGameMode) -> bool:
		if not target is Vector2i:
			return false
		
		# Would create and place the piece
		# This needs integration with piece factory
		return true


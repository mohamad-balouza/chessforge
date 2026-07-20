class_name BoardEvent
extends BaseEvent
## Events that affect the board and squares

# =============================================================================
# ENUMS
# =============================================================================

enum BoardEffect {
	HAZARD = 0,       ## Dangerous square that damages/destroys pieces
	TELEPORTER = 1,   ## Teleports pieces to linked square
	OBSTACLE = 2,     ## Blocks movement
	BUFF_ZONE = 3,    ## Grants buffs to pieces on square
	WIND = 4,         ## Pushes pieces in direction
	GIFT = 5,         ## Power-up on square
	SPAWN = 6,        ## Spawns pieces
	RESHAPE = 7       ## Changes board shape
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var effect_type: BoardEffect = BoardEffect.HAZARD

@export_group("Position")
@export var affected_positions: Array[Vector2i] = []
@export var random_position_count: int = 0  ## If > 0, randomly select positions

@export_group("Teleporter Settings")
@export var teleport_destination: Vector2i = Vector2i(-1, -1)
@export var teleport_pairs: Array[Vector2i] = []  ## Pairs of linked teleporters

@export_group("Wind Settings")
@export var wind_direction: Vector2i = Vector2i(1, 0)
@export var wind_strength: int = 1  ## How many squares to push

@export_group("Hazard Settings")
@export var hazard_damage: int = 1  ## Turns on hazard before death
@export var instant_death: bool = false

@export_group("Spawn Settings")
@export var spawn_piece_type: BasePiece.PieceType = BasePiece.PieceType.PAWN
@export var spawn_color: BasePiece.PieceColor = BasePiece.PieceColor.NONE  ## NONE = random

# =============================================================================
# PROPERTIES
# =============================================================================

var hazard_timers: Dictionary = {}  # piece -> turns on hazard
var modified_squares: Array[Vector2i] = []

# =============================================================================
# EXECUTION
# =============================================================================

func execute(board: BaseBoard, game_mode: BaseGameMode = null) -> bool:
	# Determine affected positions
	var positions := _get_affected_positions(board)
	
	if positions.is_empty():
		return false
	
	modified_squares = positions
	
	match effect_type:
		BoardEffect.HAZARD:
			return _execute_hazard(board, positions)
		BoardEffect.TELEPORTER:
			return _execute_teleporter(board, positions)
		BoardEffect.OBSTACLE:
			return _execute_obstacle(board, positions)
		BoardEffect.BUFF_ZONE:
			return _execute_buff_zone(board, positions)
		BoardEffect.WIND:
			return _execute_wind(board, positions)
		BoardEffect.GIFT:
			return _execute_gift(board, positions)
		BoardEffect.SPAWN:
			return _execute_spawn(board, positions)
		BoardEffect.RESHAPE:
			return _execute_reshape(board, positions)
		_:
			return false


func _get_affected_positions(board: BaseBoard) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	
	if random_position_count > 0:
		# Select random valid positions
		var all_valid: Array[Vector2i] = []
		for x in range(board.columns):
			for y in range(board.rows):
				var pos := Vector2i(x, y)
				if board.is_valid_square(pos):
					all_valid.append(pos)
		
		all_valid.shuffle()
		for i in range(min(random_position_count, all_valid.size())):
			positions.append(all_valid[i])
	else:
		positions = affected_positions.duplicate()
	
	return positions


func _execute_hazard(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	for pos in positions:
		board.set_square_state(pos, BaseBoard.SquareState.HAZARD)
		
		# Check if piece is already there
		var piece: BasePiece = board.get_piece_at(pos)
		if piece:
			if instant_death:
				piece.on_death(null)
				board.remove_piece(pos)
			else:
				hazard_timers[piece] = 0
	
	return true


func _execute_teleporter(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	for pos in positions:
		board.set_square_state(pos, BaseBoard.SquareState.SPECIAL)
		
		# Create teleporter modifier for the square
		var teleporter := SquareModifier.new()
		teleporter.modifier_id = "teleporter"
		teleporter.destination = teleport_destination if teleport_destination != Vector2i(-1, -1) else _get_paired_destination(pos)
		board.add_square_modifier(pos, teleporter)
	
	return true


func _get_paired_destination(pos: Vector2i) -> Vector2i:
	# Find the paired teleporter destination
	for i in range(0, teleport_pairs.size(), 2):
		if i + 1 < teleport_pairs.size():
			if teleport_pairs[i] == pos:
				return teleport_pairs[i + 1]
			elif teleport_pairs[i + 1] == pos:
				return teleport_pairs[i]
	
	return Vector2i(-1, -1)


func _execute_obstacle(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	for pos in positions:
		board.set_square_state(pos, BaseBoard.SquareState.BLOCKED)
		
		# Move any piece on this square
		var piece: BasePiece = board.get_piece_at(pos)
		if piece:
			var new_pos := _find_adjacent_empty(board, pos)
			if new_pos != Vector2i(-1, -1):
				board.move_piece(pos, new_pos)
	
	return true


func _execute_buff_zone(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	for pos in positions:
		board.set_square_state(pos, BaseBoard.SquareState.BUFF_ZONE)
		
		var buff := SquareModifier.new()
		buff.modifier_id = "buff_zone"
		buff.grants_buff = true
		board.add_square_modifier(pos, buff)
	
	return true


func _execute_wind(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	# Push all pieces on affected squares
	var pieces_to_move: Array = []
	
	for pos in positions:
		var piece: BasePiece = board.get_piece_at(pos)
		if piece:
			pieces_to_move.append({"piece": piece, "from": pos})
	
	# Move pieces in wind direction
	for data in pieces_to_move:
		var piece: BasePiece = data.piece
		var from_pos: Vector2i = data.from
		var to_pos := from_pos + wind_direction * wind_strength
		
		# Check if destination is valid and empty
		if board.is_valid_square(to_pos):
			var target: BasePiece = board.get_piece_at(to_pos)
			if target:
				# Push into enemy = capture, push into ally = blocked
				if target.piece_color != piece.piece_color:
					board.remove_piece(to_pos)
					target.on_death(piece)
			
			if board.is_square_empty(to_pos):
				board.move_piece(from_pos, to_pos)
	
	return true


func _execute_gift(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	for pos in positions:
		board.set_square_state(pos, BaseBoard.SquareState.SPECIAL)
		
		var gift := SquareModifier.new()
		gift.modifier_id = "gift"
		gift.grants_powerup = true
		board.add_square_modifier(pos, gift)
	
	return true


func _execute_spawn(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	for pos in positions:
		if not board.is_square_empty(pos):
			continue
		
		# Would need piece factory to create actual pieces
		# For now, mark the position for spawning
		pass
	
	return true


func _execute_reshape(board: BaseBoard, positions: Array[Vector2i]) -> bool:
	# Remove squares from the valid playing area
	for pos in positions:
		board.valid_squares[pos] = false
		
		# Move any piece on removed square
		var piece: BasePiece = board.get_piece_at(pos)
		if piece:
			var new_pos := _find_adjacent_empty(board, pos)
			if new_pos != Vector2i(-1, -1):
				board.move_piece(pos, new_pos)
			else:
				# No valid square - piece is eliminated
				board.remove_piece(pos)
				piece.on_death(null)
	
	board.queue_redraw()
	return true


func _find_adjacent_empty(board: BaseBoard, pos: Vector2i) -> Vector2i:
	var directions := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for dir in directions:
		var new_pos := pos + dir
		if board.is_valid_square(new_pos) and board.is_square_empty(new_pos):
			return new_pos
	
	return Vector2i(-1, -1)

# =============================================================================
# TURN HANDLING
# =============================================================================

func on_turn_end(board: BaseBoard, current_player: BasePiece.PieceColor) -> void:
	super.on_turn_end(board, current_player)
	
	# Handle hazard damage
	if effect_type == BoardEffect.HAZARD and not instant_death:
		var to_kill: Array = []
		
		for pos in modified_squares:
			var piece: BasePiece = board.get_piece_at(pos)
			if piece:
				if not hazard_timers.has(piece):
					hazard_timers[piece] = 0
				
				hazard_timers[piece] += 1
				
				if hazard_timers[piece] >= hazard_damage:
					to_kill.append({"piece": piece, "pos": pos})
		
		for data in to_kill:
			var piece: BasePiece = data.piece
			var pos: Vector2i = data.pos
			piece.on_death(null)
			board.remove_piece(pos)
			hazard_timers.erase(piece)

# =============================================================================
# CLEANUP
# =============================================================================

func _cleanup(board: BaseBoard) -> void:
	# Restore squares to normal state
	for pos in modified_squares:
		board.set_square_state(pos, BaseBoard.SquareState.NORMAL)
		
		# Remove any modifiers we added
		var mods := board.get_square_modifiers(pos)
		for mod in mods:
			if mod is SquareModifier:
				if mod.modifier_id in ["teleporter", "buff_zone", "gift"]:
					board.remove_square_modifier(pos, mod)
	
	# Restore blocked squares for reshape
	if effect_type == BoardEffect.RESHAPE:
		for pos in modified_squares:
			board.valid_squares[pos] = true
		board.queue_redraw()
	
	hazard_timers.clear()
	modified_squares.clear()
	
	super._cleanup(board)


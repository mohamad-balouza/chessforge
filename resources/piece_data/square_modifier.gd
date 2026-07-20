class_name SquareModifier
extends Resource
## Modifier that affects a board square

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var modifier_id: String = ""
@export var modifier_name: String = ""
@export var description: String = ""
@export var icon: Texture2D

@export_group("Teleporter")
@export var destination: Vector2i = Vector2i(-1, -1)

@export_group("Effects")
@export var grants_buff: bool = false
@export var grants_powerup: bool = false
@export var buff_modifier: Resource  # PieceModifier to apply

# =============================================================================
# METHODS
# =============================================================================

## Called when added to a square
func on_added_to_square(board: BaseBoard, position: Vector2i) -> void:
	pass


## Called when removed from a square
func on_removed_from_square(board: BaseBoard, position: Vector2i) -> void:
	pass


## Called when a piece lands on this square
func on_piece_entered(board: BaseBoard, position: Vector2i, piece: BasePiece) -> void:
	# Handle teleportation
	if destination != Vector2i(-1, -1):
		_teleport_piece(board, piece, destination)
	
	# Handle buff application
	if grants_buff and buff_modifier:
		piece.add_modifier(buff_modifier.duplicate())
	
	# Handle powerup collection
	if grants_powerup:
		_apply_powerup(piece)


## Called when a piece leaves this square
func on_piece_exited(board: BaseBoard, position: Vector2i, piece: BasePiece) -> void:
	pass


func _teleport_piece(board: BaseBoard, piece: BasePiece, dest: Vector2i) -> void:
	if not board.is_valid_square(dest):
		return
	
	var from_pos := piece.board_position
	
	# Check if destination is empty
	var target: BasePiece = board.get_piece_at(dest)
	if target:
		# Can't teleport to occupied square (or capture?)
		return
	
	# Move the piece
	board.pieces[from_pos.x][from_pos.y] = null
	board.pieces[dest.x][dest.y] = piece
	piece.board_position = dest
	piece.position = board.board_to_world(dest)


func _apply_powerup(piece: BasePiece) -> void:
	# Random powerup effect
	var powerups := ["speed", "armor", "damage", "range"]
	var chosen: String = powerups[randi() % powerups.size()]
	
	# Create and apply modifier based on powerup type
	var mod := PieceModifier.new()
	mod.modifier_id = "powerup_" + chosen
	mod.modifier_name = chosen.capitalize() + " Boost"
	mod.base_duration = 3
	
	piece.add_modifier(mod)


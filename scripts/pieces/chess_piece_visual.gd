class_name ChessPieceVisual
extends Node2D
## Visual representation of a chess piece
## Handles sprite loading and animation

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

@export var white_piece_textures: Dictionary = {}
@export var black_piece_textures: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var sprite: Sprite2D = $Sprite2D

# =============================================================================
# PROPERTIES
# =============================================================================

var piece_type: BasePiece.PieceType = BasePiece.PieceType.NONE
var piece_color: BasePiece.PieceColor = BasePiece.PieceColor.NONE

# Asset paths for the pixel art pieces
const ASSET_PATH := "res://assets/pixel chess_v1.2/16x32 pieces/"

const WHITE_TEXTURES := {
	BasePiece.PieceType.KING: ASSET_PATH + "W_King.png",
	BasePiece.PieceType.QUEEN: ASSET_PATH + "W_Queen.png",
	BasePiece.PieceType.ROOK: ASSET_PATH + "W_Rook.png",
	BasePiece.PieceType.BISHOP: ASSET_PATH + "W_Bishop.png",
	BasePiece.PieceType.KNIGHT: ASSET_PATH + "W_Knight.png",
	BasePiece.PieceType.PAWN: ASSET_PATH + "W_Pawn.png",
}

const BLACK_TEXTURES := {
	BasePiece.PieceType.KING: ASSET_PATH + "B_King.png",
	BasePiece.PieceType.QUEEN: ASSET_PATH + "B_Queen.png",
	BasePiece.PieceType.ROOK: ASSET_PATH + "B_Rook.png",
	BasePiece.PieceType.BISHOP: ASSET_PATH + "B_Bishop.png",
	BasePiece.PieceType.KNIGHT: ASSET_PATH + "B_Knight.png",
	BasePiece.PieceType.PAWN: ASSET_PATH + "B_Pawn.png",
}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		add_child(sprite)

# =============================================================================
# SETUP
# =============================================================================

func setup(type: BasePiece.PieceType, color: BasePiece.PieceColor) -> void:
	piece_type = type
	piece_color = color
	_load_texture()


func _load_texture() -> void:
	if not sprite:
		return
	
	var texture_path: String = ""
	
	if piece_color == BasePiece.PieceColor.WHITE:
		texture_path = WHITE_TEXTURES.get(piece_type, "")
	else:
		texture_path = BLACK_TEXTURES.get(piece_type, "")
	
	if texture_path and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
		# Scale to fit square (assuming 64x64 squares and 16x32 pieces)
		sprite.scale = Vector2(3.0, 3.0)  # Adjust as needed
	else:
		# Create placeholder
		_create_placeholder()


func _create_placeholder() -> void:
	# Create a simple colored rectangle as placeholder
	var image := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	var color := Color.WHITE if piece_color == BasePiece.PieceColor.WHITE else Color.BLACK
	image.fill(color)
	
	var texture := ImageTexture.create_from_image(image)
	sprite.texture = texture
	sprite.scale = Vector2(3.0, 3.0)

# =============================================================================
# ANIMATION (For future use)
# =============================================================================

func play_move_animation(from_pos: Vector2, to_pos: Vector2, duration: float = 0.2) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", to_pos, duration).set_ease(Tween.EASE_OUT)


func play_capture_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func play_spawn_animation() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


class_name PromotionDialog
extends Control
## Dialog for choosing pawn promotion piece

# =============================================================================
# SIGNALS
# =============================================================================

signal piece_selected(piece_type: BasePiece.PieceType)
signal cancelled()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var queen_button: Button = $Panel/VBoxContainer/QueenButton if has_node("Panel/VBoxContainer/QueenButton") else null
@onready var rook_button: Button = $Panel/VBoxContainer/RookButton if has_node("Panel/VBoxContainer/RookButton") else null
@onready var bishop_button: Button = $Panel/VBoxContainer/BishopButton if has_node("Panel/VBoxContainer/BishopButton") else null
@onready var knight_button: Button = $Panel/VBoxContainer/KnightButton if has_node("Panel/VBoxContainer/KnightButton") else null

# =============================================================================
# PROPERTIES
# =============================================================================

var promoting_pawn: BasePiece = null
var promotion_position: Vector2i = Vector2i(-1, -1)

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	hide()
	_connect_buttons()


func _connect_buttons() -> void:
	if queen_button:
		queen_button.pressed.connect(func(): _select_piece(BasePiece.PieceType.QUEEN))
	if rook_button:
		rook_button.pressed.connect(func(): _select_piece(BasePiece.PieceType.ROOK))
	if bishop_button:
		bishop_button.pressed.connect(func(): _select_piece(BasePiece.PieceType.BISHOP))
	if knight_button:
		knight_button.pressed.connect(func(): _select_piece(BasePiece.PieceType.KNIGHT))

# =============================================================================
# PUBLIC METHODS
# =============================================================================

func show_promotion(pawn: BasePiece, promo_pos: Vector2i) -> void:
	promoting_pawn = pawn
	promotion_position = promo_pos
	show()
	
	# Position the dialog near the promotion square
	# This would need to be adjusted based on actual UI layout


func _select_piece(piece_type: BasePiece.PieceType) -> void:
	piece_selected.emit(piece_type)
	
	# Complete the promotion in GameManager
	if promoting_pawn and GameManager:
		GameManager.complete_promotion(promoting_pawn, piece_type)
	
	hide()
	promoting_pawn = null


func _on_cancel() -> void:
	# Cannot cancel promotion - must choose a piece
	# But we can default to Queen
	_select_piece(BasePiece.PieceType.QUEEN)


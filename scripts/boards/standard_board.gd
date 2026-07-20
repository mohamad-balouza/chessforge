class_name StandardBoard
extends BaseBoard
## Standard 8x8 chess board

func _init() -> void:
	columns = 8
	rows = 8
	square_size = Vector2(64, 64)


func _ready() -> void:
	super._ready()
	_load_textures()


func _load_textures() -> void:
	# Board textures could be loaded here if using sprite-based rendering
	pass


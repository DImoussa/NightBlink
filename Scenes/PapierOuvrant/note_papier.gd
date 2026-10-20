extends Area3D

@export_multiline var contenu_texte: String = "Jour 14 : Ils ne m'ont pas cru...\nLe monstre craint la lumière directe de la torche."
@export var distance_ouverture: float = 3.0 # S'ouvre quand le joueur est à moins de 3 mètres

@onready var ui_lecture: CanvasLayer = $CanvasLayer
@onready var label_texte: Label = $CanvasLayer/TexteNote

func _ready() -> void:
	if contenu_texte != "":
		label_texte.text = contenu_texte
	ui_lecture.visible = false

func _process(_delta: float) -> void:
	var player = get_node_or_null("../Player")
	if player == null:
		return
		
	var distance = global_position.distance_to(player.global_position)
	
	
	ui_lecture.visible = (distance <= distance_ouverture)

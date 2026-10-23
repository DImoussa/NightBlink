extends Area3D
# Zone invisible sur le tableau de la fin de la map : quand le joueur le traverse,
# la vidéo d'outro se lance après un petit délai, puis on revient à l'écran d'accueil.

@export var delai := 2.0   # secondes entre la traversée du tableau et la vidéo
@export_file("*.tscn") var scene_apres := "res://Scenes/Start.tscn"

const VIDEO_OUTRO := preload("res://Video/outro.ogv")
const GENERIQUE := preload("res://Scripts/generique.gd")

var declenchee := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if declenchee or not body.is_in_group("player") or body.mort:
		return
	declenchee = true
	await get_tree().create_timer(delai).timeout
	_jouer_outro()


# Plein écran par-dessus le jeu, mis en pause le temps de la vidéo (la lampe ne peut plus tuer le joueur)
func _jouer_outro() -> void:
	var calque := CanvasLayer.new()
	calque.layer = 100
	calque.process_mode = Node.PROCESS_MODE_ALWAYS
	var fond := ColorRect.new()
	fond.color = Color.BLACK
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	calque.add_child(fond)
	var video := VideoStreamPlayer.new()
	video.stream = VIDEO_OUTRO
	video.expand = true
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	calque.add_child(video)
	add_child(calque)
	get_tree().paused = true
	video.play()
	await video.finished
	var generique := GENERIQUE.new()
	add_child(generique)
	await generique.fini
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_apres)

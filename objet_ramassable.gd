extends Node3D
# Objet à ramasser en le visant avec l'aimant (touche E, voir player.gd) : il part dans l'inventaire du joueur

@export var nom_objet := "cle"
@export var son_ramassage: AudioStream = preload("res://Son/Clé.wav")
@export var volume_ramassage := 6.0   # dB : Clé.wav est enregistré bas, sinon le bruit de fond le couvre

const Sons := preload("res://Scripts/sons.gd")

var centre: Vector3   # centre du modèle dans le monde (pour viser à côté, voir player.gd)


func _ready() -> void:
	add_to_group("ramassable")
	# Le modèle n'a pas de collision : on ajoute une boîte autour pour que le rayon de l'aimant le touche
	var boite := AABB()
	var premier := true
	for mi in find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		boite = b if premier else boite.merge(b)
		premier = false
	var corps := StaticBody3D.new()
	corps.top_level = true   # pas d'échelle non uniforme héritée du modèle
	var forme := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = boite.size.max(Vector3.ONE * 0.08) + Vector3.ONE * 0.04
	forme.shape = cube
	corps.add_child(forme)
	add_child(corps)
	centre = boite.get_center()
	corps.global_transform = Transform3D(Basis(), centre)


func ramasser(joueur: Node) -> void:
	joueur.ajouter_objet(nom_objet)
	if son_ramassage:
		Sons.jouer(get_tree(), son_ramassage, volume_ramassage)   # continue après la disparition de l'objet
	queue_free()

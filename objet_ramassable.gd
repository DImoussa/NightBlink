extends Node3D
# Objet à ramasser en le visant avec l'aimant (touche E, voir player.gd) : il part dans l'inventaire du joueur

@export var nom_objet := "cle"
@export var son_ramassage: AudioStream = preload("res://Son/Clé.wav")
@export var volume_ramassage := 6.0   # dB : Clé.wav est enregistré bas, sinon le bruit de fond le couvre
@export var son_reperage: AudioStream   # son 3D en boucle pour retrouver l'objet, lancé par une zone (zone_declencheur.gd)
@export var portee_reperage := 20.0     # mètres

const Sons := preload("res://Scripts/sons.gd")
const Surbrillance := preload("res://Scripts/surbrillance.gd")

var centre: Vector3   # centre du modèle dans le monde (pour viser à côté, voir player.gd)


func _ready() -> void:
	add_to_group("ramassable")
	Surbrillance.appliquer(self)
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


# Le son part du centre de l'objet et s'arrête quand on le ramasse (il disparaît avec lui)
func commencer_reperage() -> void:
	if not son_reperage or has_node("SonReperage"):
		return
	var lecteur: AudioStreamPlayer3D = Sons.boucle(self, son_reperage, true)
	lecteur.name = "SonReperage"
	lecteur.top_level = true   # pas d'échelle héritée du modèle
	lecteur.global_position = centre
	lecteur.max_distance = portee_reperage
	lecteur.unit_size = portee_reperage / 3.0
	lecteur.play()


func ramasser(joueur: Node) -> void:
	joueur.ajouter_objet(nom_objet)
	if son_ramassage:
		Sons.jouer(get_tree(), son_ramassage, volume_ramassage)   # continue après la disparition de l'objet
	queue_free()

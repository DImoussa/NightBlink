extends Area3D
# Zone invisible autour d'une échelle : tant que le joueur est dedans, avancer = monter, reculer = descendre
# (l'échelle est trop raide pour une rampe comme Mur/Mur2 : un CharacterBody3D ne monte pas plus de 45°)

@export var carte: NodePath = ^"../scene3jsp/Scene_Cycles_Baked"   # l'échelle fait partie de ce maillage
@export var zone_surbrillance := Vector3(1.0, 2.6, 0.85)          # demi-taille de la boîte où chercher l'échelle

const Surbrillance := preload("res://Scripts/surbrillance.gd")


func _ready() -> void:
	body_entered.connect(func(body): if body.has_method("entrer_echelle"): body.entrer_echelle(true))
	body_exited.connect(func(body): if body.has_method("entrer_echelle"): body.entrer_echelle(false))
	# Aura comme sur les portes : les joueurs ne voyaient pas l'échelle
	var maillage := get_node_or_null(carte) as MeshInstance3D
	if maillage:
		Surbrillance.extraire_de_la_carte(self, maillage, zone_surbrillance)

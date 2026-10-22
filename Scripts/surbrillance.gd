extends RefCounted
## Aura jaune sur les objets avec lesquels on peut interagir (clé, portes métalliques, chariot).
## À utiliser avec : const Surbrillance := preload("res://Scripts/surbrillance.gd")

const MATERIAU := preload("res://Scripts/surbrillance.tres")


static func appliquer(objet: Node) -> void:
	for maillage in objet.find_children("*", "GeometryInstance3D", true, false):
		maillage.material_overlay = MATERIAU


# Plus d'interaction possible (porte ouverte...) : l'aura s'en va
static func retirer(objet: Node) -> void:
	for maillage in objet.find_children("*", "GeometryInstance3D", true, false):
		if maillage.material_overlay == MATERIAU:
			maillage.material_overlay = null

extends RefCounted
## Aura jaune sur les objets avec lesquels on peut interagir (clé, portes métalliques, chariot).
## À utiliser avec : const Surbrillance := preload("res://Scripts/surbrillance.gd")

const MATERIAU := preload("res://Scripts/surbrillance.tres")                  
const MATERIAU_CONTOUR := preload("res://Scripts/surbrillance_contour.tres")  


static func appliquer(objet: Node, contour_seul := false) -> void:
	for maillage in objet.find_children("*", "GeometryInstance3D", true, false):
		maillage.material_overlay = MATERIAU_CONTOUR if contour_seul else MATERIAU


static func retirer(objet: Node) -> void:
	for maillage in objet.find_children("*", "GeometryInstance3D", true, false):
		if maillage.material_overlay in [MATERIAU, MATERIAU_CONTOUR]:
			maillage.material_overlay = null

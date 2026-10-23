extends RefCounted
## Aura jaune sur les objets avec lesquels on peut interagir (clé, portes métalliques, chariot).
## À utiliser avec : const Surbrillance := preload("res://Scripts/surbrillance.gd")

const MATERIAU := preload("res://Scripts/surbrillance.tres")
const MATERIAU_CONTOUR := preload("res://Scripts/surbrillance_contour.tres")
const MATERIAU_LEGER := preload("res://Scripts/surbrillance_leger.tres")


static func appliquer(objet: Node, materiau: Material = MATERIAU) -> void:
	for maillage in objet.find_children("*", "GeometryInstance3D", true, false):
		maillage.material_overlay = materiau


static func retirer(objet: Node) -> void:
	for maillage in objet.find_children("*", "GeometryInstance3D", true, false):
		if maillage.material_overlay in [MATERIAU, MATERIAU_CONTOUR, MATERIAU_LEGER]:
			maillage.material_overlay = null


# Objet fondu dans le maillage de la carte (échelle, serrure...) : on recopie les morceaux du maillage
# entièrement contenus dans la boîte autour de la zone (les murs et le sol qui en dépassent sont ignorés)
# et on les affiche avec l'aura. Renvoie null si rien n'est trouvé.
static func extraire_de_la_carte(zone: Node3D, carte: MeshInstance3D, demi_taille: Vector3, materiau: Material = MATERIAU_LEGER) -> MeshInstance3D:
	var vers_zone := zone.global_transform.affine_inverse() * carte.global_transform
	var parents := {}         # morceaux reliés : sommets à la même position (au mm près)
	var debordent := []       # un sommet de ces triangles est hors de la boîte
	var triangles := []       # [position, normale] x 3, triangles entièrement dans la boîte
	for s in carte.mesh.get_surface_count():
		var tableaux := carte.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = tableaux[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = tableaux[Mesh.ARRAY_INDEX] if tableaux[Mesh.ARRAY_INDEX] else PackedInt32Array(range(v.size()))
		for t in range(0, idx.size(), 3):
			var dedans := 0
			for k in 3:
				var p := (vers_zone * v[idx[t + k]]).abs()
				if p.x <= demi_taille.x and p.y <= demi_taille.y and p.z <= demi_taille.z:
					dedans += 1
			if dedans == 0:
				continue
			var cle := Vector3i((v[idx[t]] * 1000.0).round())
			for k in [1, 2]:
				_relier(parents, cle, Vector3i((v[idx[t + k]] * 1000.0).round()))
			if dedans < 3:
				debordent.append(cle)
			else:
				triangles.append([cle, v[idx[t]], n[idx[t]], v[idx[t + 1]], n[idx[t + 1]], v[idx[t + 2]], n[idx[t + 2]]])
	var exclus := {}
	for cle in debordent:
		exclus[_racine(parents, cle)] = true
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()
	for tri in triangles:
		if exclus.has(_racine(parents, tri[0])):
			continue
		for k in 3:
			sommets.append(tri[1 + k * 2])
			normales.append(tri[2 + k * 2])
	if sommets.is_empty():
		return null
	var tableaux := []
	tableaux.resize(Mesh.ARRAY_MAX)
	tableaux[Mesh.ARRAY_VERTEX] = sommets
	tableaux[Mesh.ARRAY_NORMAL] = normales
	var maillage := ArrayMesh.new()
	maillage.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
	var aura := MeshInstance3D.new()
	aura.mesh = maillage
	aura.material_override = materiau
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carte.add_child(aura)   # mêmes coordonnées que la carte : l'aura recouvre exactement l'objet
	return aura


static func _racine(parents: Dictionary, cle: Vector3i) -> Vector3i:
	if not parents.has(cle):
		parents[cle] = cle
	while parents[cle] != cle:
		parents[cle] = parents[parents[cle]]
		cle = parents[cle]
	return cle


static func _relier(parents: Dictionary, a: Vector3i, b: Vector3i) -> void:
	parents[_racine(parents, b)] = _racine(parents, a)

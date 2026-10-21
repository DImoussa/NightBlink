# tests/test_mecaniques.gd — vérifie dans scene_finalversion.tscn : portes métalliques (touche E à 0,4 m de l'aimant),
# piles (placement, recharge au max, ramassage au contact), durée de la lampe et portée réduite de la note. Lancer :
#   "<Godot>_console.exe" --headless --path <projet> -s res://tests/test_mecaniques.gd
# Attendu : que des lignes "[OK]", puis "TOUS LES TESTS PASSENT", code de sortie 0.
extends SceneTree

var _ok := true
var _scene: Node
var _joueur: CharacterBody3D
var _lampe: Node


func _initialize() -> void:
	_lancer()


func verifier(condition: bool, message: String) -> void:
	print("[OK] " if condition else "[ECHEC] ", message)
	_ok = _ok and condition


func attendre_physique(n: int) -> void:
	for i in n:
		await physics_frame


func placer_joueur(pos: Vector3, angle_y := 0.0) -> void:
	_joueur.global_position = pos
	_joueur.rotation = Vector3(0, angle_y, 0)
	_joueur.get_node("Head").rotation = Vector3.ZERO
	_joueur.velocity = Vector3.ZERO


func appuyer_e() -> void:
	var ev := InputEventAction.new()
	ev.action = "magnet"
	ev.pressed = true
	_joueur._unhandled_input(ev)


func _lancer() -> void:
	_scene = load("res://scene_finalversion.tscn").instantiate()
	root.add_child(_scene)
	await attendre_physique(10)
	_joueur = _scene.get_node("Player")
	_lampe = get_first_node_in_group("lantern")

	# --- Lampe : se vide en 20 s
	verifier(is_equal_approx(_lampe.max_energy / _lampe.drain_rate, 20.0), "lampe vide en %.1f s" % (_lampe.max_energy / _lampe.drain_rate))

	# --- Piles : nombre, autonomie totale et placement (sol dessous, pas dans un mur)
	var piles := _scene.find_children("PileRechargeable*", "", false)
	var autonomie: float = (piles.size() + 1) * _lampe.max_energy / _lampe.drain_rate
	verifier(autonomie >= 180.0, "%d piles -> autonomie max %d s (~3 min)" % [piles.size(), autonomie])
	var espace := _joueur.get_world_3d().direct_space_state
	for pile in piles:
		var centre: Vector3 = pile.get_node("CollisionShape3D").global_position
		var rayon := PhysicsRayQueryParameters3D.create(centre, centre + Vector3.DOWN * 3.0)
		var sol := espace.intersect_ray(rayon)
		var hauteur: float = centre.y - sol.position.y if sol else -1.0
		var forme := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.3
		forme.shape = sphere
		forme.transform = Transform3D(Basis(), centre)
		var dans_mur := espace.intersect_shape(forme).filter(func(r): return r.collider != _joueur)
		for r in dans_mur: print("   touche : ", r.collider.get_path())
		verifier(hauteur > 0.2 and hauteur < 1.0 and dans_mur.is_empty(),
			"%s en %s : %.2f m au-dessus du sol, libre = %s" % [pile.name, centre.snapped(Vector3.ONE * 0.01), hauteur, dans_mur.is_empty()])

	# --- Ramassage au contact + recharge au max
	var pile: Area3D = piles[0]
	var pos_pile := pile.global_position
	_lampe.energy = 3.0
	placer_joueur(pos_pile + Vector3(0, 1.2, 0.3))
	await attendre_physique(10)
	verifier(_lampe.energy > _lampe.max_energy - 1.0, "pile touchée -> lampe rechargée au max (%.1f / %.1f)" % [_lampe.energy, _lampe.max_energy])
	await create_timer(0.5).timeout
	verifier(not is_instance_valid(pile), "pile ramassée (supprimée de la scène)")

	# --- Note : portée réduite (0,8 m -> 0,45 m)
	var note: Area3D = _scene.get_node("Node3D2/NotePapier")
	var pos_note := note.global_position
	placer_joueur(Vector3(pos_note.x, 1.4, pos_note.z - 1.2))   # 1,2 m : s'ouvrait avec l'ancienne portée (1,3 m)
	await attendre_physique(10)
	verifier(not note._ouverte, "note fermée à 1,2 m (portée réduite)")
	placer_joueur(Vector3(pos_note.x, 1.4, pos_note.z - 0.8))
	await attendre_physique(10)
	verifier(note._ouverte, "note ouverte à 0,8 m")
	var texte: Label = note.get_node("CanvasLayer/Feuille/TexteNote")
	verifier(texte.text != "" and texte.size.x > 100 and texte.size.y > 100,
		"texte de la note visible (%d x %d px)" % [texte.size.x, texte.size.y])
	placer_joueur(Vector3(pos_note.x, 1.4, pos_note.z - 2.5))
	await attendre_physique(10)

	# --- Portes métalliques : E trop loin = rien, E à moins de 0,4 m de l'aimant = ouverture
	for nom in ["portemetalentree", "portemetalsortie"]:
		var porte: Node3D = _scene.get_node(nom)
		var battant: MeshInstance3D = porte.get_child(0)
		var b := battant.global_basis
		# Face de la porte côté joueur, joueur tourné vers elle (la caméra regarde -Z)
		var normale := b.z.normalized()
		var face := battant.global_position + normale * 0.13
		var angle := atan2(normale.x, normale.z)
		var avance_aimant: float = -_joueur.aimant.position.z
		for essai in [[0.8, false], [0.3, true]]:
			var dist_cam: float = essai[0] + avance_aimant
			var cam := face + normale * dist_cam
			placer_joueur(Vector3(cam.x, battant.global_position.y - 0.25, cam.z), angle)
			await attendre_physique(2)
			var dist_reelle: float = _joueur.camera.global_position.distance_to(face) - avance_aimant
			appuyer_e()
			verifier(porte.ouverte == essai[1], "%s : E à %.2f m de l'aimant -> ouverte = %s" % [nom, dist_reelle, porte.ouverte])
		await create_timer(1.5).timeout
		# Une fois ouverte, le passage est libre au milieu de l'encadrement
		var milieu := PhysicsRayQueryParameters3D.create(face + normale * 0.6, face - normale * 1.0)
		milieu.exclude = [_joueur.get_rid()]
		var obstacle := espace.intersect_ray(milieu)
		verifier(obstacle.is_empty() or not battant.is_ancestor_of(obstacle.collider),
			"%s : battant pivoté (%.0f°), passage libre" % [nom, rad_to_deg(battant.global_basis.z.signed_angle_to(b.z, Vector3.UP))])

	# --- Imprimante : retirée de la map, posée au sol, attrapée avec E maintenu, suit en reculant sans traverser les murs
	var imp: CharacterBody3D = _scene.get_node("Imprimante")
	var pos_imp := imp.global_position
	var vers_bas := PhysicsRayQueryParameters3D.create(pos_imp + Vector3(0, 1.8, 0), pos_imp + Vector3(0, -1, 0))
	vers_bas.exclude = [imp.get_rid()]
	var sol_imp := espace.intersect_ray(vers_bas)
	verifier(sol_imp and absf(sol_imp.position.y - 5.98) < 0.05, "imprimante retirée de la map (sol trouvé dessous à y=%.2f)" % (sol_imp.position.y if sol_imp else -1.0))
	verifier(imp.is_on_floor() and absf(imp.global_position.y - pos_imp.y) < 0.05, "imprimante posée au sol (y=%.2f)" % imp.global_position.y)
	# Le joueur arrive par la salle à l'est (+x) et vise le haut du chariot
	placer_joueur(Vector3(pos_imp.x + 1.15, 6.98, pos_imp.z), PI / 2)
	await attendre_physique(3)
	var vise: Vector3 = Vector3(pos_imp.x + 0.45, 7.25, pos_imp.z) - _joueur.camera.global_position
	_joueur.get_node("Head").rotation.x = atan2(vise.y, Vector2(vise.x, vise.z).length())
	appuyer_e()
	verifier(_joueur.objet_tenu == imp, "E maintenu sur l'imprimante -> attrapée")
	var penetration_max := 0.0
	var forme_imp := PhysicsShapeQueryParameters3D.new()
	forme_imp.shape = imp.get_node("CollisionShape3D").shape
	forme_imp.exclude = [imp.get_rid(), _joueur.get_rid()]
	# Recule 1,2 s puis tourne de 120° : l'imprimante suit et doit buter contre les murs
	Input.action_press("move_down")
	for i in 72:
		if i >= 30:
			_joueur.tourner_camera(deg_to_rad(120.0) / 42.0, 0)
		await physics_frame
		forme_imp.transform = imp.global_transform.translated(Vector3.UP * 0.05)
		if not espace.intersect_shape(forme_imp, 1).is_empty():
			penetration_max += 1
	Input.action_release("move_down")
	var deplacement := Vector2(imp.global_position.x - pos_imp.x, imp.global_position.z - pos_imp.z).length()
	verifier(deplacement > 0.8, "imprimante tirée en reculant (déplacée de %.2f m)" % deplacement)
	verifier(penetration_max == 0, "imprimante jamais dans un mur pendant le transport (%d images en collision)" % penetration_max)
	var sous_imp := PhysicsRayQueryParameters3D.create(imp.global_position + Vector3(0, 1.8, 0), imp.global_position + Vector3(0, -1, 0))
	sous_imp.exclude = [imp.get_rid()]
	var sol_fin := espace.intersect_ray(sous_imp)
	print("   imprimante en ", imp.global_position, " sol dessous ", sol_fin.position if sol_fin else null, " sur le sol ", imp.is_on_floor(), " ; joueur en ", _joueur.global_position)
	verifier(absf(imp.global_position.y - (sol_fin.position.y if sol_fin else 0.0)) < 0.1, "imprimante reste au sol (y=%.2f)" % imp.global_position.y)
	var relache := InputEventAction.new()
	relache.action = "magnet"
	relache.pressed = false
	_joueur._unhandled_input(relache)
	var pos_lachee := imp.global_position
	await attendre_physique(20)
	print("   apres lacher : tenu ", _joueur.objet_tenu, " deplacement ", imp.global_position.distance_to(pos_lachee), " vitesse ", imp.velocity)
	verifier(_joueur.objet_tenu == null and imp.global_position.distance_to(pos_lachee) < 0.3, "E relâché -> imprimante lâchée et immobile")

	print("TOUS LES TESTS PASSENT" if _ok else "DES TESTS ECHOUENT")
	quit(0 if _ok else 1)

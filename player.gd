extends CharacterBody3D

@export var speed := 4.0
@export var mouse_sensitivity := 0.002
@export var portee_aimant := 30.0   # distance max pour attraper un mur
@export var portee_porte := 0.4     # distance max entre l'aimant et une porte métallique pour l'ouvrir
@export var portee_objet := 0.6     # distance max entre l'aimant et un objet à attraper (imprimante...)
@export var portee_ramassage := 1.0 # distance max entre l'aimant et un objet à ramasser (clé...)
@export var tolerance_visee := 0.4  # on ramasse aussi si on vise à moins de ça de l'objet (ex. le lavabo autour)
@export var vitesse_echelle := 2.5  # m/s pour monter/descendre une échelle

signal inventaire_change

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var aimant: Node3D = $Head/Camera3D/Aimant

var inventaire: Array[String] = ["lampe", "aimant"]   # affiché par la barre du bas (inventaire_hud.gd)
var sur_echelle := 0                 # nombre de zones d'échelle où se trouve le joueur (echelle.gd)
var mur_tenu: Node3D = null          # le mur attrapé par l'aimant
var objet_tenu: Node3D = null        # l'objet tenu tant que E reste appuyé (objet_aimante.gd)
var decalage_mur: Transform3D        # position du mur par rapport à la caméra
var arduino: Node = null             # reste vide si la manette n'est pas activée


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# On cherche l'autoload Arduino. S'il est désactivé, on joue au clavier.
	# (Le bouton de la carte déclenche directement l'action "magnet", voir arduino.gd)
	arduino = get_node_or_null("/root/Arduino")
	add_to_group("player")   # pour que le gyroscope (arduino.gd) retrouve le joueur
	# La lampe tenue en main ne doit pas faire d'ombre devant sa propre lumière
	for maillage in $Head/Camera3D/Lampe.find_children("*", "GeometryInstance3D", true, false):
		maillage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _unhandled_input(event):
	# Regarder avec la souris
	if event is InputEventMouseMotion:
		tourner_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)

	# Action "magnet" (touche E) : même effet que le bouton de la carte
	if event.is_action_pressed("magnet"):
		basculer_aimant()
	# Relâcher E lâche l'objet tenu
	if event.is_action_released("magnet") and objet_tenu:
		lacher_objet()

	# Échap pour libérer la souris
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func tourner_camera(gauche_droite: float, haut_bas: float):
	# Utilisé par la souris et par le gyroscope de la manette (angles en radians)
	rotate_y(gauche_droite)
	head.rotate_x(haut_bas)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func allumer_led(allumee: bool):
	# N'envoie l'ordre que si la manette est là
	if arduino:
		arduino.led(allumee)


func basculer_aimant():
	if mur_tenu:
		# Deuxième appui : on relâche le mur là où il est
		mur_tenu = null
		allumer_led(false)
		return
	# Premier appui : on attrape le mur visé au centre de l'écran
	var origine := camera.global_position
	var fin := origine - camera.global_basis.z * portee_aimant
	var requete := PhysicsRayQueryParameters3D.create(origine, fin)
	requete.exclude = [get_rid()]
	var resultat := get_world_3d().direct_space_state.intersect_ray(requete)
	# Porte métallique visée : on l'ouvre si l'aimant est assez près
	var collider: Object = resultat.collider if resultat else null
	# L'aimant dépasse devant la caméra : on retire ce bout pour avoir la distance aimant -> cible
	var distance_aimant: float = origine.distance_to(resultat.position) + aimant.position.z if resultat else INF
	var porte := trouver_dans_groupe(collider, "porte_metal")
	if porte:
		if distance_aimant <= portee_porte:
			porte.ouvrir(global_position)
		return
	# Objet métallique visé : on le tient tant que E reste appuyé
	var objet := trouver_dans_groupe(collider, "attrapable")
	if objet:
		if distance_aimant <= portee_objet:
			objet_tenu = objet
			objet.attraper(self)
			allumer_led(true)
		return
	# Objet à ramasser visé (clé...) : il part dans l'inventaire
	var ramassable := trouver_dans_groupe(collider, "ramassable")
	# On vise juste à côté (ex. le bord du lavabo) : on prend l'objet à ramasser le plus proche du point visé
	if not ramassable and resultat:
		for objet_proche in get_tree().get_nodes_in_group("ramassable"):
			if objet_proche.centre.distance_to(resultat.position) <= tolerance_visee:
				ramassable = objet_proche
	if ramassable:
		if distance_aimant <= portee_ramassage:
			ramassable.ramasser(self)
		return
	if resultat and resultat.collider is Node3D and str(resultat.collider.name).begins_with("Mur"):
		mur_tenu = resultat.collider
		decalage_mur = camera.global_transform.affine_inverse() * mur_tenu.global_transform
		allumer_led(true)   # LED allumée = aimant actif


func lacher_objet():
	if objet_tenu:
		objet_tenu.lacher()
		objet_tenu = null
		allumer_led(false)


func ajouter_objet(nom: String):
	inventaire.append(nom)
	inventaire_change.emit()


func retirer_objet(nom: String) -> bool:
	if not nom in inventaire:
		return false
	inventaire.erase(nom)
	inventaire_change.emit()
	return true


func entrer_echelle(dedans: bool):
	sur_echelle += 1 if dedans else -1


func trouver_dans_groupe(objet: Object, groupe: String) -> Node:
	# La collision touchée peut être un enfant (ex. modèle de la porte) : on remonte jusqu'au nœud du groupe
	var noeud := objet as Node
	while noeud:
		if noeud.is_in_group(groupe):
			return noeud
		noeud = noeud.get_parent()
	return null


func _physics_process(delta):
	# Déplacement ZQSD dans la direction du regard
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Sur une échelle : avancer fait monter, reculer fait descendre. Sinon gravité.
	if sur_echelle > 0:
		velocity.y = -input_dir.y * vitesse_echelle
	elif not is_on_floor():
		velocity += get_gravity() * delta
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()

	# Le mur attrapé suit la caméra (donc la souris)
	if mur_tenu:
		mur_tenu.global_transform = camera.global_transform * decalage_mur

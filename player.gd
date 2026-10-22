extends CharacterBody3D

@export var speed := 4.0
@export var mouse_sensitivity := 0.002
@export var portee_aimant := 30.0   # distance max pour attraper un mur
@export var portee_porte := 10     # distance max entre l'aimant et une porte métallique pour l'ouvrir
@export var portee_objet := 10     # distance max entre l'aimant et un objet à attraper (imprimante...)
@export var portee_ramassage := 1.0 # distance max entre l'aimant et un objet à ramasser (clé...)
@export var tolerance_visee := 0.4  # on ramasse aussi si on vise à moins de ça de l'objet (ex. le lavabo autour)
@export var vitesse_echelle := 2.5  # m/s pour monter/descendre une échelle
@onready var lampe: SpotLight3D = get_tree().get_first_node_in_group("lantern")


signal inventaire_change

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var aimant: Node3D = $Head/Camera3D/Aimant
@onready var animation_player: AnimationPlayer = $Head/AnimationPlayer   # animation "marche" (balancement de la tête)

const ECRAN_MORT := preload("res://Scenes/EcranMort.tscn")
const Sons := preload("res://Scripts/sons.gd")
const SON_AIMANT_ON := preload("res://Son/Aimant_ON.wav")
const SON_AIMANT_OFF := preload("res://Son/Aimant_OFF.wav")
const SON_CHUTE := preload("res://Son/Tomber.wav")
@export var vitesse_chute_bruit := 6.0   # m/s : au-dessus, on entend le bruit de chute à l'atterrissage (~1,8 m de chute)

var inventaire: Array[String] = ["lampe", "aimant"]   # affiché par la barre du bas (inventaire_hud.gd)
var sur_echelle := 0                 # nombre de zones d'échelle où se trouve le joueur (echelle.gd)
var mur_tenu: Node3D = null          # le mur attrapé par l'aimant
var objet_tenu: Node3D = null        # l'objet tenu tant que E reste appuyé (objet_aimante.gd)
var decalage_mur: Transform3D        # position du mur par rapport à la caméra
var arduino: Node = null             # reste vide si la manette n'est pas activée
var mort := false                    # vrai pendant l'écran de mort : le joueur ne bouge plus
var aimant_actif := false            # pour les sons de l'aimant (activation, bourdonnement, arrêt)
var son_marche: AudioStreamPlayer
var son_echelle: AudioStreamPlayer
var son_aimant: AudioStreamPlayer

func _ready():
	# Garde la scène en mémoire : "Rejouer" la recrée sans relire le fichier (beaucoup plus rapide)
	if owner and owner.scene_file_path != "":
		get_tree().set_meta("scene_jeu_en_memoire", load(owner.scene_file_path))
	lampe.energie_vide.connect(mourir)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# On cherche l'autoload Arduino. S'il est désactivé, on joue au clavier.
	# (Le bouton de la carte déclenche directement l'action "magnet", voir arduino.gd)
	arduino = get_node_or_null("/root/Arduino")
	add_to_group("player")   # pour que le gyroscope (arduino.gd) retrouve le joueur
	# La lampe tenue en main ne doit pas faire d'ombre devant sa propre lumière
	for maillage in $Head/Camera3D/Lampe.find_children("*", "GeometryInstance3D", true, false):
		maillage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Les sons 3D (piles, néons, bruits aléatoires) s'entendent depuis la tête du joueur
	var oreille := AudioListener3D.new()
	camera.add_child(oreille)
	oreille.make_current()
	son_marche = Sons.boucle(self, preload("res://Son/Walking.wav"))
	son_echelle = Sons.boucle(self, preload("res://Son/Grincement_bois_V1.wav"))
	son_aimant = Sons.boucle(self, preload("res://Son/Aimant_continu.wav"))


func mourir():
	if mort:
		return
	mort = true
	# On lâche tout ce qu'on tenait
	mur_tenu = null
	lacher_objet()
	allumer_led(false)
	velocity = Vector3.ZERO
	animation_player.stop()
	son_marche.stop()
	son_echelle.stop()
	# Écran "Tu es mort !" : avancer = rejouer, aimant = retour à l'accueil (voir ecran_mort.gd)
	var ecran := ECRAN_MORT.instantiate()
	ecran.rejouer.connect(respawn)
	add_child(ecran)


func respawn():
	# On recharge toute la scène : le joueur revient au spawn avec la lampe pleine,
	# et les portes, le chariot, la clé, les piles... reprennent leur place de départ
	get_tree().reload_current_scene()


func _unhandled_input(event):
	if mort:
		return
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
	_son_aimant(allumee)
	# N'envoie l'ordre que si la manette est là
	if arduino:
		arduino.led(allumee)


# LED allumée = aimant actif : son d'activation, bourdonnement tant qu'il tient quelque chose, son d'arrêt
func _son_aimant(actif: bool):
	if actif == aimant_actif:
		return
	aimant_actif = actif
	Sons.jouer(get_tree(), SON_AIMANT_ON if actif else SON_AIMANT_OFF)
	Sons.garder(son_aimant, actif)


# La porte ne s'attrape pas : l'aimant sonne seulement le temps qu'elle s'ouvre
func _son_aimant_porte(porte: Node):
	_son_aimant(true)
	await porte.get_node("AnimationPlayer").animation_finished
	if not mur_tenu and not objet_tenu:
		_son_aimant(false)


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
		if distance_aimant <= portee_porte and not porte.ouverte:
			porte.ouvrir(global_position)
			_son_aimant_porte(porte)
		return
	# Objet métallique visé : on le tient tant que E reste appuyé
	var objet := trouver_dans_groupe(collider, "attrapable")
	if objet:
		# Le chariot reste trop lourd tant que toutes les piles n'ont pas été ramassées
		if distance_aimant <= portee_objet and objet.peut_etre_attrape():
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
	if mort:
		return
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

	var vitesse_chute := -velocity.y
	move_and_slide()

	# Grosse chute (ex. on lâche l'échelle) : bruit de chute à l'atterrissage
	if is_on_floor() and vitesse_chute > vitesse_chute_bruit:
		Sons.jouer(get_tree(), SON_CHUTE)

	# Bruits de pas au sol, grincement du bois quand on monte ou descend l'échelle
	var marche := is_on_floor() and sur_echelle == 0 and input_dir != Vector2.ZERO
	Sons.garder(son_marche, marche)
	Sons.garder(son_echelle, sur_echelle > 0 and absf(velocity.y) > 0.1)

	# Balancement de la tête quand on marche au sol (animation "marche" de player.tscn)
	if marche:
		if animation_player.current_animation != "marche":
			animation_player.play("marche")
	else:
		if animation_player.current_animation == "marche":
			animation_player.stop()
		# La caméra revient doucement à sa place pour ne pas rester penchée
		camera.position = camera.position.lerp(Vector3.ZERO, delta * 10.0)

	# Le mur attrapé suit la caméra (donc la souris)
	if mur_tenu:
		mur_tenu.global_transform = camera.global_transform * decalage_mur

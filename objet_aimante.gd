extends CharacterBody3D
# Objet métallique (ex. chariot-imprimante) : tant que le joueur maintient E en le visant, il suit la caméra
# au sol, à la même distance, et se cogne contre les murs (voir player.gd)

@export var vitesse_max := 5.0       # m/s, un peu plus que le joueur pour ne pas décrocher en marchant
@export var decrochage := 1.0        # l'aimant lâche si l'objet est bloqué à plus de cette distance de sa cible
@export var demande_toutes_les_piles := false   # vrai pour le chariot : l'aimant n'est assez puissant qu'avec toutes les piles
@export var son_deplacement: AudioStream        # joué en 3D en boucle tant que l'aimant tient l'objet (chariot qui roule)
@export var trajet_balayage: PackedVector3Array # positions dans le monde : si rempli, l'aimant ne tient pas l'objet,
												# il le balaye le long de ce trajet (chariot poussé sur le côté)
@export var duree_balayage := 2.5

signal balayage_fini

const Sons := preload("res://Scripts/sons.gd")
const Surbrillance := preload("res://Scripts/surbrillance.gd")

var porteur: Node3D = null           # le joueur qui tient l'objet
var son: AudioStreamPlayer3D
var _distance := 0.0                 # distance caméra -> objet au moment de la prise (à plat)
var _decalage_angle := 0.0           # rotation de l'objet par rapport au joueur
var en_balayage := false
var _points: Array[Vector3] = []     # départ + trajet_balayage, à la hauteur de l'objet


func _ready() -> void:
	add_to_group("attrapable")
	Surbrillance.appliquer(self, Surbrillance.MATERIAU_CONTOUR)
	if son_deplacement:
		son = Sons.boucle(self, son_deplacement, true)


# Faux tant qu'il reste des piles à ramasser dans la scène (si demande_toutes_les_piles)
func peut_etre_attrape() -> bool:
	return not demande_toutes_les_piles or get_tree().get_nodes_in_group("pile").is_empty()


# Une seule fois : l'objet glisse le long du trajet puis ne s'attrape plus
func balayer() -> void:
	en_balayage = true
	remove_from_group("attrapable")
	Surbrillance.retirer(self)
	_points = [global_position]
	for point in trajet_balayage:
		_points.append(Vector3(point.x, global_position.y, point.z))
	if son:
		son.play()
	var anim := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	anim.tween_method(_placer_sur_trajet, 0.0, 1.0, duree_balayage)
	await anim.finished
	if son:
		son.stop()
	en_balayage = false
	balayage_fini.emit()


# avancement : 0 = départ, 1 = dernier point (vitesse régulière sur tout le trajet)
func _placer_sur_trajet(avancement: float) -> void:
	var longueur := 0.0
	for i in range(1, _points.size()):
		longueur += _points[i - 1].distance_to(_points[i])
	var reste := avancement * longueur
	for i in range(1, _points.size()):
		var segment := _points[i - 1].distance_to(_points[i])
		if reste <= segment or i == _points.size() - 1:
			global_position = _points[i - 1].lerp(_points[i], clampf(reste / segment, 0.0, 1.0))
			return
		reste -= segment


func attraper(joueur: Node3D) -> void:
	porteur = joueur
	var ecart: Vector3 = global_position - joueur.camera.global_position
	ecart.y = 0
	_distance = ecart.length()
	_decalage_angle = rotation.y - joueur.rotation.y
	# Le joueur et l'objet ne se poussent pas entre eux pendant le transport
	add_collision_exception_with(joueur)
	joueur.add_collision_exception_with(self)
	if son:
		son.play()


func lacher() -> void:
	if porteur:
		remove_collision_exception_with(porteur)
		porteur.remove_collision_exception_with(self)
	porteur = null
	if son:
		son.stop()
	velocity.x = 0   # l'objet s'arrête net quand l'aimant le lâche
	velocity.z = 0


func _physics_process(delta: float) -> void:
	if en_balayage:
		return   # c'est l'animation qui le déplace
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

	if porteur:
		# Cible : devant la caméra, à plat, à la distance de prise
		var camera: Camera3D = porteur.camera
		var avant := -camera.global_basis.z
		avant.y = 0
		var cible: Vector3 = camera.global_position + avant.normalized() * _distance
		var ecart := cible - global_position
		ecart.y = 0
		if ecart.length() > _distance + decrochage:
			porteur.lacher_objet()   # bloqué par un mur pendant que le joueur s'éloigne : l'aimant décroche
			return
		var vitesse := (ecart / delta).limit_length(vitesse_max)
		velocity.x = vitesse.x
		velocity.z = vitesse.z
		# L'objet tourne avec le joueur, sauf si ça le fait rentrer dans un mur
		var ancien := rotation.y
		rotation.y = porteur.rotation.y + _decalage_angle
		if test_move(global_transform.translated(Vector3.UP * 0.05), Vector3.ZERO):   # +5 cm : on ignore le sol
			rotation.y = ancien
	else:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)

	move_and_slide()

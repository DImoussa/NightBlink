extends CharacterBody3D
# Objet métallique (ex. chariot-imprimante) : tant que le joueur maintient E en le visant, il suit la caméra
# au sol, à la même distance, et se cogne contre les murs (voir player.gd)

@export var vitesse_max := 5.0       # m/s, un peu plus que le joueur pour ne pas décrocher en marchant
@export var decrochage := 1.0        # l'aimant lâche si l'objet est bloqué à plus de cette distance de sa cible
@export var demande_toutes_les_piles := false   # vrai pour le chariot : l'aimant n'est assez puissant qu'avec toutes les piles
@export var son_deplacement: AudioStream        # joué en 3D en boucle tant que l'aimant tient l'objet (chariot qui roule)

const Sons := preload("res://Scripts/sons.gd")

var porteur: Node3D = null           # le joueur qui tient l'objet
var son: AudioStreamPlayer3D
var _distance := 0.0                 # distance caméra -> objet au moment de la prise (à plat)
var _decalage_angle := 0.0           # rotation de l'objet par rapport au joueur


func _ready() -> void:
	add_to_group("attrapable")
	if son_deplacement:
		son = Sons.boucle(self, son_deplacement, true)


# Faux tant qu'il reste des piles à ramasser dans la scène (si demande_toutes_les_piles)
func peut_etre_attrape() -> bool:
	return not demande_toutes_les_piles or get_tree().get_nodes_in_group("pile").is_empty()


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

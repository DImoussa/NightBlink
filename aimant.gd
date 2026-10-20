extends Node3D

@export var force_attraction: float = 12.0 # Puissance de l'aimant

@onready var rayon: RayCast3D = $"../RayonAimant"
@onready var point_cible: Marker3D = $"../PointAttraction"

var objet_attire: RigidBody3D = null
var led_allumee: bool = false

func _physics_process(delta: float) -> void:
	# 1. Vérifier ce que le joueur regarde (pour allumer la LED Verte de l'Arduino)
	var cible_visee = rayon.get_collider() if rayon.is_colliding() else null
	var vise_du_metal = false
	
	if cible_visee and (cible_visee.is_in_group("metal") or cible_visee.has_method("activer_par_aimant")):
		vise_du_metal = true

	# Allume la LED Verte sur l'Arduino dès qu'un objet métallique est à portée (ou déjà agrippé)
	var etat_led = vise_du_metal or (objet_attire != null)
	if etat_led != led_allumee:
		led_allumee = etat_led
		if get_node_or_null("/root/ArduinoManager"):
			ArduinoManager.send_led(led_allumee)

	# 2. Vérifier si le bouton de l'aimant est maintenu appuyé
	# (Corrigé ici avec 'button_pressed' du script des professeurs)
	var bouton_maintenu = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_E)
	if get_node_or_null("/root/ArduinoManager"):
		bouton_maintenu = bouton_maintenu or ArduinoManager.button_pressed

	# 3. Action quand on MAINTIENT le bouton appuyé
	if bouton_maintenu:
		# Si on n'a encore rien agrippé, on regarde ce qui est visé
		if objet_attire == null and cible_visee:
			# Cas A : C'est un objet physique déplaçable (ex: machine à laver)
			if cible_visee is RigidBody3D and cible_visee.is_in_group("metal"):
				objet_attire = cible_visee
			# Cas B : C'est une porte métallique à défoncer / ouvrir
			elif cible_visee.has_method("activer_par_aimant"):
				cible_visee.activer_par_aimant(delta)
				
		# Si on tient un objet métallique (machine à laver), on l'attire vers le PointAttraction
		if objet_attire != null:
			var direction = point_cible.global_position - objet_attire.global_position
			objet_attire.linear_velocity = direction * force_attraction
			# Empêche la machine à laver de tourner dans tous les sens pendant qu'on la déplace
			objet_attire.angular_velocity = Vector3.ZERO
	else:
		# 4. Dès qu'on RELÂCHE le bouton : on lâche l'objet immédiatement (il retombe au sol)
		if objet_attire != null:
			objet_attire = null

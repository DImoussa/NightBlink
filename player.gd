extends CharacterBody3D

@export var speed := 4.0
@export var mouse_sensitivity := 0.002
@export var force_attraction := 12.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var rayon_aimant: RayCast3D = get_node_or_null("Head/Camera3D/RayonAimant")
@onready var point_attraction: Marker3D = get_node_or_null("Head/Camera3D/PointAttraction")
@onready var lanterne: SpotLight3D = get_node_or_null("Head/Camera3D/Lantern")

var objet_attire: RigidBody3D = null
var arduino_btn_state: bool = false # État du bouton de l'Arduino

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if lanterne:
		lanterne.visible = true

	# Écoute le signal universel "message_received" du script des professeurs
	var arduino_node = get_node_or_null("/root/Arduino")
	if arduino_node and arduino_node.has_signal("message_received"):
		arduino_node.message_received.connect(_sur_message_arduino)

func _sur_message_arduino(key: String, value: String) -> void:
	# Quand l'Arduino envoie "button:1" ou "button:0"
	if key == "button":
		arduino_btn_state = (value == "1")
		print("Bouton Arduino reçu -> État : ", arduino_btn_state)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(_delta):
	if not is_on_floor():
		velocity += get_gravity() * _delta

	# 1. DÉPLACEMENT : Avancer avec le bouton de l'Arduino ou Z/W
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if arduino_btn_state or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		direction = -transform.basis.z

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	# 2. LOGIQUE DE L'AIMANT
	if rayon_aimant and point_attraction:
		var cible_visee = rayon_aimant.get_collider() if rayon_aimant.is_colliding() else null
		var vise_du_metal = cible_visee is RigidBody3D and cible_visee.is_in_group("metal")

		var arduino_node = get_node_or_null("/root/Arduino")
		if arduino_node and arduino_node.has_method("send_led"):
			arduino_node.send_led(vise_du_metal or (objet_attire != null))

		if arduino_btn_state or Input.is_key_pressed(KEY_E):
			if objet_attire == null and vise_du_metal:
				objet_attire = cible_visee

			if objet_attire != null:
				var dir = point_attraction.global_position - objet_attire.global_position
				objet_attire.linear_velocity = dir * force_attraction
				objet_attire.angular_velocity = Vector3.ZERO
		else:
			if objet_attire != null:
				objet_attire = null

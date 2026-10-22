extends Area3D

@export var distance_lueur_min: float = 1.0 
@export var distance_lueur_max: float = 3.0 

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var player: Node3D = null
var lueur_active: bool = false

func _ready() -> void:
	add_to_group("pile")   # le chariot ne s'attrape qu'une fois toutes les piles ramassées (objet_aimante.gd)
	body_entered.connect(_on_body_entered)

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance = global_position.distance_to(player.global_position)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		var lanterne = get_tree().get_first_node_in_group("lantern")
		if lanterne and lanterne.has_method("recharger"):
			lanterne.recharger(lanterne.max_energy)   # recharge au max
			print("Pile ramassée en étant collé !")
			
			remove_from_group("pile")   # ramassée : elle ne compte plus tout de suite
			collision_shape.set_deferred("disabled", true)
			visible = false
			
			await get_tree().create_timer(0.3).timeout
			queue_free()

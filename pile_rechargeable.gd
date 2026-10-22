extends Area3D

@export var distance_lueur_min: float = 1.0 
@export var distance_lueur_max: float = 3.0
@export var ordre := 1   # les piles s'entendent une par une : seule la pile restante de plus petit ordre émet son son

const Sons := preload("res://Scripts/sons.gd")

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var player: Node3D = null
var lueur_active: bool = false
var son: AudioStreamPlayer3D

func _ready() -> void:
	add_to_group("pile")   # le chariot ne s'attrape qu'une fois toutes les piles ramassées (objet_aimante.gd)
	body_entered.connect(_on_body_entered)
	son = Sons.boucle(self, preload("res://Son/Batterie_continu.wav"), true)
	son.max_distance = 25.0
	maj_son.call_deferred()   # attend que toutes les piles soient dans le groupe


# Appelé au départ et à chaque pile ramassée : on n'entend que la prochaine pile à aller chercher
func maj_son() -> void:
	var prochaine := true
	for pile in get_tree().get_nodes_in_group("pile"):
		if pile.ordre < ordre:
			prochaine = false
	Sons.garder(son, prochaine)

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
			son.stop()
			Sons.jouer(get_tree(), preload("res://Son/Batterie_catch.wav"))
			get_tree().call_group("pile", "maj_son")   # la pile suivante se met à sonner
			collision_shape.set_deferred("disabled", true)
			visible = false
			
			await get_tree().create_timer(0.3).timeout
			queue_free()

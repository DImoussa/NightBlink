extends Area3D
# Serrure invisible : quand le joueur s'en approche tout près avec la clé, il l'insère et les portes s'ouvrent

@export var objet_requis := "cle"
@export var portes: Array[NodePath] = []

var deverrouillee := false

const Sons := preload("res://Scripts/sons.gd")


func _ready() -> void:
	add_to_group("serrure")   # les piles "apres_serrure" attendent qu'elle soit ouverte (pile_rechargeable.gd)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if deverrouillee or not body.is_in_group("player"):
		return
	if not body.retirer_objet(objet_requis):
		return
	deverrouillee = true
	Sons.jouer(get_tree(), preload("res://Son/Unlock.wav"), 2.0)   # +2 dB : le maximum sans saturer
	get_tree().call_group("pile", "maj_son")   # la pile qui attendait la clé se met à sonner
	# La clé reste plantée dans la serrure
	var cle := get_node_or_null("CleInseree") as Node3D
	if cle:
		cle.visible = true
	for chemin in portes:
		get_node(chemin).ouvrir(body.global_position)

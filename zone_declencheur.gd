extends Area3D
# Zone invisible : la première fois que le joueur y entre, elle appelle une fonction d'un autre nœud
# (ex. en haut des 3 petites marches : la clé se met à émettre son son de repérage).

@export var cible: NodePath
@export var fonction := "commencer_reperage"

var declenchee := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if declenchee or not body.is_in_group("player"):
		return
	declenchee = true
	var noeud := get_node_or_null(cible)
	if noeud:
		noeud.call(fonction)

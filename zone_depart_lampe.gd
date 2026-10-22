extends Area3D
# Zone invisible juste après la porte avant les escaliers : la lampe commence à s'user
# quand le joueur la traverse (avant, dans la pièce du départ, elle ne s'use pas).

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var lampe = get_tree().get_first_node_in_group("lantern")
		if lampe and lampe.has_method("demarrer_decharge"):
			lampe.demarrer_decharge()

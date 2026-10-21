extends CanvasLayer
# Barre d'inventaire (nœuds Control dans la scène) : chaque case porte le nom d'un objet
# et n'est visible que si le joueur possède cet objet (voir inventaire dans player.gd)


func _ready() -> void:
	var joueur := get_tree().get_first_node_in_group("player")
	joueur.inventaire_change.connect(_afficher.bind(joueur))
	_afficher(joueur)


func _afficher(joueur: Node) -> void:
	for case in $Barre.get_children():
		case.visible = str(case.name) in joueur.inventaire

extends Area3D
# Zone invisible : quand le joueur y entre, la musique du monstre se joue (ambiance_sonore.gd).
# À dupliquer et redimensionner sur chaque endroit sombre de la map.

@export var une_seule_fois := false   # vrai pour l'escalier du début : la musique ne se rejoue pas à chaque passage
@export var monstre: NodePath         # optionnel : silhouette qui apparaît en même temps (monstre_ombre.gd)

var declenchee := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or (une_seule_fois and declenchee):
		return
	declenchee = true
	get_tree().call_group("ambiance_sonore", "musique_monstre")
	var silhouette := get_node_or_null(monstre)
	if silhouette:
		silhouette.apparaitre(body)

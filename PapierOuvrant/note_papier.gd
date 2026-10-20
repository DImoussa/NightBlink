extends Area3D

# Écris le texte de ta note directement dans l'Inspecteur de Godot
@export_multiline var contenu_texte: String = "Jour 14 : Ils ne m'ont pas cru...\nLe monstre craint la lumière directe de la torche."

@onready var indice_proche: Label3D = $IndiceEcrit
@onready var ui_lecture: CanvasLayer = $CanvasLayer
@onready var label_texte: Label = $CanvasLayer/TexteNote

func _ready() -> void:
	# Tout est caché au départ
	ui_lecture.visible = false
	indice_proche.visible = false
	label_texte.text = contenu_texte
	
	# Connexion automatique des signaux d'entrée/sortie de zone
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	# Quand le joueur entre dans la zone du papier
	if body.is_in_group("player") or body.name == "Player":
		ui_lecture.visible = true     # Affiche le papier en grand
		indice_proche.visible = false # Cache l'indice "Appuyez..." puisqu'on y est

func _on_body_exited(body: Node3D) -> void:
	# Quand le joueur s'éloigne et sort de la zone
	if body.is_in_group("player") or body.name == "Player":
		ui_lecture.visible = false     # Ferme le papier automatiquement
		indice_proche.visible = true  # Remet l'indice si on revient

# Optionnel : si tu veux que l'indice s'affiche seulement quand on s'approche sans être encore dedans,
# tu peux utiliser une 2ème Area3D plus grande, mais là, le papier s'ouvre directement dans la range !

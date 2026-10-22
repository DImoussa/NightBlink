extends Area3D
# Note à lire : quand le joueur s'approche, la feuille s'affiche à l'écran.
# Les mouvements de la feuille sont dans l'AnimationPlayer : "ouvrir", "fermer" et "flottement" (en boucle).

# Écris le texte de ta note directement dans l'Inspecteur de Godot
@export_multiline var contenu_texte: String = "Jour 14 : Ils ne m'ont pas cru...\nLe monstre craint la lumière directe de la torche."
@export var son_papier: AudioStream # Optionnel : bruit de feuille joué à l'ouverture/fermeture
@export var portee: float = 0.45 # Distance (en mètres) à laquelle la note s'ouvre

@onready var indice_proche: Label3D = $IndiceEcrit
@onready var ui_lecture: CanvasLayer = $CanvasLayer
@onready var feuille: TextureRect = $CanvasLayer/Feuille
@onready var fond_papier: ColorRect = $CanvasLayer/Feuille/FondPapier
@onready var label_texte: Label = $CanvasLayer/Feuille/TexteNote
@onready var animation: AnimationPlayer = $AnimationPlayer

var _ouverte := false
var _lecteur_son: AudioStreamPlayer

func _ready() -> void:
	# Tout est caché au départ
	ui_lecture.visible = false
	indice_proche.visible = false
	label_texte.text = contenu_texte
	# Portée : on duplique la sphère pour que chaque note ait sa propre portée
	var forme := $CollisionShape3D as CollisionShape3D
	forme.shape = forme.shape.duplicate()
	(forme.shape as SphereShape3D).radius = portee
	# Couleur papier de secours tant qu'aucune texture n'est mise sur "Feuille"
	fond_papier.visible = feuille.texture == null

	if son_papier:
		_lecteur_son = AudioStreamPlayer.new()
		_lecteur_son.stream = son_papier
		add_child(_lecteur_son)

	# Connexion automatique des signaux d'entrée/sortie de zone
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	# Quand le joueur entre dans la zone du papier
	if body.is_in_group("player") or body.name == "Player":
		indice_proche.visible = false
		_ouvrir()

func _on_body_exited(body: Node3D) -> void:
	# Quand le joueur s'éloigne et sort de la zone
	if body.is_in_group("player") or body.name == "Player":
		indice_proche.visible = true
		_fermer()

func _ouvrir() -> void:
	if _ouverte:
		return
	_ouverte = true
	_pause_lampe(true)   # la lampe ne s'use pas pendant la lecture
	_jouer_son()
	animation.play("ouvrir")
	animation.queue("flottement")   # la feuille se balance une fois ouverte

func _fermer() -> void:
	if not _ouverte:
		return
	_ouverte = false
	_pause_lampe(false)
	_jouer_son()
	animation.play("fermer")

func _pause_lampe(pause: bool) -> void:
	var lampe = get_tree().get_first_node_in_group("lantern")
	if lampe and lampe.has_method("mettre_en_pause"):
		lampe.mettre_en_pause(pause)

func _jouer_son() -> void:
	if _lecteur_son:
		_lecteur_son.pitch_scale = randf_range(0.9, 1.1)
		_lecteur_son.play()

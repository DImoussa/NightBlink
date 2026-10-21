extends Area3D

# Écris le texte de ta note directement dans l'Inspecteur de Godot
@export_multiline var contenu_texte: String = "Jour 14 : Ils ne m'ont pas cru...\nLe monstre craint la lumière directe de la torche."
@export var son_papier: AudioStream # Optionnel : bruit de feuille joué à l'ouverture/fermeture
@export var portee: float = 0.45 # Distance (en mètres) à laquelle la note s'ouvre

@export_group("Animation")
@export var duree_ouverture: float = 0.65
@export var duree_fermeture: float = 0.35
@export var inclinaison_finale_deg: float = -2.0

@onready var indice_proche: Label3D = $IndiceEcrit
@onready var ui_lecture: CanvasLayer = $CanvasLayer
@onready var fond_noir: ColorRect = $CanvasLayer/FondNoir
@onready var feuille: TextureRect = $CanvasLayer/Feuille
@onready var fond_papier: ColorRect = $CanvasLayer/Feuille/FondPapier
@onready var label_texte: Label = $CanvasLayer/Feuille/TexteNote

var _tween: Tween
var _tween_flottement: Tween
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

# Position centrée de la feuille à l'écran
func _position_centre() -> Vector2:
	return (get_viewport().get_visible_rect().size - feuille.size) / 2.0

# Position de départ : sous l'écran, comme si on remontait la feuille vers ses yeux
func _position_basse() -> Vector2:
	return _position_centre() + Vector2(0, get_viewport().get_visible_rect().size.y * 0.75)

func _ouvrir() -> void:
	if _ouverte:
		return
	_ouverte = true
	_arreter_tweens()
	_jouer_son()

	# Si la feuille était déjà en train de se fermer, on repart de là où elle est
	if not ui_lecture.visible:
		feuille.position = _position_basse()
		feuille.scale = Vector2(0.35, 0.35)
		feuille.rotation = deg_to_rad(-14.0)
		feuille.modulate.a = 0.0
		fond_noir.modulate.a = 0.0
	ui_lecture.visible = true

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(fond_noir, "modulate:a", 1.0, duree_ouverture * 0.8)
	_tween.tween_property(feuille, "modulate:a", 1.0, duree_ouverture * 0.4)
	_tween.tween_property(feuille, "position", _position_centre(), duree_ouverture) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(feuille, "scale", Vector2.ONE, duree_ouverture) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(feuille, "rotation", deg_to_rad(inclinaison_finale_deg), duree_ouverture) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_lancer_flottement)

func _fermer() -> void:
	if not _ouverte:
		return
	_ouverte = false
	_arreter_tweens()
	_jouer_son()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(fond_noir, "modulate:a", 0.0, duree_fermeture)
	_tween.tween_property(feuille, "position", _position_basse(), duree_fermeture) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_property(feuille, "scale", Vector2(0.5, 0.5), duree_fermeture) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(feuille, "rotation", deg_to_rad(10.0), duree_fermeture) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(feuille, "modulate:a", 0.0, duree_fermeture * 0.5).set_delay(duree_fermeture * 0.5)
	_tween.chain().tween_callback(func(): ui_lecture.visible = false)

# Léger balancement en boucle, comme une feuille tenue à la main
func _lancer_flottement() -> void:
	var centre := _position_centre()
	var rot := deg_to_rad(inclinaison_finale_deg)
	_tween_flottement = create_tween().set_loops()
	_tween_flottement.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_flottement.tween_property(feuille, "position:y", centre.y - 5.0, 1.6)
	_tween_flottement.parallel().tween_property(feuille, "rotation", rot + deg_to_rad(0.8), 1.6)
	_tween_flottement.tween_property(feuille, "position:y", centre.y + 5.0, 1.6)
	_tween_flottement.parallel().tween_property(feuille, "rotation", rot - deg_to_rad(0.8), 1.6)

func _arreter_tweens() -> void:
	if _tween:
		_tween.kill()
	if _tween_flottement:
		_tween_flottement.kill()

func _jouer_son() -> void:
	if _lecteur_son:
		_lecteur_son.pitch_scale = randf_range(0.9, 1.1)
		_lecteur_son.play()

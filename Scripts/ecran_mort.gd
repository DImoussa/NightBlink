extends CanvasLayer
## Écran "NightBlink - Tu es mort !" affiché par player.gd (mourir()).
## Avancer (Z / bouton FWD) = Rejouer.
## Aimant (E / bouton MAG) = retour à l'accueil.
## Les boutons fonctionnent aussi à la souris.

signal rejouer

@onready var son_rejouer: AudioStreamPlayer = $BoutonRejouer/Jouer
@onready var son_accueil: AudioStreamPlayer = $BoutonAccueil/Jouer

const SCENE_ACCUEIL := "res://Scenes/Start.tscn"
const DELAI_AVANT_CHOIX := 1.0
const DELAI_SON := 0.3

var pret := false
var action_en_cours := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	%BoutonRejouer.pressed.connect(_rejouer)
	%BoutonAccueil.pressed.connect(_retour_accueil)

	await get_tree().create_timer(DELAI_AVANT_CHOIX).timeout
	pret = true


func _input(event: InputEvent) -> void:
	if not pret or action_en_cours:
		return

	if event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_rejouer()

	elif event.is_action_pressed("magnet"):
		get_viewport().set_input_as_handled()
		_retour_accueil()


func _rejouer() -> void:
	if not pret or action_en_cours:
		return
	action_en_cours = true
	pret = false
	son_rejouer.play()
	await get_tree().create_timer(DELAI_SON).timeout
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rejouer.emit()
	queue_free()


func _retour_accueil() -> void:
	if not pret or action_en_cours:
		return

	action_en_cours = true
	pret = false
	son_accueil.play()
	await get_tree().create_timer(DELAI_SON).timeout

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	get_tree().set_meta(
		"scene_a_relancer",
		get_tree().current_scene.scene_file_path
	)

	get_tree().change_scene_to_file(SCENE_ACCUEIL)

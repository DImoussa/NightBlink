extends CanvasLayer
## Écran "NighBlink - Tu es mort !" affiché par player.gd (mourir()).
## Avancer (Z / bouton FWD de la carte) = Rejouer, Aimant (E / bouton MAG) = retour à l'accueil.
## Les boutons marchent aussi à la souris.

signal rejouer

const SCENE_ACCUEIL := "res://Scenes/Start.tscn"
const DELAI_AVANT_CHOIX := 1.0   # évite de rejouer par accident si on appuyait déjà sur avancer

var pret := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	%BoutonRejouer.pressed.connect(_rejouer)
	%BoutonAccueil.pressed.connect(_retour_accueil)
	await get_tree().create_timer(DELAI_AVANT_CHOIX).timeout
	pret = true


func _input(event: InputEvent) -> void:
	if not pret:
		return
	if event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_rejouer()
	elif event.is_action_pressed("magnet"):
		get_viewport().set_input_as_handled()
		_retour_accueil()


func _rejouer() -> void:
	if not pret:
		return
	pret = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rejouer.emit()
	queue_free()


func _retour_accueil() -> void:
	if not pret:
		return
	pret = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# L'accueil relancera cette scène quand on appuiera sur "Jouer" (start_screen.gd)
	get_tree().set_meta("scene_a_relancer", get_tree().current_scene.scene_file_path)
	get_tree().change_scene_to_file(SCENE_ACCUEIL)

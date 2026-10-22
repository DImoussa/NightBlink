extends Node
## Écran d'accueil (même style que l'écran de mort).
## Jouer : clic sur le bouton, ou avancer (Z / bouton FWD de la carte).
## Relance la scène où le joueur est mort ; sinon la scène de jeu par défaut ci-dessous.

@export_file("*.tscn") var scene_de_jeu := "res://versionfinaletest.tscn"

const DELAI_AVANT_CHOIX := 1.0   # évite de relancer par accident si on appuyait encore sur avancer

@onready var bouton_jouer: Button = %BoutonJouer
@onready var etat_manette: Label = %EtatManette

var pret := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# La partie se charge en arrière-plan pendant qu'on est sur l'accueil : "Jouer" démarre tout de suite
	ResourceLoader.load_threaded_request(_scene_a_lancer())
	bouton_jouer.pressed.connect(_jouer)
	# État de la manette Arduino (indicatif : on peut aussi jouer au clavier)
	var manager := get_node_or_null("/root/ArduinoManager")
	if manager:
		manager.arduino_connected.connect(_afficher_manette.bind(true))
		manager.arduino_disconnected.connect(_afficher_manette.bind(false))
		_afficher_manette(manager._paired)
	else:
		_afficher_manette(false)
	await get_tree().create_timer(DELAI_AVANT_CHOIX).timeout
	pret = true


func _afficher_manette(connectee: bool) -> void:
	etat_manette.text = "Manette connectée" if connectee else "Manette non connectée (clavier)"
	etat_manette.modulate = Color(0.5, 1, 0.5) if connectee else Color(1, 0.5, 0.5)


func _input(event: InputEvent) -> void:
	if pret and event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_jouer()


func _jouer() -> void:
	if not pret:
		return
	pret = false
	var paquet := ResourceLoader.load_threaded_get(_scene_a_lancer()) as PackedScene
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_packed(paquet)


# La scène où l'on est mort est retenue par l'écran de mort (ecran_mort.gd)
func _scene_a_lancer() -> String:
	return get_tree().get_meta("scene_a_relancer", scene_de_jeu)

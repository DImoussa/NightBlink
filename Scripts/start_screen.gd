extends Node
## Écran d'accueil (même style que l'écran de mort).
## Jouer : clic sur le bouton, ou avancer (Z / bouton FWD de la carte).
## Relance la scène où le joueur est mort ; sinon la scène de jeu par défaut ci-dessous.

@export_file("*.tscn") var scene_de_jeu := "res://versiofinaletest.tscn"

@onready var son_jouer: AudioStreamPlayer = $Interface/BoutonJouer/Jouer

const DELAI_AVANT_CHOIX := 1.0   # évite de relancer par accident si on appuyait encore sur avancer

@onready var bouton_jouer: Button = %BoutonJouer
@onready var etat_manette: Label = %EtatManette

var pret := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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


# 2. Dans la fonction qui lance le jeu quand on appuie sur "Jouer" :
func lancer_jeu() -> void: # (Remplacez par le nom de votre fonction actuelle)
	# Lance le son FMOD
	son_jouer.play()
	
	# Petite pause de 0.3 seconde pour entendre le son avant que la scène ne soit détruite
	await get_tree().create_timer(0.3).timeout
	
	# Votre ligne actuelle qui charge le niveau :
	get_tree().change_scene_to_file("res://...")

func _jouer() -> void:
	son_jouer.play()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://versionfinaletest.tscn")

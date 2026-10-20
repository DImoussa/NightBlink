extends Node
## Pont entre la manette Arduino et les actions du jeu (Projet > Paramètres > Contrôles).
## La connexion série (DISCOVER / GDSERIAL_ACK) est faite par l'autoload ArduinoManager.
## Ici on traduit les trames de la carte en actions, comme si on appuyait sur les touches :
##   FWD:1/0  (bouton pin 8) -> "move_up" (touche Z), maintenu tant que le bouton est appuyé
##   MAG:1/0  (bouton pin 7) -> "magnet"  (touche E)
##   imu:<pitch>,<roll>,<yaw>  (gyroscope) -> tourne la caméra (pencher = haut/bas, pivoter = gauche/droite)
## Et dans l'autre sens : L1 / L0 pour la LED pin 13 (aimant actif).

signal imu_changed(pitch: float, roll: float, yaw: float)  # angles en degrés, pour d'autres usages

@export var sensibilite_horizontale := 1.0  # 1 = la caméra tourne d'autant de degrés que la manette
@export var sensibilite_verticale := 1.0
@export var inverser_horizontal := false
@export var inverser_vertical := false
@export var utiliser_roll := false  # true si la manette se penche sur le côté pour regarder haut/bas

var manager: Node = null
var pitch := 0.0
var roll := 0.0
var yaw := 0.0
var imu_ok := false


func _ready():
	manager = get_node_or_null("/root/ArduinoManager")
	if manager:
		manager.message_received.connect(_message)


func _message(cle: String, valeur: String):
	match cle:
		"fwd":
			_action("move_up", valeur == "1")
		"mag":
			_action("magnet", valeur == "1")
		"imu":
			if valeur == "err":
				imu_ok = false
				push_warning("[Arduino] Gyroscope LSM6DS3 non détecté (vérifier SDA -> A4, SCL -> A5)")
				return
			var angles := valeur.split(",")
			if angles.size() < 3:
				return
			var p := angles[0].to_float()
			var r := angles[1].to_float()
			var y := angles[2].to_float()
			# La caméra suit la VARIATION des angles : la souris continue de fonctionner en même temps
			if imu_ok:
				var haut_bas := (r - roll) if utiliser_roll else (p - pitch)
				_tourner_camera(y - yaw, haut_bas)
			imu_ok = true
			pitch = p
			roll = r
			yaw = y
			imu_changed.emit(pitch, roll, yaw)


var niveau_envoye := -1  # dernier niveau envoyé aux LEDs de la lampe

func _process(_delta):
	# Énergie de la lanterne -> LEDs verte/orange/rouge (3 = pleine, 0 = vide ou éteinte)
	if manager == null or not manager._paired:
		niveau_envoye = -1
		return
	var lanterne = get_tree().get_first_node_in_group("lantern")
	if lanterne == null:
		return
	var pct: float = lanterne.energy / lanterne.max_energy
	var niveau := 0 if (pct <= 0.0 or not lanterne.is_on) else (1 if pct < 0.34 else (2 if pct < 0.67 else 3))
	if niveau != niveau_envoye:
		niveau_envoye = niveau
		manager._send("energy:" + str(niveau))


func _tourner_camera(delta_yaw: float, delta_pitch: float):
	var joueur = get_tree().get_first_node_in_group("player")
	if joueur == null:
		return
	var h := delta_yaw * sensibilite_horizontale * (-1.0 if inverser_horizontal else 1.0)
	var v := delta_pitch * sensibilite_verticale * (-1.0 if inverser_vertical else 1.0)
	joueur.tourner_camera(deg_to_rad(h), deg_to_rad(v))


func _action(nom: String, appuye: bool):
	var ev := InputEventAction.new()
	ev.action = nom
	ev.pressed = appuye
	ev.strength = 1.0 if appuye else 0.0
	Input.parse_input_event(ev)


func led(allumee: bool):
	# LED pin 13 : allumée quand l'aimant tient un mur
	if manager:
		manager._send("L1" if allumee else "L0")

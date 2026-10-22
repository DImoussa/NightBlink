extends Node
## Pont entre la manette Arduino et les actions du jeu (Projet > Paramètres > Contrôles).
## La connexion série (DISCOVER / GDSERIAL_ACK) est faite par l'autoload ArduinoManager.
## Ici on traduit les trames de la carte en actions, comme si on appuyait sur les touches :
##   FWD:1/0  (bouton pin 8) -> "move_up" (touche Z), maintenu tant que le bouton est appuyé
##   MAG:1/0  (bouton pin 7) -> "magnet"  (touche E)
##   imu:<pitch>,<roll>        (gyroscope BMI160 / LSM6DS3, envoyé quand l'angle change)
##       pencher en avant/arrière = regarder haut/bas, pencher sur le côté = tourner (comme un joystick)
##   imu:<pitch>,<roll>,<yaw>  (carte finale, Arduino Code/Code_Projet) -> rotations réelles de la torche :
##       lever/baisser (roulis) = regarder haut/bas, tourner à gauche/droite (lacet) = tourner, 1 pour 1
## Et dans l'autre sens : L1 / L0 pour la LED pin 13 (aimant actif).

signal imu_changed(pitch: float, roll: float, yaw: float)  # angles en degrés, pour d'autres usages

@export var sensibilite_horizontale := 1.0  # seulement si rotation_continue = false (1 = autant de degrés que la torche)
@export var sensibilite_verticale := 1.0
@export var inverser_horizontal := false
@export var inverser_vertical := false
@export var utiliser_roll := true  # manette tenue comme une torche : lever/baisser = roulis du capteur
# true : la caméra prend l'angle RÉEL de la torche (torche à l'horizontale = regard droit devant, dès le spawn)
# false : la caméra suit seulement les variations (la souris garde la main sur le haut/bas)
@export var haut_bas_absolu := true

@export_group("Rotation continue (comme un joystick)")
# Tant que la torche est tournée par rapport au centre, la caméra continue de tourner (360° faciles) ;
# revenir au centre l'arrête. false = la caméra suit l'angle de la torche (1 pour 1, sans 360°).
@export var rotation_continue := true
@export var zone_morte := 8.0             # degrés autour du centre sans rotation
@export var inclinaison_max := 40.0       # degrés depuis le centre pour tourner à la vitesse max
@export var vitesse_rotation_max := 150.0 # degrés par seconde
@export var inverser_rotation := false

var manager: Node = null
var pitch := 0.0
var roll := 0.0
var yaw := 0.0
var imu_ok := false
var tourne_en_penchant := false   # rotation continue active (carte sans lacet, ou rotation_continue)
var inclinaison := 0.0            # écart (°) au centre qui sert à tourner dans ce mode
var signe_rotation := -1.0        # roulis positif = tourner à droite ; lacet positif = tourner à gauche
var centre_lacet := 0.0           # direction "centre" de la torche (lacet au moment de la connexion)


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
				push_warning("[Arduino] Gyroscope (BMI160 / LSM6DS3) non détecté : vérifier SDA -> A4, SCL -> A5")
				return
			var angles := valeur.split(",")
			# Lignes d'information au démarrage (ex. "imu:BMI160 @0x68") : pas des angles
			if angles.size() < 2 or not angles[0].is_valid_float() or not angles[1].is_valid_float():
				return
			var p := angles[0].to_float()
			var r := angles[1].to_float()
			var a_lacet := angles.size() >= 3 and angles[2].is_valid_float()
			var y := angles[2].to_float() if a_lacet else 0.0
			# Haut/bas : la caméra suit la VARIATION de l'angle (la souris continue de fonctionner)
			var continu := a_lacet and rotation_continue
			if not imu_ok:
				centre_lacet = y   # la torche est "au centre" quand le jeu se connecte
			if imu_ok:
				var haut_bas := 0.0 if haut_bas_absolu else ((r - roll) if utiliser_roll else (p - pitch))
				var gauche_droite := (y - yaw) if (a_lacet and not continu) else 0.0
				_tourner_camera(gauche_droite, haut_bas)
			tourne_en_penchant = continu or not a_lacet
			if a_lacet:
				inclinaison = y - centre_lacet
				signe_rotation = 1.0
			else:
				inclinaison = p if utiliser_roll else r
				signe_rotation = -1.0
			imu_ok = true
			pitch = p
			roll = r
			yaw = y
			imu_changed.emit(pitch, roll, yaw)


var niveau_envoye := -1  # dernier niveau envoyé aux LEDs de la lampe

func _process(delta):
	_tourner_en_penchant(delta)
	_regarder_comme_la_torche(delta)
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


# Carte sans lacet : tant que la manette est penchée sur le côté, la caméra tourne (vitesse selon l'angle).
# Appelé à chaque image, car la carte n'envoie rien tant que l'angle ne bouge pas.
func _tourner_en_penchant(delta: float) -> void:
	if not tourne_en_penchant or not imu_ok or manager == null or not manager._paired:
		return
	var ecart: float = (yaw - centre_lacet) if signe_rotation > 0.0 else inclinaison
	var exces: float = abs(ecart) - zone_morte
	if exces <= 0.0:
		# Torche au centre : le centre suit doucement la torche (compense la petite dérive du gyroscope)
		if signe_rotation > 0.0:
			centre_lacet = move_toward(centre_lacet, yaw, 2.0 * delta)
		return
	var t: float = clamp(exces / max(inclinaison_max - zone_morte, 1.0), 0.0, 1.0)
	var vitesse := vitesse_rotation_max * t * t   # douce près de la zone morte, rapide en penchant fort
	# Lacet positif = torche tournée à gauche -> tourner à gauche ; roulis positif -> tourner à droite
	var sens := signe_rotation * signf(ecart) * (-1.0 if inverser_rotation else 1.0)
	var joueur = get_tree().get_first_node_in_group("player")
	if joueur and not joueur.get("mort") and not joueur.get("fige"):
		joueur.tourner_camera(deg_to_rad(sens * vitesse * delta), 0.0)


# Haut/bas absolu : à chaque image, la tête du joueur prend l'inclinaison réelle de la torche
# (aussi juste après un spawn ou un respawn, sans attendre que la torche bouge)
func _regarder_comme_la_torche(delta: float) -> void:
	if not haut_bas_absolu or not imu_ok or manager == null or not manager._paired:
		return
	var joueur = get_tree().get_first_node_in_group("player")
	if joueur == null or joueur.get("mort") or joueur.get("fige"):
		return
	var tete: Node3D = joueur.get_node_or_null("Head")
	if tete == null:
		return
	var angle := (roll if utiliser_roll else pitch) * sensibilite_verticale * (-1.0 if inverser_vertical else 1.0)
	var cible := deg_to_rad(clampf(angle, -80.0, 80.0))
	# Léger lissage : la carte envoie l'angle par pas de 0,3°
	tete.rotation.x = lerp_angle(tete.rotation.x, cible, minf(1.0, 20.0 * delta))


func _tourner_camera(delta_yaw: float, delta_pitch: float):
	var joueur = get_tree().get_first_node_in_group("player")
	if joueur == null or joueur.get("mort") or joueur.get("fige"):
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

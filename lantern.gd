extends SpotLight3D

@export var max_energy := 80.0
@export var drain_rate := 0.75
@export var duree_extinction := 5.0   # secondes : avant la mort, la lumière baisse peu à peu jusqu'à s'éteindre

var energy := 40.0
var is_on := true
var decharge_demarree := false   # la lampe ne s'use qu'une fois passée la porte avant les escaliers (zone_depart_lampe.gd)
var pauses := 0                  # nombre de notes ouvertes : la lampe ne s'use pas pendant la lecture
var vacillement := 1.0           # multiplie la lumière pendant les dernières secondes (lampe qui meurt)
var prochain_vacillement := 0.0  # secondes avant de tirer un nouveau vacillement

func _enter_tree() -> void:
	add_to_group("lantern") 

func _ready() -> void:
	energy = max_energy
	is_on = true
	update_light()
	# Pas de zone de départ dans la scène : la lampe s'use dès le début
	if get_tree().get_nodes_in_group("depart_lampe").is_empty():
		decharge_demarree = true

signal energie_vide

func _process(delta: float) -> void:
	if is_on and energy > 0 and decharge_demarree and pauses == 0:
		energy -= drain_rate * delta
		_vaciller(delta)
		update_light()
		if energy <= 0:
			energy = 0
			is_on = false
			update_light()
			energie_vide.emit()

func update_light() -> void:
	visible = is_on and energy > 0
	# Pleine puissance, sauf pendant les dernières secondes d'énergie où elle faiblit en vacillant
	var reste := clampf(energy / (drain_rate * duree_extinction), 0.0, 1.0)
	light_energy = 2.5 * lerpf(0.4, 1.0, reste) * (vacillement if reste < 1.0 else 1.0)
	spot_range = 17.0
	spot_angle = 38.5

# Lampe à piles qui meurt : baisses brusques et micro-coupures, de plus en plus fréquentes vers la fin
func _vaciller(delta: float) -> void:
	var reste := clampf(energy / (drain_rate * duree_extinction), 0.0, 1.0)
	if reste >= 1.0:
		vacillement = 1.0
		return
	prochain_vacillement -= delta
	if prochain_vacillement > 0.0:
		return
	var fin := 1.0 - reste   # 0 au début de l'agonie, 1 juste avant de s'éteindre
	prochain_vacillement = randf_range(0.04, 0.3) * (1.0 - 0.7 * fin)
	var tirage := randf()
	if tirage < 0.15 + 0.35 * fin:
		vacillement = 0.0                       # coupure
	elif tirage < 0.45 + 0.3 * fin:
		vacillement = randf_range(0.1, 0.5)     # grosse baisse
	else:
		vacillement = randf_range(0.8, 1.0)     # presque normale


func demarrer_decharge() -> void:
	decharge_demarree = true


# Appelé par les notes (note_papier.gd) : true à l'ouverture, false à la fermeture
func mettre_en_pause(pause: bool) -> void:
	pauses = maxi(0, pauses + (1 if pause else -1))


func recharger(montant: float = 40.0) -> void:
	energy = clamp(energy + montant, 0.0, max_energy)
	is_on = true
	update_light()
	print("Lanterne rechargée ! Énergie : ", energy)

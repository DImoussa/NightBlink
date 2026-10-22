extends SpotLight3D

@export var max_energy := 80.0
@export var drain_rate := 2.0
@export var duree_extinction := 5.0   # secondes : avant la mort, la lumière baisse peu à peu jusqu'à s'éteindre

var energy := 40.0
var is_on := true
var decharge_demarree := false   # la lampe ne s'use qu'une fois passée la porte avant les escaliers (zone_depart_lampe.gd)
var pauses := 0                  # nombre de notes ouvertes : la lampe ne s'use pas pendant la lecture

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
		update_light()
		if energy <= 0:
			energy = 0
			is_on = false
			update_light()
			energie_vide.emit()

func update_light() -> void:
	visible = is_on and energy > 0
	# Pleine puissance, sauf pendant les dernières secondes d'énergie où elle diminue jusqu'à 0
	light_energy = 2.5 * clampf(energy / (drain_rate * duree_extinction), 0.0, 1.0)
	spot_range = 17.0
	spot_angle = 38.5

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

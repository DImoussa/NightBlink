extends SpotLight3D

@export var max_energy := 40.0
@export var drain_rate := 2.0    

var energy := 40.0
var is_on := true

func _enter_tree() -> void:
	add_to_group("lantern") 

func _ready() -> void:
	energy = max_energy
	is_on = true
	update_light()

#func _process(delta: float) -> void:
#	if is_on and energy > 0:
#		energy -= drain_rate * delta
	#	if energy <= 0:
			#energy = 0
			#is_on = false
			#update_light()

func update_light() -> void:
	visible = is_on and energy > 0
	light_energy = 1.0
	spot_range = 12.0
	spot_angle = 32.5

func recharger(montant: float = 40.0) -> void:
	energy = clamp(energy + montant, 0.0, max_energy)
	is_on = true
	update_light()
	print("Lanterne rechargée ! Énergie : ", energy)

extends SpotLight3D

@export var max_energy := 100.0
@export var drain_rate := 5.0      # énergie perdue par seconde à pleine puissance
@export var power_step := 0.1      # de combien la molette change la puissance

var energy := 100.0
var power := 0.5                   # entre 0.1 (faible) et 1.0 (max)
var is_on := true

func _enter_tree():
	add_to_group("lantern")        # pour que le HUD puisse retrouver la lanterne

func _ready():
	energy = max_energy
	update_light()

func _unhandled_input(event):
	if event.is_action_pressed("lantern"):
		is_on = not is_on
		update_light()
	if event.is_action_pressed("lantern_up"):
		power = clamp(power + power_step, 0.1, 1.0)
		update_light()
	if event.is_action_pressed("lantern_down"):
		power = clamp(power - power_step, 0.1, 1.0)
		update_light()

func _process(delta):
	if is_on and energy > 0:
		energy -= drain_rate * power * delta
		if energy <= 0:
			energy = 0
			is_on = false
			update_light()

func update_light():
	visible = is_on and energy > 0
	light_energy = lerp(0.5, 5.0, power)   # luminosité
	spot_range = lerp(5.0, 20.0, power)    # portée
	spot_angle = lerp(20.0, 45.0, power)   # largeur du faisceau

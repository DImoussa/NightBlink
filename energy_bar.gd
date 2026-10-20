extends ProgressBar

var lantern

func _ready():
	lantern = get_tree().get_first_node_in_group("lantern")

func _process(delta):
	if lantern:
		value = lantern.energy / lantern.max_energy * 100

extends CanvasLayer
# Barre d'inventaire style Roblox : cases carrées collées en bas de l'écran (affichage seul)

const MODELES := {"lampe": "res://Lampe.glb", "aimant": "res://scene_baked.glb", "cle": "res://Key by Quaternius - bg6e1lfNsO.glb"}
@export var taille := 70

var barre := HBoxContainer.new()


func _ready() -> void:
	barre.add_theme_constant_override("separation", 0)   # cases collées
	add_child(barre)
	barre.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	barre.grow_horizontal = Control.GROW_DIRECTION_BOTH   # reste centrée
	barre.grow_vertical = Control.GROW_DIRECTION_BEGIN    # grandit vers le haut
	get_parent().inventaire_change.connect(_rafraichir)
	_rafraichir()


func _rafraichir() -> void:
	for case in barre.get_children():
		barre.remove_child(case)
		case.queue_free()
	for nom in get_parent().inventaire:
		_ajouter_case(nom)


func _ajouter_case(nom: String) -> void:
	# Case : fond gris foncé transparent + bordure claire
	var case := PanelContainer.new()
	case.name = nom
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	style.border_color = Color(1, 1, 1, 0.4)
	style.set_border_width_all(1)
	case.add_theme_stylebox_override("panel", style)
	# Icône : le modèle 3D rendu dans un petit monde à part
	var cadre := SubViewportContainer.new()
	cadre.stretch = true
	cadre.custom_minimum_size = Vector2(taille, taille)
	var vue := SubViewport.new()
	vue.own_world_3d = true
	vue.transparent_bg = true
	var modele: Node3D = load(MODELES[nom]).instantiate()
	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-40, 30, 0)
	var camera := Camera3D.new()
	camera.fov = 30
	vue.add_child(modele)
	vue.add_child(lumiere)
	vue.add_child(camera)
	cadre.add_child(vue)
	case.add_child(cadre)
	barre.add_child(case)
	# Cadrage : la caméra recule jusqu'à voir tout le modèle
	var boite := AABB()
	for mi in modele.find_children("*", "MeshInstance3D", true, false):
		boite = boite.merge(mi.global_transform * mi.get_aabb()) if boite.size else mi.global_transform * mi.get_aabb()
	var distance := boite.size.length() * 2.0
	camera.far = distance * 3.0
	camera.look_at_from_position(boite.get_center() + Vector3(0.6, 0.45, 1.0).normalized() * distance, boite.get_center())

extends Node3D
# Silhouette noire du monstre (shadow_monster.glb). Cachée au départ, elle apparaît une seule fois
# quand le joueur entre dans la zone de l'escalier (zone_monstre.gd) : le joueur est figé et regarde
# le monstre pendant son cri, puis le monstre recule et disparaît pour de bon.

@export var duree_cri := 5.0            # secondes : durée de Monstre.wav
@export var recul := Vector3(0, 0, 5)   # déplacement (dans le monde) quand il s'en va
@export var duree_recul := 1.2
@export var contre_jour := Vector3(0, 1.5, 2.0)   # lumière derrière lui (décalage dans le monde) : sa silhouette noire se détache
@export var energie_contre_jour := 3.0

var apparu := false


func _ready() -> void:
	visible = false
	# Noir pur, insensible à la lumière : on ne voit que sa silhouette
	var noir := StandardMaterial3D.new()
	noir.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	noir.albedo_color = Color.BLACK
	for maillage in find_children("*", "MeshInstance3D", true, false):
		maillage.material_override = noir


func apparaitre(joueur: Node3D) -> void:
	if apparu:
		return
	apparu = true
	visible = true
	# Le palier est sombre : sans lumière derrière, du noir sur du noir ne se voit pas.
	# Elle reste sur place quand il recule, et disparaît avec lui.
	var lumiere := OmniLight3D.new()
	lumiere.top_level = true
	lumiere.light_color = Color(0.7, 0.75, 1.0)
	lumiere.light_energy = energie_contre_jour
	lumiere.omni_range = 5.0
	add_child(lumiere)
	lumiere.global_position = global_position + contre_jour
	joueur.figer(_centre(), duree_cri)
	await get_tree().create_timer(duree_cri).timeout
	var depart := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	depart.tween_property(self, "global_position", global_position + recul, duree_recul)
	await depart.finished
	queue_free()


# Le joueur regarde le milieu du corps, pas les pieds
func _centre() -> Vector3:
	var boite := AABB()
	var premier := true
	for maillage in find_children("*", "MeshInstance3D", true, false):
		var b: AABB = maillage.global_transform * maillage.get_aabb()
		boite = b if premier else boite.merge(b)
		premier = false
	return boite.get_center()

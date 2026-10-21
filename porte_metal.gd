extends Node3D
# Porte qui pivote sur sa charnière. Porte métallique : s'ouvre quand l'aimant du joueur la vise de près
# (touche E, voir player.gd). Avec ouverture_aimant = false, seule une serrure peut l'ouvrir (serrure.gd).

@export var angle_ouverture_deg := 100.0
@export var duree_ouverture := 1.2
@export var ouverture_aimant := true     # false : l'aimant n'a pas d'effet (ex. grilles à clé)
@export var charniere_au_max := false    # charnière sur l'autre bord de la porte

var ouverte := false
var _battant: MeshInstance3D       # le modèle de la porte (sa collision StaticBody3D est dedans)
var _transform_fermee: Transform3D
var _charniere: Vector3            # bord de la porte autour duquel elle tourne (repère du modèle)
var _milieu: Vector3               # milieu de la porte (repère du modèle)


func _ready() -> void:
	if ouverture_aimant:
		add_to_group("porte_metal")
	_battant = get_child(0) as MeshInstance3D
	_transform_fermee = _battant.transform
	# La charnière est sur un bord de la largeur de la porte (son plus grand côté horizontal)
	var boite := _battant.get_aabb()
	var axe := 0 if boite.size.x >= boite.size.z else 2
	_milieu = boite.get_center()
	_milieu.y = 0
	_charniere = _milieu
	_charniere[axe] = boite.end[axe] if charniere_au_max else boite.position[axe]


func ouvrir(position_joueur: Vector3) -> void:
	if ouverte:
		return
	ouverte = true
	# La porte s'ouvre du côté opposé au joueur (on la pousse)
	var joueur_local := _battant.global_transform.affine_inverse() * position_joueur
	var vers_milieu := _milieu - _charniere
	var sens_positif := Vector3(vers_milieu.z, 0, -vers_milieu.x)   # où va la porte pour un angle positif
	var signe := -1.0 if sens_positif.dot(joueur_local - _charniere) > 0 else 1.0
	create_tween().tween_method(_tourner, 0.0, deg_to_rad(angle_ouverture_deg) * signe, duree_ouverture) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _tourner(angle: float) -> void:
	var pivot := Transform3D(Basis(), _charniere)
	_battant.transform = _transform_fermee * pivot * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO) * pivot.affine_inverse()

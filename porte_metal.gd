extends Node3D
# Porte métallique (portemetal.glb) : s'ouvre quand l'aimant du joueur la vise de près (touche E, voir player.gd)

@export var angle_ouverture_deg := 100.0
@export var duree_ouverture := 1.2

var ouverte := false
var _battant: MeshInstance3D       # le modèle de la porte (sa collision StaticBody3D est dedans)
var _transform_fermee: Transform3D
var _charniere: Vector3            # bord de la porte autour duquel elle tourne (repère du modèle)


func _ready() -> void:
	add_to_group("porte_metal")
	_battant = get_child(0) as MeshInstance3D
	_transform_fermee = _battant.transform
	var boite := _battant.get_aabb()
	_charniere = Vector3(boite.position.x, 0, boite.get_center().z)


func ouvrir(position_joueur: Vector3) -> void:
	if ouverte:
		return
	ouverte = true
	# La porte s'ouvre du côté opposé au joueur (on la pousse)
	var cote := (_battant.global_transform.affine_inverse() * position_joueur).z
	var angle := deg_to_rad(angle_ouverture_deg) * (1.0 if cote > 0 else -1.0)
	create_tween().tween_method(_tourner, 0.0, angle, duree_ouverture) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _tourner(angle: float) -> void:
	var pivot := Transform3D(Basis(), _charniere)
	_battant.transform = _transform_fermee * pivot * Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO) * pivot.affine_inverse()

extends Node3D
# Porte : ce nœud est le pivot placé sur la charnière. Son AnimationPlayer joue "ouvrir" (rotation du pivot).
# Porte métallique : s'ouvre quand l'aimant la vise de près (touche E, voir player.gd).
# Avec ouverture_aimant = false, seule une serrure peut l'ouvrir (serrure.gd).

@export var ouverture_aimant := true
@export var son_ouverture: AudioStream   # joué en 3D sur la porte à l'ouverture (double porte : sur un seul battant)
@export var surbrillance_entiere := false   # aura légère sur toute la porte (sinon juste le contour)

var ouverte := false

const Surbrillance := preload("res://Scripts/surbrillance.gd")


func _ready() -> void:
	if ouverture_aimant:
		add_to_group("porte_metal")
		Surbrillance.appliquer(self, Surbrillance.MATERIAU_LEGER if surbrillance_entiere else Surbrillance.MATERIAU_CONTOUR)


func ouvrir(_position_joueur := Vector3.ZERO) -> void:
	if ouverte:
		return
	ouverte = true
	Surbrillance.retirer(self)
	$AnimationPlayer.play("ouvrir")
	if son_ouverture:
		var lecteur := AudioStreamPlayer3D.new()
		lecteur.stream = son_ouverture
		lecteur.finished.connect(lecteur.queue_free)
		add_child(lecteur)
		lecteur.play()

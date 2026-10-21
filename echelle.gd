extends Area3D
# Zone invisible autour d'une échelle : tant que le joueur est dedans, avancer = monter, reculer = descendre
# (l'échelle est trop raide pour une rampe comme Mur/Mur2 : un CharacterBody3D ne monte pas plus de 45°)


func _ready() -> void:
	body_entered.connect(func(body): if body.has_method("entrer_echelle"): body.entrer_echelle(true))
	body_exited.connect(func(body): if body.has_method("entrer_echelle"): body.entrer_echelle(false))

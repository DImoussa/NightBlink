extends RefCounted
## Petites fonctions partagées pour jouer les sons du dossier Son/ (sons natifs Godot, pas FMOD).
## À utiliser avec : const Sons := preload("res://Scripts/sons.gd")


# Son joué une fois, qui va jusqu'au bout même si la scène change ou si l'objet disparaît (ex. pile ramassée)
static func jouer(arbre: SceneTree, flux: AudioStream) -> void:
	var lecteur := AudioStreamPlayer.new()
	lecteur.stream = flux
	lecteur.finished.connect(lecteur.queue_free)
	arbre.root.add_child(lecteur)
	lecteur.play()


# Lecteur qui recommence à la fin du son (les .wav ne bouclent pas à l'import). Arrêté tant qu'on n'appelle pas play().
# en_3d : le son vient de la position du parent (AudioStreamPlayer3D) au lieu d'être joué "dans la tête"
static func boucle(parent: Node, flux: AudioStream, en_3d := false) -> Node:
	var lecteur: Node
	if en_3d:
		lecteur = AudioStreamPlayer3D.new()
	else:
		lecteur = AudioStreamPlayer.new()
	lecteur.stream = flux
	lecteur.finished.connect(lecteur.play)
	parent.add_child(lecteur)
	return lecteur


# Lance ou arrête un son en boucle selon la situation, sans le faire redémarrer à chaque image
static func garder(lecteur: Node, actif: bool) -> void:
	if actif and not lecteur.playing:
		lecteur.play()
	elif not actif and lecteur.playing:
		lecteur.stop()

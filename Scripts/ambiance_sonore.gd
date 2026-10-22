extends Node3D
## Sons d'ambiance de la partie (voir SOUND SYSTEM SHEET) : bruit de fond,
## cœur qui s'accélère quand la lampe faiblit, néons, et bruits aléatoires en 3D autour du joueur.

const Sons := preload("res://Scripts/sons.gd")

@export var lumieres_neon: Array[NodePath] = []   # chaque lumière reçoit le grésillement "Neon" en 3D
@export var secondes_coeur := 20.0                # le cœur et la respiration commencent 20 s avant que la lampe s'éteigne
@export var volume_respiration := 12.0            # dB en plus : le fichier Respiration.wav est enregistré très bas
@export var delai_aleatoire := Vector2(20, 45)    # secondes entre deux bruits aléatoires (min, max)
@export var distance_aleatoire := Vector2(6, 14)  # distance au joueur des bruits aléatoires (min, max)

const SONS_ALEATOIRES: Array[AudioStream] = [
	preload("res://Son/Metalpipe.wav"),
	preload("res://Son/Corbeau.wav"),
	preload("res://Son/Scream.wav"),
	preload("res://Son/Voix/j'arrive.wav"),
	preload("res://Son/Voix/je te vois.wav"),
	preload("res://Son/Voix/n'y vas pas.wav"),
	preload("res://Son/Voix/suis ce son.wav"),
	preload("res://Son/Voix/suis le son.wav"),
]

var coeur: AudioStreamPlayer
var respiration: AudioStreamPlayer
var minuterie := Timer.new()


func _ready() -> void:
	Sons.boucle(self, preload("res://Son/Brown_noise.mp3")).play()
	coeur = Sons.boucle(self, preload("res://Son/Coeur.wav"))
	respiration = Sons.boucle(self, preload("res://Son/Respiration.wav"))
	respiration.volume_db = volume_respiration
	for chemin in lumieres_neon:
		var neon: AudioStreamPlayer3D = Sons.boucle(get_node(chemin), preload("res://Son/Neon.wav"), true)
		neon.max_distance = 15.0
		neon.play()
	minuterie.one_shot = true
	minuterie.timeout.connect(_bruit_aleatoire)
	add_child(minuterie)
	minuterie.start(randf_range(delai_aleatoire.x, delai_aleatoire.y))


func _process(_delta: float) -> void:
	var lampe := get_tree().get_first_node_in_group("lantern")
	var joueur := get_tree().get_first_node_in_group("player")
	if not lampe or not joueur:
		return
	var restant: float = lampe.energy / lampe.drain_rate   # secondes avant que la lampe s'éteigne
	var actif: bool = restant < secondes_coeur and not joueur.mort
	Sons.garder(coeur, actif)
	Sons.garder(respiration, actif)
	# Plus la lampe est près de s'éteindre, plus le cœur bat vite
	coeur.pitch_scale = lerpf(1.6, 1.0, clampf(restant / secondes_coeur, 0.0, 1.0))


func _bruit_aleatoire() -> void:
	minuterie.start(randf_range(delai_aleatoire.x, delai_aleatoire.y))
	var joueur := get_tree().get_first_node_in_group("player")
	if not joueur or joueur.mort:
		return
	# Un bruit au hasard, quelque part autour du joueur
	var lecteur := AudioStreamPlayer3D.new()
	lecteur.stream = SONS_ALEATOIRES.pick_random()
	lecteur.max_distance = 30.0
	lecteur.finished.connect(lecteur.queue_free)
	add_child(lecteur)
	var direction := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	lecteur.global_position = joueur.global_position + direction * randf_range(distance_aleatoire.x, distance_aleatoire.y) + Vector3.UP
	lecteur.play()

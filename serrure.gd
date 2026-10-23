extends Area3D
# Serrure invisible : avec la clé, le joueur l'insère en visant la serrure avec l'aimant (de loin, voir player.gd)
# ou en s'en approchant tout près, et les portes s'ouvrent. La serrure brille tant qu'on a la clé.

@export var objet_requis := "cle"
@export var portes: Array[NodePath] = []
@export var carte: NodePath = ^"../scene3jsp/Scene_Cycles_Baked"   # la serrure fait partie de ce maillage
@export var rayon_surbrillance := 0.6

var deverrouillee := false
var surbrillance: MeshInstance3D = null

const Sons := preload("res://Scripts/sons.gd")
const Surbrillance := preload("res://Scripts/surbrillance.gd")


func _ready() -> void:
	add_to_group("serrure")   # les piles "apres_serrure" attendent qu'elle soit ouverte (pile_rechargeable.gd)
	body_entered.connect(_on_body_entered)
	var maillage := get_node_or_null(carte) as MeshInstance3D
	if maillage:
		surbrillance = Surbrillance.extraire_de_la_carte(self, maillage, Vector3.ONE * rayon_surbrillance)
	if surbrillance:
		surbrillance.visible = false
	_suivre_inventaire.call_deferred()   # le joueur n'est peut-être pas encore prêt


func _suivre_inventaire() -> void:
	var joueur := get_tree().get_first_node_in_group("player")
	if joueur:
		joueur.inventaire_change.connect(_maj_surbrillance.bind(joueur))
		_maj_surbrillance(joueur)


func _maj_surbrillance(joueur: Node) -> void:
	if surbrillance:
		surbrillance.visible = not deverrouillee and objet_requis in joueur.inventaire


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		deverrouiller(body)


# Renvoie false si la serrure est déjà ouverte ou si le joueur n'a pas la clé
func deverrouiller(body: Node3D) -> bool:
	if deverrouillee or not body.retirer_objet(objet_requis):
		return false
	deverrouillee = true
	if surbrillance:
		surbrillance.visible = false
	Sons.jouer(get_tree(), preload("res://Son/Unlock.wav"), 2.0)   # +2 dB : le maximum sans saturer
	get_tree().call_group("pile", "maj_son")   # la pile qui attendait la clé se met à sonner
	# La clé reste plantée dans la serrure
	var cle := get_node_or_null("CleInseree") as Node3D
	if cle:
		cle.visible = true
	for chemin in portes:
		get_node(chemin).ouvrir(body.global_position)
	return true

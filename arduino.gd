extends Node
## Connexion à l'Arduino (programme de test du prof) via pont_serie.py, port 4001.
## Messages : DISCOVER -> GDSERIAL_ACK, button:1 / button:0, led:1 / led:0
## Accessible partout : Arduino.bouton_appuye.connect(...), Arduino.led(true)

signal bouton_appuye   # émis à chaque nouvel appui (pas au relâchement)

var connectee := false

var tcp := StreamPeerTCP.new()
var buffer := ""
var attente := 0.0
var discover_envoye := false

func _process(delta):
	tcp.poll()
	var statut := tcp.get_status()
	if statut == StreamPeerTCP.STATUS_NONE or statut == StreamPeerTCP.STATUS_ERROR:
		# Pas connecté : on réessaie toutes les 2 secondes
		connectee = false
		discover_envoye = false
		attente -= delta
		if attente <= 0.0:
			attente = 2.0
			tcp = StreamPeerTCP.new()
			tcp.connect_to_host("127.0.0.1", 4001)
		return
	if statut != StreamPeerTCP.STATUS_CONNECTED:
		return
	# Comme le projet du prof : on demande à la carte de se présenter
	if not connectee:
		attente -= delta
		if attente <= 0.0 or not discover_envoye:
			attente = 1.0
			discover_envoye = true
			_envoyer("DISCOVER")
	var n := tcp.get_available_bytes()
	if n > 0:
		buffer += tcp.get_utf8_string(n)
		while "\n" in buffer:
			var i := buffer.find("\n")
			_message(buffer.substr(0, i).strip_edges())
			buffer = buffer.substr(i + 1)

func _message(ligne: String):
	if ligne.begins_with("GDSERIAL_ACK"):
		connectee = true
		print("Arduino connectée")
	elif ligne == "button:1":
		bouton_appuye.emit()

func led(allumee: bool):
	_envoyer("led:1" if allumee else "led:0")

func _envoyer(msg: String):
	if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		tcp.put_data((msg + "\n").to_utf8_buffer())

extends CanvasLayer
## Générique de fin, lancé par zone_fin.gd après la vidéo d'outro.
## Le contenu est scellé : toute modification du bloc ou de l'empreinte désactive le générique.

signal fini

const _Q := "wl0qjmLcS3RXf3BKh5UY0n/e5BfO9P3D8GBAFdHaPfqCcGd51aoNkQ2vDdeI4ctT7fSFnEtSc8MIk7zUH/TQ5Z392trXAVm9VxuRuy4UDGlwBwuwoVlsOicvRMGeJF2+wPB0pUhTUNqKS2ky6tYKS9aXPMGWyz1KSoglLPuIlh7xH3wsVpv0DbYDbB4Bp96EfB6f7awxCDCw0p9W9Zte30hyAjsdSGZ8tu01ty9TXWiINVmzsupLOFWRZiyraOYv4RwQ5y7JTG+KUFJx0lVOWMjC//SLBXvQTWbeNg=="
const _W := 3934354269
const _G := 0x5A17C3

const VITESSE := 55.0          # pixels par seconde
const DELAI_PASSER := 2.0      # avant de pouvoir passer le générique
const OR := Color(0.85, 0.72, 0.42)
const GRIS := Color(0.62, 0.62, 0.66)

var _peut_passer := false
var _termine := false


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	var l := _ouvrir()
	if l.is_empty():
		_finir.call_deferred()
		return
	_construire(l)
	get_tree().create_timer(DELAI_PASSER, true).timeout.connect(func(): _peut_passer = true)


func _ouvrir() -> PackedStringArray:
	var o := Marshalls.base64_to_raw(_Q)
	var k := _G
	for i in o.size():
		k = (k * 1103515245 + 12345) & 0x7fffffff
		o[i] = o[i] ^ ((k >> 16) & 0xFF) ^ ((i * 31) & 0xFF)
	o.reverse()
	var h := 2166136261
	for x in o:
		h = ((h ^ x) * 16777619) & 0xffffffff
	if h != _W:
		return PackedStringArray()
	return o.get_string_from_utf8().split("\n")


func _construire(l: PackedStringArray) -> void:
	var fond := ColorRect.new()
	fond.color = Color.BLACK
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var ecran := get_viewport().get_visible_rect().size
	var rouleau := VBoxContainer.new()
	rouleau.alignment = BoxContainer.ALIGNMENT_CENTER
	rouleau.add_theme_constant_override("separation", 14)
	rouleau.size.x = ecran.x
	rouleau.position = Vector2(0, ecran.y)
	fond.add_child(rouleau)

	var espace := FontVariation.new()
	espace.base_font = ThemeDB.fallback_font
	espace.spacing_glyph = 6

	for ligne in l:
		var t := ligne.substr(0, 1)
		var v := ligne.substr(2)
		match t:
			"T":
				rouleau.add_child(_texte(v.to_upper(), 110, Color.WHITE, espace))
				rouleau.add_child(_filet())
			"R":
				rouleau.add_child(_texte(v.to_upper(), 26, OR, espace))
			"N":
				rouleau.add_child(_texte(v, 48, Color.WHITE, null))
			"S":
				var vide := Control.new()
				vide.custom_minimum_size.y = 70
				rouleau.add_child(vide)
			"F":
				var fin := Control.new()
				fin.custom_minimum_size.y = ecran.y * 0.35
				rouleau.add_child(fin)
				rouleau.add_child(_texte(v, 40, GRIS, null))

	# La taille du conteneur n'est connue qu'après une passe de mise en page
	await get_tree().process_frame
	var hauteur := rouleau.get_combined_minimum_size().y
	# On s'arrête quand le dernier message est centré à l'écran
	var arrivee := ecran.y * 0.5 - hauteur + 30.0
	var duree := (ecran.y - arrivee) / VITESSE
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(rouleau, "position:y", arrivee, duree)
	tw.tween_interval(3.0)
	tw.tween_property(fond, "modulate:a", 0.0, 1.5)
	tw.finished.connect(_finir)


func _texte(contenu: String, taille: int, couleur: Color, police: Font) -> Label:
	var lab := Label.new()
	lab.text = contenu
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", taille)
	lab.add_theme_color_override("font_color", couleur)
	if police:
		lab.add_theme_font_override("font", police)
	return lab


func _filet() -> Control:
	var boite := CenterContainer.new()
	var barre := ColorRect.new()
	barre.color = OR
	barre.custom_minimum_size = Vector2(220, 2)
	boite.add_child(barre)
	return boite


func _input(event: InputEvent) -> void:
	if not _peut_passer:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("magnet") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finir()


func _finir() -> void:
	if _termine:
		return
	_termine = true
	fini.emit()
	queue_free()

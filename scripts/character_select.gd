extends Control
## Layar pilih karakter, ditampilkan sebelum tiap permainan.
## Lawan komputer: pemain memilih, komputer mengambil karakter lain secara acak.
## 2 pemain: Pemain 1 memilih dulu; kartunya ditandai dan dikunci, lalu
## Pemain 2 memilih dari karakter yang tersisa.

const Config = preload("res://scripts/game_config.gd")
const UI = preload("res://scripts/ui.gd")
const Characters = preload("res://scripts/characters.gd")
const PortraitScript = preload("res://scripts/portrait.gd")

const MENU_SCENE := "res://scenes/menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

## Pemain yang sedang memilih (0 = bawah, 1 = atas).
var _picking := 0
var _heading: Label
var _cards: Array[Button] = []
## Isi tiap kartu (diredupkan saat kartunya terkunci) dan lencana "Pemain 1".
var _contents: Array[Control] = []
var _badges: Array[Control] = []


func _ready() -> void:
	get_tree().quit_on_go_back = false
	add_child(UI.background())
	var margin := UI.safe_margin(10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var bar := HBoxContainer.new()
	column.add_child(bar)
	var back := UI.button("Kembali", false)
	back.custom_minimum_size.x = 96
	back.pressed.connect(_go_back)
	bar.add_child(back)
	_heading = UI.label("", UI.NORMAL, UI.GOLD)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_heading)
	# Penyeimbang tombol Kembali supaya judul tetap di tengah.
	var balance := Control.new()
	balance.custom_minimum_size.x = 96
	bar.add_child(balance)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	for index in Characters.ROSTER.size():
		row.add_child(_card(index))
	_update_heading()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _card(index: int) -> Button:
	var info: Dictionary = Characters.ROSTER[index]
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(300, 226)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_color: Color = info.get("backdrop", UI.PANEL).lightened(0.08)
	card.add_theme_stylebox_override("normal", UI.box(panel_color))
	card.add_theme_stylebox_override("hover", UI.box(panel_color.lightened(0.1)))
	card.add_theme_stylebox_override("pressed", UI.box(panel_color.lightened(0.18), 8, true))
	card.add_theme_stylebox_override("disabled", UI.box(panel_color.darkened(0.4)))
	card.pressed.connect(_pick.bind(index))
	_cards.append(card)

	# Isi kartu hanya hiasan; sentuhan diteruskan ke tombol di bawahnya.
	# Sprite karakter di kiri, keterangannya di kanan.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	card.add_child(row)
	_contents.append(row)

	# Sprite 64 x 96 diperbesar dua kali.
	var portrait := PortraitScript.new()
	portrait.character = info
	portrait.custom_minimum_size = Vector2(128, 192)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 5)
	row.add_child(box)
	box.add_child(UI.label(info.name, UI.NORMAL, UI.GOLD))
	box.add_child(UI.label(info.title, UI.SMALL, Color("b9d1cb")))
	var bg_label := UI.label("Latar: %s" % info.get("bg_title", ""), UI.SMALL, info.get("bg_accent", Color("8fb0a9")))
	bg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(bg_label)
	box.add_child(_skill("Main lagi", info.stun, info.stun_info))
	box.add_child(_skill("Tembak", info.capture, info.capture_info))

	# Lencana penanda pilihan Pemain 1, di tengah atas kartu.
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", UI.box(UI.GOLD, 8))
	badge.add_child(UI.label("Pemain 1", UI.NORMAL, UI.DARK))
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 6)
	badge.hide()
	card.add_child(badge)
	_badges.append(badge)
	return card


func _skill(trigger: String, skill_name: String, description: String) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	box.add_child(UI.label("%s: %s" % [trigger, skill_name], UI.SMALL))
	var detail := UI.label(description, UI.SMALL, Color("8fb0a9"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail)
	return box


func _update_heading() -> void:
	if Config.mode == Config.Mode.VS_AI:
		_heading.text = "Pilih karaktermu"
	else:
		_heading.text = "Pemain %d, pilih karaktermu" % (_picking + 1)


## Mengunci kartu pilihan Pemain 1 selama Pemain 2 memilih (-1 = tidak ada).
func _lock_card(locked: int) -> void:
	for index in _cards.size():
		var is_locked := index == locked
		_cards[index].disabled = is_locked
		_contents[index].modulate = Color(0.45, 0.45, 0.45) if is_locked else Color.WHITE
		_badges[index].visible = is_locked


func _pick(index: int) -> void:
	# Pemain 2 tidak boleh mengambil karakter yang sudah dipilih Pemain 1.
	if _picking == 1 and index == Config.characters[0]:
		return
	Config.characters[_picking] = index
	if Config.mode == Config.Mode.VS_AI:
		var others: Array[int] = []
		for other in Characters.ROSTER.size():
			if other != index:
				others.append(other)
		Config.characters[1] = others.pick_random()
	elif _picking == 0:
		_picking = 1
		_lock_card(index)
		_update_heading()
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _go_back() -> void:
	if _picking == 1:
		_picking = 0
		_lock_card(-1)
		_update_heading()
	else:
		get_tree().change_scene_to_file(MENU_SCENE)

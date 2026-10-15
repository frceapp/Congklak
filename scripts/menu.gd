extends Control
## Menu utama: atur papan, pilih mode dan tingkat kesulitan, baca cara bermain.

const Config = preload("res://scripts/game_config.gd")
const Logic = preload("res://scripts/congklak_logic.gd")
const UI = preload("res://scripts/ui.gd")

const CHARACTER_SCENE := "res://scenes/character_select.tscn"
const RULES := """[color=#ffd166]Papan[/color]
Ada 2 baris lubang kecil dan 2 lumbung di ujung papan. Papan tradisional punya 7 lubang per baris dengan 7 biji per lubang; keduanya bisa kamu atur di menu utama. Baris bawah dan lumbung kiri milik pemain bawah; baris atas dan lumbung kanan milik pemain atas.

[color=#ffd166]Giliran[/color]
Ketuk salah satu lubang di barismu. Semua bijinya diambil lalu disebar satu per satu searah jarum jam, termasuk ke lumbungmu sendiri. Lumbung lawan dilewati.

[color=#ffd166]Biji terakhir jatuh di...[/color]
- Lumbungmu: kamu main lagi.
- Lubang kosong di barismu yang seberangnya berisi: "tembak"! Biji itu dan semua biji di lubang seberangnya masuk ke lumbungmu.
- Tempat lain, termasuk lubang yang berisi: giliran selesai. Biji yang sudah jatuh tidak diambil lagi.

[color=#ffd166]Akhir permainan[/color]
Permainan selesai begitu salah satu baris kosong. Biji yang tersisa di baris lain masuk ke lumbung pemilik baris itu. Pemilik biji terbanyak di lumbung menang.

[color=#ffd166]Jurus karakter[/color]
Jurus hanya hiasan dan tidak mengubah aturan."""

var _difficulty_buttons: Array[Button] = []
var _holes_label: Label
var _seeds_label: Label
var _rules: Control


func _ready() -> void:
	get_tree().quit_on_go_back = true
	Config.load_settings()
	add_child(UI.background())

	var margin := UI.safe_margin(10)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 340
	column.add_theme_constant_override("separation", 7)
	center.add_child(column)

	column.add_child(_title())
	column.add_child(UI.label("Permainan tradisional Nusantara", UI.SMALL, Color("b9d1cb")))
	column.add_child(_spacer(4))

	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 14)
	column.add_child(board)
	_holes_label = _add_stepper(board, "Lubang", _change_holes)
	_seeds_label = _add_stepper(board, "Biji", _change_seeds)
	_change_holes(0)
	_change_seeds(0)

	var vs_ai := UI.button("Lawan Komputer")
	vs_ai.pressed.connect(_start.bind(Config.Mode.VS_AI))
	column.add_child(vs_ai)

	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 6)
	column.add_child(levels)
	for level in Config.DIFFICULTY_NAMES.size():
		var b := UI.button(Config.DIFFICULTY_NAMES[level], false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_difficulty.bind(level))
		levels.add_child(b)
		_difficulty_buttons.append(b)
	_set_difficulty(Config.difficulty, false)
	column.add_child(_spacer(2))

	var two_players := UI.button("2 Pemain")
	two_players.pressed.connect(_start.bind(Config.Mode.TWO_PLAYERS))
	column.add_child(two_players)

	var rules := UI.button("Cara Bermain", false)
	rules.pressed.connect(_show_rules.bind(true))
	column.add_child(rules)

	_build_rules()


func _notification(what: int) -> void:
	# Tombol kembali Android menutup panel aturan dulu sebelum keluar.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _rules != null and _rules.visible:
		_show_rules(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _rules.visible:
		_show_rules(false)


## Judul besar dengan bayangan gelap bergeser, gaya gim arkade.
func _title() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 48)
	for layer in 2:
		var text := UI.label("CONGKLAK", 40, UI.GOLD if layer == 1 else UI.OUTLINE)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if layer == 0:
			text.offset_left = 3
			text.offset_right = 3
			text.offset_top = 3
			text.offset_bottom = 3
		holder.add_child(text)
	return holder


func _spacer(height: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = height
	return s


## Menambah pengatur angka "judul  [-] nilai [+]" ke `row`; mengembalikan label nilainya.
## `on_change` dipanggil dengan -1 atau +1.
func _add_stepper(row: HBoxContainer, title: String, on_change: Callable) -> Label:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)

	var caption := UI.label(title)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(caption)

	var minus := UI.button("-", false)
	minus.custom_minimum_size.x = 30
	minus.pressed.connect(on_change.bind(-1))
	box.add_child(minus)

	var value := UI.label("", UI.NORMAL, UI.GOLD)
	value.custom_minimum_size.x = 28
	box.add_child(value)

	var plus := UI.button("+", false)
	plus.custom_minimum_size.x = 30
	plus.pressed.connect(on_change.bind(1))
	box.add_child(plus)
	return value


func _change_holes(step: int) -> void:
	Config.holes = clampi(Config.holes + step, Logic.MIN_HOLES, Logic.MAX_HOLES)
	_holes_label.text = str(Config.holes)
	if step != 0:
		Config.save_settings()


func _change_seeds(step: int) -> void:
	Config.seeds = clampi(Config.seeds + step, Logic.MIN_SEEDS, Logic.MAX_SEEDS)
	_seeds_label.text = str(Config.seeds)
	if step != 0:
		Config.save_settings()


func _set_difficulty(level: int, save: bool = true) -> void:
	Config.difficulty = level
	for i in _difficulty_buttons.size():
		UI.set_primary(_difficulty_buttons[i], i == level)
	if save:
		Config.save_settings()


func _start(mode: Config.Mode) -> void:
	Config.mode = mode
	get_tree().change_scene_to_file(CHARACTER_SCENE)


func _build_rules() -> void:
	_rules = UI.overlay()
	add_child(_rules)
	var box := UI.panel(_rules, 560)
	box.add_child(UI.label("Cara Bermain", UI.BIG, UI.GOLD))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 220
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	text.add_theme_font_size_override("normal_font_size", UI.NORMAL)
	text.text = RULES
	scroll.add_child(text)

	var close := UI.button("Tutup")
	close.pressed.connect(_show_rules.bind(false))
	box.add_child(close)
	_rules.hide()


func _show_rules(open: bool) -> void:
	_rules.visible = open
	# Selama panel terbuka, tombol kembali tidak langsung menutup aplikasi.
	get_tree().quit_on_go_back = not open

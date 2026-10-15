extends Control
## Layar permainan: mengatur giliran, lawan komputer, dan tampilan hasil.

const Logic = preload("res://scripts/congklak_logic.gd")
const AI = preload("res://scripts/ai.gd")
const Config = preload("res://scripts/game_config.gd")
const UI = preload("res://scripts/ui.gd")
const BoardScript = preload("res://scripts/board.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const Characters = preload("res://scripts/characters.gd")
const PortraitScript = preload("res://scripts/portrait.gd")
const SkillFxScript = preload("res://scripts/skill_fx.gd")
const UltimateScript = preload("res://scripts/ultimate.gd")

const MENU_SCENE := "res://scenes/menu.tscn"
const CHARACTER_SCENE := "res://scenes/character_select.tscn"
const SPEEDS: Array[float] = [0.12, 0.06, 0.025]
const SPEED_NAMES: Array[String] = ["Normal", "Cepat", "Kilat"]
## Jeda minimum sebelum komputer melangkah, supaya gilirannya terasa wajar.
const AI_THINK_TIME := 0.7
const AI_PLAYER := 1

var _logic := Logic.new(Config.holes, Config.seeds)
var _vs_ai := true
var _first_player := 0
## Pemain yang sedang (atau terakhir) menyebar biji.
var _mover := 0
## Bertambah setiap permainan baru; animasi/AI dari permainan lama diabaikan.
var _game_id := 0

var _board: BoardScript
var _sfx: SfxScript
var _skill_fx: SkillFxScript
var _ultimate: UltimateScript
var _status: Label
var _speed_button: Button
var _sound_button: Button
var _result: Control
var _result_portrait: PortraitScript
var _result_title: Label
var _result_score: Label

var _ai_thread: Thread
var _ai_thread_game := -1
var _ai_request := false
var _ai_result := -1
var _ai_timer := 0.0


func _ready() -> void:
	get_tree().quit_on_go_back = false
	_vs_ai = Config.mode == Config.Mode.VS_AI
	_build_ui()
	_new_game()


func _exit_tree() -> void:
	if _ai_thread != null:
		_ai_thread.wait_to_finish()
		_ai_thread = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_to_menu()


func _process(delta: float) -> void:
	if _ai_thread != null and not _ai_thread.is_alive():
		var move: int = _ai_thread.wait_to_finish()
		_ai_thread = null
		if _ai_thread_game == _game_id:
			_ai_result = move
	if not _ai_request:
		return
	_ai_timer += delta
	if _ai_result < 0:
		if _ai_thread == null:
			_start_ai_thread()
	elif _ai_timer >= AI_THINK_TIME:
		var move := _ai_result
		_ai_request = false
		_ai_result = -1
		_do_move(move)


func _build_ui() -> void:
	# Latar pemandangan seni piksel panoramik non-repetitif yang memadukan dunia kedua karakter.
	add_child(UI.scenery_background(_character(0).id, _character(1).id))
	_sfx = SfxScript.new()
	add_child(_sfx)

	var margin := UI.safe_margin(6)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	column.add_child(bar)

	var menu_button := UI.button("Menu", false)
	menu_button.pressed.connect(_go_to_menu)
	bar.add_child(menu_button)

	_status = UI.label("")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	bar.add_child(_status)

	# Lebar tetap supaya bilah tidak bergeser saat labelnya berganti.
	_speed_button = UI.button("", false)
	_speed_button.custom_minimum_size.x = 84
	_speed_button.pressed.connect(_on_speed_pressed)
	bar.add_child(_speed_button)

	_sound_button = UI.button("Suara", false)
	_sound_button.pressed.connect(_on_sound_pressed)
	bar.add_child(_sound_button)

	var restart_button := UI.button("Ulang", false)
	restart_button.pressed.connect(_new_game)
	bar.add_child(restart_button)

	_board = BoardScript.new()
	_board.setup(_logic)
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _vs_ai:
		_board.player_names = ["Kamu", "Komputer"]
	_board.set_characters(_character(0), _character(1))
	if not _vs_ai:
		# Dua pemain duduk berhadapan: sisi papan diberi warna karakternya dan
		# milik pemain atas diputar menghadap dia.
		_board.set_side_colors(_side_color(0, "board"), _side_color(1, "board"))
		_board.flip_top = true
	_board.pit_pressed.connect(_on_pit_pressed)
	_board.sound_requested.connect(_sfx.play)
	_board.capture_started.connect(_on_capture_started)
	column.add_child(_board)

	# Efek jurus menumpang di papan supaya memakai koordinat yang sama.
	_skill_fx = SkillFxScript.new()
	_skill_fx.board = _board
	_skill_fx.sound_requested.connect(_sfx.play)
	_board.add_child(_skill_fx)

	# Jurus pamungkas pemenang menutupi seluruh layar, di bawah panel hasil.
	_ultimate = UltimateScript.new()
	_ultimate.sound_requested.connect(_sfx.play)
	add_child(_ultimate)

	_build_result_panel()
	_refresh_buttons()


func _character(player: int) -> Dictionary:
	return Characters.ROSTER[Config.characters[player]]


## Warna tema karakter pemain (`key` = "board" atau "backdrop"). Bila kedua
## pemain memilih karakter yang sama, warna pemain atas digelapkan supaya
## kedua sisi tetap bisa dibedakan.
func _side_color(player: int, key: String) -> Color:
	var color: Color = _character(player)[key]
	if player == 1 and Config.characters[0] == Config.characters[1]:
		color = color.darkened(0.3)
	return color


func _build_result_panel() -> void:
	_result = UI.overlay()
	add_child(_result)
	var box := UI.panel(_result, 300)
	# Pemenang: potongan dada sprite (64 x 52) diperbesar dua kali.
	_result_portrait = PortraitScript.new()
	_result_portrait.crop_rows = PortraitScript.BUST_ROWS
	_result_portrait.custom_minimum_size = Vector2(128, 104)
	_result_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_result_portrait)
	_result_title = UI.label("", UI.BIG, UI.GOLD)
	box.add_child(_result_title)
	_result_score = UI.label("")
	box.add_child(_result_score)
	var again := UI.button("Main Lagi")
	again.pressed.connect(_on_play_again)
	box.add_child(again)
	var change := UI.button("Ganti Karakter", false)
	change.pressed.connect(get_tree().change_scene_to_file.bind(CHARACTER_SCENE))
	box.add_child(change)
	var menu := UI.button("Menu Utama", false)
	menu.pressed.connect(_go_to_menu)
	box.add_child(menu)
	_result.hide()


func _refresh_buttons() -> void:
	_board.step_time = SPEEDS[Config.speed]
	_skill_fx.pace = clampf(SPEEDS[Config.speed] / SPEEDS[0], 0.55, 1.0)
	_speed_button.text = SPEED_NAMES[Config.speed]
	# Tombol suara menyala emas saat suara aktif.
	UI.set_primary(_sound_button, Config.sound)


func _new_game() -> void:
	_game_id += 1
	_ai_request = false
	_ai_result = -1
	_board.cancel_animation()
	_board.restore_seeds()
	_skill_fx.cancel()
	_ultimate.clear()
	_logic.reset(_first_player)
	_board.counts = _logic.pits.duplicate()
	_result.hide()
	_start_turn("")


func _start_turn(note: String) -> void:
	var player := _logic.current
	_board.active_player = player
	_status.add_theme_color_override("font_color", Color.WHITE if note.is_empty() else UI.GOLD)
	# Teks dijaga pendek: font piksel lebar dan bilah atas sempit, jadi
	# catatan (bila ada) menggantikan teks giliran biasa.
	if _vs_ai and player == AI_PLAYER:
		_board.selectable = []
		_status.text = note if not note.is_empty() else "Komputer berpikir..."
		_ai_request = true
		_ai_result = -1
		_ai_timer = 0.0
	else:
		_board.selectable = _logic.legal_moves()
		if not note.is_empty():
			_status.text = note
		elif _vs_ai:
			_status.text = "Giliranmu, pilih lubang"
		else:
			_status.text = "Giliran %s" % _board.player_names[player]


func _start_ai_thread() -> void:
	var state: RefCounted = _logic.clone()
	var level := Config.difficulty
	_ai_thread_game = _game_id
	_ai_thread = Thread.new()
	_ai_thread.start(func() -> int: return AI.choose_move(state, level))


func _on_pit_pressed(pit: int) -> void:
	if pit in _board.selectable:
		_do_move(pit)


func _do_move(pit: int) -> void:
	var id := _game_id
	var mover := _logic.current
	_mover = mover
	_board.selectable = []
	_board.active_player = mover
	_status.add_theme_color_override("font_color", Color.WHITE)
	_status.text = "%s menyebar..." % _board.player_names[mover]

	var events: Array = []
	var extra_turn := _logic.play(pit, events)
	await _board.play_events(events)
	if id != _game_id:
		return
	if _board.counts != _logic.pits:
		push_warning("Animasi papan tidak sinkron dengan logika setelah lubang %d" % pit)
	_board.counts = _logic.pits.duplicate()

	# Jurus karakter hanya hiasan: main lagi = jurus stun ke lawan.
	if extra_turn and not _logic.game_over and _logic.current == mover:
		_status.add_theme_color_override("font_color", UI.GOLD)
		_status.text = "%s!" % _character(mover).stun
		await _skill_fx.cast(mover, "stun")
	elif _skill_fx.busy:
		# Jurus tembak masih berjalan; tunggu sampai selesai.
		await _skill_fx.finished
	if id != _game_id:
		return

	if _logic.game_over:
		_show_result()
		return
	_start_turn("%s main lagi!" % _board.player_names[mover] if extra_turn else "")


func _on_capture_started() -> void:
	_skill_fx.cast(_mover, "capture")


func _show_result() -> void:
	var id := _game_id
	var winner := _logic.winner()
	_board.active_player = winner
	_status.add_theme_color_override("font_color", Color.WHITE)
	_status.text = "Permainan selesai"
	if winner >= 0:
		# Jurus pamungkas pemenang (video lalu efek penutup); hanya hiasan.
		await _ultimate.play(_character(winner), winner, _board)
		if id != _game_id:
			return
	_result_portrait.visible = winner >= 0
	if winner >= 0:
		_result_portrait.character = _character(winner)
	if winner < 0:
		_result_title.text = "Seri!"
	elif _vs_ai:
		_result_title.text = "Kamu Menang!" if winner == 0 else "Komputer Menang"
	else:
		_result_title.text = "%s Menang!" % _board.player_names[winner]
	_result_score.text = "%s %d  -  %d %s" % [
		_board.player_names[0], _logic.score(0), _logic.score(1), _board.player_names[1]]
	_sfx.play("lose" if _vs_ai and winner == AI_PLAYER else "win")
	_result.show()


func _on_play_again() -> void:
	# Pemain yang memulai bergantian tiap ronde.
	_first_player = 1 - _first_player
	_new_game()


func _on_speed_pressed() -> void:
	Config.speed = (Config.speed + 1) % SPEEDS.size()
	Config.save_settings()
	_refresh_buttons()


func _on_sound_pressed() -> void:
	Config.sound = not Config.sound
	Config.save_settings()
	_refresh_buttons()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

extends Control
## Jurus pamungkas pemenang, dimainkan sekali di akhir permainan: video
## karakter (assets/scene/<id>_ult.ogv), lalu efek penutup menurut gayanya.
##   "magic"  : lubang hitam di tengah papan yang melahap semua biji.
##   "potion" : asap racun yang menyebar sampai memenuhi layar, dan tetap
##              di sana di belakang panel hasil.
## Murni hiasan. Ketukan di layar melewati video.

signal sound_requested(sound: String)
## Dipancarkan tiap kali satu tahap (video atau efek) selesai, dilewati,
## atau dibatalkan.
signal _step_done

const Config = preload("res://scripts/game_config.gd")
const BoardScript = preload("res://scripts/board.gd")
const UI = preload("res://scripts/ui.gd")

const VIDEO_PATH := "res://assets/scene/%s_ult.ogv"
## Video ditampilkan pada ukuran aslinya supaya pikselnya seragam.
const VIDEO_SIZE := Vector2(640, 360)

const HOLE_GROW := 0.5
const HOLE_DEVOUR := 2.2
const HOLE_SHRINK := 0.4
const HOLE_RADIUS := 40
const HOLE_CORE := Color("05020a")
const HOLE_RING := Color("5b2bd6")
const HOLE_RIM := Color("c79bff")

## Lama asap menyebar dari karakter sampai menutup seluruh layar, dalam detik.
const SMOKE_SPREAD := 1.9
const SMOKE_TIME := 2.4
const SMOKE_CELL := 26.0
const SMOKE_PUFF := 16
const SMOKE_BASE := Color("2a1638")
const SMOKE_COLORS: Array[Color] = [
	Color("7b3fa0"), Color("9b59b6"), Color("5a2d7a"), Color("5d8a3a"), Color("3d5c2a"),
]

## Jari-jari -> tekstur lubang hitam.
static var _hole_textures := {}
static var _puff_texture: ImageTexture

var busy := false
## "", "video", "hole", "smoke", atau "smoke_hold" (asap menetap).
var phase := ""

var _board: BoardScript
var _character := {}
## Bertambah tiap kali jurus dimulai atau dibatalkan; tahap dari putaran lama diabaikan.
var _run := 0
var _time := 0.0
var _center := Vector2.ZERO
## Kepulan asap: {pos, scale, tint, delay, drift}.
var _puffs: Array[Dictionary] = []
var _curtain: ColorRect
var _frame: Control
var _video: VideoStreamPlayer
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.hide()
	add_child(_curtain)

	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.size = VIDEO_SIZE
	_frame.pivot_offset = VIDEO_SIZE / 2.0
	_frame.hide()
	add_child(_frame)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.finished.connect(_on_video_finished)
	_frame.add_child(_video)

	_hint = UI.label("Ketuk untuk lewati", UI.SMALL, Color(1, 1, 1, 0.7))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 6)
	_hint.hide()
	add_child(_hint)

	resized.connect(_place_frame)
	_place_frame()
	set_process(false)


## Memainkan jurus pamungkas `character` milik pemain `player`; selesai
## setelah efek penutupnya habis (asap racun tetap tampil sampai clear()).
func play(character: Dictionary, player: int, board: BoardScript) -> void:
	clear()
	var run := _run
	_board = board
	_character = character
	busy = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var path := VIDEO_PATH % character.id
	if ResourceLoader.exists(path):
		phase = "video"
		_curtain.show()
		_frame.show()
		_hint.show()
		# Di mode berhadapan, video pemain atas diputar menghadap dia.
		_frame.rotation = PI if board.is_flipped(player) else 0.0
		_video.stream = load(path)
		_video.volume_db = 0.0 if Config.sound else -80.0
		_video.play()
		await _step_done
		if run != _run:
			return
		_hide_video()

	_time = 0.0
	set_process(true)
	sound_requested.emit("cast")
	if character.style == "potion":
		phase = "smoke"
		_build_smoke(_to_local(board.portrait_center(player)))
	else:
		phase = "hole"
		_center = _to_local(board.board_center()).round()
	await _step_done
	if run != _run:
		return
	sound_requested.emit("hit")
	busy = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Melewati video yang sedang diputar.
func skip() -> void:
	if phase == "video":
		_step_done.emit()


## Menghentikan jurus dan membersihkan layar (dipakai saat permainan baru).
func clear() -> void:
	_run += 1
	_hide_video()
	phase = ""
	busy = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_puffs.clear()
	set_process(false)
	queue_redraw()
	_step_done.emit()


func _hide_video() -> void:
	if _video == null:
		return
	_video.stop()
	_video.stream = null
	_curtain.hide()
	_frame.hide()
	_hint.hide()


func _on_video_finished() -> void:
	if phase == "video":
		_step_done.emit()


func _gui_input(event: InputEvent) -> void:
	if phase == "video" and event is InputEventMouseButton and event.pressed:
		accept_event()
		skip()


func _place_frame() -> void:
	_frame.position = ((size - VIDEO_SIZE) / 2.0).round()


## Mengubah titik dari koordinat papan ke koordinat lapisan ini.
func _to_local(board_point: Vector2) -> Vector2:
	return board_point + _board.global_position - global_position


func _process(delta: float) -> void:
	_time += delta
	match phase:
		"hole":
			if _time >= HOLE_GROW and _time - delta < HOLE_GROW:
				_board.devour_seeds(_center + global_position - _board.global_position, HOLE_DEVOUR)
			if _time >= HOLE_GROW + HOLE_DEVOUR + HOLE_SHRINK:
				phase = ""
				set_process(false)
				_step_done.emit()
		"smoke":
			if _time >= SMOKE_TIME:
				phase = "smoke_hold"
				_step_done.emit()
	queue_redraw()


func _draw() -> void:
	match phase:
		"hole":
			_draw_hole()
		"smoke", "smoke_hold":
			_draw_smoke()


## Lubang hitam: membesar, menahan selagi biji tersedot, lalu menutup.
func _draw_hole() -> void:
	var grow := clampf(_time / HOLE_GROW, 0.0, 1.0)
	var shrink := clampf((_time - HOLE_GROW - HOLE_DEVOUR) / HOLE_SHRINK, 0.0, 1.0)
	# Layar meredup bertingkat selama lubang hitam terbuka.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.15 * ceilf(grow * (1.0 - shrink) * 3.0)))

	var radius := HOLE_RADIUS * grow * (1.0 - shrink)
	if grow >= 1.0 and shrink <= 0.0 and fmod(_time, 0.3) < 0.15:
		radius += 2.0
	# Jari-jari dibulatkan ke kelipatan 2 supaya teksturnya sedikit dan pikselnya tajam.
	var step := int(radius / 2.0) * 2
	if step < 4:
		return
	var texture := _hole_texture(step)
	draw_texture(texture, _center - Vector2(texture.get_size()) / 2.0)
	# Percik cahaya yang mengorbit tepi lubang.
	for i in 8:
		var angle := _time * 4.0 + i * TAU / 8.0
		var distance := step + 7.0 + 3.0 * sin(_time * 3.0 + i)
		var spark := (_center + Vector2.from_angle(angle) * distance).round()
		draw_rect(Rect2(spark - Vector2.ONE, Vector2(2, 2)), Color.WHITE if i % 2 == 0 else HOLE_RIM)


## Asap racun: kepulan muncul menurut jaraknya dari karakter, membesar
## bertingkat, lalu terus bergoyang pelan.
func _draw_smoke() -> void:
	# Lapisan dasar menggelap bertingkat di paruh akhir sebaran, supaya tidak
	# ada celah di antara kepulan.
	var cover := clampf((_time / SMOKE_SPREAD - 0.5) * 2.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(SMOKE_BASE, ceilf(cover * 4.0) / 4.0))
	for puff in _puffs:
		var age: float = _time - puff.delay
		if age < 0.0:
			continue
		var full: int = puff.scale
		var now := clampi(ceili(full * minf(age / 0.3, 1.0)), 1, full)
		var side := float(SMOKE_PUFF * now)
		var drift: float = puff.drift
		var sway := Vector2(roundf(sin(_time * 1.3 + drift) * 3.0), roundf(cos(_time * 1.1 + drift) * 2.0))
		var corner: Vector2 = puff.pos + sway - Vector2(side, side) / 2.0
		draw_texture_rect(_puff_texture, Rect2(corner, Vector2(side, side)), false, SMOKE_COLORS[puff.tint])


func _build_smoke(origin: Vector2) -> void:
	_make_puff_texture()
	_puffs.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var far := 1.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
		far = maxf(far, origin.distance_to(corner))
	for row in range(-1, int(size.y / SMOKE_CELL) + 2):
		for column in range(-1, int(size.x / SMOKE_CELL) + 2):
			var pos := Vector2(column, row) * SMOKE_CELL + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
			_puffs.append({
				"pos": pos.round(),
				"scale": rng.randi_range(2, 4),
				"tint": rng.randi_range(0, SMOKE_COLORS.size() - 1),
				"delay": pos.distance_to(origin) / far * SMOKE_SPREAD,
				"drift": rng.randf() * TAU,
			})


## Kepulan bundar bergerigi 16 x 16, diwarnai saat digambar.
static func _make_puff_texture() -> void:
	if _puff_texture != null:
		return
	var image := Image.create(SMOKE_PUFF, SMOKE_PUFF, false, Image.FORMAT_RGBA8)
	var middle := Vector2(SMOKE_PUFF, SMOKE_PUFF) / 2.0
	for y in SMOKE_PUFF:
		for x in SMOKE_PUFF:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(middle)
			if distance <= 6.5 or (distance <= 8.0 and (x + y) % 2 == 0):
				image.set_pixel(x, y, Color.WHITE)
	_puff_texture = ImageTexture.create_from_image(image)


## Cakram hitam dengan cincin ungu dan tepi bergerigi yang berpendar.
static func _hole_texture(radius: int) -> ImageTexture:
	if not _hole_textures.has(radius):
		var reach := radius + 4
		var side := reach * 2 + 1
		var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
		for y in side:
			for x in side:
				var distance := Vector2(x, y).distance_to(Vector2(reach, reach))
				if distance <= radius - 4.0:
					image.set_pixel(x, y, HOLE_CORE)
				elif distance <= radius - 1.5:
					image.set_pixel(x, y, HOLE_RING)
				elif distance <= radius + 0.5:
					image.set_pixel(x, y, HOLE_RIM)
				elif distance <= reach and (x + y) % 2 == 0:
					image.set_pixel(x, y, Color(HOLE_RING, 0.7))
		_hole_textures[radius] = ImageTexture.create_from_image(image)
	return _hole_textures[radius]

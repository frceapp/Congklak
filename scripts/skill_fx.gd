extends Control
## Efek jurus karakter bergaya piksel, dipasang sebagai anak papan supaya
## memakai koordinat yang sama. Murni hiasan: tidak mengubah jalannya permainan.
##
## "stun"    : cut-in karakter + nama jurus, lalu jurus melesat dan lawan pusing.
## "capture" : serangan singkat tanpa cut-in (dimainkan selagi biji terbang).

signal finished
signal sound_requested(sound: String)

const BoardScript = preload("res://scripts/board.gd")
const PortraitScript = preload("res://scripts/portrait.gd")

const GOLD := Color("ffd166")
const INK := Color("0a1c19")
const BAND_IN := 0.18
const BAND_OUT_START := 0.8
const BAND_OUT_END := 1.0
## Cut-in = potongan dada sprite (64 x 52) diperbesar tiga kali, setinggi pita.
const CUT_IN_SIZE := Vector2(192, 156)
const BAND_HEIGHT := 156.0

var board: BoardScript
## Di bawah 1 mempercepat efek, mengikuti tombol laju.
var pace := 1.0
var busy := false

var _kind := ""
var _caster := 0
var _character := {}
var _time := 0.0
var _shot_start := 0.0
var _shot_end := 0.0
var _end := 0.0
var _hit := false
var _cut_in: PortraitScript


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cut_in = PortraitScript.new()
	_cut_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut_in.crop_rows = PortraitScript.BUST_ROWS
	_cut_in.size = CUT_IN_SIZE
	_cut_in.pivot_offset = _cut_in.size / 2.0
	_cut_in.hide()
	add_child(_cut_in)
	set_process(false)


## Memainkan jurus milik pemain `caster`; selesai ketika efeknya habis.
func cast(caster: int, kind: String) -> void:
	_character = board.character(caster)
	if _character.is_empty():
		return
	_caster = caster
	_kind = kind
	_time = 0.0
	_hit = false
	busy = true
	if kind == "stun":
		_shot_start = 0.85
		_shot_end = 1.2
		_end = 1.95
	else:
		_shot_start = 0.0
		_shot_end = 0.35
		_end = 1.0
	_cut_in.character = _character
	# Di mode berhadapan, cut-in pemain atas diputar menghadap pemain itu.
	_cut_in.rotation = PI if board.is_flipped(caster) else 0.0
	_place_cut_in()
	set_process(true)
	sound_requested.emit("cast")
	await finished


func cancel() -> void:
	if busy:
		_stop()


func _stop() -> void:
	busy = false
	set_process(false)
	_cut_in.hide()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta / pace
	if not _hit and _time >= _shot_end:
		_hit = true
		sound_requested.emit("hit")
		_shake(board.portrait(1 - _caster))
	if _time >= _end:
		_stop()
		finished.emit()
		return
	_place_cut_in()
	queue_redraw()


## Potret lawan bergetar beberapa piksel ke kiri dan kanan.
func _shake(target: Control) -> void:
	var home := target.position
	var tween := target.create_tween()
	for i in 6:
		tween.tween_property(target, "position", home + Vector2(3 if i % 2 == 0 else -3, 0), 0.05)
	tween.tween_property(target, "position", home, 0.05)


## 0..1: seberapa terbuka pita cut-in pada saat ini.
func _band_open() -> float:
	if _kind != "stun":
		return 0.0
	return minf(smoothstep(0.0, BAND_IN, _time), 1.0 - smoothstep(BAND_OUT_START, BAND_OUT_END, _time))


func _place_cut_in() -> void:
	var open := _band_open()
	_cut_in.visible = open > 0.0
	# Masuk dari sisi pemain yang mengeluarkan jurus, lalu bergeser pelan.
	var rest := size.x * 0.08 + _time * 8.0
	var x := lerpf(-CUT_IN_SIZE.x, rest, open)
	if _caster == 1:
		x = size.x - CUT_IN_SIZE.x - x
	_cut_in.position = Vector2(x, (size.y - CUT_IN_SIZE.y) / 2.0).round()


func _draw() -> void:
	if not busy:
		return
	# Jurus berangkat dari badan pemakainya dan mengenai kepala lawan.
	var from := board.portrait_center(_caster)
	var to := board.portrait_head(1 - _caster)
	if _kind == "stun":
		_draw_band()
	elif _time < 0.7:
		# Tanpa cut-in: nama jurus muncul sekilas di atas kepala pemakainya.
		_label(board.portrait_overhead(_caster), _character.capture + "!", 2, _color(),
				board.is_flipped(_caster))

	if _time > _shot_start and _time < _shot_end:
		_draw_shot(from, to, inverse_lerp(_shot_start, _shot_end, _time))
	if _time >= _shot_end:
		_draw_impact(to, inverse_lerp(_shot_end, _end, _time))


## Pita gelap yang membuka dari tengah, dengan nama karakter dan jurusnya.
func _draw_band() -> void:
	var open := _band_open()
	if open <= 0.0:
		return
	var height := roundf(BAND_HEIGHT * open)
	var top := roundf((size.y - height) / 2.0)
	draw_rect(Rect2(0, top, size.x, height), INK)
	draw_rect(Rect2(0, top, size.x, 2), _color())
	draw_rect(Rect2(0, top + height - 2, size.x, 2), _color())
	if open < 0.9:
		return

	var direction := 1.0 if _caster == 0 else -1.0
	var center := Vector2(size.x / 2.0 + direction * (CUT_IN_SIZE.x * 0.5 + 8.0), size.y / 2.0)
	# Untuk pemain yang melihat dari seberang, susunan atas-bawahnya ikut terbalik.
	var flipped := board.is_flipped(_caster)
	var down := -1.0 if flipped else 1.0
	_label(center + Vector2(0, -22 * down), _character.name, 2, Color.WHITE, flipped)
	_label(center + Vector2(0, 10 * down), _character.stun + "!", 3, GOLD, flipped)


## Jurus yang sedang melesat dari `from` ke `to`; f = 0..1.
func _draw_shot(from: Vector2, to: Vector2, f: float) -> void:
	var u := board.unit()
	var color := _color()
	var p := from.lerp(to, f).round()
	match _character.style:
		"magic":
			if _kind == "capture":
				# Zoltraak: sinar lurus yang memanjang cepat lalu menipis.
				var tip := from.lerp(to, minf(f * 1.6, 1.0)).round()
				var width := roundf(u * 0.3 * (1.0 - 0.6 * f))
				draw_line(from, tip, color, width + 4.0)
				draw_line(from, tip, Color.WHITE, maxf(width - 2.0, 2.0))
				draw_circle(tip, width, Color.WHITE)
			else:
				draw_line(from.lerp(to, maxf(f - 0.3, 0.0)).round(), p, color, 4.0)
				_orb(p, roundf(u * 0.16), color)
		"potion":
			# Botol ramuan yang dilempar melambung sambil berputar.
			var bottle := (from.lerp(to, f) + Vector2(0, -sin(PI * f) * u * 1.2)).round()
			var neck := Vector2.from_angle(f * TAU * 2.0 - PI / 2.0) * 9.0
			draw_line(bottle, bottle + neck, Color("efe9d8"), 4.0)
			draw_circle(bottle, 7.0, INK)
			draw_circle(bottle, 6.0, _liquid())
			draw_rect(Rect2(bottle - Vector2(3, 3), Vector2(2, 2)), Color.WHITE)


## Akibat jurus di potret lawan; f = 0..1 sejak jurus mengenai.
func _draw_impact(to: Vector2, f: float) -> void:
	var u := board.unit()
	var color := _color()
	# Efek berkedip di akhir alih-alih memudar halus.
	var visible_now := f < 0.75 or fmod(_time, 0.12) < 0.06
	if visible_now:
		match _character.style:
			"magic":
				if _kind == "capture":
					draw_arc(to, roundf(u * (0.3 + 0.6 * f)), 0.0, TAU, 32, color, 3.0)
					for i in 8:
						var ray := Vector2.from_angle(i * TAU / 8.0)
						draw_line(to + ray * u * (0.2 + 0.5 * f), to + ray * u * (0.4 + 0.65 * f), Color.WHITE, 2.0)
				else:
					# Lingkaran sihir berputar yang mengikat lawan.
					var spin := _time * 2.5
					draw_arc(to, roundf(u * 0.62), 0.0, TAU, 40, color, 2.0)
					draw_arc(to, roundf(u * 0.5), spin, spin + TAU * 0.8, 32, Color.WHITE, 2.0)
					for i in 6:
						var tick := Vector2.from_angle(-spin + i * TAU / 6.0)
						draw_line(to + tick * u * 0.5, to + tick * u * 0.62, color, 2.0)
			"potion":
				# Kepulan asap kotak-kotak yang mengembang dan naik.
				for i in 6:
					var drift := Vector2.from_angle(i * TAU / 6.0 + 0.4) * u * (0.15 + 0.45 * f)
					var puff := roundf(4.0 + 8.0 * f)
					var corner := (to + drift + Vector2(0, -u * 0.35 * f)).round() - Vector2(puff, puff)
					draw_rect(Rect2(corner, Vector2(puff, puff) * 2.0), _liquid().darkened(0.15 * (i % 2)))

	if _kind == "stun":
		# Bintang berputar mengelilingi kepala lawan yang pusing, dengan
		# tulisan di atasnya.
		var target := 1 - _caster
		for i in 3:
			var orbit := _time * 7.0 + i * TAU / 3.0
			_star((to + Vector2(cos(orbit) * u * 0.7, sin(orbit) * u * 0.2)).round(), GOLD)
		if visible_now:
			_label(board.portrait_overhead(target), "STUN!", 2, GOLD, board.is_flipped(target))


func _color() -> Color:
	return _character.color


func _liquid() -> Color:
	return _character.color if _kind == "stun" else Color("8fd16a")


## Bola sihir: inti putih dengan pinggiran berwarna.
func _orb(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius + 3.0, INK)
	draw_circle(center, radius + 2.0, color)
	draw_circle(center, maxf(radius - 2.0, 2.0), Color.WHITE)


## Bintang piksel berbentuk tanda tambah 7 x 7.
func _star(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(1, 4), Vector2(3, 9)), INK)
	draw_rect(Rect2(center - Vector2(4, 1), Vector2(9, 3)), INK)
	draw_rect(Rect2(center - Vector2(0, 3), Vector2(1, 7)), color)
	draw_rect(Rect2(center - Vector2(3, 0), Vector2(7, 1)), color)
	draw_rect(Rect2(center - Vector2(1, 1), Vector2(3, 3)), color)


## Teks terpusat di `center` dengan bayangan gelap; `text_scale` = kelipatan font piksel 8.
## `flipped` memutar teks 180 derajat untuk pemain di seberang.
func _label(center: Vector2, text: String, text_scale: int, color: Color, flipped: bool = false) -> void:
	var width := 480.0
	var origin := Vector2(-width / 2.0, 4.0 * text_scale)
	var font := get_theme_default_font()
	draw_set_transform(center.round(), PI if flipped else 0.0)
	draw_string(font, origin + Vector2(text_scale, text_scale), text, HORIZONTAL_ALIGNMENT_CENTER,
			width, 8 * text_scale, INK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_CENTER, width, 8 * text_scale, color)
	draw_set_transform(Vector2.ZERO)

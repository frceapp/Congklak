extends Control
## Papan congklak bergaya piksel: menggambar papan dan biji, menerima sentuhan,
## dan menganimasikan penyebaran biji.
##
## Tata letak di layar (pemain 0 duduk di bawah, pemain 1 di atas):
##   lumbung pemain 0 di kiri, lumbung pemain 1 di kanan,
##   baris bawah = lubang pemain 0 dari kanan ke kiri,
##   baris atas  = lubang pemain 1 dari kiri ke kanan,
## sehingga biji bergerak searah jarum jam.
## Karakter pemain 0 berdiri di kiri papan dan karakter pemain 1 di kanan,
## masing-masing di sisi lumbungnya.
##
## Semua sprite digambar pada ukuran aslinya di koordinat bulat supaya
## pikselnya tetap tajam dan seragam.

signal pit_pressed(pit: int)
signal sound_requested(sound: String)
## Dipancarkan saat animasi "tembak" dimulai.
signal capture_started

const Logic = preload("res://scripts/congklak_logic.gd")
const PortraitScript = preload("res://scripts/portrait.gd")

## Warna papan bawaan. Garis tepi, serat, dan lubang diturunkan dari warna
## sisi papan, jadi tiap sisi bisa diberi warna sendiri (mode 2 pemain).
const WOOD := Color("a8703c")
const GOLD := Color("ffd166")
const GOLD_DIM := Color("c08a2e")
const RED := Color("ff6b5e")
const INK := Color("2b1b12")

## Tinggi jalur di atas dan bawah papan untuk nama pemain.
const STRIP := 22.0
## Layar selebar ini atau lebih (rasio ponsel) menampilkan karakter dua kali
## ukuran sprite; di layar sempit karakter tampil satu kali supaya papan muat.
const BIG_CHARACTER_WIDTH := 700.0
## Bagian lebar sprite yang benar-benar dicadangkan di sisi papan; sisanya
## (tepi sprite yang kosong) boleh menimpa ujung papan.
const CHARACTER_COLUMN := 0.84

# Biji: o = garis tepi, w = kilau, a = warna dasar, b = bayangan.
const SEED_SPRITE: Array[String] = [
	"..ooooo..",
	".oaaaaao.",
	"oawwaaaao",
	"oawaaaaao",
	"oaaaaaabo",
	"oaaaaaabo",
	"oaaaaabbo",
	".oabbbbo.",
	"..ooooo..",
]
const SEED_SIZE := 9
const SEED_OUTLINE := Color("5a3d22")
const SEED_COLORS: Array[Color] = [
	Color("f6ecd8"), Color("e9d6b1"), Color("fffaf0"), Color("dcc59b"), Color("f0e2c4"),
]
## Jarak antarbiji pada susunan spiral di dalam lubang, dalam piksel.
const SEED_SPACING := 4.7
const GOLDEN_ANGLE := 2.39996
## Batas jumlah biji yang digambar saat tersedot ke tangan.
const MAX_ABSORBED := 30

## Satu sel per warna di SEED_COLORS, berjajar mendatar.
static var _seed_atlas: ImageTexture
# Tekstur yang bergantung pada ukuran papan, dikunci dengan jari-jarinya.
static var _pit_textures := {}
static var _ring_textures := {}
static var _hand_textures := {}


## Satu biji yang sedang melayang menuju lubang tujuannya.
class Flyer:
	var from: Vector2
	var pit: int
	var slot: int
	## Negatif selama biji masih menunggu gilirannya berangkat.
	var time: float
	var duration: float
	var arc: float
	var sound: String


## Jumlah biji yang sedang ditampilkan (bisa tertinggal dari logika selama animasi).
var counts := PackedInt32Array()
var selectable: Array[int] = []
var active_player := 0:
	set(value):
		active_player = value
		_refresh_portraits()
var player_names: Array[String] = ["Pemain 1", "Pemain 2"]
## Mode 2 pemain berhadapan: potret, nama, dan angka milik pemain atas
## diputar 180 derajat supaya terbaca dari seberang ponsel.
var flip_top := false:
	set(value):
		flip_top = value
		_refresh_portraits()
		if _backdrop != null:
			_update_layout()
## Lama tangan berpindah satu lubang, dalam detik. Boleh diubah di tengah animasi.
var step_time := 0.12:
	set(value):
		step_time = value
		if _tween != null and _tween.is_valid():
			_tween.set_speed_scale(_built_step / step_time)

## Dipakai hanya untuk bentuk papan (jumlah lubang, mana yang lumbung).
var _rules := Logic.new()
## Lebar satu lubang, dalam piksel bulat.
var _unit := 60.0
var _board := Rect2()
var _pos: Array[Vector2] = []
## Warna sisi papan pemain bawah dan atas.
var _side_colors: Array[Color] = [WOOD, WOOD]
## Ujung kiri (lumbung pemain bawah) dan ujung kanan (lumbung pemain atas).
var _cap_styles: Array[StyleBoxFlat] = [StyleBoxFlat.new(), StyleBoxFlat.new()]
var _shadow_style := StyleBoxFlat.new()
## Lapisan papan dan lubang; hanya digambar ulang saat ukuran berubah.
var _backdrop: Control
## Karakter pemain bawah dan atas (entri Characters.ROSTER; kosong = tanpa potret).
var _characters: Array[Dictionary] = [{}, {}]
var _portraits: Array[PortraitScript] = []
var _tween: Tween
## Nilai step_time ketika tween giliran ini disusun.
var _built_step := 0.12
var _hand_shown := false
var _hand_pos := Vector2.ZERO
var _hand_count := 0
var _flyers: Array[Flyer] = []
## Biji yang sedang tersedot dari lubang ke tangan: {pit, count, t, duration}.
var _absorbs: Array[Dictionary] = []
var _pulses := {}
## Efek penutup lubang hitam: semua biji tersedot berputar ke `_devour_target`.
## `_devour_time` negatif berarti efeknya tidak sedang berjalan.
var _devour_target := Vector2.ZERO
var _devour_time := -1.0
var _devour_duration := 1.0
var _seeds_hidden := false
var _time := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for style in _cap_styles:
		style.anti_aliasing = false
		style.set_border_width_all(2)
	# Sisi ujung yang menempel ke bagian tengah papan tidak bergaris tepi.
	_cap_styles[0].border_width_right = 0
	_cap_styles[1].border_width_left = 0
	_shadow_style.bg_color = Color(0, 0, 0, 0.35)
	_shadow_style.anti_aliasing = false
	_make_seed_atlas()

	_backdrop = Control.new()
	_backdrop.show_behind_parent = true
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)

	for player in 2:
		var node := PortraitScript.new()
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)
		_portraits.append(node)

	resized.connect(_update_layout)
	setup(_rules)
	set_characters(_characters[0], _characters[1])


## Menyesuaikan papan dengan ukuran permainan `rules` dan menampilkan isinya.
func setup(rules: Logic) -> void:
	_rules = rules
	cancel_animation()
	counts = rules.pits.duplicate()
	_pos.resize(rules.pit_count())
	selectable = []
	# Sebelum _ready() lapisan papan belum ada; tata letak dihitung di sana.
	if _backdrop != null:
		_update_layout()


## Memasang karakter pemain bawah (kiri papan) dan pemain atas (kanan papan).
func set_characters(bottom: Dictionary, top: Dictionary) -> void:
	_characters = [bottom, top]
	for player in _portraits.size():
		_portraits[player].character = _characters[player]
		_portraits[player].visible = not _characters[player].is_empty()
	_refresh_portraits()
	# Ada atau tidaknya karakter mengubah ruang yang tersisa untuk papan.
	if _backdrop != null:
		_update_layout()


## Memberi warna berbeda pada sisi papan pemain bawah dan pemain atas.
func set_side_colors(bottom: Color, top: Color) -> void:
	_side_colors = [bottom, top]
	if _backdrop != null:
		_backdrop.queue_redraw()


func character(player: int) -> Dictionary:
	return _characters[player]


## Benar bila milik `player` digambar terbalik (pemain atas di mode berhadapan).
func is_flipped(player: int) -> bool:
	return flip_top and player == 1


func portrait(player: int) -> Control:
	return _portraits[player]


## Titik tengah sprite karakter pemain, dalam koordinat papan.
func portrait_center(player: int) -> Vector2:
	return _portraits[player].position + _portraits[player].size / 2.0


## Titik tengah kepala karakter pemain (mengikuti arah hadapnya).
func portrait_head(player: int) -> Vector2:
	return portrait_center(player) + _up(player) * _portraits[player].size.y * 0.25


## Titik sedikit di atas kepala karakter pemain, tempat tulisan efek jurus.
func portrait_overhead(player: int) -> Vector2:
	return portrait_center(player) + _up(player) * (_portraits[player].size.y * 0.5 + 10.0)


## Arah "atas" menurut karakter pemain: terbalik untuk pemain atas di mode berhadapan.
func _up(player: int) -> Vector2:
	return Vector2.DOWN if is_flipped(player) else Vector2.UP


## Lebar satu lubang papan, dalam piksel.
func unit() -> float:
	return _unit


## Titik tengah papan, dalam koordinat papan.
func board_center() -> Vector2:
	return _board.get_center()


## Menyedot semua biji ke `target` (koordinat papan) sambil berputar, lalu
## menyembunyikannya. Angka skor tidak berubah. Dibatalkan oleh restore_seeds().
func devour_seeds(target: Vector2, duration: float) -> void:
	_devour_target = target
	_devour_duration = maxf(duration, 0.01)
	_devour_time = 0.0


func restore_seeds() -> void:
	_devour_time = -1.0
	_seeds_hidden = false


func _refresh_portraits() -> void:
	for player in _portraits.size():
		_portraits[player].highlighted = player == active_player
		_portraits[player].modulate = Color.WHITE if player == active_player else Color(0.62, 0.62, 0.62)
		_portraits[player].rotation = PI if is_flipped(player) else 0.0


func _process(delta: float) -> void:
	_time += delta
	if _devour_time >= 0.0:
		_devour_time += delta
		if _devour_time >= _devour_duration:
			_devour_time = -1.0
			_seeds_hidden = true

	var i := 0
	while i < _flyers.size():
		var flyer := _flyers[i]
		flyer.time += delta
		if flyer.time >= flyer.duration:
			_flyers.remove_at(i)
			_land(flyer, true)
		else:
			i += 1

	for k in range(_absorbs.size() - 1, -1, -1):
		_absorbs[k].t += delta / _absorbs[k].duration
		if _absorbs[k].t >= 1.0:
			_absorbs.remove_at(k)

	for pit in _pulses.keys():
		_pulses[pit].t -= delta * 2.4
		if _pulses[pit].t <= 0.0:
			_pulses.erase(pit)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for pit in selectable:
			if event.position.distance_to(_pos[pit]) <= _radius(pit) * 1.2:
				accept_event()
				pit_pressed.emit(pit)
				return


## Menjalankan animasi satu giliran dari catatan langkah Logic.play().
## Seluruh giliran disusun menjadi satu Tween supaya tangan meluncur tanpa
## jeda antar-lubang; biji yang dilepas melayang sendiri lewat `_flyers`.
func play_events(events: Array) -> void:
	cancel_animation()
	if events.is_empty():
		return
	_built_step = step_time
	var tween := create_tween()
	_tween = tween
	var at := -1
	for i in events.size():
		var e: Dictionary = events[i]
		match e.type:
			"pickup":
				tween.tween_callback(_begin_pickup.bind(e.pit, e.count))
				tween.tween_interval(step_time * 1.8)
				at = e.pit
			"drop":
				# Hanya awal dan akhir satu rangkaian yang dipercepat/diperlambat;
				# di tengah rangkaian tangan bergerak dengan kecepatan tetap.
				var starts: bool = events[i - 1].type != "drop"
				var stops: bool = i + 1 >= events.size() or events[i + 1].type != "drop"
				var hop := tween.tween_method(_glide.bind(at, e.pit), 0.0, 1.0,
						_hop_time(at, e.pit, starts, stops))
				if starts and stops:
					hop.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				elif starts:
					hop.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
				elif stops:
					hop.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_callback(_release_seed.bind(e.pit))
				at = e.pit
			"capture":
				tween.tween_callback(_begin_capture.bind(e.pit, e.opposite, e.store))
				tween.tween_interval(_capture_time(e.count))
			"sweep":
				tween.tween_callback(_begin_sweep.bind(e.pits, e.store))
				tween.tween_interval(_capture_time(e.count))
	tween.tween_callback(func() -> void: _hand_shown = false)
	tween.tween_interval(_drop_time() + 0.1)
	await tween.finished
	_land_all()


func cancel_animation() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_flyers.clear()
	_absorbs.clear()
	_pulses.clear()
	_hand_shown = false


func _glide(progress: float, from_pit: int, to_pit: int) -> void:
	_hand_pos = _pos[from_pit].lerp(_pos[to_pit], progress)


func _hop_time(from_pit: int, to_pit: int, starts: bool, stops: bool) -> float:
	var hops := maxf(_pos[from_pit].distance_to(_pos[to_pit]) / _unit, 0.5)
	# Langkah yang berakselerasi (sinus) dibuat pi/2 kali lebih lama supaya
	# kecepatan di ujungnya sama dengan kecepatan tetap langkah di sebelahnya.
	var stretch := 1.0
	if starts != stops:
		stretch = PI / 2.0
	elif starts:
		stretch = 1.3
	return step_time * hops * stretch


func _drop_time() -> float:
	return clampf(step_time * 1.5, 0.06, 0.18)


## Faktor percepatan animasi tembak mengikuti tombol laju.
func _capture_pace() -> float:
	return clampf(step_time / 0.12, 0.35, 1.0)


func _capture_stagger(count: int) -> float:
	return minf(0.04, 0.5 / maxi(count, 1)) * _capture_pace()


func _capture_time(count: int) -> float:
	return (0.3 + 0.5) * _capture_pace() + _capture_stagger(count) * count + 0.1


func _begin_pickup(pit: int, count: int) -> void:
	_land_into(pit)
	_absorbs.append({
		"pit": pit, "count": mini(counts[pit], MAX_ABSORBED), "t": 0.0,
		"duration": clampf(step_time * 1.6, 0.08, 0.22),
	})
	counts[pit] = 0
	_hand_pos = _pos[pit]
	_hand_count = count
	_hand_shown = true
	_pulse(pit, GOLD)
	sound_requested.emit("pickup")


func _release_seed(pit: int) -> void:
	_hand_count -= 1
	var flyer := Flyer.new()
	flyer.from = _hand_center()
	flyer.pit = pit
	flyer.slot = counts[pit] + _pending_into(pit)
	flyer.duration = _drop_time()
	flyer.sound = "store" if _rules.is_store(pit) else "drop"
	_flyers.append(flyer)


## Tembak: biji di kedua lubang terbang berurutan ke lumbung.
func _begin_capture(pit: int, opposite_pit: int, store: int) -> void:
	_land_into(pit)
	_land_into(opposite_pit)
	_hand_shown = false
	_pulse(pit, RED)
	_pulse(opposite_pit, RED)
	sound_requested.emit("capture")
	capture_started.emit()

	_fly_to_store([opposite_pit, pit], store)


## Akhir permainan: biji yang tersisa di satu baris terbang ke lumbung pemiliknya.
func _begin_sweep(pits: Array, store: int) -> void:
	_hand_shown = false
	for pit: int in pits:
		_land_into(pit)
		_pulse(pit, GOLD)
	sound_requested.emit("capture")
	_fly_to_store(pits, store)


## Mengosongkan lubang-lubang `pits` dan menerbangkan bijinya berurutan ke `store`.
func _fly_to_store(pits: Array, store: int) -> void:
	var sources: Array[Vector2] = []
	for pit: int in pits:
		for k in counts[pit]:
			sources.append(_slot_pos(pit, k))
		counts[pit] = 0

	var pace := _capture_pace()
	var stagger := _capture_stagger(sources.size())
	var first_slot := counts[store] + _pending_into(store)
	for i in sources.size():
		var flyer := Flyer.new()
		flyer.from = sources[i]
		flyer.pit = store
		flyer.slot = first_slot + i
		flyer.time = -(0.3 * pace + stagger * i)
		flyer.duration = 0.5 * pace
		flyer.arc = _unit * 0.45
		flyer.sound = "store" if i % 3 == 0 else ""
		_flyers.append(flyer)


func _land(flyer: Flyer, audible: bool) -> void:
	counts[flyer.pit] += 1
	if audible:
		_pulse(flyer.pit, Color.WHITE)
		if not flyer.sound.is_empty():
			sound_requested.emit(flyer.sound)


## Menuntaskan biji yang masih melayang ke `pit` sebelum isinya diambil.
func _land_into(pit: int) -> void:
	for k in range(_flyers.size() - 1, -1, -1):
		if _flyers[k].pit == pit:
			_land(_flyers[k], false)
			_flyers.remove_at(k)


func _land_all() -> void:
	for flyer in _flyers:
		_land(flyer, false)
	_flyers.clear()


func _pending_into(pit: int) -> int:
	var pending := 0
	for flyer in _flyers:
		if flyer.pit == pit:
			pending += 1
	return pending


func _pulse(pit: int, color: Color) -> void:
	_pulses[pit] = {"color": color, "t": 1.0}


## Jari-jari lubang dalam piksel bulat.
func _radius(pit: int) -> int:
	return roundi(_unit * (0.68 if _rules.is_store(pit) else 0.43))


func _hand_radius() -> int:
	return roundi(_unit * 0.3)


func _hand_center() -> Vector2:
	return _hand_pos + Vector2(0, -roundf(_unit * 0.1))


## Posisi biji ke-k di dalam lubang: spiral bunga matahari, dan biji yang
## tidak muat menumpuk di tepi lubang.
func _slot_pos(pit: int, k: int) -> Vector2:
	var limit := _radius(pit) - SEED_SIZE * 0.75
	var distance := minf(SEED_SPACING * sqrt(k + 0.6), limit)
	var angle := k * GOLDEN_ANGLE + pit * 1.7
	return _pos[pit] + Vector2(cos(angle), sin(angle)) * distance


## Indeks warna (sel atlas) untuk biji ke-k di lubang `pit`.
func _slot_tint(pit: int, k: int) -> int:
	return (k * 7 + pit * 3) % SEED_COLORS.size()


## Ukuran teks angka: 2 kali font dasar, atau 1 kali di papan yang sempit.
func _label_scale() -> int:
	return 2 if _unit >= 50.0 else 1


func _update_layout() -> void:
	# Karakter berdiri di kolom kiri dan kanan; papan mengisi ruang di antaranya.
	var has_characters := not (_characters[0].is_empty() and _characters[1].is_empty())
	var sprite_scale := 2.0 if size.x >= BIG_CHARACTER_WIDTH else 1.0
	var sprite_size := Vector2(PortraitScript.SIZE) * sprite_scale
	var column := roundf(sprite_size.x * CHARACTER_COLUMN) if has_characters else 0.0

	# Lebar papan: h lubang + 2 lumbung selebar 1,5 unit + tepi 0,4 unit.
	# Tinggi 2,8 unit, diapit dua jalur untuk nama pemain.
	var holes := _rules.holes
	_unit = maxf(floorf(minf((size.x - column * 2.0) / (holes + 3.6), (size.y - STRIP * 2.0) / 2.8)), 8.0)
	var board_size := Vector2(roundf(_unit * (holes + 3.4)), roundf(_unit * 2.8))
	_board = Rect2(((size - board_size) / 2.0).round(), board_size)

	var store_width := _unit * 1.5
	var left := _board.position.x + _unit * 0.2
	var center_y := _board.get_center().y
	var row := _unit * 0.6
	for i in holes:
		_pos[i] = Vector2(left + store_width + (holes - 0.5 - i) * _unit, center_y + row).round()
		_pos[holes + 1 + i] = Vector2(left + store_width + (i + 0.5) * _unit, center_y - row).round()
	_pos[_rules.store_of(0)] = Vector2(left + store_width / 2.0, center_y).round()
	_pos[_rules.store_of(1)] = Vector2(left + store_width * 1.5 + holes * _unit, center_y).round()

	var corner := int(_unit * 1.3)
	_shadow_style.set_corner_radius_all(corner)
	_cap_styles[0].corner_radius_top_left = corner
	_cap_styles[0].corner_radius_bottom_left = corner
	_cap_styles[1].corner_radius_top_right = corner
	_cap_styles[1].corner_radius_bottom_right = corner

	# Karakter berdiri di lantai (tepi bawah) di sisi lumbungnya. Di mode
	# berhadapan, karakter pemain atas terbalik dan "berdiri" di tepi atas.
	for player in _portraits.size():
		_portraits[player].size = sprite_size
		_portraits[player].pivot_offset = sprite_size / 2.0
	_portraits[0].position = Vector2(0, size.y - sprite_size.y).round()
	_portraits[1].position = Vector2(size.x - sprite_size.x,
			0.0 if is_flipped(1) else size.y - sprite_size.y).round()
	_backdrop.queue_redraw()
	queue_redraw()


## Papan, serat kayu, dan lubang; cukup dibangun sekali per ukuran.
##
## Papan terdiri dari tiga bagian: ujung kiri (lumbung pemain bawah), ujung
## kanan (lumbung pemain atas), dan bagian tengah yang terbelah dua baris.
## Tiap bagian memakai warna sisi pemiliknya.
func _draw_backdrop() -> void:
	_backdrop.draw_style_box(_shadow_style, Rect2(_board.position + Vector2(0, 5), _board.size))
	var bottom := _side_colors[0]
	var top := _side_colors[1]
	var cap := roundf(_unit * 1.7)
	var middle := Rect2(_board.position.x + cap, _board.position.y, _board.size.x - cap * 2.0, _board.size.y)
	var half := roundf(middle.size.y / 2.0)

	for player in 2:
		_cap_styles[player].bg_color = _side_colors[player]
		_cap_styles[player].border_color = _edge(_side_colors[player])
	_backdrop.draw_style_box(_cap_styles[0], Rect2(_board.position, Vector2(cap, _board.size.y)))
	_backdrop.draw_style_box(_cap_styles[1], Rect2(middle.end.x, _board.position.y, cap, _board.size.y))
	_backdrop.draw_rect(Rect2(middle.position, Vector2(middle.size.x, half)), top)
	_backdrop.draw_rect(Rect2(middle.position.x, middle.position.y + half, middle.size.x, middle.size.y - half), bottom)
	# Garis tepi atas dan bawah bagian tengah, lalu sorot terang di tepi atas.
	_backdrop.draw_rect(Rect2(middle.position, Vector2(middle.size.x, 2)), _edge(top))
	_backdrop.draw_rect(Rect2(middle.position.x, middle.end.y - 2, middle.size.x, 2), _edge(bottom))
	_backdrop.draw_rect(Rect2(middle.position.x, middle.position.y + 3, middle.size.x, 1), top.lightened(0.25))
	# Serat kayu, mengikuti warna baris yang dilewatinya.
	for k in 5:
		var y := roundf(_board.position.y + _board.size.y * (0.2 + 0.15 * k))
		var shift := _unit * (0.3 if k % 2 == 0 else 0.8)
		var grain := (top if y < middle.position.y + half else bottom).darkened(0.12)
		_backdrop.draw_rect(Rect2(middle.position.x + shift, y, middle.size.x - shift * 2.0, 1), grain)
	if bottom != top:
		# Garis pemisah di perbatasan dua warna.
		var seam := _edge(bottom).lerp(_edge(top), 0.5)
		_backdrop.draw_rect(Rect2(middle.position.x, middle.position.y + half, middle.size.x, 1), seam)
		_backdrop.draw_rect(Rect2(middle.position.x, middle.position.y + 2, 1, half - 2), seam)
		_backdrop.draw_rect(Rect2(middle.end.x - 1, middle.position.y + half, 1, middle.size.y - half - 2), seam)

	for pit in _pos.size():
		var radius := _radius(pit)
		_backdrop.draw_texture(_pit_texture(radius, _side_colors[_rules.owner_of(pit)]),
				_pos[pit] - Vector2(radius, radius))


## Warna garis tepi untuk sisi papan berwarna `base`.
static func _edge(base: Color) -> Color:
	return base.darkened(0.45)


## Semua yang berubah tiap frame. Digambar per jenis tekstur (cincin, biji,
## teks) supaya tiap kelompok menjadi satu batch.
func _draw() -> void:
	# Lubang yang bisa dipilih berkedip dua tingkat terang, gaya gim lawas.
	var glow := GOLD if fmod(_time, 0.6) < 0.3 else GOLD_DIM
	for pit in selectable:
		_draw_ring(pit, glow)
	for pit in _pulses:
		var pulse_color: Color = _pulses[pit].color
		var fade: float = _pulses[pit].t
		# Pudar bertingkat (tiga langkah), bukan halus.
		_draw_ring(pit, Color(pulse_color, ceilf(fade * 3.0) / 3.0))

	_draw_seeds()

	# Angka jumlah biji: di sisi luar lubang, menghadap pemiliknya.
	var label_scale := _label_scale()
	for pit in counts.size():
		var count := counts[pit]
		var owner_player := _rules.owner_of(pit)
		var side := 1.0 if owner_player == 0 else -1.0
		var flipped := is_flipped(owner_player)
		if _rules.is_store(pit):
			_text(_pos[pit] + Vector2(0, side * _unit * 1.02), str(count), 2, GOLD, flipped)
		else:
			_text(_pos[pit] + Vector2(0, side * (_radius(pit) + 3.0 + 4.0 * label_scale)), str(count),
					label_scale, Color.WHITE if count > 0 else _side_colors[owner_player].lightened(0.3),
					flipped)
	_draw_names()

	_draw_absorbs()
	_draw_flyers()
	_draw_hand()


func _draw_seeds() -> void:
	if _seeds_hidden:
		return
	if _devour_time < 0.0:
		for pit in counts.size():
			for k in counts[pit]:
				_draw_seed(_slot_pos(pit, k), _slot_tint(pit, k))
		return
	# Tersedot lubang hitam: biji berangkat bergiliran, berputar makin cepat
	# sambil mendekat, lalu lenyap di pusatnya.
	var total := 0
	for count in counts:
		total += count
	var progress := _devour_time / _devour_duration
	var index := 0
	for pit in counts.size():
		for k in counts[pit]:
			var pull := clampf((progress - 0.45 * index / maxf(total, 1.0)) / 0.55, 0.0, 1.0)
			index += 1
			if pull >= 1.0:
				continue
			var eased := pull * pull
			var offset := (_slot_pos(pit, k) - _devour_target).rotated(eased * 6.0) * (1.0 - eased)
			_draw_seed(_devour_target + offset, _slot_tint(pit, k))


func _draw_seed(center: Vector2, tint: int) -> void:
	@warning_ignore("integer_division")
	var corner := center.round() - Vector2(SEED_SIZE / 2, SEED_SIZE / 2)
	draw_texture_rect_region(_seed_atlas, Rect2(corner, Vector2(SEED_SIZE, SEED_SIZE)),
			Rect2(tint * SEED_SIZE, 0, SEED_SIZE, SEED_SIZE))


## Cincin dua piksel tepat di luar bibir lubang.
func _draw_ring(pit: int, color: Color) -> void:
	var radius := _radius(pit) + 3
	var texture := _ring_texture(radius)
	draw_texture(texture, _pos[pit] - Vector2(radius + 1, radius + 1), color)


func _draw_absorbs() -> void:
	var target := _hand_center()
	for absorb in _absorbs:
		var pit: int = absorb.pit
		var t: float = absorb.t
		for k in absorb.count:
			_draw_seed(_slot_pos(pit, k).lerp(target, t * t), _slot_tint(pit, k))


func _draw_flyers() -> void:
	for flyer in _flyers:
		var progress := clampf(flyer.time / flyer.duration, 0.0, 1.0)
		var target := _slot_pos(flyer.pit, flyer.slot)
		var p: Vector2
		if flyer.arc > 0.0:
			# Tembak: melengkung ke atas menuju lumbung.
			var eased := smoothstep(0.0, 1.0, progress)
			p = flyer.from.lerp(target, eased) + Vector2(0, -flyer.arc * sin(PI * eased))
		else:
			# Dilepas dari tangan: jatuh cepat lalu melambat saat mendarat.
			p = flyer.from.lerp(target, 1.0 - pow(1.0 - progress, 3.0))
		_draw_seed(p, _slot_tint(flyer.pit, flyer.slot))


func _draw_hand() -> void:
	if not _hand_shown:
		return
	var radius := _hand_radius()
	var center := _hand_center().round()
	draw_texture(_hand_texture(radius), center - Vector2(radius, radius))
	_text(center, str(_hand_count), 2 if radius >= 13 else 1, INK)


func _draw_names() -> void:
	for player in 2:
		var y := _board.end.y + STRIP / 2.0 if player == 0 else _board.position.y - STRIP / 2.0
		var active := player == active_player
		var text := "%s: %d" % [player_names[player], counts[_rules.store_of(player)]]
		if active:
			text = "> %s <" % text
		_text(Vector2(size.x / 2.0, y), text, 2, GOLD if active else Color("9db3ae"), is_flipped(player))


## Teks terpusat di `center`; `text_scale` = kelipatan font piksel 8.
## `flipped` memutar teks 180 derajat untuk pemain di seberang.
func _text(center: Vector2, text: String, text_scale: int, color: Color, flipped: bool = false) -> void:
	var width := 400.0
	# Glif menempati 7 baris di atas garis dasar, jadi pusatnya 4 piksel di atasnya.
	var origin := Vector2(-width / 2.0, 4.0 * text_scale)
	draw_set_transform(center.round(), PI if flipped else 0.0)
	draw_string(get_theme_default_font(), origin, text, HORIZONTAL_ALIGNMENT_CENTER, width,
			8 * text_scale, color)
	draw_set_transform(Vector2.ZERO)


static func _make_seed_atlas() -> void:
	if _seed_atlas != null:
		return
	var atlas := Image.create(SEED_SIZE * SEED_COLORS.size(), SEED_SIZE, false, Image.FORMAT_RGBA8)
	for tint in SEED_COLORS.size():
		var palette := {
			"o": SEED_OUTLINE, "w": Color.WHITE,
			"a": SEED_COLORS[tint], "b": SEED_COLORS[tint].darkened(0.22),
		}
		for y in SEED_SIZE:
			for x in SEED_SIZE:
				var key := SEED_SPRITE[y][x]
				if key != ".":
					atlas.set_pixel(tint * SEED_SIZE + x, y, palette[key])
	_seed_atlas = ImageTexture.create_from_image(atlas)


## Lubang cekung di papan berwarna `base`: bibir atas gelap, bibir bawah
## terang, dan bayangan bergerigi (dither) di bawah bibir atas.
static func _pit_texture(radius: int, base: Color) -> ImageTexture:
	var key := "%d/%s" % [radius, base.to_html()]
	if not _pit_textures.has(key):
		var hole := base.darkened(0.6)
		var hole_deep := base.darkened(0.78)
		var lip_dark := _edge(base)
		var lip_light := base.lightened(0.25)
		var side := radius * 2 + 1
		var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
		var shade_center := Vector2(radius, radius + radius * 0.3)
		for y in side:
			for x in side:
				var point := Vector2(x, y)
				var distance := point.distance_to(Vector2(radius, radius))
				if distance > radius + 0.5:
					continue
				var color := hole
				if distance > radius - 1.5:
					color = lip_dark if y <= radius else lip_light
				else:
					var depth := point.distance_to(shade_center) - radius * 0.86
					if depth > 2.0 or (depth > 0.0 and (x + y) % 2 == 0):
						color = hole_deep
				image.set_pixel(x, y, color)
		_pit_textures[key] = ImageTexture.create_from_image(image)
	return _pit_textures[key]


static func _ring_texture(radius: int) -> ImageTexture:
	if not _ring_textures.has(radius):
		var side := radius * 2 + 3
		var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
		var center := Vector2(radius + 1, radius + 1)
		for y in side:
			for x in side:
				if absf(Vector2(x, y).distance_to(center) - radius) <= 1.0:
					image.set_pixel(x, y, Color.WHITE)
		_ring_textures[radius] = ImageTexture.create_from_image(image)
	return _ring_textures[radius]


## Cakram emas penanda tangan, dengan garis tepi, sorot, dan bayangan.
static func _hand_texture(radius: int) -> ImageTexture:
	if not _hand_textures.has(radius):
		var side := radius * 2 + 1
		var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
		for y in side:
			for x in side:
				var distance := Vector2(x, y).distance_to(Vector2(radius, radius))
				if distance > radius + 0.5:
					continue
				var color := GOLD
				if distance > radius - 1.5:
					color = INK
				elif distance > radius - 3.5:
					color = Color("fff0b8") if x + y < radius * 2 else GOLD_DIM
				image.set_pixel(x, y, color)
		_hand_textures[radius] = ImageTexture.create_from_image(image)
	return _hand_textures[radius]

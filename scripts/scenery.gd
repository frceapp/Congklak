extends RefCounted
## Pembangkit pemandangan seni piksel panoramik 640 x 360 selayar penuh.
## Menggantikan pola ubin berulang dengan panorama kreatif bertema:
## - "frieren" : Senja reruntuhan kuno, padang bunga biru semegah langit, bintang sihir.
## - "maomao"  : Senja anggun paviliun apotek istana, lentera gantung, tanaman herbal.
## - "mahoraga": Kota malam di bawah bulan pucat, dengan roda dharma samar di langit.

const WIDTH := 640
const HEIGHT := 360

static var _cache := {}


static func get_scenery(id_bottom: String, id_top: String = "") -> ImageTexture:
	var key := "%s_%s" % [id_bottom, id_top]
	if not _cache.has(key):
		var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
		if id_top.is_empty() or id_top == id_bottom:
			_paint_single(img, id_bottom)
		else:
			_paint_versus(img, id_bottom, id_top)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


static func _paint_single(img: Image, id: String) -> void:
	match id:
		"frieren":
			_draw_frieren_scene(img, 0, HEIGHT)
		"maomao":
			_draw_maomao_scene(img, 0, HEIGHT)
		"mahoraga":
			_draw_mahoraga_scene(img, 0, HEIGHT)
		_:
			_draw_frieren_scene(img, 0, HEIGHT)
	_draw_foreground_table(img, id)


static func _paint_versus(img: Image, id_bottom: String, id_top: String) -> void:
	# Separuh atas memakai pemandangan pemain atas (lawan/AI)
	match id_top:
		"frieren":
			_draw_frieren_scene(img, 0, 180)
		"maomao":
			_draw_maomao_scene(img, 0, 180)
		"mahoraga":
			_draw_mahoraga_scene(img, 0, 180)
		_:
			_draw_frieren_scene(img, 0, 180)

	# Separuh bawah memakai pemandangan pemain bawah (pemain)
	match id_bottom:
		"frieren":
			_draw_frieren_scene(img, 180, HEIGHT)
		"maomao":
			_draw_maomao_scene(img, 180, HEIGHT)
		"mahoraga":
			_draw_mahoraga_scene(img, 180, HEIGHT)
		_:
			_draw_frieren_scene(img, 180, HEIGHT)

	# Garis transisi halus di tengah horison
	for x in WIDTH:
		img.set_pixel(x, 179, img.get_pixel(x, 178).lerp(img.get_pixel(x, 180), 0.5))
	_draw_foreground_table(img, id_bottom)


## ==================== FRIEREN: SENJA RERUNTUHAN & BUNGA BIRU ====================
static func _draw_frieren_scene(img: Image, y_start: int, y_end: int) -> void:
	# Gradien langit senja zamrud
	var sky_top := Color("0b1c20")
	var sky_mid := Color("133c38")
	var sky_bot := Color("1f5c53")

	for y in range(y_start, min(y_end, 200)):
		var t := float(y) / 200.0
		var col := sky_top.lerp(sky_mid, t * 1.5) if t < 0.66 else sky_mid.lerp(sky_bot, (t - 0.66) * 3.0)
		for x in WIDTH:
			img.set_pixel(x, y, col)

	# Bintang & kilau mana di langit atas (jika dalam rentang)
	if y_start < 120:
		var stars := [
			Vector2i(45, 22), Vector2i(90, 48), Vector2i(135, 18), Vector2i(190, 60),
			Vector2i(250, 30), Vector2i(320, 15), Vector2i(380, 52), Vector2i(430, 25),
			Vector2i(495, 38), Vector2i(560, 20), Vector2i(610, 55), Vector2i(525, 75),
			Vector2i(70, 85), Vector2i(290, 78), Vector2i(410, 95)
		]
		for s in stars:
			if s.y >= y_start and s.y < y_end:
				img.set_pixel(s.x, s.y, Color.WHITE)
				img.set_pixel(s.x + 1, s.y, Color("8fe3ff"))
				img.set_pixel(s.x - 1, s.y, Color("8fe3ff"))
				img.set_pixel(s.x, s.y + 1, Color("8fe3ff"))
				img.set_pixel(s.x, s.y - 1, Color("8fe3ff"))

		# Komet sihir melintas
		for i in 18:
			var cx := 520 - i * 3
			var cy := 30 + i
			if cy >= y_start and cy < y_end and cx >= 0 and cx < WIDTH:
				img.set_pixel(cx, cy, Color("8fe3ff").lerp(Color.TRANSPARENT, float(i) / 18.0).blend(img.get_pixel(cx, cy)))

	# Siluet pegunungan jauh (y: 110..180)
	var mtn_col := Color("102d29")
	for x in WIDTH:
		var height := int(150 + sin(x * 0.012) * 22 + cos(x * 0.028) * 14)
		for y in range(max(height, y_start), min(y_end, 220)):
			img.set_pixel(x, y, mtn_col)

	# Siluet reruntuhan kastel peri kuno di kanan (x: 480..580)
	var ruin_col := Color("0d2522")
	if y_end > 110:
		for rx in range(490, 570):
			var r_height := 130
			if (rx >= 505 and rx <= 525) or (rx >= 545 and rx <= 560):
				r_height = 105 # Menara
			for ry in range(max(r_height, y_start), min(y_end, 210)):
				img.set_pixel(rx, ry, ruin_col)
				# Jendela lengkung bercahaya biru redup
				if ry in [120, 121, 140, 141] and rx in [514, 515, 552, 553]:
					img.set_pixel(rx, ry, Color("8fe3ff"))

	# Bukit padang rumput & hamparan bunga biru (y: 180..270)
	var grass_col := Color("16423a")
	var grass_shade := Color("11342e")
	for x in WIDTH:
		var hill_y := int(190 + sin(x * 0.018 + 1.2) * 18 + cos(x * 0.007) * 12)
		for y in range(max(hill_y, y_start), y_end):
			var c := grass_col if ((x + y) % 6 > 2) else grass_shade
			img.set_pixel(x, y, c)

	# Bunga Biru bermekaran di padang rumput
	var flowers := [
		Vector2i(30, 215), Vector2i(55, 230), Vector2i(95, 210), Vector2i(130, 245),
		Vector2i(175, 225), Vector2i(220, 215), Vector2i(270, 240), Vector2i(340, 220),
		Vector2i(390, 235), Vector2i(440, 215), Vector2i(475, 245), Vector2i(530, 225),
		Vector2i(580, 210), Vector2i(615, 238), Vector2i(80, 255), Vector2i(510, 258)
	]
	for fl in flowers:
		if fl.y >= y_start and fl.y < y_end and fl.x >= 2 and fl.x < WIDTH - 2:
			img.set_pixel(fl.x, fl.y, Color("fffbe0")) # Putik
			img.set_pixel(fl.x + 1, fl.y, Color("8fe3ff")) # Kelopak
			img.set_pixel(fl.x - 1, fl.y, Color("8fe3ff"))
			img.set_pixel(fl.x, fl.y + 1, Color("8fe3ff"))
			img.set_pixel(fl.x, fl.y - 1, Color("8fe3ff"))
			img.set_pixel(fl.x - 1, fl.y + 1, Color("4f9a8e")) # Daun


## ==================== MAOMAO: TAMAN HERBAL & PAVILIUN ISTANA ====================
static func _draw_maomao_scene(img: Image, y_start: int, y_end: int) -> void:
	# Gradien langit senja lembayung apotek
	var sky_top := Color("1f0a17")
	var sky_mid := Color("3b1228")
	var sky_rose := Color("69233c")
	var sky_amber := Color("9e3d48")

	for y in range(y_start, min(y_end, 200)):
		var t := float(y) / 200.0
		var col: Color
		if t < 0.45:
			col = sky_top.lerp(sky_mid, t * 2.22)
		elif t < 0.8:
			col = sky_mid.lerp(sky_rose, (t - 0.45) * 2.85)
		else:
			col = sky_rose.lerp(sky_amber, (t - 0.8) * 5.0)
		for x in WIDTH:
			img.set_pixel(x, y, col)

	# Bulan sabit keperakan di kanan atas
	if y_start < 60:
		var moon_center := Vector2(510, 42)
		for my in range(34, 52):
			for mx in range(500, 522):
				if my >= y_start and my < y_end:
					var dist1 := Vector2(mx, my).distance_to(moon_center)
					var dist2 := Vector2(mx, my).distance_to(moon_center + Vector2(3, -2))
					if dist1 <= 7.0 and dist2 > 6.0:
						img.set_pixel(mx, my, Color("fff6d6"))

	# Lentera kertas merah-emas terbang perlahan di angkasa
	if y_start < 140:
		var lanterns := [
			Vector2i(80, 70), Vector2i(140, 45), Vector2i(210, 95),
			Vector2i(380, 80), Vector2i(450, 60), Vector2i(580, 85)
		]
		for l in lanterns:
			if l.y >= y_start and l.y < y_end:
				img.set_pixel(l.x, l.y, Color("ffd166"))
				img.set_pixel(l.x, l.y + 1, Color("e74c3c"))
				img.set_pixel(l.x, l.y - 1, Color("e74c3c"))
				img.set_pixel(l.x - 1, l.y, Color("e74c3c"))
				img.set_pixel(l.x + 1, l.y, Color("e74c3c"))

	# Siluet atap lengkung paviliun dan pagoda istana timur (x: 50..220 dan x: 420..600)
	var pagoda_col := Color("1e0817")
	if y_end > 110:
		# Pagoda kiri
		for px in range(70, 210):
			var p_top := 145
			if px in range(120, 160):
				p_top = 115 # Menara pagoda bertingkat
			elif px in range(130, 150):
				p_top = 95
			for py in range(max(p_top, y_start), min(y_end, 210)):
				img.set_pixel(px, py, pagoda_col)

		# Lentera gantung di ujung atap pagoda
		var hanging := [Vector2i(118, 118), Vector2i(162, 118), Vector2i(470, 138), Vector2i(550, 138)]
		for h in hanging:
			if h.y >= y_start and h.y < y_end:
				img.set_pixel(h.x, h.y, Color("ffd166"))
				img.set_pixel(h.x, h.y + 1, Color("d63031"))

	# Ranting pohon dedalu (weeping willow) menjuntai di kiri atas
	if y_start < 90:
		var willow_col := Color("1c3326")
		for wx in 70:
			var wy_tip := int(20 + sin(wx * 0.1) * 35 + wx * 0.5)
			for wy in range(y_start, min(wy_tip, y_end)):
				if (wx + wy) % 3 == 0:
					img.set_pixel(wx, wy, willow_col)

	# Taman herbal & halaman pelataran paviliun (y: 190..270)
	var garden_col := Color("294235")
	var garden_shade := Color("1c2f25")
	for x in WIDTH:
		var g_y := int(195 + sin(x * 0.02) * 8)
		for y in range(max(g_y, y_start), y_end):
			var c := garden_col if ((x + y) % 4 == 0) else garden_shade
			img.set_pixel(x, y, c)

	# Tanaman herbal dan botol guci obat di halaman
	var herbs := [
		Vector2i(60, 220), Vector2i(110, 235), Vector2i(180, 215), Vector2i(250, 240),
		Vector2i(380, 230), Vector2i(460, 218), Vector2i(530, 242), Vector2i(590, 225)
	]
	for hb in herbs:
		if hb.y >= y_start and hb.y < y_end and hb.x >= 2 and hb.x < WIDTH - 2:
			# Daun herbal hijau muda
			img.set_pixel(hb.x, hb.y, Color("a3e4b7"))
			img.set_pixel(hb.x - 1, hb.y - 1, Color("78c993"))
			img.set_pixel(hb.x + 1, hb.y - 1, Color("78c993"))
			img.set_pixel(hb.x, hb.y + 1, Color("4f785e"))


## ==================== MAHORAGA: KOTA MALAM & RODA DHARMA ====================
static func _draw_mahoraga_scene(img: Image, y_start: int, y_end: int) -> void:
	# Gradien langit malam nila
	var sky_top := Color("07060f")
	var sky_mid := Color("15132b")
	var sky_bot := Color("2a2547")
	for y in range(y_start, min(y_end, 200)):
		var t := float(y) / 200.0
		var col := sky_top.lerp(sky_mid, t * 2.0) if t < 0.5 else sky_mid.lerp(sky_bot, (t - 0.5) * 2.0)
		for x in WIDTH:
			img.set_pixel(x, y, col)

	# Bulan pucat besar di kiri atas, dengan dua kawah
	var moon := Vector2(140, 62)
	for my in range(max(y_start, 34), min(y_end, 91)):
		for mx in range(112, 169):
			var point := Vector2(mx, my)
			var dist := point.distance_to(moon)
			if dist <= 27.0:
				var crater := point.distance_to(moon + Vector2(8, -6)) <= 5.0
				if point.distance_to(moon + Vector2(-10, 9)) <= 4.0:
					crater = true
				img.set_pixel(mx, my, Color("b9b5d1") if crater or dist > 25.0 else Color("dedbee"))

	# Roda dharma samar di langit kanan: cincin, delapan jeruji, delapan gagang
	var wheel := Vector2(480, 66)
	var wheel_col := Color("6b5a2e")
	for wy in range(max(y_start, 30), min(y_end, 103)):
		for wx in range(444, 517):
			var offset := Vector2(wx, wy) - wheel
			var dist := offset.length()
			var spoke := fposmod(offset.angle(), TAU / 8.0)
			var on_spoke := minf(spoke, TAU / 8.0 - spoke) * dist <= 1.0
			var on_ring := absf(dist - 26.0) <= 1.5 or dist <= 4.0
			var on_handle := on_spoke and dist >= 30.0 and dist <= 34.0
			if on_ring or on_handle or (on_spoke and dist <= 26.0):
				img.set_pixel(wx, wy, wheel_col)

	# Siluet gedung-gedung kota dengan jendela menyala: [x awal, x akhir, puncak]
	var buildings := [
		[0, 45, 150], [45, 80, 120], [80, 130, 160], [130, 170, 105], [170, 230, 140],
		[230, 270, 95], [270, 330, 150], [330, 380, 115], [380, 440, 135], [440, 480, 100],
		[480, 540, 155], [540, 590, 125], [590, 640, 145],
	]
	var tower_col := Color("0d0c1c")
	var tower_edge := Color("1b1933")
	for b in buildings:
		var left: int = b[0]
		var right: int = b[1]
		var top: int = b[2]
		for bx in range(left, right):
			for by in range(max(top, y_start), min(y_end, 210)):
				var lit := bx % 6 == 2 and by % 8 == 3 and (bx * 7 + by * 13) % 5 == 0
				if lit and bx > left + 2 and bx < right - 2:
					img.set_pixel(bx, by, Color("f2d16b"))
				else:
					img.set_pixel(bx, by, tower_edge if bx == left or by == top else tower_col)

	# Jalan aspal kota (y: 195 ke bawah)
	var road := Color("16142a")
	var road_shade := Color("100f1f")
	for x in WIDTH:
		for y in range(max(195, y_start), y_end):
			@warning_ignore("integer_division")
			var c := road if ((x / 20 + y / 6) % 2 == 0) else road_shade
			img.set_pixel(x, y, c)


## ==================== MEJA / LANTAI DEPAN PAPAN CONGKLAK ====================
static func _draw_foreground_table(img: Image, character_id: String) -> void:
	# Papan congklak bertumpu di lantai teras kayu / marmer depan
	var floor_base: Color
	var floor_seam: Color
	match character_id:
		"frieren":
			floor_base = Color("1a2926")
			floor_seam = Color("101b19")
		"maomao":
			floor_base = Color("28151f")
			floor_seam = Color("1a0d14")
		"mahoraga":
			floor_base = Color("17162a")
			floor_seam = Color("0c0b18")
		_:
			floor_base = Color("201a18")
			floor_seam = Color("14100e")

	# Garis lantai perspektif teras dari y: 260 hingga 360
	for y in range(270, HEIGHT):
		var depth_shade := floor_base.lightened(float(y - 270) * 0.001)
		for x in WIDTH:
			# Sambungan papan lantai tiap 40 piksel
			if (x + int((y - 270) * 0.3)) % 48 == 0 or y % 24 == 0:
				img.set_pixel(x, y, floor_seam)
			else:
				img.set_pixel(x, y, depth_shade)

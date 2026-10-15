extends RefCounted
## Pembuat elemen antarmuka bergaya piksel.
##
## Layar dirender pada 640 x 360 lalu diperbesar tanpa penghalusan, jadi semua
## ukuran di sini dalam piksel layar-rendah. Font piksel tingginya 8; pakai
## ukuran kelipatan 8 (8, 16, 24, ...) supaya hurufnya tetap tajam.

const GOLD := Color("ffd166")
const DARK := Color("2b1b12")
const PANEL := Color("1b4a43")
const SOFT := Color("2f6a5f")
const OUTLINE := Color("0a1c19")

## Font kecil, normal, dan judul.
const SMALL := 8
const NORMAL := 16
const BIG := 24

const BACKDROP := Color("123a34")
const Scenery = preload("res://scripts/scenery.gd")

static var _boxes := {}
## Warna dasar (html) -> ubin latar.
static var _tiles := {}


## Kotak piksel 9-iris: garis tepi gelap bersudut tumpul, sorot terang di
## atas, dan bayangan di bawah. `sunken` membalik sorot/bayangan (tombol ditekan).
static func box(fill: Color, pad: int = 8, sunken: bool = false) -> StyleBoxTexture:
	var key := "%s/%s" % [fill.to_html(), sunken]
	if not _boxes.has(key):
		var light := fill.lightened(0.28)
		var shade := fill.darkened(0.3)
		if sunken:
			light = fill.darkened(0.3)
			shade = fill.darkened(0.1)
		# Digambar pada 6 x 6 lalu digandakan supaya garisnya setebal 2 piksel.
		var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		for y in 12:
			for x in 12:
				@warning_ignore("integer_division")
				var cell := Vector2i(x / 2, y / 2)
				var edge_x := cell.x == 0 or cell.x == 5
				var edge_y := cell.y == 0 or cell.y == 5
				var color := fill
				if edge_x and edge_y:
					color = Color(0, 0, 0, 0)
				elif edge_x or edge_y:
					color = OUTLINE
				elif cell.y == 1:
					color = light
				elif cell.y == 4:
					color = shade
				image.set_pixel(x, y, color)
		_boxes[key] = ImageTexture.create_from_image(image)
	var style := StyleBoxTexture.new()
	style.texture = _boxes[key]
	style.set_texture_margin_all(6)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


static func button(text: String, primary: bool = true, font_size: int = NORMAL) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, font_size + 14)
	b.add_theme_font_size_override("font_size", font_size)
	set_primary(b, primary)
	return b


## Mengganti gaya tombol: emas (utama) atau hijau redup (sekunder).
static func set_primary(b: Button, primary: bool) -> void:
	var base := GOLD if primary else SOFT
	var text_color := DARK if primary else Color.WHITE
	b.add_theme_stylebox_override("normal", box(base))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.12), 8, true))
	for key in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, text_color)


static func label(text: String, font_size: int = NORMAL, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Latar pemandangan seni piksel 640 x 360 artistik penuh dan tidak berulang.
static func scenery_background(id_bottom: String = "frieren", id_top: String = "") -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = Scenery.get_scenery(id_bottom, id_top)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## Latar layar permainan / menu: secara bawaan menampilkan panorama pemandangan artistik.
static func background(base: Color = BACKDROP, style: String = "", accent: Color = Color.TRANSPARENT) -> TextureRect:
	if style.is_empty():
		return scenery_background("frieren")
	var key := "%s|%s|%s" % [base.to_html(), style, accent.to_html()]
	if not _tiles.has(key):
		var image: Image
		match style:
			"magic_flower", "magic":
				image = _tile_magic(base, accent if accent != Color.TRANSPARENT else Color("8fe3ff"))
			"herb_potion", "potion":
				image = _tile_potion(base, accent if accent != Color.TRANSPARENT else Color("a3e4b7"))
			_:
				image = _tile_default(base)
		_tiles[key] = ImageTexture.create_from_image(image)
	var rect := TextureRect.new()
	rect.texture = _tiles[key]
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


## Latar khusus sesuai konfigurasi dictionary karakter di Characters.ROSTER.
static func character_background(character_info: Dictionary, darkened: bool = false) -> TextureRect:
	var id: String = character_info.get("id", "frieren")
	return scenery_background(id)


static func _tile_default(base: Color) -> Image:
	var motif := base.lightened(0.06)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(base)
	for y in 16:
		for x in 16:
			var distance := absi(x - 8) + absi(y - 8)
			if distance == 6 or distance == 0 or (x % 16 == 0 and y % 16 == 0):
				image.set_pixel(x, y, motif)
	return image


static func _tile_magic(base: Color, accent: Color) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(base)
	var dot_col := base.lightened(0.05)
	var flower_col := accent
	var flower_dark := accent.darkened(0.25)
	var flower_center := Color("fffde6")
	var leaf_col := Color("4f9a8e")
	var star_bright := Color("ffffff")
	var mana_dust := accent.lightened(0.12)
	var mana_dim := base.lightened(0.12)

	# Titik wajik halus di latar
	for y in 32:
		for x in 32:
			if (x % 16 == 0 and y % 16 == 0) or ((x + 8) % 16 == 0 and (y + 8) % 16 == 0):
				image.set_pixel(x, y, dot_col)

	# Bunga Biru (Blue Moonweed) di (8, 8)
	var cx := 8
	var cy := 8
	for off in [-2, 2]:
		image.set_pixel(cx + off, cy, flower_dark)
		image.set_pixel(cx, cy + off, flower_dark)
	for off in [-1, 1]:
		image.set_pixel(cx + off, cy, flower_col)
		image.set_pixel(cx, cy + off, flower_col)
		image.set_pixel(cx + off, cy + 1, flower_col)
		image.set_pixel(cx + off, cy - 1, flower_col)
	image.set_pixel(cx, cy, flower_center)
	image.set_pixel(cx - 3, cy + 1, leaf_col)
	image.set_pixel(cx + 3, cy - 1, leaf_col)

	# Bintang Sihir / Mana Sparkle di (24, 24)
	var sx := 24
	var sy := 24
	image.set_pixel(sx, sy, star_bright)
	for off in [-1, 1]:
		image.set_pixel(sx + off, sy, mana_dust)
		image.set_pixel(sx, sy + off, mana_dust)
		image.set_pixel(sx + off, sy + off, mana_dim)
		image.set_pixel(sx + off, sy - off, mana_dim)
	for off in [-3, -2, 2, 3]:
		image.set_pixel(sx + off, sy, mana_dust)
		image.set_pixel(sx, sy + off, mana_dust)

	# Runik sihir kecil di (24, 8)
	image.set_pixel(24, 8, star_bright)
	for d in [-1, 1]:
		image.set_pixel(24 + d, 7, mana_dim)
		image.set_pixel(24 + d, 9, mana_dim)
		image.set_pixel(24, 8 + d * 2, mana_dim)
		image.set_pixel(24 + d * 2, 8, mana_dim)

	# Kelopak bunga gugur di (8, 24)
	image.set_pixel(7, 23, flower_col)
	image.set_pixel(8, 24, flower_col)
	image.set_pixel(9, 23, flower_dark)
	image.set_pixel(9, 25, leaf_col)

	return image


static func _tile_potion(base: Color, accent: Color) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(base)
	var dot_col := base.lightened(0.05)
	var cork_col := Color("c29367")
	var glass_col := Color("dfa39e")
	var liquid_col := Color("c79bff")
	var liquid_dark := Color("8b5fa8")
	var liquid_shine := Color.WHITE
	var herb_col := accent
	var herb_bright := Color("c4f7d4")
	var herb_stem := Color("624a38")

	# Titik wajik halus di latar
	for y in 32:
		for x in 32:
			if (x % 16 == 0 and y % 16 == 0) or ((x + 8) % 16 == 0 and (y + 8) % 16 == 0):
				image.set_pixel(x, y, dot_col)

	# Botol Ramuan di (8, 8)
	var bx := 8
	image.set_pixel(bx, 3, cork_col)
	image.set_pixel(bx - 1, 3, cork_col)
	image.set_pixel(bx + 1, 3, cork_col)
	image.set_pixel(bx - 1, 4, glass_col)
	image.set_pixel(bx, 4, glass_col)
	image.set_pixel(bx + 1, 4, glass_col)
	image.set_pixel(bx - 2, 6, glass_col)
	image.set_pixel(bx + 2, 6, glass_col)
	for x in range(bx - 1, bx + 2):
		image.set_pixel(x, 6, liquid_col)
	for by in range(7, 10):
		image.set_pixel(bx - 3, by, glass_col)
		image.set_pixel(bx + 3, by, glass_col)
		for x in range(bx - 2, bx + 3):
			image.set_pixel(x, by, liquid_dark if by == 9 else liquid_col)
	image.set_pixel(bx - 1, 7, liquid_shine)
	for x in range(bx - 2, bx + 3):
		image.set_pixel(x, 10, glass_col)

	# Daun Herbal di (24, 24)
	var lx := 24
	var ly := 24
	image.set_pixel(lx + 3, ly - 3, herb_bright)
	image.set_pixel(lx + 2, ly - 2, herb_bright)
	image.set_pixel(lx + 1, ly - 1, herb_bright)
	image.set_pixel(lx, ly, herb_col)
	image.set_pixel(lx - 1, ly + 1, herb_col)
	image.set_pixel(lx + 1, ly, herb_col)
	image.set_pixel(lx, ly + 1, herb_col)
	image.set_pixel(lx - 1, ly + 2, herb_col)
	image.set_pixel(lx + 1, ly - 1, Color.WHITE)
	image.set_pixel(lx, ly, Color.WHITE)
	image.set_pixel(lx - 2, ly + 3, herb_stem)
	image.set_pixel(lx - 3, ly + 4, herb_stem)

	# Gelembung ramuan di (24, 8)
	image.set_pixel(24, 6, liquid_col)
	image.set_pixel(24, 8, liquid_col)
	image.set_pixel(23, 7, liquid_col)
	image.set_pixel(25, 7, liquid_col)
	image.set_pixel(23, 6, liquid_shine)
	image.set_pixel(26, 10, liquid_col)
	image.set_pixel(22, 11, liquid_col)

	# Tunas herbal kembar di (8, 24)
	image.set_pixel(8, 25, herb_stem)
	image.set_pixel(8, 24, herb_stem)
	image.set_pixel(7, 23, herb_col)
	image.set_pixel(6, 22, herb_bright)
	image.set_pixel(9, 23, herb_col)
	image.set_pixel(10, 22, herb_bright)

	return image


## MarginContainer selayar penuh yang menghindari poni/lubang kamera di ponsel.
static func safe_margin(base: int = 10) -> MarginContainer:
	var left := base
	var top := base
	var right := base
	var bottom := base
	if OS.has_feature("mobile"):
		var window := DisplayServer.window_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var design := Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
		var scale := minf(window.x / design.x, window.y / design.y)
		if scale > 0.0:
			left += int(maxf(safe.position.x, 0) / scale)
			top += int(maxf(safe.position.y, 0) / scale)
			right += int(maxf(window.x - safe.end.x, 0) / scale)
			bottom += int(maxf(window.y - safe.end.y, 0) / scale)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return margin


## Lapisan gelap selayar penuh yang menahan sentuhan ke layar di bawahnya.
static func overlay() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


## Panel di tengah `parent` (biasanya hasil overlay()); mengembalikan VBox isinya.
static func panel(parent: Control, min_width: float = 260) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var style := box(PANEL, 14)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size.x = min_width
	center.add_child(frame)
	var box_content := VBoxContainer.new()
	box_content.add_theme_constant_override("separation", 6)
	frame.add_child(box_content)
	return box_content

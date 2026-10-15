extends Control
## Sprite karakter 2D bergaya piksel, 64 x 96, berdiri menghadap depan.
##
## Bentuk besar (rambut, pakaian, alat) dirasterkan dari poligon dan elips
## tanpa penghalusan langsung di koordinat piksel sprite; mata, mulut, dan
## detail kecil ditaruh piksel demi piksel. Hasilnya diberi garis tepi gelap
## dan disimpan sebagai tekstur berlatar transparan.
##
## Node ini menampilkan sprite itu diperbesar. Pakai ukuran kelipatan bulat
## dari 64 x 96 (atau 64 x BUST_ROWS untuk potongan dada) supaya pikselnya
## seragam.

const SIZE := Vector2i(64, 96)
## Jumlah baris teratas sprite yang memuat kepala sampai dada.
const BUST_ROWS := 52
const SKIN := Color("ffe2cc")
const SKIN_SHADE := Color("eebfa2")
const LINE := Color("32211c")
const BLUSH := Color("f6a79f")
const GOLD := Color("ffd166")
const OUTLINE := Color("1e141a")
## Gambar milik sendiri di assets/characters/<id>.<ekstensi> menggantikan
## sprite bawaan; dikecilkan ke 64 x 96.
const ART_PATH := "res://assets/characters/%s.%s"
const ART_EXTENSIONS: Array[String] = ["png", "webp", "jpg"]

# Pola mata 5 x 6: L = bulu mata, W = putih, H = kilau, D = iris gelap,
# G = iris, P = pupil.
const EYE_OPEN: Array[String] = ["LLLLL", "LHDDL", "WGPGW", "WGPGW", "WGGGW", ".WWW."]
const EYE_LIDDED: Array[String] = ["LLLLL", "WHPGW", "WGPGW", "WGGGW", ".WWW."]

## id karakter -> ImageTexture 64 x 96.
static var _textures := {}


## Kanvas kecil tempat sprite dirasterkan. Semua koordinat dalam piksel sprite.
class Painter:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	## 1 untuk piksel yang termasuk sosok karakter (diberi garis tepi).
	var figure := PackedByteArray()
	var marking := true

	func _init() -> void:
		figure.resize(SIZE.x * SIZE.y)

	func put(x: int, y: int, color: Color) -> void:
		if x < 0 or y < 0 or x >= SIZE.x or y >= SIZE.y:
			return
		image.set_pixel(x, y, image.get_pixel(x, y).blend(color))
		if marking:
			figure[y * SIZE.x + x] = 1

	func rect(x: int, y: int, width: int, height: int, color: Color) -> void:
		for row in range(y, y + height):
			for column in range(x, x + width):
				put(column, row, color)

	func shape(points: PackedVector2Array, color: Color) -> void:
		for y in SIZE.y:
			for x in SIZE.x:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
					put(x, y, color)

	func ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
		for y in SIZE.y:
			for x in SIZE.x:
				if ((Vector2(x + 0.5, y + 0.5) - center) / radii).length_squared() <= 1.0:
					put(x, y, color)

	## Melubangi kanvas (dipakai untuk membentuk bulan sabit pada tongkat).
	func erase_ellipse(center: Vector2, radii: Vector2) -> void:
		for y in SIZE.y:
			for x in SIZE.x:
				if ((Vector2(x + 0.5, y + 0.5) - center) / radii).length_squared() <= 1.0:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
					figure[y * SIZE.x + x] = 0

	## Pola piksel; '.' dilewati, huruf lain dicari warnanya di `palette`.
	func stamp(origin: Vector2i, rows: Array[String], palette: Dictionary) -> void:
		for y in rows.size():
			for x in rows[y].length():
				var key := rows[y][x]
				if key != ".":
					put(origin.x + x, origin.y + y, palette[key])

	## Garis tepi satu piksel di sekeliling sosok, ciri khas gambar piksel.
	func outline(color: Color) -> void:
		for y in SIZE.y:
			for x in SIZE.x:
				if figure[y * SIZE.x + x] == 0 and (_is_figure(x - 1, y) or _is_figure(x + 1, y)
						or _is_figure(x, y - 1) or _is_figure(x, y + 1)):
					image.set_pixel(x, y, color)

	func _is_figure(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y and figure[y * SIZE.x + x] == 1


## Salah satu entri Characters.ROSTER.
var character := {}:
	set(value):
		character = value
		queue_redraw()
## Penanda giliran: pijakan emas di kaki dan gerak naik-turun kecil.
var highlighted := true:
	set(value):
		highlighted = value
		queue_redraw()
## Bila lebih dari 0, hanya baris teratas sebanyak ini yang ditampilkan
## (potongan dada untuk cut-in jurus dan panel hasil).
var crop_rows := 0:
	set(value):
		crop_rows = value
		queue_redraw()

var _time := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if highlighted and crop_rows == 0 and not character.is_empty():
		_time += delta
		queue_redraw()


func _draw() -> void:
	if character.is_empty():
		return
	var texture := texture_for(character)
	if crop_rows > 0:
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), Rect2(0, 0, SIZE.x, crop_rows))
		return

	var pixel := size.x / SIZE.x
	var bob := 0.0
	if highlighted:
		# Pijakan emas berkedip dua tingkat di bawah kaki, dan sosoknya naik
		# satu piksel sprite secara berkala.
		bob = -pixel if fmod(_time, 0.8) < 0.4 else 0.0
		var glow := GOLD if fmod(_time, 0.6) < 0.3 else Color("c08a2e")
		var base := Vector2(size.x / 2.0, size.y - 3.5 * pixel)
		draw_rect(Rect2(base - Vector2(22, 1.5) * pixel, Vector2(44, 3) * pixel), glow)
		draw_rect(Rect2(base - Vector2(18, 2.5) * pixel, Vector2(36, 5) * pixel), Color(glow, 0.45))
	draw_texture_rect(texture, Rect2(Vector2(0, bob), size), false)


static func texture_for(info: Dictionary) -> ImageTexture:
	var id: String = info.id
	if not _textures.has(id):
		var image := _load_art(id)
		if image == null:
			image = _paint(id)
		_textures[id] = ImageTexture.create_from_image(image)
	return _textures[id]


static func _load_art(id: String) -> Image:
	for extension in ART_EXTENSIONS:
		var path := ART_PATH % [id, extension]
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path)
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_NEAREST)
		image.convert(Image.FORMAT_RGBA8)
		return image
	return null


static func _paint(id: String) -> Image:
	var p := Painter.new()
	# Bayangan di lantai bukan bagian sosok, jadi tidak ikut diberi garis tepi.
	p.marking = false
	p.ellipse(Vector2(32, 92.5), Vector2(19, 3), Color(0, 0, 0, 0.35))
	p.marking = true
	match id:
		"frieren":
			_paint_frieren(p)
		"maomao":
			_paint_maomao(p)
	p.outline(OUTLINE)
	return p.image


## Frieren: penyihir elf berambut putih kuncir dua, bertelinga runcing,
## berjubah putih berpinggiran emas, memegang tongkat berkepala bulan sabit.
static func _paint_frieren(p: Painter) -> void:
	var hair := Color("f3f5f8")
	var hair_shade := Color("c9d1dc")
	var cloth := Color("f4f1ea")
	var cloth_shade := Color("d6d2c8")
	var gold := Color("e9b94a")
	var navy := Color("2b2d42")
	var boot := Color("6b4a32")
	var ruby := Color("d63a4a")

	# Kuncir dua panjang di belakang badan, lalu rambut belakang kepala.
	for mirrored in [false, true]:
		p.shape(_side([Vector2(12, 20), Vector2(18, 20), Vector2(18, 48), Vector2(16, 64),
				Vector2(12, 75), Vector2(8, 64), Vector2(8, 44), Vector2(10, 28)], mirrored), hair)
		p.shape(_side([Vector2(15, 32), Vector2(17, 32), Vector2(16, 60), Vector2(13, 70),
				Vector2(14, 54)], mirrored), hair_shade)
	p.ellipse(Vector2(32, 22), Vector2(16, 15), hair_shade)

	# Kaki berstoking gelap dan sepatu bot.
	for x in [26, 33]:
		p.rect(x, 72, 5, 13, navy)
		p.rect(x - 1, 84, 7, 6, boot)
		p.rect(x - 1, 90, 7, 1, boot.darkened(0.45))

	# Rok putih melebar dengan pinggiran emas.
	p.shape([Vector2(22, 54), Vector2(42, 54), Vector2(47, 74), Vector2(17, 74)], cloth)
	p.shape([Vector2(38, 54), Vector2(42, 54), Vector2(47, 74), Vector2(42, 74)], cloth_shade)
	p.shape([Vector2(17.6, 71), Vector2(46.4, 71), Vector2(47, 74), Vector2(17, 74)], gold)
	# Leher, badan, dan sabuk bergesper emas.
	p.rect(29, 35, 6, 6, SKIN_SHADE)
	p.shape([Vector2(23, 40), Vector2(41, 40), Vector2(42, 55), Vector2(22, 55)], cloth)
	p.rect(22, 53, 20, 2, Color("4a3426"))
	p.rect(31, 53, 2, 2, gold)

	# Lengan kiri terjuntai.
	p.shape([Vector2(16, 45), Vector2(22, 44), Vector2(22, 60), Vector2(16, 61)], cloth)
	p.ellipse(Vector2(19, 62.5), Vector2(2.6, 2.3), SKIN)
	# Tongkat: gagang kayu, kepala bulan sabit emas, permata merah.
	p.rect(54, 14, 2, 77, Color("b98a3c"))
	p.rect(55, 14, 1, 77, Color("8a6226"))
	p.ellipse(Vector2(55, 9), Vector2(6, 7), gold)
	p.erase_ellipse(Vector2(55, 7), Vector2(3.6, 4.4))
	p.ellipse(Vector2(55, 8), Vector2(1.8, 2.3), ruby)
	# Lengan kanan menggenggam tongkat.
	p.shape([Vector2(42, 44), Vector2(47, 45), Vector2(55, 56), Vector2(51, 60), Vector2(42, 52)], cloth)
	p.ellipse(Vector2(54.5, 58.5), Vector2(2.7, 2.6), SKIN)

	# Jubah bahu pendek berpinggiran emas, kerah gelap, bros merah.
	p.shape([Vector2(19, 40), Vector2(45, 40), Vector2(49, 50), Vector2(15, 50)], cloth)
	p.shape([Vector2(15.8, 48), Vector2(48.2, 48), Vector2(49, 50), Vector2(15, 50)], gold)
	p.shape([Vector2(26, 38), Vector2(38, 38), Vector2(35, 44), Vector2(29, 44)], navy)
	p.rect(31, 44, 2, 2, ruby)

	# Telinga elf yang runcing, lalu wajah.
	for mirrored in [false, true]:
		p.shape(_side([Vector2(21, 21), Vector2(7, 16), Vector2(21, 28)], mirrored), SKIN)
		p.shape(_side([Vector2(19, 22), Vector2(11, 19), Vector2(19, 26)], mirrored), SKIN_SHADE)
	p.ellipse(Vector2(32, 25), Vector2(12.5, 12), SKIN)

	# Rambut depan: mahkota, poni belah tengah, dan anak rambut di sisi wajah.
	p.ellipse(Vector2(32, 15), Vector2(15.5, 10), hair)
	for mirrored in [false, true]:
		p.shape(_side([Vector2(16.5, 14), Vector2(32, 9), Vector2(32, 15), Vector2(28, 20),
				Vector2(23, 23), Vector2(20, 28), Vector2(17, 30)], mirrored), hair)
		p.shape(_side([Vector2(16.5, 22), Vector2(20, 22), Vector2(20, 36), Vector2(18, 41),
				Vector2(16, 34)], mirrored), hair)
	for y in range(9, 15):
		p.put(31, y, hair_shade)

	# Mata hijau setengah terpejam, alis tipis, pipi, mulut, dan anting merah.
	_paint_eyes(p, Color("3fae7a"), true)
	for x in [22, 23, 24, 25, 38, 39, 40, 41]:
		p.put(x, 20, Color("a3adba"))
	_paint_blush(p)
	p.put(31, 32, LINE)
	p.put(32, 32, LINE)
	for x in [20, 43]:
		p.rect(x, 29, 1, 2, ruby)


## Maomao: ahli obat berambut hijau tua bersanggul, untaian samping bermanik
## merah, memakai atasan hijau dan rok merah, mengangkat botol ramuan ungu.
static func _paint_maomao(p: Painter) -> void:
	var hair := Color("2f5d4a")
	var hair_shade := Color("1f4133")
	var robe := Color("93c47d")
	var robe_shade := Color("6c9c58")
	var cream := Color("f4ead5")
	var skirt := Color("a8424f")
	var skirt_shade := Color("86313d")
	var bead := Color("d9534f")

	# Sanggul di puncak kepala dan rambut belakang.
	p.ellipse(Vector2(32, 4.5), Vector2(5.5, 4.5), hair)
	p.ellipse(Vector2(32, 22), Vector2(15.5, 14.5), hair_shade)

	# Sepatu, lalu rok panjang berlipat.
	for x in [25, 33]:
		p.rect(x, 87, 6, 4, Color("3b2530"))
	p.shape([Vector2(22, 56), Vector2(42, 56), Vector2(47, 88), Vector2(17, 88)], skirt)
	for x in [25, 31, 37, 42]:
		p.rect(x, 60, 1, 26, skirt_shade)
	p.shape([Vector2(17.4, 85.5), Vector2(46.6, 85.5), Vector2(47, 88), Vector2(17, 88)], skirt_shade)

	# Leher, atasan hijau, kerah silang krem, dan selendang pinggang.
	p.rect(29, 35, 6, 6, SKIN_SHADE)
	p.shape([Vector2(22, 40), Vector2(42, 40), Vector2(43, 57), Vector2(21, 57)], robe)
	p.shape([Vector2(38, 40), Vector2(42, 40), Vector2(43, 57), Vector2(39, 57)], robe_shade)
	p.shape([Vector2(27, 39), Vector2(30.5, 39), Vector2(38, 53), Vector2(34.5, 53)], cream)
	p.shape([Vector2(37, 39), Vector2(33.5, 39), Vector2(31, 44), Vector2(33, 47)], cream)
	p.rect(21, 53, 22, 4, Color("7a2f3a"))
	p.rect(30, 54, 4, 2, Color("c9616d"))

	# Lengan kiri berlengan lebar dengan manset krem.
	p.shape([Vector2(14, 45), Vector2(22, 42), Vector2(23, 58), Vector2(13, 61)], robe)
	p.shape([Vector2(13.3, 58.5), Vector2(23, 56), Vector2(23, 58), Vector2(13, 61)], cream)
	p.ellipse(Vector2(17.5, 62.5), Vector2(2.5, 2.2), SKIN)
	# Lengan kanan terangkat memegang botol ramuan ungu bersumbat gabus.
	p.shape([Vector2(41, 42), Vector2(46, 42), Vector2(58, 50), Vector2(56, 57), Vector2(46, 58),
			Vector2(41, 53)], robe)
	p.rect(54, 33, 3, 1, Color("8a6226"))
	p.rect(54, 34, 3, 3, cream)
	p.ellipse(Vector2(55.5, 41), Vector2(4.2, 4.4), Color("c79bff"))
	p.ellipse(Vector2(55.5, 43), Vector2(3.2, 2.2), Color("a274e0"))
	p.put(53, 39, Color.WHITE)
	p.put(53, 40, Color.WHITE)
	p.ellipse(Vector2(55.5, 48), Vector2(2.6, 2.5), SKIN)

	# Telinga dan wajah.
	p.ellipse(Vector2(19.5, 26), Vector2(2.2, 3), SKIN)
	p.ellipse(Vector2(44.5, 26), Vector2(2.2, 3), SKIN)
	p.ellipse(Vector2(32, 25), Vector2(12.5, 12), SKIN)

	# Rambut depan: mahkota, pita ungu pengikat sanggul, poni lurus bergerigi,
	# dan untaian samping bermanik.
	p.ellipse(Vector2(32, 16), Vector2(15.5, 9), hair)
	p.rect(27, 7, 10, 2, Color("9a6fc4"))
	p.shape([Vector2(17, 14), Vector2(47, 14), Vector2(47, 21), Vector2(43, 23), Vector2(39, 21),
			Vector2(35, 23), Vector2(32, 22), Vector2(29, 23), Vector2(25, 21), Vector2(21, 23),
			Vector2(17, 21)], hair)
	for mirrored in [false, true]:
		p.shape(_side([Vector2(15.5, 18), Vector2(20, 18), Vector2(20, 42), Vector2(18, 46),
				Vector2(15.5, 42)], mirrored), hair)
	for x in [15, 44]:
		p.rect(x, 31, 5, 2, bead)
		p.rect(x, 39, 5, 2, bead)

	# Mata biru dan senyum tipis yang miring.
	_paint_eyes(p, Color("4f6fd0"), false)
	_paint_blush(p)
	for point in [Vector2i(30, 33), Vector2i(31, 33), Vector2i(32, 33), Vector2i(33, 32)]:
		p.put(point.x, point.y, LINE)


## `lidded`: kelopak setengah menutup (tatapan tenang).
static func _paint_eyes(p: Painter, iris: Color, lidded: bool) -> void:
	var palette := {
		"L": LINE, "W": Color.WHITE, "H": Color.WHITE,
		"D": iris.darkened(0.35), "G": iris, "P": iris.darkened(0.65),
	}
	for x in [22, 37]:
		if lidded:
			p.stamp(Vector2i(x, 23), EYE_LIDDED, palette)
		else:
			p.stamp(Vector2i(x, 22), EYE_OPEN, palette)


static func _paint_blush(p: Painter) -> void:
	for x in [21, 22, 41, 42]:
		p.put(x, 30, BLUSH)


## Mengembalikan titik apa adanya (sisi kiri) atau dicerminkan ke sisi kanan.
static func _side(points: Array, mirrored: bool) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(Vector2(SIZE.x - point.x, point.y) if mirrored else point)
	return result

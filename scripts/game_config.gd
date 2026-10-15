extends RefCounted
## Pilihan pemain yang dibawa antar-scene dan disimpan ke user://settings.cfg.

const Logic = preload("res://scripts/congklak_logic.gd")

enum Mode { VS_AI, TWO_PLAYERS }

const PATH := "user://settings.cfg"
const DIFFICULTY_NAMES: Array[String] = ["Mudah", "Sedang", "Sulit"]

static var mode := Mode.VS_AI
static var difficulty := 1
static var sound := true
static var speed := 0
## Jumlah lubang kecil per baris dan biji awal per lubang.
static var holes := Logic.DEFAULT_HOLES
static var seeds := Logic.DEFAULT_SEEDS
## Indeks Characters.ROSTER untuk pemain bawah dan pemain atas; dipilih ulang
## di layar pilih karakter sebelum tiap permainan.
static var characters: Array[int] = [0, 1]

static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	difficulty = clampi(file.get_value("game", "difficulty", difficulty), 0, 2)
	sound = file.get_value("game", "sound", sound)
	speed = clampi(file.get_value("game", "speed", speed), 0, 2)
	holes = clampi(file.get_value("board", "holes", holes), Logic.MIN_HOLES, Logic.MAX_HOLES)
	seeds = clampi(file.get_value("board", "seeds", seeds), Logic.MIN_SEEDS, Logic.MAX_SEEDS)


static func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("game", "difficulty", difficulty)
	file.set_value("game", "sound", sound)
	file.set_value("game", "speed", speed)
	file.set_value("board", "holes", holes)
	file.set_value("board", "seeds", seeds)
	file.save(PATH)

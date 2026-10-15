extends SceneTree
## Uji aturan (gaya mancala, tanpa estafet). Jalankan:
##   godot --headless --path . --script res://tests/test_logic.gd

const Logic = preload("res://scripts/congklak_logic.gd")
const AI = preload("res://scripts/ai.gd")

var _failed := 0


func _init() -> void:
	_test_initial_state()
	_test_extra_turn()
	_test_capture()
	_test_empty_hole_on_enemy_side()
	_test_no_relay()
	_test_skip_enemy_store()
	_test_game_ends_when_a_side_is_empty()
	_test_custom_board()
	_test_random_playouts()
	_test_ai()
	print("SEMUA UJI LULUS" if _failed == 0 else "GAGAL: %d" % _failed)
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failed += 1
		printerr("GAGAL: ", what)


func _empty(holes: int = 7, seeds: int = 7) -> RefCounted:
	var g := Logic.new(holes, seeds)
	g.pits.fill(0)
	return g


func _sum(g: RefCounted) -> int:
	var total := 0
	for v in g.pits:
		total += v
	return total


func _test_initial_state() -> void:
	var g := Logic.new()
	_check(_sum(g) == 98 and g.total_seeds() == 98, "total biji awal 98")
	_check(g.score(0) == 0 and g.score(1) == 0, "lumbung awal kosong")
	_check(g.legal_moves() == [0, 1, 2, 3, 4, 5, 6], "langkah awal pemain 0")
	_check(g.legal_moves(1) == [8, 9, 10, 11, 12, 13, 14], "langkah awal pemain 1")


func _test_extra_turn() -> void:
	var g := _empty()
	g.pits[6] = 1
	g.pits[0] = 3
	g.pits[10] = 2
	var events: Array = []
	var extra: bool = g.play(6, events)
	_check(extra, "biji terakhir di lumbung -> main lagi")
	_check(g.score(0) == 1, "lumbung bertambah 1")
	_check(g.current == 0, "giliran tetap di pemain 0")
	_check(events.size() == 2 and events[0].type == "pickup" and events[1].pit == 7, "catatan langkah")


func _test_capture() -> void:
	var g := _empty()
	g.pits[2] = 1   # jatuh di lubang 3 (kosong, sisi sendiri)
	g.pits[11] = 5  # seberang lubang 3
	g.pits[0] = 1
	g.pits[13] = 2  # supaya baris pemain 1 tidak kosong setelah ditembak
	var events: Array = []
	var extra: bool = g.play(2, events)
	_check(not extra, "tembak tidak memberi giliran tambahan")
	_check(g.score(0) == 6, "tembak: 5 + 1 masuk lumbung")
	_check(g.pits[3] == 0 and g.pits[11] == 0, "kedua lubang kosong setelah tembak")
	_check(g.current == 1 and not g.game_over, "giliran pindah")
	_check(events[-1].type == "capture" and events[-1].count == 6, "catatan tembak")

	# Seberang kosong: biji tetap di tempat.
	g = _empty()
	g.pits[2] = 1
	g.pits[9] = 4
	g.play(2)
	_check(g.pits[3] == 1 and g.score(0) == 0, "seberang kosong -> tidak ada tembak")
	_check(g.current == 1, "giliran pindah ke pemain 1")


func _test_empty_hole_on_enemy_side() -> void:
	var g := _empty()
	g.pits[6] = 3   # 7 (lumbung), 8, 9 -> berhenti di 9 (kosong, sisi lawan)
	g.pits[5] = 4   # seberang lubang 9
	g.pits[12] = 1
	g.play(6)
	_check(g.pits[9] == 1 and g.pits[5] == 4, "lubang kosong sisi lawan: tidak menembak")
	_check(g.score(0) == 1 and g.current == 1, "giliran selesai")


## Biji terakhir jatuh di lubang berisi: tidak diambil lagi, giliran selesai.
func _test_no_relay() -> void:
	var g := _empty()
	g.pits[0] = 2   # jatuh di 1, 2
	g.pits[2] = 3   # jadi 4 dan tetap di sana
	g.pits[8] = 1
	var events: Array = []
	var extra: bool = g.play(0, events)
	_check(g.pits[2] == 4 and g.pits[1] == 1, "lubang berisi tidak diambil lagi")
	_check(g.score(0) == 0 and not extra, "tidak ada biji masuk lumbung")
	_check(g.current == 1, "giliran pindah ke pemain 1")
	var pickups := 0
	for e in events:
		if e.type == "pickup":
			pickups += 1
	_check(pickups == 1 and events.size() == 3, "hanya satu kali mengambil biji")

	# Sebaran yang berputar penuh kembali ke lubang asal yang sudah kosong.
	g = _empty()
	g.pits[0] = 15  # 14 lubang lain selain lumbung lawan, lalu kembali ke lubang 0
	g.pits[9] = 0
	g.play(0)
	_check(g.pits[0] == 0 and g.score(0) == 1 + 2, "putaran penuh: jatuh di lubang asal lalu menembak")


func _test_skip_enemy_store() -> void:
	var g := _empty()
	g.pits[6] = 10  # 7, 8..14 (7 lubang), lewati 15, 0, 1
	g.pits[9] = 0
	g.play(6)
	_check(g.score(1) == 0, "lumbung lawan dilewati")
	_check(g.score(0) >= 1, "lumbung sendiri diisi")
	_check(_sum(g) == 10, "jumlah biji tetap")


## Begitu satu baris kosong, permainan selesai dan sisa biji di baris lain
## masuk ke lumbung pemilik baris itu.
func _test_game_ends_when_a_side_is_empty() -> void:
	var g := _empty()
	g.pits[6] = 1   # masuk lumbung; baris pemain 0 jadi kosong
	g.pits[9] = 3
	g.pits[12] = 2
	var events: Array = []
	var extra: bool = g.play(6, events)
	_check(extra and g.game_over, "baris kosong -> selesai walau dapat giliran lagi")
	_check(g.score(0) == 1 and g.score(1) == 5, "sisa biji masuk lumbung pemilik barisnya")
	_check(g.side_total(0) + g.side_total(1) == 0, "semua lubang kecil kosong")
	_check(g.winner() == 1 and g.legal_moves().is_empty(), "pemenang pemain 1, tidak ada langkah lagi")
	var last: Dictionary = events[-1]
	_check(last.type == "sweep" and last.player == 1 and last.count == 5 and last.pits == [9, 12]
			and last.store == 15, "catatan sapuan akhir")

	# Selama kedua baris masih berisi, permainan berlanjut.
	g = _empty()
	g.pits[5] = 1
	g.pits[9] = 3
	g.play(5)
	_check(not g.game_over and g.current == 1, "kedua baris berisi -> lanjut")


## Papan 4 lubang: 0..3 pemain 0, lumbung 4, 5..8 pemain 1, lumbung 9.
func _test_custom_board() -> void:
	var g := Logic.new(4, 3)
	_check(g.pit_count() == 10 and g.total_seeds() == 24, "papan 4x3: 10 lubang, 24 biji")
	_check(g.store_of(0) == 4 and g.store_of(1) == 9, "letak lumbung papan 4 lubang")
	_check(g.is_store(4) and g.is_store(9) and not g.is_store(7), "is_store papan 4 lubang")
	_check(g.owner_of(3) == 0 and g.owner_of(4) == 0 and g.owner_of(5) == 1, "pemilik lubang")
	_check(g.opposite(0) == 8 and g.opposite(3) == 5 and g.opposite(6) == 2, "lubang berhadapan")
	_check(g.legal_moves() == [0, 1, 2, 3] and g.legal_moves(1) == [5, 6, 7, 8], "langkah papan 4 lubang")
	_check(g.pits[4] == 0 and g.pits[9] == 0 and g.pits[8] == 3, "isi awal papan 4x3")

	g = _empty(4, 3)
	g.pits[3] = 1
	g.pits[6] = 2
	_check(g.play(3), "papan 4 lubang: masuk lumbung -> main lagi")
	_check(g.score(0) == 1, "lumbung pemain 0 di indeks 4")

	g = _empty(4, 3)
	g.pits[0] = 1   # jatuh di 1 (kosong), seberangnya lubang 7
	g.pits[7] = 4
	g.play(0)
	_check(g.score(0) == 5 and g.pits[7] == 0, "papan 4 lubang: tembak lubang seberang")

	g = _empty(4, 3)
	g.pits[8] = 3   # pemain 1: 9 (lumbung), 0, 1 -> lumbung pemain 0 tidak dilewati di sini
	g.pits[5] = 1
	g.current = 1
	g.play(8)
	_check(g.score(1) == 1 and g.pits[0] == 1 and g.pits[1] == 1, "pemain 1 menyebar melewati lumbungnya")

	g = _empty(4, 3)
	g.pits[3] = 7   # 4, 5, 6, 7, 8, (lewati 9), 0, 1
	g.play(3)
	_check(g.score(1) == 0 and _sum(g) == 7, "papan 4 lubang: lumbung lawan dilewati")


func _test_random_playouts() -> void:
	for size in [[7, 7], [3, 2], [4, 12], [10, 12], [5, 5], [10, 2]]:
		var holes: int = size[0]
		var seeds: int = size[1]
		var total := holes * seeds * 2
		var longest := 0
		var turns_max := 0
		for n in 150:
			var g := Logic.new(holes, seeds)
			g.reset(n % 2)
			var turns := 0
			while not g.game_over and turns < 20000:
				var moves: Array[int] = g.legal_moves()
				if moves.is_empty():
					_check(false, "tidak ada langkah padahal belum selesai")
					break
				var events: Array = []
				g.play(moves.pick_random(), events)
				longest = maxi(longest, events.size())
				turns += 1
				if _sum(g) != total:
					_check(false, "jumlah biji berubah")
					break
			_check(g.game_over, "permainan acak %dx%d selesai" % [holes, seeds])
			_check(g.score(0) + g.score(1) == total, "semua biji berakhir di lumbung")
			turns_max = maxi(turns_max, turns)
		print("playout acak %dx%d: giliran terbanyak %d, langkah animasi terpanjang %d" % [
			holes, seeds, turns_max, longest])


func _test_ai() -> void:
	for size in [[7, 7], [8, 9], [10, 12]]:
		var g := Logic.new(size[0], size[1])
		for level in 3:
			var start := Time.get_ticks_msec()
			var move: int = AI.choose_move(g, level)
			var elapsed := Time.get_ticks_msec() - start
			_check(move in g.legal_moves(), "AI tingkat %d memilih langkah sah" % level)
			print("AI papan %dx%d tingkat %d: langkah %d dalam %d ms" % [size[0], size[1], level, move, elapsed])

	# AI Sulit harus mengalahkan pemain acak di sebagian besar permainan.
	for size in [[7, 7], [5, 4]]:
		var wins := 0
		var games := 20
		var slowest := 0
		for n in games:
			var g := Logic.new(size[0], size[1])
			g.reset(n % 2)
			while not g.game_over:
				if g.current == 1:
					var start := Time.get_ticks_msec()
					var move: int = AI.choose_move(g, 2)
					slowest = maxi(slowest, Time.get_ticks_msec() - start)
					g.play(move)
				else:
					g.play(g.legal_moves().pick_random())
			if g.winner() == 1:
				wins += 1
		print("AI Sulit vs acak papan %dx%d: menang %d/%d, berpikir paling lama %d ms" % [
			size[0], size[1], wins, games, slowest])
		_check(wins >= 16, "AI Sulit menang minimal 16 dari 20")

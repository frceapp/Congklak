extends RefCounted
## Aturan permainan (murni logika, tanpa tampilan). Mengikuti mancala:
## satu lubang disebar sekali saja per giliran, tanpa estafet.
##
## Papan dengan h lubang kecil per baris punya 2h + 2 lubang, diberi nomor
## mengikuti arah penyebaran biji:
##   0..h-1     lubang kecil pemain 0
##   h          lumbung pemain 0
##   h+1..2h    lubang kecil pemain 1
##   2h+1       lumbung pemain 1
## Lubang kecil i berhadapan dengan lubang 2h - i.

const DEFAULT_HOLES := 7
const DEFAULT_SEEDS := 7
const MIN_HOLES := 3
const MAX_HOLES := 10
const MIN_SEEDS := 2
const MAX_SEEDS := 12

## Jumlah lubang kecil per baris.
var holes := DEFAULT_HOLES
## Jumlah biji awal di tiap lubang kecil.
var seeds_per_hole := DEFAULT_SEEDS
var pits := PackedInt32Array()
var current := 0
var game_over := false


func _init(hole_count: int = DEFAULT_HOLES, seed_count: int = DEFAULT_SEEDS) -> void:
	holes = hole_count
	seeds_per_hole = seed_count
	reset()


func reset(first_player: int = 0) -> void:
	pits.resize(pit_count())
	pits.fill(seeds_per_hole)
	pits[store_of(0)] = 0
	pits[store_of(1)] = 0
	current = first_player
	game_over = false


func clone() -> RefCounted:
	var copy: RefCounted = get_script().new(holes, seeds_per_hole)
	copy.pits = pits.duplicate()
	copy.current = current
	copy.game_over = game_over
	return copy


func pit_count() -> int:
	return holes * 2 + 2


func total_seeds() -> int:
	return holes * seeds_per_hole * 2


func store_of(player: int) -> int:
	return holes if player == 0 else holes * 2 + 1


func owner_of(pit: int) -> int:
	return 0 if pit <= holes else 1


func is_store(pit: int) -> bool:
	return pit == holes or pit == holes * 2 + 1


func opposite(pit: int) -> int:
	return holes * 2 - pit


func score(player: int) -> int:
	return pits[store_of(player)]


func side_total(player: int) -> int:
	var total := 0
	var start := player * (holes + 1)
	for i in range(start, start + holes):
		total += pits[i]
	return total


## Lubang yang boleh dipilih pemain (default: pemain yang sedang mendapat giliran).
func legal_moves(player: int = -1) -> Array[int]:
	if player < 0:
		player = current
	var moves: Array[int] = []
	if game_over:
		return moves
	var start := player * (holes + 1)
	for i in range(start, start + holes):
		if pits[i] > 0:
			moves.append(i)
	return moves


## Menjalankan satu giliran dari lubang `pit` untuk pemain `current`: semua
## bijinya disebar satu per satu, lalu giliran selesai di mana pun biji
## terakhir jatuh.
##   - di lumbung sendiri: pemain main lagi;
##   - di lubang kosong sisi sendiri yang seberangnya berisi: "tembak";
##   - di tempat lain (termasuk lubang berisi): tidak terjadi apa-apa.
## Jika `events` berupa Array, setiap langkah dicatat ke dalamnya untuk animasi:
##   {type = "pickup", pit, count}
##   {type = "drop", pit}
##   {type = "capture", pit, opposite, store, count}
##   {type = "sweep", player, pits, store, count}   (lihat _advance)
## Mengembalikan true bila biji terakhir jatuh di lumbung sendiri.
func play(pit: int, events: Variant = null) -> bool:
	var player := current
	assert(not game_over and owner_of(pit) == player and not is_store(pit) and pits[pit] > 0)
	var own_store := store_of(player)
	var enemy_store := store_of(1 - player)
	var count := pit_count()

	var hand := pits[pit]
	pits[pit] = 0
	if events != null:
		events.append({"type": "pickup", "pit": pit, "count": hand})

	var pos := pit
	while hand > 0:
		pos = (pos + 1) % count
		if pos == enemy_store:
			continue
		pits[pos] += 1
		hand -= 1
		if events != null:
			events.append({"type": "drop", "pit": pos})

	var extra_turn := pos == own_store
	# Biji terakhir sendirian di lubang sisi sendiri: "tembak" lubang seberang.
	if not extra_turn and owner_of(pos) == player and pits[pos] == 1:
		var opp := opposite(pos)
		if pits[opp] > 0:
			var gain := pits[opp] + 1
			pits[opp] = 0
			pits[pos] = 0
			pits[own_store] += gain
			if events != null:
				events.append({
					"type": "capture", "pit": pos, "opposite": opp,
					"store": own_store, "count": gain,
				})

	_advance(player, extra_turn, events)
	return extra_turn


## Menentukan giliran berikutnya. Begitu salah satu baris kosong, permainan
## selesai dan biji yang tersisa di baris lain masuk ke lumbung pemilik baris itu.
func _advance(player: int, extra_turn: bool, events: Variant) -> void:
	if side_total(0) > 0 and side_total(1) > 0:
		current = player if extra_turn else 1 - player
		return
	for side in 2:
		var swept: Array[int] = []
		var total := 0
		var start := side * (holes + 1)
		for i in range(start, start + holes):
			if pits[i] > 0:
				swept.append(i)
				total += pits[i]
				pits[i] = 0
		if total > 0:
			pits[store_of(side)] += total
			if events != null:
				events.append({
					"type": "sweep", "player": side, "pits": swept,
					"store": store_of(side), "count": total,
				})
	game_over = true


## 0 atau 1 untuk pemenang, -1 bila seri.
func winner() -> int:
	if score(0) == score(1):
		return -1
	return 0 if score(0) > score(1) else 1

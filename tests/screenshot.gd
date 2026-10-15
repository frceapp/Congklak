extends SceneTree
## Alat bantu pengembangan: memainkan beberapa langkah lalu menyimpan tangkapan layar.
##   godot --path . --script res://tests/screenshot.gd -- <folder_keluaran> [lubang biji [2p]]

const Config = preload("res://scripts/game_config.gd")

var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run()


func _run() -> void:
	await _open("res://scenes/menu.tscn")
	await _shot("menu")
	current_scene.call("_show_rules", true)
	await _shot("aturan")

	Config.mode = Config.Mode.VS_AI
	Config.sound = false
	Config.speed = 2
	# Argumen opsional: jumlah lubang per baris, biji per lubang, lalu "2p"
	# untuk mode 2 pemain (kedua sisi dimainkan acak oleh skrip ini).
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3:
		Config.holes = int(args[1])
		Config.seeds = int(args[2])
	if args.size() >= 4 and args[3] == "2p":
		Config.mode = Config.Mode.TWO_PLAYERS
	await _open("res://scenes/character_select.tscn")
	await _shot("karakter")
	if Config.mode == Config.Mode.TWO_PLAYERS:
		# Pemain 1 memilih karakter pertama; kartunya harus terkunci untuk Pemain 2.
		var select := current_scene
		select.call("_pick", 0)
		await _shot("karakter_pemain2")
		select._cards[0].pressed.emit()
		print("pilih karakter: kartu P1 terkunci=%s, masih giliran pemain %d" % [
			select._cards[0].disabled, select._picking + 1])
		select.call("_pick", 1)
		print("pilih karakter: hasil=%s" % [Config.characters])

	Config.characters = [0, 1]
	await _open("res://scenes/game.tscn")
	await _shot("awal")
	var game := current_scene
	# Jurus pamungkas tiap karakter: video (dilewati), lalu efek penutupnya.
	for player in 2:
		var info: Dictionary = game._board.character(player)
		game._ultimate.play(info, player, game._board)
		await create_timer(1.2).timeout
		print("pamungkas %s: tahap=%s video diputar=%s" % [
			info.id, game._ultimate.phase, game._ultimate._video.is_playing()])
		await _shot("pamungkas_video_%s" % info.id)
		game._ultimate.skip()
		await create_timer(1.6).timeout
		await _shot("pamungkas_efek_%s" % info.id)
		await create_timer(2.2).timeout
		print("pamungkas %s: setelah efek tahap=%s sibuk=%s biji tersembunyi=%s" % [
			info.id, game._ultimate.phase, game._ultimate.busy, game._board._seeds_hidden])
		await _shot("pamungkas_akhir_%s" % info.id)
		game._ultimate.clear()
		game._board.restore_seeds()

	# Jurus: cut-in + stun dari pemain bawah, lalu jurus tembak dari pemain atas.
	game._skill_fx.pace = 1.0
	game._skill_fx.cast(0, "stun")
	await create_timer(0.5).timeout
	await _shot("jurus_cutin")
	await create_timer(0.55).timeout
	await _shot("jurus_melesat")
	await create_timer(0.35).timeout
	await _shot("jurus_stun")
	await create_timer(0.8).timeout
	game._skill_fx.cast(1, "capture")
	await create_timer(0.2).timeout
	await _shot("jurus_tembak")
	await create_timer(1.0).timeout
	game._skill_fx.cast(1, "stun")
	await create_timer(0.5).timeout
	await _shot("jurus_cutin_atas")
	await create_timer(1.7).timeout
	game.call("_refresh_buttons")
	await _shot("papan")
	game.call("_on_pit_pressed", 3)
	await create_timer(0.35).timeout
	await _shot("animasi")

	# Mainkan otomatis sampai selesai untuk memeriksa alur giliran dan panel hasil.
	var guard := 0
	var picks: Array[int] = []
	while not game._logic.game_over and guard < 4000:
		guard += 1
		if not game._board.selectable.is_empty():
			picks.append(game._board.selectable.pick_random())
			game.call("_on_pit_pressed", picks[-1])
		await create_timer(0.05).timeout
		if guard == 150:
			await _shot("tengah")
	# Setelah sapuan akhir, jurus pamungkas pemenang diputar: lewati videonya,
	# lalu tunggu efek penutupnya selesai sebelum panel hasil muncul.
	var waited := 0.0
	while not game._result.visible and waited < 20.0:
		game._ultimate.skip()
		await create_timer(0.25).timeout
		waited += 0.25
	await _shot("hasil")
	print("panel hasil tampil=%s" % game._result.visible)
	print("selesai: game_over=%s skor=%d-%d langkah pemain=%s" % [
		game._logic.game_over, game._logic.score(0), game._logic.score(1), picks])
	quit()


func _open(path: String) -> void:
	change_scene_to_file(path)
	await process_frame
	await process_frame


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("tersimpan: ", path)

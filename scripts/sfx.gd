extends Node
## Efek suara yang dibangkitkan lewat kode, jadi tidak butuh berkas audio.

const Config = preload("res://scripts/game_config.gd")

const RATE := 22050

var _players := {}


func _ready() -> void:
	_add("pickup", _tone([420.0], 0.09, 0.35, 30.0, 0.5), 2)
	_add("drop", _tone([1250.0, 1900.0], 0.06, 0.45, 70.0, 0.55), 6)
	_add("store", _tone([660.0, 990.0], 0.16, 0.1, 22.0, 0.55), 4)
	_add("capture", _melody([523.0, 784.0], 0.11, 0.6), 2)
	_add("cast", _melody([660.0, 880.0, 1320.0], 0.07, 0.5), 2)
	_add("hit", _tone([170.0], 0.2, 0.7, 16.0, 0.75), 2)
	_add("win", _melody([523.0, 659.0, 784.0, 1047.0], 0.16, 0.6), 1)
	_add("lose", _melody([392.0, 330.0, 262.0], 0.2, 0.5), 1)


func play(sound: String) -> void:
	if not Config.sound or not _players.has(sound):
		return
	var player: AudioStreamPlayer = _players[sound]
	player.pitch_scale = randf_range(0.9, 1.1) if sound == "drop" else 1.0
	player.play()


func _add(sound: String, stream: AudioStreamWAV, polyphony: int) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.max_polyphony = polyphony
	add_child(player)
	_players[sound] = player


## Bunyi ketukan pendek: campuran sinus dan derau dengan peluruhan eksponensial.
static func _tone(freqs: Array, duration: float, noise: float, decay: float, volume: float) -> AudioStreamWAV:
	return _wav(_samples(freqs, duration, noise, decay, volume))


static func _melody(notes: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for note in notes:
		samples.append_array(_samples([note, note * 2.0], note_duration, 0.0, 9.0, volume))
	return _wav(samples)


static func _samples(freqs: Array, duration: float, noise: float, decay: float, volume: float) -> PackedFloat32Array:
	var count := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / RATE
		var value := 0.0
		for f in freqs:
			value += sin(TAU * f * t)
		value /= freqs.size()
		value = lerpf(value, randf_range(-1.0, 1.0), noise)
		# Serangan singkat supaya tidak berbunyi "klik".
		var attack := minf(t / 0.003, 1.0)
		samples[i] = value * exp(-t * decay) * attack * volume
	return samples


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav

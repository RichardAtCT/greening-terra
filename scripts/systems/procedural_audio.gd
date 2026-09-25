class_name ProceduralAudio
extends RefCounted
## Generated sounds with no asset behind them: the wind loop and bird chirps (no CC0 wind suited).


## Seamlessly looping, low-passed noise. Pitch and volume are changed at playback.
static func wind_loop(seconds: float, mix_rate: int, smoothing: float, seed_value := 7) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(seconds * mix_rate)
	var fade := mix_rate / 2
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	# Two one-pole low-passes: a darker body plus a little hiss, with a slow wobble in the cutoff.
	var lo := 0.0
	var hi := 0.0
	for i in raw.size():
		var w := rng.randf() * 2.0 - 1.0
		var wobble := 0.6 + 0.4 * sin(TAU * i / (mix_rate * 1.7)) * sin(TAU * i / (mix_rate * 0.63))
		lo += (w - lo) * smoothing * wobble
		hi += (w - hi) * smoothing * 4.0
		raw[i] = lo * 3.2 + (hi - lo) * 0.25
	# Crossfade the extra tail into the head so the loop has no click.
	for i in fade:
		var k := float(i) / fade
		raw[i] = raw[i] * k + raw[n + i] * (1.0 - k)
	return _wav(raw.slice(0, n), mix_rate, true)


## A short bird call: a few quick notes sweeping in pitch.
static func chirp(rng: RandomNumberGenerator, mix_rate := 22050) -> AudioStreamWAV:
	var notes := rng.randi_range(2, 4)
	var out := PackedFloat32Array()
	var base := rng.randf_range(2600.0, 4200.0)
	for k in notes:
		var dur := rng.randf_range(0.05, 0.12)
		var sweep := rng.randf_range(-0.35, 0.45)
		var f0 := base * rng.randf_range(0.85, 1.15)
		var count := int(dur * mix_rate)
		var phase := 0.0
		for i in count:
			var t := float(i) / count
			var f := f0 * (1.0 + sweep * t)
			phase += TAU * f / mix_rate
			var env := sin(PI * t)
			out.append(sin(phase + 0.6 * sin(phase * 0.5)) * env * env * 0.5)
		var gap := int(rng.randf_range(0.03, 0.09) * mix_rate)
		for i in gap:
			out.append(0.0)
	return _wav(out, mix_rate, false)


static func _wav(samples: PackedFloat32Array, mix_rate: int, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

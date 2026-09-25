extends Node
## Sound effects from a small pool of players on the SFX bus, plus the planet ambience on the
## Music bus: a generated wind loop that calms as terraform % rises, and birdsong late on.
## iOS Safari only starts audio after a user gesture, so the planet starts the ambience
## (the title screen's Start tap has already happened by then).

const DEF_PATH := "res://data/audio.tres"
const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"

var def: AudioDef

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played: Dictionary = {}
var _wind: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _chirps: Array[AudioStreamWAV] = []
var _rng := RandomNumberGenerator.new()
var _terraform := 0.0
var _storm := 0.0
var _ambience_on := false
var _time := 0.0
var _bird_wait := 0.0


func _ready() -> void:
	def = load(DEF_PATH)
	for i in def.pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)
	SettingsPanel.apply_audio()


## Plays a sound effect by id (see data/audio.tres). Unknown ids are ignored.
func play(id: StringName, pitch := 1.0) -> void:
	var s := def.sound(id)
	if s == null or s.streams.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(id, -100.0) < s.min_interval:
		return
	_last_played[id] = now
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s.streams[_rng.randi() % s.streams.size()]
	p.volume_db = s.volume_db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-s.pitch_jitter, s.pitch_jitter))
	p.play()


## Starts the wind (and birdsong, once the planet is green enough). Safe to call again.
func start_ambience() -> void:
	if _ambience_on:
		return
	_ambience_on = true
	if _wind == null:
		_wind = AudioStreamPlayer.new()
		_wind.bus = MUSIC_BUS
		_wind.stream = ProceduralAudio.wind_loop(def.wind_loop_seconds, def.wind_mix_rate, def.wind_smoothing)
		add_child(_wind)
		_birds = AudioStreamPlayer.new()
		_birds.bus = MUSIC_BUS
		add_child(_birds)
		for i in def.birds_variations:
			_chirps.append(ProceduralAudio.chirp(_rng))
	_apply_wind()
	_wind.play()
	_bird_wait = def.birds_gap_min


func stop_ambience() -> void:
	_ambience_on = false
	if _wind:
		_wind.stop()
		_birds.stop()


## The displayed terraform %, which sets how windy it sounds and whether birds sing.
func set_terraform(t: float) -> void:
	_terraform = t


## How strong the planet's hazard is right now (0..1): a dust storm howls the wind up.
func set_storm(amount: float) -> void:
	_storm = amount


func _process(delta: float) -> void:
	if not _ambience_on:
		return
	_time += delta
	_apply_wind()
	var birds := clampf((_terraform - def.birds_from) / maxf(0.01, def.birds_full_at - def.birds_from), 0.0, 1.0)
	if _terraform < def.birds_from:
		return
	_bird_wait -= delta
	if _bird_wait <= 0.0 and not _chirps.is_empty():
		_bird_wait = _rng.randf_range(def.birds_gap_min, def.birds_gap_max) / maxf(0.35, birds)
		_birds.stream = _chirps[_rng.randi() % _chirps.size()]
		_birds.volume_db = def.birds_volume_db + linear_to_db(maxf(birds, 0.05))
		_birds.pitch_scale = _rng.randf_range(0.9, 1.12)
		_birds.play()


func _apply_wind() -> void:
	var k := clampf(_terraform / 100.0, 0.0, 1.0)
	var gust := sin(_time * TAU * def.wind_gust_rate) * 0.6 + sin(_time * TAU * def.wind_gust_rate * 2.7 + 1.3) * 0.4
	_wind.volume_db = lerpf(def.wind_volume_db_start, def.wind_volume_db_end, k) + gust * def.wind_gust_db * 0.5 \
		+ _storm * def.wind_storm_db
	_wind.pitch_scale = lerpf(def.wind_pitch_start, def.wind_pitch_end, k) * (1.0 + gust * 0.04) + _storm * def.wind_storm_pitch

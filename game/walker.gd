extends Node2D

const SHEET = preload("res://art/hero_gait.png")
const UNIFORM = preload("res://uniform.gdshader")
const STEPS = [
	preload("res://audio/footstep.wav"), preload("res://audio/footstep_2.wav"),
	preload("res://audio/footstep_3.wav"), preload("res://audio/footstep_4.wav"),
	preload("res://audio/footstep_5.wav"), preload("res://audio/footstep_6.wav")
]
const DEPTH = 0.68
var body := Sprite2D.new()
var footstep := AudioStreamPlayer2D.new()
var heading := Vector2.DOWN
var gait := 0.25
var is_player := false

func setup(start: Vector2, color: Color, player: bool) -> void:
	position = start
	is_player = player
	body.texture = SHEET
	body.region_enabled = true
	body.offset = Vector2(0, -21)
	body.scale = Vector2(0.87, 0.87)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not player:
		var dye := ShaderMaterial.new()
		dye.shader = UNIFORM
		dye.set_shader_parameter("cloth", color)
		body.material = dye
	add_child(body)
	footstep.max_distance = 420
	footstep.panning_strength = 0.7
	add_child(footstep)
	if player:
		var listener := AudioListener2D.new()
		add_child(listener)
		listener.make_current()
	pose(12, false)

func pose(frame: int, running: bool) -> void:
	var view := roundi(absf(Vector2.DOWN.angle_to(heading)) / (PI / 4.0))
	body.flip_h = heading.x < 0
	body.region_rect = Rect2(frame * 56, (view * 2 + int(running)) * 56, 56, 56)

func follow(destination: Vector2, running := false, facing := Vector2.ZERO) -> void:
	var motion := (destination - position) / Vector2(1.0, DEPTH)
	position = destination
	if facing != Vector2.ZERO:
		heading = facing
	if motion.is_zero_approx():
		gait = 0.25 if gait < 0.5 else 0.75
		pose(12, false)
		return
	if facing == Vector2.ZERO:
		heading = motion.normalized()
	var old_half := gait >= 0.5
	gait = fmod(gait + motion.length() / (62.0 if running else 46.0), 1.0)
	if (gait >= 0.5) != old_half:
		footstep.stream = STEPS[2 * randi_range(0, 2) + int(gait >= 0.5)]
		if is_player:
			footstep.volume_db = -1.0 if running else -4.0
		else:
			footstep.volume_db = -12.0
		footstep.play()
	pose(floori(gait * 12.0), running)

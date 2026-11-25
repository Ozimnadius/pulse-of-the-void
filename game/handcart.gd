extends RefCounted

const DEPTH := Vector2(1, 0.68)
const HANDLE_DISTANCE := 26.0
var angle := PI
var rolled := 0.0
var parked := false
var parking_spot := Vector2(256,352)

func axis() -> Vector2:
	return Vector2.from_angle(angle)

func center(foot: Vector2) -> Vector2:
	return parking_spot if parked else foot + axis() * HANDLE_DISTANCE * DEPTH

func grip_position() -> Vector2:
	return parking_spot - axis() * HANDLE_DISTANCE * DEPTH

func fits(game, foot: Vector2, yaw: float) -> bool:
	if not game.can_walk(foot):
		return false
	var forward := Vector2.from_angle(yaw)
	var across := forward.orthogonal() * 10
	for length: float in [6.0, HANDLE_DISTANCE, 46.0]:
		var axle := forward * length
		for side in [-1,1]:
			if not game.can_walk(foot + (axle + side * across) * DEPTH):
				return false
	return true

func align_at_entry(game) -> void:
	# В старой записи могла помещаться только тележка боком к стене.
	if fits(game, game.player, angle):
		return
	var original: Vector2 = game.player
	for radius: int in [0,8,16,24,32,48,64]:
		for j in (1 if radius == 0 else 8):
			var foot := original + Vector2.from_angle(j*TAU/8) * radius * DEPTH
			for i in 16:
				var step := ceili(i / 2.0) * (1 if i % 2 else -1)
				var yaw := angle + step * TAU / 16.0
				if fits(game, foot, yaw):
					angle = yaw
					game.player = foot
					return

func park(foot: Vector2) -> void:
	if parked:
		return
	parking_spot = center(foot)
	parked = true

func drive(game, direction: Vector2, speed: float, delta: float) -> void:
	if direction == Vector2.ZERO:
		return
	var foot: Vector2 = game.player
	var wanted := direction.angle()
	var yaw := rotate_toward(angle, wanted, 4.5 * delta)
	var turning_back := axis().dot(direction) < 0.5
	if yaw != angle:
		# При развороте герой обходит рукоять, удерживая платформу в середине настила.
		var pivot := center(foot) - Vector2.from_angle(yaw) * HANDLE_DISTANCE * DEPTH
		if turning_back and fits(game, pivot, yaw):
			game.player = pivot
			angle = yaw
		elif fits(game, foot, yaw):
			angle = yaw
		elif fits(game, pivot, yaw):
			game.player = pivot
			angle = yaw
	var alignment := clampf(axis().dot(direction),0.0,1.0)
	var travel := direction * speed * lerpf(0.25,1.0,alignment) * DEPTH * delta
	for component in [Vector2(travel.x,0),Vector2(0,travel.y)]:
		if component != Vector2.ZERO and fits(game, game.player + component, angle):
			game.player += component
	rolled += ((game.player - foot) / DEPTH).length()
	if game.supply.place == game.supply.Place.DOCK and direction.x < 0 and game.player.x < 285:
		var at := center(game.player)
		if at.x >= 244 and at.distance_to(game.supply.CART_BAY) < 26:
			park(game.player)
			game._autosave()

extends Node2D

const Trip = preload("res://supply_run.gd")
const CART = preload("res://art/freight_cart.png")
const ITEMS = preload("res://art/freight_items.png")
const CELL := 180
const SIZE := Vector2(72,72)
const DEPTH := Vector2(1,0.68)
var trip
var shop := false
var ration_worker := false

static func shadow(c: Node2D, p: Vector2, yaw: float, length: float, width: float) -> void:
	var outline := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		var edge := Vector2(length*cos(a),width*sin(a)).rotated(yaw) * DEPTH
		outline.append(p + Vector2(1,1.5) + edge)
	c.draw_colored_polygon(outline,Color(0.035,0.032,0.023,0.34))

static func draw_frame(c: Node2D, tex: Texture2D, p: Vector2, frame: int, columns: int) -> void:
	var source := Vector2(frame % columns, floori(float(frame)/columns)) * CELL
	c.draw_texture_rect_region(tex,Rect2(p-SIZE/2,SIZE),Rect2(source,Vector2(CELL,CELL)))

static func draw_cart(c: Node2D, p: Vector2, load_mask: int, yaw := 0.0, rolled := 0.0) -> void:
	var turn := posmod(roundi(yaw * 32.0 / TAU),32)
	var phase := floori(rolled/2.7) % 2
	shadow(c,p,yaw,23,12)
	draw_frame(c,CART,p,(load_mask*2+phase)*32+turn,16)

static func draw_item(c: Node2D, p: Vector2, item: int) -> void:
	draw_frame(c,ITEMS,p,0 if item == Trip.RATIONS else 1,5)

static func pallet(c: Node2D, p: Vector2, item: int) -> void:
	shadow(c,p,-0.15,18,13)
	draw_frame(c,ITEMS,p,2 if item == Trip.RATIONS else 3,5)

func _draw() -> void:
	var actor = get_parent()
	if ration_worker:
		if actor.position.distance_to(Vector2(272,330)) > 17:
			draw_rect(Rect2(-5,-17,12,6), Color("#d0af76"))
			draw_rect(Rect2(0,-17,2,6), Color("#344143"))
		return
	if shop and trip.access_ready:
		if trip.cart.parked:
			return
		var axis: Vector2 = trip.cart.axis()
		var lateral := axis.orthogonal()
		var hub: Vector2 = trip.cart.center(actor.position) - actor.position
		draw_cart(self,hub,trip.carried,trip.cart.angle,trip.cart.rolled)
		for side: int in [-1,1]:
			var shoulder := (lateral*side*4.5)*DEPTH + Vector2(0,-23)
			var grip := hub + (-axis*21.8+lateral*side*6.4)*DEPTH + Vector2(0,-17.5)
			var elbow := shoulder.lerp(grip,0.5) + Vector2(0,2)
			draw_line(shoulder,elbow,Color("#435652"),2.8,true)
			draw_line(elbow,grip,Color("#82775a"),2.5,true)
			draw_circle(grip,1.6,Color("#ba9a70"))
	elif trip.carried:
		draw_item(self,Vector2(4,-14),trip.carried)

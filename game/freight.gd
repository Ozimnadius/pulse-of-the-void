extends Node2D

const Trip = preload("res://supply_run.gd")
const IRON := Color("#263339")
const RIM := Color("#a8b5aa")
const BRASS := Color("#d6a25b")
const SHADOW := Color(0.025, 0.045, 0.05, 0.55)
var trip
var cart := false
var ration_worker := false

func _draw() -> void:
	if ration_worker:
		# Житель отходит от ящика с одним свёртком и возвращается с пустыми руками.
		if get_parent().position.distance_to(Vector2(272,330)) > 17:
			draw_rect(Rect2(-5,-17,12,6), Color("#d0af76"))
			draw_rect(Rect2(0,-17,2,6), IRON)
		return
	if cart:
		draw_cart(self, trip.cart_offset(get_parent().position), trip.carried)
	elif trip.carried:
		draw_item(self, Vector2(4,-13), trip.carried)

static func draw_cart(c: Node2D, p: Vector2, load_mask: int) -> void:
	c.draw_set_transform(p,0,Vector2(0.78,0.78))
	p = Vector2.ZERO
	c.draw_rect(Rect2(p + Vector2(-27,-4), Vector2(54,10)), SHADOW)
	for x in [-21,16]:
		c.draw_circle(p + Vector2(x,1), 5, IRON)
		c.draw_circle(p + Vector2(x,1), 2, RIM)
	c.draw_rect(Rect2(p + Vector2(-27,-11), Vector2(48,9)), IRON)
	c.draw_rect(Rect2(p + Vector2(-27,-10), Vector2(48,3)), BRASS)
	c.draw_line(p+Vector2(17,-9),p+Vector2(24,-25),RIM,3)
	c.draw_line(p+Vector2(24,-25),p+Vector2(31,-25),IRON,4)
	if load_mask & Trip.RATIONS:
		draw_item(c, p + Vector2(-16,-10), Trip.RATIONS)
	if load_mask & Trip.HEATER:
		draw_item(c, p + Vector2(7,-10), Trip.HEATER)
	c.draw_set_transform(Vector2.ZERO)

static func draw_item(c: Node2D, p: Vector2, item: int) -> void:
	if item == Trip.RATIONS:
		c.draw_rect(Rect2(p+Vector2(-13,-15),Vector2(26,16)), IRON)
		c.draw_rect(Rect2(p+Vector2(-12,-14),Vector2(24,13)), Color("#a0794d"))
		c.draw_rect(Rect2(p+Vector2(-12,-15),Vector2(24,4)), Color("#d2ac76"))
		for x in [-8,7]:
			c.draw_rect(Rect2(p+Vector2(x,-15),Vector2(2,15)), Color("#534d41"))
		c.draw_rect(Rect2(p+Vector2(-4,-10),Vector2(8,5)),Color("#efe2b9"))
		c.draw_line(p+Vector2(-2,-8),p+Vector2(2,-8),IRON,1)
	else:
		c.draw_rect(Rect2(p+Vector2(-10,-20),Vector2(20,21)), IRON)
		c.draw_rect(Rect2(p+Vector2(-9,-18),Vector2(18,15)), Color("#668781"))
		c.draw_rect(Rect2(p+Vector2(-5,-23),Vector2(10,5)), RIM,false,2)
		for y in [-15,-12,-9,-6]:
			c.draw_line(p+Vector2(-6,y),p+Vector2(6,y),IRON,1)
		c.draw_circle(p+Vector2(6,-16),1.5,BRASS)

static func pallet(c: Node2D, p: Vector2, item: int) -> void:
	c.draw_rect(Rect2(p+Vector2(-25,-4),Vector2(50,12)),SHADOW)
	for y in [-7,-2,3]:
		c.draw_rect(Rect2(p+Vector2(-23,y),Vector2(45,4)),Color("#937757"))
	draw_item(c,p,item)

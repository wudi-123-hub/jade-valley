extends Control

var brass := Color("#caab67")
var soft := Color("#7b794e")
var dock := false

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w<70 or h<38:
		return
	for mx in [1,-1]:
		for my in [1,-1]:
			var x: float = 12 if mx==1 else w-12
			var y: float = 12 if my==1 else h-12
			var origin := Vector2(x,y)
			var vx := Vector2(mx,0)
			var vy := Vector2(0,my)
			var curve := PackedVector2Array([
				origin+vx*37,origin+vx*12,origin+vx*5+vy*7,origin+vy*13,origin+vy*35
			])
			draw_polyline(curve,Color(brass,.86),1.8,true)
			draw_line(origin+vx*20+vy*5,origin+vx*42+vy*5,Color(soft,.88),1.0,true)
			draw_line(origin+vy*17+vx*5,origin+vy*34+vx*5,Color(soft,.88),1.0,true)
			var center := origin+vx*8+vy*9
			draw_colored_polygon(PackedVector2Array([center-Vector2(4,0),center-Vector2(0,4),center+Vector2(4,0),center+Vector2(0,4)]),Color(brass,.88))
	if dock:
		for at in [Vector2(0,h*.5),Vector2(w,h*.5)]:
			draw_circle(at,8,Color("#233b2d"),true,-1,true)
			draw_arc(at,7,0,TAU,32,brass,1.3,true)
			draw_circle(at,2.5,brass)

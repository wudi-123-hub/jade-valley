extends Control

const PAVILION = preload("res://assets/teaching-pavilion.webp")

var scenery: TextureRect
var teacher: TextureRect
var student: TextureRect
var glow: GradientTexture2D
var progress := 0.0
var accent: Color

func _ready() -> void:
	var light := Gradient.new()
	light.offsets=PackedFloat32Array([0,.29,.72,1])
	light.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.64),Color(1,1,1,.13),Color(1,1,1,0)])
	glow=GradientTexture2D.new()
	glow.width=256
	glow.height=256
	glow.fill=GradientTexture2D.FILL_RADIAL
	glow.fill_from=Vector2(.5,.5)
	glow.fill_to=Vector2(1,.5)
	glow.gradient=light

func play_frame(value: float) -> void:
	progress=value
	scenery.scale=Vector2.ONE*(1.015+value*.057)
	var entrance := smoothstep(.09,.53,value)
	teacher.position=Vector2(102-126*(1-entrance),134)
	student.position=Vector2(779+126*(1-entrance),229)
	teacher.modulate.a=entrance
	student.modulate.a=entrance
	queue_redraw()

func _draw() -> void:
	if glow==null:
		return
	var center := size*Vector2(.5,.46)
	var clarity := smoothstep(0,.36,progress)
	for i in 6:
		var fog_x := fposmod(183.0*i+progress*(134+21*i),size.x+660)-280
		var fog := Rect2(fog_x,210+float((i*43)%155),470,108+19*(i%3))
		draw_texture_rect(glow,fog,false,Color(.77,.93,.90,(.22-.12*clarity)))
	var seal := smoothstep(.42,.70,progress)
	var transfer := smoothstep(.56,.86,progress)
	var target := center.lerp(Vector2(935,355),transfer) - Vector2(0,sin(transfer*PI)*120)
	draw_texture_rect(glow,Rect2(target-Vector2(111,97),Vector2(222,194)),false,Color(accent,seal*.68))
	draw_texture_rect(glow,Rect2(center-Vector2(201,151),Vector2(402,302)),false,Color(accent,sin(seal*PI)*.33+.10))
	if seal>0:
		draw_set_transform(target,progress*1.1,Vector2(1,.62))
		var rim := Color(accent,seal*(.78-.35*transfer))
		draw_arc(Vector2.ZERO,70+24*seal,0,TAU,84,rim,1.7,true)
		draw_arc(Vector2.ZERO,54+18*seal,0,TAU,72,Color(accent,rim.a*.5),1,true)
		for i in 8:
			var angle := i*TAU/8
			var point := Vector2.from_angle(angle)*(82+24*seal)
			draw_circle(point,2.8,Color(1,.96,.76,rim.a),true,-1,true)
		draw_set_transform(Vector2.ZERO)
	for i in 26:
		var angle := float(i)*2.39996+progress*(.7+.13*(i%4))
		var span := 43+float((i*67)%195)+progress*(i%5)*13
		var point := center+Vector2.from_angle(angle)*Vector2(span,span*.62)-Vector2(0,progress*54)
		var fade := (.27+.39*absf(sin(float(i)+progress*3.8)))*clarity
		draw_circle(point,1.1+float(i%4)*.57,Color(1,.91,.67,fade),true,-1,true)

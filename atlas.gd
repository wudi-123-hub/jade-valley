extends Control

signal camera_changed
const FALLS = [
	[[.35,.13,.38,.37],[.51,.23,.52,.33],[.26,.30,.24,.44],[.64,.84,.61,.97]],
	[[.21,.22,.21,.35],[.16,.29,.18,.40],[.83,.26,.85,.39],[.81,.70,.86,.90]],
	[[.74,.27,.74,.47],[.76,.69,.75,.88],[.20,.61,.17,.76]],
	[[.32,.15,.33,.33],[.82,.75,.79,.97],[.41,.68,.44,.88]]
]
const POOLS = [
	[[.39,.36],[.40,.63],[.53,.69],[.57,.46]],[[.21,.38],[.37,.56],[.68,.57]],
	[[.73,.49],[.30,.78]],[[.51,.39],[.72,.65],[.45,.78]]
]
const COLORS = [Color("#ffbdcd"),Color("#e8f6a7"),Color("#ffc16d"),Color("#e7f8ff")]
var maps: Array[Texture2D] = [
	preload("res://assets/spring.webp"),preload("res://assets/summer.webp"),
	preload("res://assets/autumn.webp"),preload("res://assets/winter.webp")
]
var index := 0
var previous := 0
var fade := 1.0
var timer := 0.0
var target_pan := Vector2.ZERO
var pan := Vector2.ZERO
var target_zoom := 1.0
var zoom := 1.0
var moving := false
var motion := true
var flakes: Array[Vector4] = []
var fog: GradientTexture2D
var shade: GradientTexture2D

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var random := RandomNumberGenerator.new()
	random.seed = 92643
	for i in 66:
		flakes.append(Vector4(random.randf(),random.randf(),random.randf_range(.035,.081),random.randf_range(1,4.3)))
	var cloud := Gradient.new()
	cloud.colors = PackedColorArray([Color(0.97,.94,.85,.31),Color(0.83,.93,.96,0)])
	fog = GradientTexture2D.new()
	fog.width = 96
	fog.height = 96
	fog.fill = GradientTexture2D.FILL_RADIAL
	fog.fill_from = Vector2(.5,.5)
	fog.fill_to = Vector2(.98,.5)
	fog.gradient = cloud
	var dark := Gradient.new()
	dark.offsets = PackedFloat32Array([0.0,.29,.70,1.0])
	dark.colors = PackedColorArray([Color(0.02,.11,.10,.73),Color(0.02,.11,.10,0),Color(0.02,.11,.10,.03),Color(0.02,.11,.10,.62)])
	shade = GradientTexture2D.new()
	shade.width = 1
	shade.height = 192
	shade.fill_from = Vector2(0,0)
	shade.fill_to = Vector2(0,1)
	shade.gradient = dark

func change_season(area: int) -> void:
	if index == area:
		return
	previous = index
	index = area
	fade = 0.0 if motion else 1.0
	reset_camera()
	queue_redraw()

func reset_camera() -> void:
	target_zoom = 1.0
	target_pan = Vector2.ZERO

func zoom_camera(amount: float, around: Vector2) -> void:
	var next := clampf(target_zoom+amount,1.0,2.15)
	var offset := around-size*.5
	target_pan = offset - (offset-target_pan)*(next/target_zoom)
	target_zoom = next
	limit_pan()

func limit_pan() -> void:
	var margin: Vector2 = (art_size(target_zoom)-size)*.5
	target_pan = target_pan.clamp(-margin,margin)

func art_size(scale_factor: float) -> Vector2:
	var image := maps[index].get_size()
	return image * maxf(size.x/image.x,size.y/image.y) * scale_factor

func art_rect() -> Rect2:
	var dimensions := art_size(zoom)
	return Rect2((size-dimensions)*.5+pan,dimensions)

func project(point: Vector2) -> Vector2:
	var rect := art_rect()
	return rect.position+point*rect.size

func _process(delta: float) -> void:
	var moved := zoom != target_zoom or pan != target_pan
	if moved:
		if motion:
			var factor := 1.0-exp(-14.0*delta)
			zoom = lerpf(zoom,target_zoom,factor)
			pan = pan.lerp(target_pan,factor)
			if absf(zoom-target_zoom)<.001:
				zoom = target_zoom
			if pan.distance_squared_to(target_pan)<.1:
				pan = target_pan
		else:
			zoom = target_zoom
			pan = target_pan
		camera_changed.emit()
	if motion:
		timer += delta
		fade = minf(1.0,fade+delta*1.85)
	if motion or moved:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_camera(.19,event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_camera(-.19,event.position)
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
			moving = event.pressed
			mouse_default_cursor_shape = Control.CURSOR_MOVE if moving else Control.CURSOR_DRAG
			accept_event()
	elif event is InputEventMouseMotion and (moving or event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if event.button_mask == 0:
			moving = false
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			return
		target_pan += event.relative
		limit_pan()
		accept_event()

func _draw() -> void:
	if not is_instance_valid(shade):
		return
	var rect := art_rect()
	if fade < 1.0:
		draw_texture_rect(maps[previous],rect,false)
	draw_texture_rect(maps[index],rect,false,Color(1,1,1,fade))
	if motion:
		draw_weather()
	draw_texture_rect(shade,Rect2(Vector2.ZERO,size),false)

func draw_weather() -> void:
	for waterfall: Array in FALLS[index]:
		var start := project(Vector2(waterfall[0],waterfall[1]))
		var end := project(Vector2(waterfall[2],waterfall[3]))
		for i in 16:
			var f := fposmod(timer*(.69 + float(i%3)*.13)+i*.071,1.0)
			var drift := Vector2(sin(float(i)*5.74)*(5.0+zoom),0)
			var here := start.lerp(end,f)+drift
			var there := start.lerp(end,minf(1.0,f+.05+float(i%4)*.016))+drift
			draw_line(here,there,Color(.77,.97,1,.11 + .32*sin(PI*f)),1.1+float(i%4)*.56,true)
	for i in POOLS[index].size():
		var pool: Array = POOLS[index][i]
		var phase := fposmod(timer*.53+i*.28,1.0)
		var center := project(Vector2(pool[0],pool[1]))
		var line := PackedVector2Array()
		for step in 21:
			var theta := step*TAU/20.0
			line.append(center+Vector2(cos(theta)*(3+phase*31),sin(theta)*(1.5+phase*7))*zoom)
		draw_polyline(line,Color(.76,1.0,.95,.45*(1-phase)),1.2,true)
	for i in flakes.size():
		var mote := flakes[i]
		var upward := -.23 if index==1 else 1.0
		var y := fposmod(mote.y + timer*mote.z*upward,1.0)*size.y
		var x := fposmod(mote.x + timer*mote.z*.38+sin(timer*.92+mote.y*17)*.027,1.0)*size.x
		var alpha := .32+.45*absf(sin(timer+float(i)))
		var particle := Color(COLORS[index],alpha)
		var direction := Vector2.from_angle(timer*.71+float(i))*mote.w
		var center := Vector2(x,y)
		if index in [0,2]:
			var wing := direction.orthogonal()*.49
			draw_colored_polygon(PackedVector2Array([center-direction,center-wing,center+direction,center+wing*.72]),particle)
		else:
			draw_circle(center,mote.w*.61,particle,true,-1,true)
	for i in 5:
		var width := size.x * (.52+.16*sin(float(i)*9))
		var center := Vector2(fposmod(timer*(.016+.002*i)+i*.29,1.36)*size.x-size.x*.16,size.y*(.16+i*.17))
		var height := 118.0+13*i
		draw_texture_rect(fog,Rect2(center-Vector2(width*.5,height*.5),Vector2(width,height)),false,Color(1,1,1,.54))

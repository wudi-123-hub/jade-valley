extends Control

const COLORS = {
	"tide":Color("#73e3ff"),"dragon":Color("#ffae65"),"staff":Color("#ffc16b"),
	"ember":Color("#df85ff"),"wind":Color("#91ffbd"),"seal":Color("#ffd67f"),
	"moon":Color("#ddbcff"),"arrow":Color("#96f8ff"),"shield":Color("#ffe08b")
}

var animate := true
var glow: GradientTexture2D
var events: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets=PackedFloat32Array([0,.16,.49,1])
	gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.69),Color(1,1,1,.21),Color(1,1,1,0)])
	glow=GradientTexture2D.new()
	glow.width=128
	glow.height=128
	glow.fill=GradientTexture2D.FILL_RADIAL
	glow.fill_from=Vector2(.5,.5)
	glow.fill_to=Vector2(1,.5)
	glow.gradient=gradient

func swing(at: Vector2,direction: float,school: String,reach: float,diving: bool) -> void:
	events.append({"kind":"swing","at":at,"face":direction,"school":school,"reach":reach,
		"diving":diving,"age":0.0,"span":.23})

func cast(at: Vector2,goal: Vector2,direction: float,school: String) -> void:
	events.append({"kind":"cast","at":at,"goal":goal,"face":direction,"school":school,
		"age":0.0,"span":.64 if animate else .33})

func hit(at: Vector2,tint: Color,heavy := false,blocked := false,delay := 0.0) -> void:
	events.append({"kind":"hit","at":at,"color":tint,"heavy":heavy,"blocked":blocked,
		"age":-delay,"span":.46 if animate else .24})

func ward(at: Vector2,tint: Color) -> void:
	events.append({"kind":"ward","at":at,"color":tint,"age":0.0,"span":.55 if animate else .22})

func advance(dt: float) -> void:
	if events.is_empty():
		return
	for i in range(events.size()-1,-1,-1):
		events[i].age+=dt
		if events[i].age>=events[i].span:
			events.remove_at(i)
	queue_redraw()

func _draw() -> void:
	for event in events:
		var progress: float = event.age/event.span
		if progress<0:
			continue
		match String(event.kind):
			"swing": draw_swing(event,progress)
			"cast": draw_cast(event,progress)
			"hit": draw_impact(event,progress)
			"ward": draw_ward(event,progress)

func haze(at: Vector2,span: Vector2,tint: Color,alpha: float) -> void:
	draw_texture_rect(glow,Rect2(at-span*.5,span),false,Color(tint,alpha))

func cut(at: Vector2,radius: Vector2,from: float,to: float,width: float,tint: Color,alpha: float) -> void:
	var rim := PackedVector2Array()
	var belly := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 27:
		var u := float(i)/26
		var normal := Vector2.from_angle(lerpf(from,to,u))
		var taper := pow(maxf(0.0,sin(u*PI)),.62)*(1.0-u*.35)
		rim.append(at+normal*radius)
		belly.append(at+normal*(radius-Vector2.ONE*width*taper))
		colors.append(Color(tint.lightened(.71),alpha*taper))
	belly.reverse()
	rim.append_array(belly.slice(1,26))
	for i in 25:
		var u := float(25-i)/26
		colors.append(Color(tint.darkened(.44),alpha*sin(u*PI)*.65))
	draw_polygon(rim,colors)
	var rimline := rim.slice(1,26)
	draw_polyline(rimline,Color(tint.lightened(.77),alpha*.65),1.8,true)

func ray(from: Vector2,to: Vector2,width: float,tint: Color,alpha: float) -> void:
	if from.distance_squared_to(to)<1.0:
		return
	var along := (to-from).normalized()
	var normal := along.orthogonal()
	var shoulder := from.lerp(to,.43)
	var points := PackedVector2Array([from,shoulder-normal*width,to,shoulder+normal*width])
	draw_polygon(points,PackedColorArray([Color(tint,0),Color(tint,alpha*.66),Color(tint.lightened(.67),alpha),Color(tint,alpha*.66)]))
	draw_line(shoulder,to,Color(tint.lightened(.81),alpha*.85),maxf(1,width*.18),true)

func diamond(at: Vector2,length: float,width: float,angle: float,tint: Color) -> void:
	var axis := Vector2.from_angle(angle)
	var normal := axis.orthogonal()
	draw_colored_polygon(PackedVector2Array([at+axis*length,at+normal*width,at-axis*length,at-normal*width]),tint)

func draw_swing(event: Dictionary,p: float) -> void:
	var at: Vector2 = event.at
	var face: float = event.face
	var school: String = event.school
	var tint: Color = COLORS[school]
	var reach: float = event.reach
	var opacity := pow(1.0-p,.8)*.91
	if event.diving:
		cut(at+Vector2(0,12),Vector2(89,108),.17,PI-.19,42,tint,opacity)
		ray(at-Vector2(-24,60),at+Vector2(-18,86*p),15,tint,opacity*.72)
		return
	if school=="arrow" or school=="ember":
		var tip := at+Vector2(face*(23+reach*ease(p,.48)),-5)
		ray(at+Vector2(7*face,-6),tip,12 if school=="ember" else 8,tint,opacity)
		diamond(tip,14,5,0,Color(tint.lightened(.72),opacity))
		return
	if school=="moon":
		var moon := at+Vector2(face*(22+reach*.74*sin(p*PI)),-17)
		cut(moon,Vector2(49,56),-1.67 if face>0 else 1.46,1.63 if face>0 else 4.79,25,tint,opacity)
		haze(moon,Vector2(136,130),tint,opacity*.42)
		return
	var direction := 0.0 if face>0 else PI
	var wide := 1.22 if school in ["staff","wind","shield"] else .91
	var angle := direction+(p-.23)*.52*face
	cut(at+Vector2(face*(7+23*p),5),Vector2(reach*.91,82),angle-wide,angle+wide,44,tint,opacity)
	cut(at+Vector2(face*(28+33*p),-4),Vector2(reach*.64,107),angle-wide-.19,angle+wide-.23,25,tint,opacity*.47)
	if animate:
		haze(at+Vector2(face*81,-8),Vector2(222,154),tint,opacity*.46)

func draw_cast(event: Dictionary,p: float) -> void:
	var at: Vector2 = event.at
	var goal: Vector2 = event.goal
	var face: float = event.face
	var school: String = event.school
	var tint: Color = COLORS[school]
	var force := smoothstep(.02,.30,p)
	var flight := ease(minf(1.0,p/.54),.48)
	var out := pow(1.0-p,.58)
	var head := at.lerp(goal,flight)
	var alpha := out*(.14+.86*smoothstep(.035,.25,p))
	var side := 0.0 if face>0 else PI
	haze(at,Vector2(195,159),tint,out*.48)
	if animate:
		haze(head,Vector2(393,249),tint,alpha*.49)
	match school:
		"tide","wind":
			var swell := 108+79*force
			for i in 3:
				var crest := head-Vector2(face*i*47,13+i*19)
				var tilt := side+face*(-.58+i*.31+p*.62)
				cut(crest,Vector2(swell-i*17,91+i*29),tilt-1.11,tilt+1.23,55-i*9,tint,alpha*(.91-i*.20))
			stream(at,head,face,tint,alpha,school=="wind")
		"dragon":
			draw_dragon(at,head,face,tint,force,alpha)
		"staff":
			draw_staff(at,goal,face,tint,force,alpha)
		"ember","arrow":
			var lanes := 5 if school=="arrow" else 3
			for i in lanes:
				var offset := Vector2(-face*16*absf(i-(lanes-1)*.5),(i-(lanes-1)*.5)*24)
				var tip := head+offset+Vector2(face*(44+21*force),-3)
				var trace := at.lerp(head,.12+i*.13)+offset*.51
				ray(trace,tip,33 if i*2==lanes-1 else 13,tint,alpha)
				diamond(tip,20,6,0,Color(tint.lightened(.74),alpha))
			if school=="ember":
				sigil(head,52+force*45,p*2.2,tint,alpha*.72,6)
		"seal":
			stream(at,head,face,tint,alpha,false)
			sigil(head,43+96*force,p*.85,tint,alpha,8)
			ray(head-Vector2(0,211),head+Vector2(0,108),29,tint,alpha*.93)
			haze(head,Vector2(195,299),tint,alpha*.60)
		"moon":
			var moon := head-Vector2(0,43+43*sin(p*PI))
			cut(moon,Vector2(112,136),side-1.87,side+1.81,71,tint,alpha)
			cut(moon-Vector2(face*27,0),Vector2(91,108),side-1.68,side+1.71,24,tint,alpha*.55)
			stream(at,moon,face,tint,alpha*.85,true)
			haze(moon,Vector2(290,273),tint,alpha*.63)
		"shield":
			sigil(head,54+79*force,p*.72,tint,alpha,6)
			cut(at.lerp(head,.81),Vector2(109,127),side-1.18,side+1.18,58,tint,alpha)
			ray(at,head+Vector2(face*60,0),39,tint,alpha*.56)
	if not animate:
		return
	for i in 23:
		var u := fposmod(float(i)*.618034+p*.67,1.0)
		var mote := at.lerp(head,u)+Vector2(face*(19+i%5)*p,sin(i*2.3+p*6)*(38+float(i%5)*18))
		var light := alpha*(.26+.59*absf(sin(float(i)*4.7+p*6)))
		diamond(mote,3+float(i%4)*3,1.4,face*.21,Color(tint.lightened(.63),light))

func stream(at: Vector2,head: Vector2,face: float,tint: Color,alpha: float,swirl: bool) -> void:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var width := 31.0 if swirl else 20.0
	for i in 25:
		var u := float(i)/24
		var crest := sin(u*TAU*(1.26 if swirl else .55))*48.0*sin(u*PI)*face
		var mid := at.lerp(head,u)+Vector2(0,crest)
		var depth := width*sin(u*PI)
		upper.append(mid-Vector2(0,depth))
		lower.append(mid+Vector2(0,depth))
	var edge := upper.duplicate()
	lower.reverse()
	upper.append_array(lower.slice(1,24))
	if absf(head.x-at.x)>6:
		draw_colored_polygon(upper,Color(tint,alpha*.31))
	draw_polyline(edge,Color(tint.lightened(.7),alpha*.78),2.5,true)

func draw_dragon(at: Vector2,head: Vector2,face: float,tint: Color,force: float,alpha: float) -> void:
	var spine := PackedVector2Array()
	for i in 30:
		var u := float(i)/29
		var curl := sin(u*TAU*1.11-force*2.6)*78*sin(u*PI)
		spine.append(at.lerp(head,u)+Vector2(0,curl-22*u))
	if at.distance_to(head)>4:
		draw_polyline(spine,Color(tint.darkened(.46),alpha*.75),32,true)
		draw_polyline(spine,Color(tint,alpha*.84),18,true)
		draw_polyline(spine,Color(tint.lightened(.74),alpha*.79),4,true)
	head.y-=24
	draw_set_transform(head,0,Vector2(face,1))
	var shape := PackedVector2Array([Vector2(-75,-34),Vector2(-40,-50),Vector2(-38,-81),Vector2(-20,-55),
		Vector2(4,-91),Vector2(17,-50),Vector2(55,-34),Vector2(88,-17),Vector2(68,0),Vector2(32,-5),
		Vector2(65,17),Vector2(46,32),Vector2(-16,15),Vector2(-56,21),Vector2(-40,-1)])
	draw_colored_polygon(shape,Color(tint.darkened(.3),alpha*.92))
	var edge := shape.duplicate()
	edge.append(shape[0])
	draw_polyline(edge,Color(tint.lightened(.69),alpha*.92),2.7,true)
	diamond(Vector2(17,-24),13,5,-.2,Color("#fff6cb",alpha))
	draw_set_transform(Vector2.ZERO)

func draw_staff(at: Vector2,goal: Vector2,face: float,tint: Color,force: float,alpha: float) -> void:
	var high_tip := at+Vector2(face*134,-257)
	var low_tip := goal+Vector2(face*90,79)
	var tip := high_tip.lerp(low_tip,force)
	cut(at+Vector2(59*face,-82),Vector2(284,223),-.99 if face>0 else 1.17,1.95 if face>0 else 4.13,92,tint,alpha*.85)
	ray(at-Vector2(face*48,-29),tip,41,tint,alpha)
	draw_line(at-Vector2(face*47,-22),tip,Color(tint.darkened(.37),alpha*.88),18,true)
	draw_line(at-Vector2(face*47,-22),tip,Color(tint.lightened(.66),alpha*.96),6,true)
	diamond(tip,29,14,(tip-at).angle(),Color(tint.lightened(.75),alpha))

func sigil(at: Vector2,radius: float,angle: float,tint: Color,alpha: float,sides: int) -> void:
	var path := PackedVector2Array()
	for i in sides:
		var bearing := angle+i*TAU/sides
		var point := at+Vector2.from_angle(bearing)*radius
		path.append(point)
		diamond(point,9,4,bearing,Color(tint.lightened(.65),alpha))
	draw_colored_polygon(path,Color(tint,alpha*.13))
	path.append(path[0])
	draw_polyline(path,Color(tint.lightened(.63),alpha),3,true)
	draw_arc(at,radius*.77,angle,angle+TAU,54,Color(tint,alpha*.69),2,true)
	draw_arc(at,radius*1.11,angle,angle+TAU,66,Color(tint,alpha*.63),1.6,true)

func draw_impact(event: Dictionary,p: float) -> void:
	var at: Vector2 = event.at
	var tint: Color = event.color
	var power := 1.43 if event.heavy else .84
	var alpha := pow(1.0-p,1.58)
	var projection := 34+((113 if animate else 53) if event.heavy else 65)*p
	haze(at,Vector2(211,181)*power,tint,alpha*.77)
	draw_arc(at,projection*.73,0,TAU,43,Color(tint.lightened(.46),alpha*.83),maxf(1.0,4-p*3),true)
	if p<.37:
		var flash := (1.0-p/.37)*power
		diamond(at,94*flash,12*flash,-.51,Color(tint.lightened(.84),alpha*.96))
		diamond(at,55*flash,9*flash,1.22,Color(tint.lightened(.88),alpha*.87))
	var count := 21 if event.heavy else 12
	if not animate:
		count=5
	for i in count:
		var angle := float(i)*2.39996
		var axis := Vector2.from_angle(angle)
		var drift := Vector2(0,58*p*p)
		var mote := at+axis*(projection*(.44+float(i%6)*.18))*power+drift
		ray(mote-axis*(11+18*float(i%4))*alpha,mote,2+float(i%3),tint,alpha)
	if event.blocked:
		sigil(at,39+p*29,p*.45,tint,alpha,6)

func draw_ward(event: Dictionary,p: float) -> void:
	var at: Vector2 = event.at
	var tint: Color = event.color
	var alpha := pow(1.0-p,.7)
	haze(at,Vector2(223,212),tint,alpha*.65)
	sigil(at,65+45*p,-.3+p*.8,tint,alpha,6)
	for i in 3:
		draw_arc(at,53+i*17+89*p,-.39+i*.31,1.93+i*.62,30,Color(tint,alpha*.7),3-i*.69,true)

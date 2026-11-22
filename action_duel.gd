extends Control

const UI = preload("res://ui.gd")
const Expedition = preload("res://expedition.gd")
const State = preload("res://state.gd")

signal finished(won: bool)
signal changed
signal sounded(cue: String)

const FLOOR := 746.0
const LEFT := 82.0
const RIGHT := 1358.0
const LEDGES := [Rect2(206,592,226,20),Rect2(1008,592,226,20)]
const CLOUD_LEDGES := [Rect2(119,607,230,20),Rect2(1047,578,244,20)]
const JADE := Color("a7f3c6")
const GOLD := Color("efc180")
const EMBER := Color("ff9b79")
const MOVEMENT := [KEY_A,KEY_D,KEY_LEFT,KEY_RIGHT,KEY_S,KEY_DOWN]
const COMMANDS := {KEY_SPACE:"jump",KEY_W:"jump",KEY_UP:"jump",KEY_J:"slash",KEY_X:"slash",KEY_K:"dash",KEY_C:"dash",KEY_SHIFT:"dash",KEY_L:"burst",KEY_V:"burst",KEY_H:"herb",KEY_Q:"spirit"}

var stats: Dictionary
var boss: bool
var seal_trial: bool
var practice: bool
var spirit: int
var charges: int
var herbs: int
var guard: int
var motion: bool
var ledges: Array
var active := true
var focused := true
var held := {}
var buffer := {}
var player := Vector2(273,FLOOR)
var enemy := Vector2(1079,FLOOR)
var velocity := Vector2.ZERO
var face := 1.0
var enemy_face := -1.0
var on_ground := true
var coyote := .1
var dash := 0.0
var dash_cooldown := 0.0
var dash_used := false
var cooldown := 0.0
var slash_time := 0.0
var slash_angle := 0.0
var immune := 0.0
var reduction := 0
var phase := "wait"
var phase_time := 1.2
var phase_span := 1.2
var move_index := 0
var move := "rush"
var slam_x := 0.0
var move_hit := false
var wave := 0.0
var clock := 0.0
var outcome_delay := .44
var freeze := 0.0
var feedback := ""
var feedback_time := 0.0
var effects: Array[Dictionary] = []
var hero_art: Texture2D
var enemy_art: Texture2D
var scenery: Texture2D
var stone_art: Texture2D
var sky_shade: GradientTexture2D
var mist_light: GradientTexture2D
var ui: RefCounted
var hp_label: Label
var foe_label: Label
var help_label: Label
var notice_label: Label
var remedy_button: Button
var imprint_label: Label
var player_name: String
var technique: String
var technique_color: Color
var burst_time := 0.0

func setup(values: Dictionary, herbs_count: int, spirit_id: int, spirit_charges: int, animate: bool, tutorial: bool, style := 0, display_name := "掌门") -> void:
	stats=values
	player_name=display_name
	var identity := maxi(style,0)
	technique=State.HERO_TECHNIQUES[identity]
	technique_color=[Color("91e9ff"),Color("a6e4ab"),Color("ffca7b")][identity]
	boss=stats.expedition_node=="boss"
	seal_trial=stats.expedition_node=="seal"
	ledges=CLOUD_LEDGES if boss else LEDGES
	practice=tutorial
	herbs=herbs_count
	spirit=spirit_id
	charges=spirit_charges
	guard=stats.get("guard",0)
	motion=animate
	var snapshot: Dictionary = stats.get("duel_snapshot",{})
	player=snapshot.get("player",player)
	enemy.x=snapshot.get("enemy_x",enemy.x)
	velocity=snapshot.get("velocity",velocity)
	face=snapshot.get("face",face)
	enemy_face=snapshot.get("enemy_face",enemy_face)
	dash_cooldown=snapshot.get("dash_cooldown",dash_cooldown)
	dash_used=snapshot.get("dash_used",dash_used)
	dash=snapshot.get("dash",dash)
	on_ground=snapshot.get("on_ground",on_ground)
	coyote=snapshot.get("coyote",coyote)
	immune=snapshot.get("immune",immune)
	reduction=snapshot.get("reduction",reduction)
	phase=snapshot.get("phase",phase)
	phase_time=snapshot.get("phase_time",phase_time)
	phase_span=snapshot.get("phase_span",phase_span)
	move=snapshot.get("move",move)
	move_hit=snapshot.get("move_hit",move_hit)
	slam_x=snapshot.get("slam_x",slam_x)
	wave=snapshot.get("wave",wave)
	move_index=snapshot.get("move_index",0)
	stats.relic_spent=stats.get("relic_spent",false)
	hero_art=load_art("hero_action_%d" % identity,"duel_hero")
	enemy_art=load_art("duel_guardian" if boss else ("duel_seal_mastiff" if seal_trial else "duel_beast"),"guardian0" if boss else "duel_beast")
	scenery=load_art("duel_canyon","lantern-depths")
	if boss and ResourceLoader.exists("res://assets/duel_depths.webp"):
		scenery=load("res://assets/duel_depths.webp")
	if ResourceLoader.exists("res://assets/duel_terrain.webp"):
		stone_art=load("res://assets/duel_terrain.webp")

func load_art(name: String, fallback: String) -> Texture2D:
	var path := "res://assets/%s.webp" % name
	return load(path) if ResourceLoader.exists(path) else load("res://assets/%s.webp" % fallback)

func _ready() -> void:
	ui=UI.new()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade := Gradient.new()
	shade.offsets=PackedFloat32Array([0,.60,1])
	shade.colors=PackedColorArray([Color(.025,.067,.080,.90),Color(.025,.067,.080,.62),Color(.025,.067,.080,0)])
	sky_shade=GradientTexture2D.new()
	sky_shade.width=2
	sky_shade.height=128
	sky_shade.fill_to=Vector2(0,1)
	sky_shade.gradient=shade
	var light := Gradient.new()
	var cloud_color := Color("ffddad") if boss else Color("b4e6d8")
	light.colors=PackedColorArray([Color(cloud_color,.19),Color(cloud_color,0)])
	mist_light=GradientTexture2D.new()
	mist_light.width=192
	mist_light.height=96
	mist_light.fill=GradientTexture2D.FILL_RADIAL
	mist_light.fill_from=Vector2(.5,.5)
	mist_light.fill_to=Vector2(1,.5)
	mist_light.gradient=light
	var site := "悬云观" if boss else ("封灯台" if seal_trial else "断灯栈道")
	ui.label(self,"青龙谷  /  "+site,Rect2(77,29,468,42),24,UI.PAPER,false,true)
	ui.label(self,"横版试炼" if practice else "遗灯秘境",Rect2(76,72,400,28),15,GOLD)
	ui.label(self,player_name,Rect2(95,103,340,35),23,UI.PAPER,false,true)
	var name_text: String = Expedition.BOSSES[0] if boss else Expedition.FOES[stats.expedition_node]
	ui.label(self,name_text,Rect2(968,103,377,35),23,UI.PAPER,true,true)
	hp_label=ui.label(self,"",Rect2(95,153,300,26),16,JADE)
	foe_label=ui.label(self,"",Rect2(1160,153,170,26),16,GOLD,true)
	help_label=ui.label(self,"",Rect2(103,833,1234,33),16,UI.PAPER,true)
	notice_label=ui.label(self,"",Rect2(473,223,494,47),21,GOLD,true,true)
	notice_label.add_theme_color_override("font_outline_color",Color("152b31"))
	notice_label.add_theme_constant_override("outline_size",5)
	if stats.get("imprint",-1)>=0:
		imprint_label=ui.label(self,"",Rect2(96,211,383,27),15,GOLD)
		imprint_label.add_theme_color_override("font_outline_color",Color("152b31"))
		imprint_label.add_theme_constant_override("outline_size",4)
	if stats.get("remedy",-1)>=0:
		remedy_button=ui.button(self,"",Rect2(1103,183,242,40),use_remedy,UI.GOLD)
		remedy_button.focus_mode=Control.FOCUS_NONE
	refresh_hud()

func refresh_hud() -> void:
	if not is_instance_valid(hp_label):
		return
	hp_label.text="气血 %d / %d" % [stats.hp,stats.maxhp]
	var rage := " · 激怒" if boss and stats.enemy*2<=stats.maxenemy and stats.result==0 else ""
	foe_label.text="%d / %d%s" % [stats.enemy,stats.maxenemy,rage]
	var supplies := "   ·   H  灵草 ×%d" % herbs if herbs>0 else ""
	if charges>0:
		supplies+="   ·   Q  灵契"
	help_label.text="A D  移动   ·   空格  跳跃   ·   J  普攻   ·   S + J  下击   ·   K  闪避   ·   L  "+technique+supplies
	if is_instance_valid(remedy_button):
		var status := Expedition.remedy_block(stats)
		var recipe: Dictionary = Expedition.REMEDIES[stats.remedy]
		var suffix := " · 护阵中" if stats.get("remedy_ward",0)>0 else (" · 已用" if stats.remedy_used else "")
		remedy_button.text="[F] "+recipe.name+suffix
		remedy_button.disabled=not status.is_empty()
		remedy_button.tooltip_text=recipe.hint if status.is_empty() else status
	if is_instance_valid(imprint_label):
		var status := " · 已返还剑意" if stats.get("imprint_spent",false) else ""
		imprint_label.text=Expedition.IMPRINTS[stats.imprint].name+status

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		focused=false
		held.clear()
		buffer.clear()
		if is_instance_valid(notice_label):
			notice_label.text="战斗暂停 · 切回游戏继续"
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_IN:
		focused=true

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or event.echo:
		return
	var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if code in MOVEMENT:
		held[code]=event.pressed
	elif code in COMMANDS:
		if event.pressed:
			buffer[COMMANDS[code]]=.14
	else:
		return
	get_viewport().set_input_as_handled()

func _physics_process(dt: float) -> void:
	if not active or not focused:
		return
	clock+=dt
	feedback_time=maxf(0,feedback_time-dt)
	for item in effects:
		item.life-=dt
		item.at+=item.velocity*dt
	effects=effects.filter(func(item: Dictionary): return item.life>0)
	if stats.result!=0:
		outcome_delay-=dt
		if outcome_delay<=0:
			active=false
			finished.emit(stats.result>0)
	elif freeze>0:
		freeze-=dt
	else:
		update_player(dt)
		if stats.result==0:
			update_enemy(dt)
		for key in buffer.keys():
			buffer[key]-=dt
			if buffer[key]<=0:
				buffer.erase(key)
	if is_instance_valid(notice_label):
		notice_label.text=notice()
	queue_redraw()

func notice() -> String:
	if stats.result!=0:
		return "破阵成功" if stats.result>0 else "气血耗尽"
	if phase=="tell":
		return {"rush":"蓄势冲锋 · 跳起或闪避","wave":"震地将至 · 跳过震波","slam":"锁定落点 · 离开红圈"}[move]
	if phase=="open" and boss:
		return "甲心外露 · 现在反击"
	return feedback if feedback_time>0 else ""

func update_player(dt: float) -> void:
	cooldown=maxf(0,cooldown-dt)
	slash_time=maxf(0,slash_time-dt)
	burst_time=maxf(0,burst_time-dt)
	immune=maxf(0,immune-dt)
	dash_cooldown=maxf(0,dash_cooldown-dt)
	coyote=.11 if on_ground else maxf(0,coyote-dt)
	var stride := float(int(held.get(KEY_D,false) or held.get(KEY_RIGHT,false))-int(held.get(KEY_A,false) or held.get(KEY_LEFT,false)))
	if dash<=0 and stride!=0:
		face=stride
	if "dash" in buffer and dash_cooldown<=0 and (on_ground or not dash_used):
		buffer.erase("dash")
		dash=.185
		dash_cooldown=.66
		dash_used=true
		velocity.y=0
		sounded.emit("guard")
	if "jump" in buffer and coyote>0 and dash<=0:
		buffer.erase("jump")
		velocity.y=-790
		coyote=0
		on_ground=false
	var before := player
	if dash>0:
		dash-=dt
		velocity.x=face*1020
		velocity.y=0
		if motion and int(clock*60)%2==0:
			spark(player+Vector2(-face*15,-45),JADE,Vector2(-face*260,0),.16)
	else:
		velocity.x=move_toward(velocity.x,stride*340,(3200.0 if stride!=0 else 4300.0)*dt)
		velocity.y=minf(980,velocity.y+1660*dt)
	player+=velocity*dt
	player.x=clampf(player.x,LEFT,RIGHT)
	on_ground=false
	if velocity.y>=0:
		for slab: Rect2 in ledges:
			if player.x>=slab.position.x and player.x<=slab.end.x and before.y<=slab.position.y and player.y>=slab.position.y:
				land(slab.position.y)
	if player.y>=FLOOR:
		land(FLOOR)
	if cooldown>0 or dash>0:
		return
	if buffer.erase("slash"):
		strike(held.get(KEY_S,false) or held.get(KEY_DOWN,false))
	elif buffer.erase("burst"):
		burst()
	elif buffer.erase("herb"):
		use_herb()
	elif buffer.erase("spirit"):
		use_spirit()

func land(height: float) -> void:
	player.y=height
	velocity.y=0
	on_ground=true
	dash_used=false

func enemy_box() -> Rect2:
	var body := Vector2(202,114) if boss else (Vector2(155,91) if seal_trial else Vector2(118,73))
	return Rect2(enemy-Vector2(body.x*.5,body.y),body)

func strike(down: bool) -> void:
	var diving := down and not on_ground
	cooldown=.31
	slash_time=.19
	slash_angle=PI*.5 if diving else (0.0 if face>0 else PI)
	var sword := Rect2(player+Vector2(-63,-38),Vector2(126,134)) if diving else Rect2(player+Vector2(-157 if face<0 else 5,-96),Vector2(152,106))
	if not sword.intersects(enemy_box()):
		sounded.emit("sword")
		return
	if diving:
		velocity.y=-543
		dash_used=false
	var damage := (18 if diving else 14)+int(stats.get("slash",0))
	if boss and phase!="open":
		damage=ceili(damage*.38)
		callout("甲壳护身 · 等它露出甲心")
	stats.focus=mini(3,stats.focus+1)
	damage_enemy(damage)

func burst() -> void:
	if stats.focus<3:
		callout("斩击命中可积攒剑意")
		return
	stats.focus=0
	cooldown=.40
	slash_time=.25
	burst_time=.34
	callout(technique)
	slash_angle=0 if face>0 else PI
	var delta := enemy.x-player.x
	if delta*face>=-28 and absf(delta)<418 and FLOOR-player.y<139:
		var damage: int = 27+int(stats.get("spell",0))
		if phase=="tell" and move!="slam":
			set_phase("open",1.32)
			if stats.relic==Expedition.Relic.FLAME and not stats.relic_spent:
				stats.relic_spent=true
				damage+=12
			var refunded := Expedition.refund_counter_imprint(stats)
			callout("破势铭 · 返还 1 点剑意" if refunded else "剑气打断 · 贴近反击")
		damage_enemy(damage)
	else:
		changed.emit()
	for i in 7:
		spark(player+Vector2(38*face,-53),technique_color,Vector2(face*(420+i*55),i*19-55),.36)
	sounded.emit("chime")

func use_herb() -> void:
	if herbs<1 or stats.hp>=stats.maxhp:
		return
	herbs-=1
	var amount: int = mini(31,stats.maxhp-stats.hp)
	stats.hp+=amount
	cooldown=.44
	if stats.relic==Expedition.Relic.MIRROR:
		stats.focus=mini(3,stats.focus+2)
	callout("灵草疗伤 +%d" % amount)
	changed.emit()
	refresh_hud()
	sounded.emit("chime")

func use_remedy() -> void:
	if not active or not focused:
		return
	var message := Expedition.apply_remedy(stats)
	if message.is_empty():
		return
	callout(message)
	impact(player+Vector2(0,-65),JADE)
	refresh_hud()
	changed.emit()
	sounded.emit("chime")

func use_spirit() -> void:
	if charges<1 or spirit<0:
		return
	charges-=1
	cooldown=.40
	callout(Expedition.PET_MOVES[spirit][0])
	match spirit:
		0:
			immune=maxf(immune,.96)
			stats.focus=mini(3,stats.focus+1)
		1:
			if phase=="tell":
				set_phase("open",1.25)
			damage_enemy(19+int(stats.get("spell",0)))
			return
		2:
			stats.focus=3
			reduction=12
		3:
			stats.hp=mini(stats.maxhp,stats.hp+22)
			reduction=14
	changed.emit()
	refresh_hud()
	sounded.emit("chime")

func callout(text_value: String) -> void:
	feedback=text_value
	feedback_time=1.18

func set_phase(next: String, duration: float) -> void:
	phase=next
	phase_time=duration
	phase_span=duration

func update_enemy(dt: float) -> void:
	phase_time-=dt
	var distance := absf(player.x-enemy.x)
	var enraged: bool = boss and stats.enemy*2<=stats.maxenemy
	match phase:
		"wait":
			enemy_face=signf(player.x-enemy.x) if distance>8 else enemy_face
			if distance>200:
				enemy.x+=enemy_face*(125 if boss else 177)*dt
			if phase_time<=0:
				if boss:
					move=["rush","wave","slam"][move_index%3]
				elif seal_trial:
					move=["wave","rush"][move_index%2]
				else:
					move="rush"
				move_index+=1
				move_hit=false
				wave=0
				slam_x=player.x
				set_phase("tell",.67 if enraged else (.89 if boss or seal_trial else .63))
		"tell":
			if phase_time<=0:
				set_phase("attack",{"rush":.50,"wave":.88,"slam":.48}[move])
				sounded.emit("guard")
		"attack":
			attack_enemy(dt,enraged)
			if phase_time<=0:
				set_phase("open",1.24 if enraged else (1.48 if boss else .92))
		"open":
			if phase_time<=0:
				set_phase("wait",.32 if enraged else .49)

func attack_enemy(dt: float, enraged: bool) -> void:
	var level: int = int(stats.tier)*5
	var hit := false
	var force := 0
	match move:
		"rush":
			enemy.x=clampf(enemy.x+enemy_face*(780 if enraged else (660 if boss else 738))*dt,LEFT+37,RIGHT-37)
			hit=absf(enemy.x-player.x)<(126.0 if boss else 83.0) and player.y>FLOOR-(105.0 if boss else 68.0)
			force=(23 if boss or seal_trial else 15)+level+(5 if stats.expedition_node=="elite" else 0)
		"wave":
			wave+=dt*(755 if enraged else 660)
			hit=absf(absf(player.x-enemy.x)-wave)<48 and player.y>FLOOR-48
			force=(22 if seal_trial else 25)+level
		"slam":
			if phase_time<=.23:
				enemy.x=clampf(slam_x,LEFT+37,RIGHT-37)
				hit=absf(slam_x-player.x)<144 and player.y>FLOOR-106
			force=30+level
	if hit and not move_hit and damage_player(force):
		move_hit=true

func damage_player(force: int) -> bool:
	if dash>0 or immune>0:
		return false
	var amount := maxi(1,force-guard-reduction)
	reduction=0
	if stats.relic==Expedition.Relic.TIDE and not stats.relic_spent and force>=23:
		amount=maxi(0,amount-14)
		stats.relic_spent=true
		callout("潮甲印护体")
	var warded := Expedition.absorb_remedy_ward(stats,amount)
	amount-=warded
	if warded>0:
		callout("镇煞符 · 减伤 %d" % warded)
	stats.hp=maxi(0,stats.hp-amount)
	immune=.85
	var away := signf(player.x-enemy.x)
	velocity=Vector2((away if away!=0 else -face)*380,-224)
	if amount>0:
		impact(player+Vector2(0,-49),EMBER)
	if stats.hp==0:
		stats.result=-1
	refresh_hud()
	changed.emit()
	sounded.emit("guard")
	return true

func damage_enemy(amount: int) -> void:
	stats.enemy=maxi(0,stats.enemy-amount)
	if stats.enemy==0:
		stats.result=1
	if not boss and phase=="wait":
		enemy.x=clampf(enemy.x+face*15,LEFT+37,RIGHT-37)
	impact(enemy+Vector2(0,-49),GOLD)
	freeze=.054 if motion else .020
	changed.emit()
	refresh_hud()
	sounded.emit("sword")

func snapshot() -> void:
	stats.duel_snapshot={
		"player":player,"enemy_x":enemy.x,"velocity":velocity,"face":face,"enemy_face":enemy_face,
		"dash_cooldown":dash_cooldown,"dash_used":dash_used,"dash":dash,"on_ground":on_ground,"coyote":coyote,
		"immune":immune,"reduction":reduction,"phase":phase,"phase_time":phase_time,"phase_span":phase_span,
		"move":move,"move_hit":move_hit,"slam_x":slam_x,"wave":wave,"move_index":move_index
	}

func spark(at: Vector2, tint: Color, speed: Vector2, life: float) -> void:
	effects.append({"at":at,"tint":tint,"velocity":speed,"life":life,"total":life})

func impact(at: Vector2, tint: Color) -> void:
	if motion:
		for i in 12:
			spark(at,tint,Vector2.from_angle(i*TAU/12)*(115+25*(i%4)),.31+.025*(i%3))

func painted_sprite(art: Texture2D, at: Vector2, target_height: float, direction: float, tint: Color) -> void:
	var span := target_height*art.get_size().aspect()
	draw_set_transform(at,0,Vector2(direction,1))
	draw_texture_rect(art,Rect2(-span*.5,-target_height,span,target_height),false,tint)
	draw_set_transform(Vector2.ZERO)

func terrain(x: float, y: float, span: float, depth: float) -> void:
	if is_instance_valid(stone_art):
		var segments := ceili(span/535)
		var width := span/segments
		var lip := minf(depth+5,56.0)
		for i in segments:
			draw_texture_rect(stone_art,Rect2(x+i*width,y-3,width+.8,lip),false,Color(1,.92,.79) if boss else Color(.75,.91,.88))
		draw_line(Vector2(x,y),Vector2(x+span,y),Color(.72,.79,.69,.63),2,true)
		return
	var path := PackedVector2Array([Vector2(x,y),Vector2(x+span,y),Vector2(x+span-26,y+depth),Vector2(x+span*.62,y+depth+11),Vector2(x+span*.22,y+depth-9),Vector2(x+19,y+depth-12)])
	draw_colored_polygon(path,Color("142927"))
	var stones := ceili(span/54)
	for i in stones:
		var n := x+float(i)*span/stones
		var shade := [.15,.19,.23][i%3] as float
		draw_line(Vector2(n+2,y+5),Vector2(n+11,y+18+(i%4)*3),Color(.32,.47,.39,shade),2)
		draw_line(Vector2(n+7,y+6),Vector2(n+span/stones-7,y+6),Color(.43,.62,.49,shade+.18),2)
	draw_line(Vector2(x,y+1),Vector2(x+span,y+1),Color("688b70"),3)
	draw_line(Vector2(x+2,y-1),Vector2(x+span-2,y-1),Color(.63,.80,.64,.46),1)

func _draw() -> void:
	if stats.is_empty():
		return
	var sway := sin(clock*.29)*12.0 if motion else 0.0
	draw_texture_rect(scenery,Rect2(-18+sway,-12,1476,858),false,Color.WHITE if boss else Color(.89,.97,.96))
	if is_instance_valid(sky_shade):
		draw_texture_rect(sky_shade,Rect2(0,0,1440,239),false)
	if is_instance_valid(mist_light):
		for i in 3:
			var center := fposmod(i*540+clock*13,1910.0)-490.0 if motion else i*580-430.0
			draw_texture_rect(mist_light,Rect2(center,366+i*120,650,138),false)
	for i in 16:
		var x := fposmod(i*117+clock*(6+i%4),1440) if motion else fposmod(i*117,1440)
		var y := 245+fposmod(i*79.0,460)+(sin(clock+i)*13 if motion else 0.0)
		draw_circle(Vector2(x,y),1.2+(i%4)*.55,Color(.86,.91,.58,.24+(i%3)*.12),true,-1,true)
	for slab: Rect2 in ledges:
		terrain(slab.position.x,slab.position.y,slab.size.x,34)
	terrain(23,FLOOR,1394,100)
	draw_rect(Rect2(0,810,1440,90),Color("101e20"))
	draw_line(Vector2(78,817),Vector2(1362,817),Color(.58,.76,.59,.33),1,true)
	for at: Vector2 in [player,enemy]:
		draw_set_transform(Vector2(at.x,FLOOR+1),0,Vector2(2.1,.12))
		draw_circle(Vector2.ZERO,36,Color(.02,.07,.07,.65),true,-1,true)
		draw_set_transform(Vector2.ZERO)
	draw_attack()
	var hero_tint := Color(1,.70,.65,.82) if immune>0 and int(clock*24)%2==0 else Color.WHITE
	if dash>0:
		hero_tint=Color(.74,1,.95,.72)
	painted_sprite(hero_art,player+Vector2(0,2),145.0+(sin(clock*19)*3 if motion and on_ground and absf(velocity.x)>20 else 0),face,hero_tint)
	var rise := -maxf(0,sin(PI*phase_time/phase_span))*93 if phase=="attack" and move=="slam" and phase_time>.23 else 0.0
	var enemy_tint := Color(1,.82,.65) if phase=="tell" else (Color(.89,1,.87) if phase=="open" else Color.WHITE)
	painted_sprite(enemy_art,enemy+Vector2(0,3+rise),235 if boss else (139 if seal_trial else 107),enemy_face,enemy_tint)
	if slash_time>0:
		var pivot := player+Vector2(0,-47 if slash_angle!=PI*.5 else -24)
		var arc_color := JADE if stats.focus==0 else Color("e4ffbb")
		for i in 4:
			draw_arc(pivot,80+i*7,slash_angle-1.01+i*.10,slash_angle+.94,26,Color(arc_color,.44-(i*.073)),8-i,true)
	if burst_time>0:
		var origin := player+Vector2(face*(48+183*(1-burst_time/.34)),-59)
		for i in 3:
			draw_arc(origin,77+i*9,slash_angle-.87,slash_angle+.79,30,Color(technique_color,burst_time/.34*(.92-.20*i)),8-i*2,true)
	for item in effects:
		var tint: Color = item.tint
		tint.a=item.life/item.total
		draw_line(item.at,item.at-item.velocity*.025,tint,2.5,true)
	draw_bar(Rect2(95,140,328,10),float(stats.hp)/stats.maxhp,JADE)
	draw_bar(Rect2(1017,140,328,10),float(stats.enemy)/stats.maxenemy,EMBER)
	for i in 3:
		var at := Vector2(103+29*i,194)
		var shape := PackedVector2Array([at+Vector2(0,-8),at+Vector2(8,0),at+Vector2(0,8),at-Vector2(8,0)])
		draw_colored_polygon(shape,GOLD if stats.focus>i else Color("365450"))
	if dash_cooldown>0:
		draw_bar(Rect2(198,191,93,5),1-dash_cooldown/.66,JADE)

func draw_bar(rect: Rect2, fill: float, tint: Color) -> void:
	draw_rect(rect.grow(2),Color("355753"))
	draw_rect(rect,Color("142c2e"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*fill,rect.size.y)),tint)

func draw_attack() -> void:
	if phase=="tell":
		var pulse := .24+.41*(1-phase_time/phase_span)
		var center := Vector2(slam_x if move=="slam" else enemy.x,FLOOR-3)
		if move=="rush":
			var end := clampf(enemy.x+enemy_face*390,LEFT,RIGHT)
			draw_line(center,Vector2(end,FLOOR-3),Color(EMBER,pulse),6,true)
			for i in 4:
				var at := center.lerp(Vector2(end,FLOOR-3),float(i+1)/5)
				draw_polyline(PackedVector2Array([at+Vector2(-enemy_face*10,-20),at+Vector2(enemy_face*4,-11),at+Vector2(-enemy_face*10,-2)]),Color(EMBER,pulse),3,true)
		else:
			draw_set_transform(center,0,Vector2(1,.18))
			draw_circle(Vector2.ZERO,146,Color(EMBER,pulse*.30),true,-1,true)
			draw_circle(Vector2.ZERO,146,Color(EMBER,pulse),false,5,true)
			draw_set_transform(Vector2.ZERO)
	if phase=="attack" and move=="wave":
		for side in [-1,1]:
			var point := Vector2(enemy.x+side*wave,FLOOR-7)
			draw_arc(point,36,PI,TAU,18,Color(EMBER,.89),7,true)
			draw_circle(point,10,GOLD,true,-1,true)
	if phase=="attack" and move=="slam" and phase_time<=.23:
		var center := Vector2(slam_x,FLOOR-6)
		for i in 7:
			var point := center+Vector2((i-3)*38,0)
			draw_line(point,point+Vector2((i-3)*8,-(63-abs(i-3)*8)),Color(EMBER,phase_time/.23),5,true)

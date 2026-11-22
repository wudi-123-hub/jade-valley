extends Control

const State = preload("res://state.gd")
const Atlas = preload("res://atlas.gd")
const UI = preload("res://ui.gd")
const Chronicle = preload("res://chronicle.gd")
const Expedition = preload("res://expedition.gd")
const ActionDuel = preload("res://action_duel.gd")
const OPENING = preload("res://assets/opening.webp")
const FOE_ART = [
	preload("res://assets/foe0.webp"),preload("res://assets/foe1.webp"),
	preload("res://assets/foe2.webp"),preload("res://assets/foe3.webp")
]
const PLOT_ART = [
	preload("res://assets/plot0.webp"),preload("res://assets/plot1.webp"),
	preload("res://assets/plot2.webp"),preload("res://assets/plot3.webp")
]
const STUDENT_ART = [
	preload("res://assets/student0.webp"),preload("res://assets/student1.webp"),
	preload("res://assets/student2.webp"),preload("res://assets/student3.webp")
]
const ACTIONS = [
	["药圃","灵药种植","sprout","garden"],["招贤台","弟子招募","hall","recruit"],
	["灵兽园","灵兽驯养","paw","pet"],["御剑台","秘境历练","compass","journey"],
	["渡劫台","境界突破","spark","rank"]
]
const LOCATIONS = [
	[Vector2(.76,.74),Vector2(.76,.31),Vector2(.27,.54),Vector2(.51,.48)],
	[Vector2(.74,.40),Vector2(.50,.39),Vector2(.26,.48),Vector2(.57,.74)],
	[Vector2(.71,.56),Vector2(.56,.34),Vector2(.27,.56),Vector2(.50,.71)],
	[Vector2(.76,.66),Vector2(.52,.34),Vector2(.25,.56),Vector2(.51,.73)]
]
const MAP_FRAME := Rect2(0,0,1440,900)
const DOCK := Rect2(349,768,742,88)
const MENU = [
	["story","主线","flame",UI.OCHRE],["work","宗务","hall",UI.GOLD],["training","修行","sword",UI.COLORS[3]],
	["seasons","四季","mountain",UI.JADE],["ledger","宗门簿","scroll",UI.GOLD]
]
const VIEW := Vector2(1440,900)

var ui = UI.new()
var game = State.new()
var root: Control
var atlas: Control
var frame_overlay: Control
var spots: Array[Button] = []
var dock_buttons: Array[Button] = []
var tray: Control
var tray_key := ""
var tray_rect: Rect2
var top_name: Label
var top_season: Label
var top_date: Label
var ledger_alert: Panel
var tray_farm_alert: Panel
var story_alert: Panel
var farm_alert: Panel
var last_season := -1
var modal: Control
var scene_key := ""
var active_plot := 0
var ledger_tab := 0
var season_preview := 0
var toast_panel: Panel
var toast_generation := 0
var music := AudioStreamPlayer.new()
var sfx := AudioStreamPlayer.new()
var is_menu := true
var have_save := false
var scenic_mode := false
var reveal_hud: Button
var closing := false
var story_preview := 0
var dialogue_page := 0
var draft_herbs := 0
var draft_tier := 0
var draft_commission := ""
var draft_relic := -1
var draft_imprint := -1
var draft_scout := false
var draft_remedy := -1
var remedy_return := "garden"
var duty_selection := -1
var relic_return := "expedition"
var imprint_return := "relics"
var route_choice := ""
var modal_focus_nodes: Array[Button] = []
var previous_focus: Control
var duel: Control
var practice_boss := false
var action_expeditions := true
var hero_destination := "start"

func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		smoke_test()
		return
	have_save = game.read_save()
	get_tree().auto_accept_quit = false
	theme = Theme.new()
	theme.default_font = ui.sans
	theme.default_font_size = 15
	theme.set_stylebox("panel","TooltipPanel",ui.skin(Color("#132b23"),UI.GOLD,8))
	theme.set_color("font_color","TooltipLabel",UI.PAPER)
	get_window().min_size = Vector2i(900,560)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	add_child(music)
	add_child(sfx)
	if ResourceLoader.exists("res://assets/valley.wav"):
		var ambience := load("res://assets/valley.wav") as AudioStreamWAV
		ambience.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambience.loop_end = int(ambience.get_length()*ambience.mix_rate)
		music.stream = ambience
		music.volume_db = -16
		if game.data.music:
			music.play()
	game.changed.connect(game_changed)
	show_title()
	if "--qa-quit" in OS.get_cmdline_user_args():
		get_tree().create_timer(.75).timeout.connect(quit_game)

func _exit_tree() -> void:
	release_audio()

func release_audio() -> void:
	for player in [music,sfx]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func quit_game() -> void:
	if closing:
		return
	closing = true
	if scene_key=="battle" and is_instance_valid(duel):
		duel.snapshot()
		game.leave_battle()
		duel.active=false
	release_audio()
	await get_tree().create_timer(.14).timeout
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func wipe() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	root = Control.new()
	root.size = VIEW
	add_child(root)
	modal = null
	toast_panel = null
	atlas = null
	spots.clear()
	dock_buttons.clear()
	tray = null
	tray_key = ""
	scenic_mode = false
	modal_focus_nodes.clear()
	previous_focus = null
	scene_key = ""

func fade_in(item: CanvasItem,duration := .22) -> void:
	if not game.data.motion:
		return
	item.modulate.a = 0
	create_tween().tween_property(item,"modulate:a",1.0,duration).set_trans(Tween.TRANS_SINE)

func show_title() -> void:
	is_menu = true
	wipe()
	ui.picture(root,OPENING,Rect2(Vector2.ZERO,VIEW),Color.WHITE,true)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0,.34,.67,1])
	grad.colors = PackedColorArray([Color(.03,.095,.09,.93),Color(.03,.095,.09,.65),Color(.03,.095,.09,.05),Color(.03,.095,.09,0)])
	var mask := GradientTexture2D.new()
	mask.width = 512
	mask.height = 2
	mask.gradient = grad
	ui.picture(root,mask,Rect2(Vector2.ZERO,VIEW)).stretch_mode = TextureRect.STRETCH_SCALE
	var shadow_ramp := Gradient.new()
	shadow_ramp.colors=PackedColorArray([Color(.10,.09,.04,.48),Color(.10,.09,.04,0)])
	var shadow := GradientTexture2D.new()
	shadow.width=192
	shadow.height=36
	shadow.fill=GradientTexture2D.FILL_RADIAL
	shadow.fill_from=Vector2(.5,.5)
	shadow.fill_to=Vector2(1,.5)
	shadow.gradient=shadow_ramp
	ui.picture(root,shadow,Rect2(1119,657,188,24)).stretch_mode=TextureRect.STRETCH_SCALE
	ui.picture(root,hero_portrait(),Rect2(1047,337,341,338))
	ui.box(root,Rect2(79,105,51,51),Color("#244d40"),UI.GOLD,14)
	ui.mark(root,"mountain",Rect2(90,116,29,29))
	ui.label(root,"四季宗门",Rect2(145,110,230,39),19,UI.GOLD,false,true)
	ui.line(root,Vector2(81,297),Vector2(432,297),Color("#c5a66e"))
	ui.label(root,"龙谷拾玉",Rect2(74,174,595,119),83,UI.PAPER,false,true)
	ui.label(root,"一座山门，四时修行。",Rect2(82,306,465,47),24,UI.PAPER,false,true)
	ui.button(root,"继续修行" if have_save else "入谷开宗",Rect2(83,431,262,56),begin_game,UI.GOLD,true)
	ui.button(root,"横版试炼 · 断灯栈道",Rect2(83,500,262,49),open_practice,UI.JADE)
	ui.button(root,"设置",Rect2(83,563,126,44),func(): sound_tick(); open_scene("settings"),UI.JADE)
	ui.button(root,"退出",Rect2(219,563,126,44),quit_game,UI.JADE)
	fade_in(root,.38)

func begin_game() -> void:
	if not game.hero_unlocked(game.data.hero_style):
		open_hero_select("start")
		return
	is_menu = false
	var first := not have_save
	if first:
		game.save_game()
		have_save = true
	show_world()
	sound_tick()
	if first or game.data.story_read.is_empty():
		story_preview = 0
		dialogue_page = 0
		open_scene("dialogue")

func hero_portrait(style := -1) -> Texture2D:
	var current: int = maxi(0,game.data.hero_style) if style<0 else style
	var path := "res://assets/hero_portrait_%d.webp" % current
	return load(path) if ResourceLoader.exists(path) else load("res://assets/dragon.webp")

func open_hero_select(destination: String) -> void:
	hero_destination=destination
	open_scene("hero_select")

func hero_selection_window() -> void:
	var host := window("选择掌门","单人出战 · 所有角色共用操作与技能效果","user",Vector2(1098,636))
	var captions := ["女 · 洛水剑修","男 · 应龙剑修","齐天大圣 · 金箍棒"]
	var accents := [UI.COLORS[3],UI.JADE,UI.OCHRE]
	for i in State.HEROES.size():
		var x := 29+i*351
		var allowed: bool = game.hero_unlocked(i)
		var selected: bool = i==game.data.hero_style
		ui.framed(host,Rect2(x,125,336,455))
		var stage := Control.new()
		stage.clip_contents=true
		stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ui.place(stage,host,Rect2(x+10,136,316,270))
		ui.picture(stage,OPENING,Rect2(0,0,316,270),Color(.57,.71,.73),true)
		ui.box(stage,Rect2(0,0,316,270),Color(.043,.12,.13,.38),UI.BORDER,7)
		ui.picture(stage,hero_portrait(i),Rect2(24,11,268,255),Color.WHITE if allowed else Color(.68,.74,.73))
		ui.label(host,State.HEROES[i],Rect2(x+18,414,300,40),25,UI.PAPER,true,true)
		ui.label(host,"%s · %s" % [captions[i],State.HERO_TECHNIQUES[i]],Rect2(x+12,452,312,31),15,accents[i],true)
		var caption := "选择%s" % State.HEROES[i] if allowed else "击败悬云观古甲解锁"
		if selected:
			caption="当前角色 · 继续"
		ui.button(host,caption,Rect2(x+20,509,296,47),func(): use_hero(i),accents[i],allowed and not selected,10,allowed)

func use_hero(style: int) -> void:
	if not game.choose_hero(style):
		return
	if have_save:
		game.save_game()
	close_scene()
	match hero_destination:
		"start": begin_game()
		"practice": open_practice()
		"title": show_title()
		_: open_scene("master",true)

func show_world() -> void:
	is_menu = false
	wipe()
	last_season = -1
	ui.box(root,Rect2(Vector2.ZERO,VIEW),UI.INK,UI.INK,0)
	var map_frame := Control.new()
	map_frame.clip_contents = true
	ui.place(map_frame,root,MAP_FRAME)
	atlas = Atlas.new()
	ui.place(atlas,map_frame,Rect2(Vector2.ZERO,VIEW))
	atlas.camera_changed.connect(place_spots)
	frame_overlay = Control.new()
	frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(frame_overlay,root,Rect2(Vector2.ZERO,VIEW))
	for i in 4:
		var info: Array = ACTIONS[i]
		var marker := ui.button(frame_overlay,"",Rect2(0,0,53,53),func(): open_scene(info[3]),UI.COLORS[i],false,26)
		marker.tooltip_text = info[0]
		var art := ui.emblem(marker,info[3],info[2],Rect2(9,9,35,35),UI.COLORS[i])
		ui.lift_on_hover(marker,art,game.data.motion)
		spots.append(marker)
	farm_alert = ui.box(spots[0],Rect2(43,0,10,10),UI.GOLD,UI.INK,5)

	ui.framed(frame_overlay,Rect2(30,26,213,66))
	ui.box(frame_overlay,Rect2(42,36,41,46),Color("#284639"),UI.GOLD,12)
	top_season = ui.label(frame_overlay,"春",Rect2(42,35,41,46),23,UI.GOLD,true,true)
	top_name = ui.label(frame_overlay,"青龙谷",Rect2(96,30,134,34),24,UI.PAPER,false,true)
	top_date = ui.label(frame_overlay,"第 1 日",Rect2(97,63,124,20),13,UI.MUTE)
	for i in 3:
		var item: Array = [["user","掌门","master"],["bag","行囊","inventory"],["cog","设置","settings"]][i]
		var button := ui.button(frame_overlay,"",Rect2(1063+i*114,29,108,51),func(): open_scene(item[2]),UI.GOLD)
		button.tooltip_text = item[1]
		var art := ui.emblem(button,item[2],item[0],Rect2(13,7,34,34))
		ui.lift_on_hover(button,art,game.data.motion)
		ui.label(button,item[1],Rect2(51,0,53,48),16,UI.PAPER,false,true)

	ui.framed(frame_overlay,DOCK.grow(5),true)
	ui.ornament(frame_overlay,Rect2(625,737,190,38))
	for i in MENU.size():
		var item: Array = MENU[i]
		var accent: Color = item[3]
		var target: String = item[0]
		var pos := Vector2(DOCK.position.x+10+i*145,DOCK.position.y+10)
		var action: Callable = func(): toggle_tray(target)
		if target=="ledger":
			action = func(): open_scene("ledger")
		elif target=="story":
			action = open_story
		var button := ui.button(frame_overlay,"",Rect2(pos,Vector2(141,68)),action,accent,false,14)
		button.tooltip_text = item[1]
		button.toggle_mode = target not in ["story","ledger"]
		var art := ui.emblem(button,target,item[2],Rect2(13,6,55,55),accent)
		ui.lift_on_hover(button,art,game.data.motion)
		ui.label(button,item[1],Rect2(73,0,65,68),19,UI.PAPER,false,true)
		dock_buttons.append(button)
	story_alert = ui.box(dock_buttons[0],Rect2(125,9,8,8),Color("#f8d68b"),UI.GOLD,4)
	tray_farm_alert = ui.box(dock_buttons[1],Rect2(125,9,8,8),UI.GOLD,UI.GOLD,4)
	ledger_alert = ui.box(dock_buttons[4],Rect2(125,9,8,8),UI.GOLD,UI.GOLD,4)

	for i in 3:
		var position_on_screen := Rect2(1349,728+i*44,38,38)
		var tip: String = ["放大地图","缩小地图","复位视角"][i]
		if i==2:
			seal_button(frame_overlay,"compass",position_on_screen,tip,func(): map_control(i),UI.JADE,13)
		else:
			var button := ui.button(frame_overlay,["+","−"][i],position_on_screen,func(): map_control(i),UI.JADE,false,13)
			button.tooltip_text = tip
			button.add_theme_font_size_override("font_size",19)
	var scenery := ui.button(frame_overlay,"观景 · H",Rect2(30,824,112,38),toggle_scenery,UI.JADE,false,13)
	scenery.add_theme_font_size_override("font_size",14)
	reveal_hud = ui.button(root,"显示界面 · H",Rect2(30,824,144,38),toggle_scenery,UI.JADE,false,13)
	reveal_hud.add_theme_font_size_override("font_size",14)
	reveal_hud.hide()
	refresh()
	fade_in(root,.26)

func seal_button(parent: Node,glyph: String,rect: Rect2,tip: String,run: Callable,accent: Color,curve := 20) -> Button:
	var button := ui.button(parent,"",rect,run,accent,false,curve)
	button.tooltip_text = tip
	ui.mark(button,glyph,Rect2((rect.size-Vector2(22,22))*.5,Vector2(22,22)),accent)
	return button

func icon_button(parent: Node,glyph: String,rect: Rect2,tip: String,run: Callable,accent := UI.GOLD) -> Button:
	return seal_button(parent,glyph,rect,tip,run,accent,12)

func close_tray() -> void:
	if is_instance_valid(tray):
		tray.get_parent().remove_child(tray)
		tray.queue_free()
	tray = null
	tray_key = ""
	for button in dock_buttons:
		if is_instance_valid(button) and button.toggle_mode:
			button.set_pressed_no_signal(false)

func toggle_scenery() -> void:
	close_tray()
	scenic_mode = not scenic_mode
	frame_overlay.visible = not scenic_mode
	reveal_hud.visible = scenic_mode
	if is_instance_valid(toast_panel):
		toast_panel.visible = not scenic_mode

func toggle_tray(key: String) -> void:
	var same := key==tray_key
	close_tray()
	if same:
		return
	tray_key = key
	for i in MENU.size():
		if MENU[i][0]==key:
			dock_buttons[i].set_pressed_no_signal(true)
			break
	sound_tick()
	tray = Control.new()
	var wide := key=="seasons"
	var size_of_tray := Vector2(624,204) if wide else Vector2(355,330 if key=="work" else 220)
	var origin := Vector2(720-size_of_tray.x*.5,DOCK.position.y-size_of_tray.y-24) if wide else Vector2(433 if key=="work" else 578,DOCK.position.y-size_of_tray.y-24)
	tray_rect = Rect2(origin,size_of_tray)
	ui.place(tray,root,tray_rect)
	ui.framed(tray,Rect2(Vector2.ZERO,size_of_tray))
	if wide:
		ui.label(tray,"四季山门",Rect2(18,8,580,35),21,UI.GOLD,false,true)
		for i in 4:
			tray_season(i)
	else:
		var work := key=="work"
		ui.label(tray,"宗门事务" if work else "修行",Rect2(20,8,310,37),21,UI.GOLD,false,true)
		var rows := [0,1,2,-3,-1] if work else [-2,3,4]
		for i in rows.size():
			tray_action(rows[i],i)
	fade_in(tray,.14)
	if game.data.motion:
		var point := tray.position
		tray.position.y+=9
		create_tween().tween_property(tray,"position",point,.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func tray_season(index: int) -> void:
	var m: Array = State.MAPS[index]
	var tile := ui.button(tray,"",Rect2(15+151*index,50,143,137),func(): season_preview=index;open_scene("season"),UI.GOLD,false,10)
	tile.tooltip_text = m[1]
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(clip,tile,Rect2(4,4,135,75))
	var enabled: bool = index<=game.data.rank
	ui.picture(clip,atlas.maps[index],Rect2(0,0,135,78),Color.WHITE if enabled else Color(.58,.65,.60),true)
	ui.box(tile,Rect2(10,45,27,27),Color(.07,.17,.14,.90),UI.GOLD,7)
	ui.label(tile,m[0],Rect2(10,45,27,27),16,UI.GOLD,true,true)
	ui.label(tile,m[1],Rect2(11,81,120,25),16,UI.PAPER,false,true)
	var status: String = "%s境解锁" % State.RANKS[index] if not enabled else ("当前驻地" if index==game.data.map else m[2])
	ui.label(tile,status,Rect2(11,108,120,21),12,UI.JADE if index==game.data.map else UI.MUTE)

func tray_action(index: int,row: int) -> void:
	var rest := index==-1
	var special := {-1:["休整","推进一日","moon",""],-2:["遗灯秘境","远征路线","compass","expedition"],-3:["宗门营造","建造升级","hall","facilities"]}
	var info: Array = special[index] if index<0 else ACTIONS[index]
	var accent: Color = UI.GOLD if index<0 else UI.COLORS[index]
	var action: Callable = func(): open_scene(info[3])
	if index==-2:
		action=open_expedition
	if rest:
		action = func():
			close_tray()
			game.record("山门","山门休整了一日。")
	var button := ui.button(tray,"",Rect2(15,48+53*row,325,46),action,accent,false,10)
	button.tooltip_text = info[0]
	var art := ui.emblem(button,info[3],info[2],Rect2(20,5,35,35),accent)
	ui.lift_on_hover(button,art,game.data.motion)
	ui.label(button,info[0],Rect2(66,0,106,46),16,UI.PAPER,false,true)
	ui.label(button,info[1],Rect2(173,0,130,46),13,UI.MUTE)

func place_spots() -> void:
	if not is_instance_valid(atlas):
		return
	for i in spots.size():
		var position_on_map: Vector2 = atlas.project(LOCATIONS[game.data.map][i])
		spots[i].position = position_on_map-Vector2(26.5,26.5)
		spots[i].visible = Rect2(Vector2(36,118),Vector2(1327,610)).has_point(position_on_map)

func map_control(index: int) -> void:
	if index == 2:
		atlas.reset_camera()
	else:
		atlas.zoom_camera(.22 if index == 0 else -.22,VIEW*.5)

func refresh() -> void:
	if is_menu:
		return
	var data: Dictionary = game.data
	var area: Array = State.MAPS[data.map]
	top_date.text = "第 %d 日" % data.day
	var harvests := 0
	for plot: Array in data.plots:
		if not plot.is_empty() and data.day>=plot[1]:
			harvests += 1
	farm_alert.visible = harvests>0
	tray_farm_alert.visible = harvests>0
	ledger_alert.visible = game.quest_count()>data.claimed.size()
	story_alert.visible = data.story_ending<0 and (data.story_chapter>=4 or data.story_chapter not in data.story_read or game.story_requirement(data.story_chapter).is_empty())
	atlas.motion = data.motion
	if last_season!=data.map:
		atlas.change_season(data.map)
		top_season.text = area[0]
		top_name.text = area[1]
		last_season = data.map
		place_spots()
	atlas.queue_redraw()

func master_window() -> void:
	var host := window("掌门","", "user", Vector2(750,476))
	ui.box(host,Rect2(28,124,251,284),UI.WELL,UI.BORDER,15)
	ui.box(host,Rect2(82,145,145,145),Color("#315748"),Color("#9d9466"),72)
	ui.picture(host,hero_portrait(),Rect2(50,129,214,188))
	ui.label(host,game.hero_name(),Rect2(42,319,222,43),27,UI.PAPER,true,true)
	ui.label(host,State.RANKS[game.data.rank],Rect2(48,363,210,31),16,UI.JADE,true)
	var requirement: int = State.NEEDS[game.data.rank] if game.data.rank<4 else 0
	var progress := "%d / %d" % [game.data.qi,requirement] if requirement else "圆满"
	ui.label(host,"突破进度",Rect2(305,136,144,35),17,UI.PAPER,false,true)
	ui.label(host,progress,Rect2(561,136,137,35),18,UI.GOLD)
	ui.meter(host,Rect2(305,179,410,8),float(game.data.qi)/maxi(1,requirement) if requirement else 1.0)
	var infos := [["宗门等级","%d 级" % (int(game.data.rank)+1)],["门下弟子","%d / 8" % game.data.people.size()],["灵兽伙伴","%d / 4" % game.data.pets.size()]]
	for i in 3:
		var x := 305+i*138
		ui.box(host,Rect2(x,216,128,82),UI.INK,UI.BORDER,10)
		ui.label(host,infos[i][0],Rect2(x,223,128,26),13,UI.MUTE,true)
		ui.label(host,infos[i][1],Rect2(x,252,128,35),20,UI.PAPER,true)
	ui.button(host,"前往渡劫台",Rect2(305,351,410,47),func(): open_scene("rank"),UI.COLORS[4],game.can_break())
	ui.button(host,"更换掌门",Rect2(305,410,410,38),func(): open_hero_select("master"),UI.JADE)

func inventory_window() -> void:
	var host := window("行囊","","bag",Vector2(680,615))
	var entries := [
		["gem","灵石",game.data.stones,"用于播种、招募弟子和布阵渡劫。",UI.GOLD],
		["flame","修为",game.data.qi,"积攒修为，冲击新的境界。",UI.COLORS[4]],
		["sprout","灵草",game.data.herbs,"可炼化、驯养灵兽或在斗法中疗伤。",UI.JADE],
		["flame","灯砂",game.data.dust,"从秘境带回，用于升级宗门设施。",UI.OCHRE],
		["compass","勘察札",game.data.scout_token,"来自巡山弟子，启程时可用于开出勘察小径。",UI.COLORS[3]]
	]
	for i in entries.size():
		var item: Array = entries[i]
		var y := 124+90*i
		ui.box(host,Rect2(27,y,626,75),UI.WELL,UI.BORDER,12)
		ui.mark(host,item[0],Rect2(44,y+22,29,29),item[4])
		ui.label(host,item[1],Rect2(88,y+6,220,32),18,item[4],false,true)
		ui.label(host,item[3],Rect2(88,y+37,447,28),14,UI.MUTE)
		ui.label(host,str(item[2]),Rect2(535,y,94,75),22,UI.PAPER,true)

func sound_tick(variant := "tick") -> void:
	if not game.data.sound:
		return
	var path := "res://assets/%s.wav" % variant
	if ResourceLoader.exists(path):
		sfx.stream = load(path)
		sfx.volume_db = -13
		sfx.play()

func game_changed(message: String) -> void:
	refresh()
	if not message.is_empty():
		announce(message)
		sound_tick("chime")

func announce(message: String) -> void:
	if is_instance_valid(toast_panel):
		toast_panel.free()
	toast_generation += 1
	var number := toast_generation
	toast_panel = ui.box(root,Rect2(415,27,610,48),Color("#183c30"),UI.GOLD,12,true)
	toast_panel.z_index = 24
	toast_panel.visible = not scenic_mode
	ui.label(toast_panel,message,Rect2(10,3,590,42),17,UI.PAPER,true)
	fade_in(toast_panel,.18)
	get_tree().create_timer(2.8).timeout.connect(func():
		if number==toast_generation and is_instance_valid(toast_panel):
			toast_panel.free()
	)

func close_scene() -> void:
	if not is_instance_valid(modal):
		return
	if scene_key == "battle" and not game.battle.is_empty():
		if is_instance_valid(duel):
			duel.snapshot()
		game.leave_battle()
	duel=null
	root.remove_child(modal)
	modal.queue_free()
	modal = null
	scene_key = ""
	for item in modal_focus_nodes:
		if is_instance_valid(item):
			item.focus_mode = Control.FOCUS_ALL
	modal_focus_nodes.clear()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()
	previous_focus = null

func open_scene(kind: String,instant := false) -> void:
	close_tray()
	duel=null
	if is_instance_valid(modal):
		root.remove_child(modal)
		modal.queue_free()
	else:
		previous_focus = get_viewport().gui_get_focus_owner()
		for item: Button in root.find_children("*","Button",true,false):
			if item.focus_mode==Control.FOCUS_ALL:
				modal_focus_nodes.append(item)
				item.focus_mode=Control.FOCUS_NONE
	scene_key = kind
	modal = Control.new()
	modal.z_index = 20
	ui.place(modal,root,Rect2(Vector2.ZERO,VIEW))
	ui.box(modal,Rect2(Vector2.ZERO,VIEW),Color(.025,.075,.063,.69),Color.TRANSPARENT,0)
	if not instant:
		sound_tick()
	match kind:
		"garden": garden_window()
		"remedies": remedies_window()
		"recruit": recruit_window()
		"duties": duties_window()
		"pet": pet_window()
		"journey": journey_window()
		"rank": rank_window()
		"season": season_window()
		"ledger": ledger_window()
		"battle": battle_window()
		"practice": action_window(true)
		"story": story_window()
		"dialogue": dialogue_window()
		"ending": ending_window()
		"expedition": expedition_window()
		"expedition_plan": expedition_plan_window()
		"relics": relic_window()
		"imprints": imprints_window()
		"extraction": extraction_window()
		"expedition_result": expedition_result_window()
		"facilities": facilities_window()
		"master": master_window()
		"inventory": inventory_window()
		"hero_select": hero_selection_window()
		"settings": settings_window()
		"reset": reset_window()
		"credits": credits_window()
	if not instant:
		fade_in(modal,.16)

func window(title: String,subtitle: String,glyph: String, dimensions: Vector2) -> Control:
	var host := Control.new()
	ui.place(host,modal,Rect2((VIEW-dimensions)*.5,dimensions))
	ui.framed(host,Rect2(Vector2.ZERO,dimensions))
	ui.ornament(host,Rect2(dimensions.x*.5-90,-14,180,31))
	ui.box(host,Rect2(24,23,42,42),UI.WELL,UI.BORDER,10)
	ui.mark(host,glyph,Rect2(32,31,26,26))
	ui.label(host,title,Rect2(79,16,dimensions.x-150,43),30,UI.PAPER,false,true)
	if not subtitle.is_empty():
		ui.label(host,subtitle,Rect2(79,60,dimensions.x-155,26),15,UI.MUTE)
	icon_button(host,"close",Rect2(dimensions.x-63,20,40,40),"关闭 · Esc",close_scene)
	ui.line(host,Vector2(25,101),Vector2(dimensions.x-25,101))
	return host

func garden_window() -> void:
	var host := window("灵药圃","灵石 %d    ·    灵草 %d" % [game.data.stones,game.data.herbs],"sprout",Vector2(850,558))
	for i in 3:
		var x := 26+i*267
		var crop: Array = game.data.plots[i]
		var ripe: bool = not crop.is_empty() and game.data.day >= crop[1]
		var hue := UI.GOLD if ripe else UI.JADE
		var tile := ui.button(host,"",Rect2(x,121,249,173),func(): active_plot=i;open_scene("garden",true),hue,false,14)
		var selected := i == active_plot
		ui.box(tile,Rect2(15,11,219,95),Color("#263b2b") if not crop.is_empty() else Color("#292e26"),hue if selected else UI.BORDER,11)
		var art: int = 0 if crop.is_empty() else (2+int(crop[0]) if ripe else 1)
		ui.picture(tile,PLOT_ART[art],Rect2(23,15,202,86))
		ui.label(tile,"第 %d 畦%s" % [i+1," · 已选中" if selected else ""],Rect2(15,106,219,29),16,hue,true)
		var plot_status := "空地" if crop.is_empty() else "%s · %s" % [State.CROPS[crop[0]][0],"可采收" if ripe else "还需 %d 日" % int(crop[1]-game.data.day)]
		ui.label(tile,plot_status,Rect2(15,137,219,23),14,UI.PAPER,true)
	var current: Array = game.data.plots[active_plot]
	ui.label(host,"当前选中第 %d 畦" % (active_plot+1),Rect2(27,306,690,30),18,UI.PAPER,false,true)
	if game.duty_member("garden",true)>=0:
		ui.label(host,"药圃照料 · 每次采收 +2 株",Rect2(517,306,303,30),15,UI.JADE,true)
	if current.is_empty():
		ui.button(host,"播种青露草 · 9 灵石",Rect2(26,346,391,47),func(): game.plant(active_plot,0);open_scene("garden",true),UI.JADE,true,10,game.can_plant(active_plot,0))
		ui.button(host,"播种火纹芝 · 18 灵石" if game.data.rank>0 else "筑基后可播种火纹芝",Rect2(430,346,391,47),func(): game.plant(active_plot,1);open_scene("garden",true),UI.OCHRE,false,10,game.can_plant(active_plot,1))
	else:
		var ready: bool = game.data.day >= current[1]
		ui.button(host,"采收灵草" if ready else "灵草正在生长",Rect2(26,346,797,47),func(): game.harvest(active_plot);open_scene("garden",true),UI.JADE,true,10,ready)
	ui.button(host,"休整一日",Rect2(26,419,391,45),func(): game.record("山门","山门休整了一日。");open_scene("garden",true),UI.GOLD)
	ui.button(host,"炼化 1 株灵草 · 修为 +23",Rect2(430,419,391,45),func(): game.refine();open_scene("garden",true),UI.COLORS[4],false,10,game.data.herbs>0)
	ui.button(host,"丹房备战",Rect2(26,478,795,46),func(): open_remedies("garden"),UI.OCHRE)

func open_remedies(from: String) -> void:
	remedy_return=from
	open_scene("remedies")

func remedies_window() -> void:
	var choosing := remedy_return=="expedition"
	var host := window("丹房备战","灵草 %d 株 · 灵石 %d · 每趟可携带一份，平安归来时退回未用药剂。" % [game.data.herbs,game.data.stones],"flame",Vector2(1110,609))
	var tones := [UI.JADE,UI.COLORS[3],UI.OCHRE]
	for i in Expedition.REMEDIES.size():
		var recipe: Dictionary = Expedition.REMEDIES[i]
		var x := 26+i*354
		var stock: int = game.data.remedies[i]
		ui.framed(host,Rect2(x,120,340,397))
		ui.box(host,Rect2(x+12,132,316,154),UI.INK,UI.BORDER,9)
		ui.picture(host,load("res://assets/remedy%d.webp" % i),Rect2(x+64,139,212,139))
		ui.label(host,recipe.name,Rect2(x+16,294,308,39),24,UI.PAPER,true,true)
		ui.label(host,recipe.hint,Rect2(x+25,337,290,42),15,UI.MUTE,true,false,true)
		ui.label(host,"库存 %d 份" % stock,Rect2(x+18,383,304,28),15,tones[i],true)
		var brew := ui.button(host,"炼制 · %d 草 / %d 石" % [recipe.herbs,recipe.stones],Rect2(x+19,416,302,39),func():
			if game.brew_remedy(i):
				open_scene("remedies",true),tones[i],not choosing,10,game.can_brew_remedy(i))
		brew.tooltip_text="消耗 %d 株灵草和 %d 灵石。" % [recipe.herbs,recipe.stones]
		if choosing:
			ui.button(host,"本趟已选" if i==draft_remedy else "携带"+recipe.name,Rect2(x+19,464,302,38),func():
				draft_remedy=i
				open_scene("expedition",true),tones[i],i!=draft_remedy,9,stock>0 and i!=draft_remedy)
	if choosing:
		ui.button(host,"本趟不携带",Rect2(26,540,320,44),func():
			draft_remedy=-1
			open_scene("expedition",true),UI.JADE,false,10,draft_remedy>=0)
	ui.button(host,"返回远征整备" if choosing else "返回灵药圃",Rect2(736,540,352,44),func():open_scene(remedy_return,true),UI.JADE)

func recruit_window() -> void:
	var people: Array = game.data.people
	var host := window("招贤台","未在岗的弟子每日供奉 4 灵石。    持有 %d 灵石" % game.data.stones,"hall",Vector2(712,490))
	for i in State.PEOPLE.size():
		var slot := Vector2(26+(i%4)*166,124+int(i/4.0)*119)
		var available := i < people.size()
		ui.box(host,Rect2(slot,Vector2(153,104)),UI.INK,UI.BORDER if available else Color("#32433b"),10)
		if available:
			var portrait := ui.picture(host,STUDENT_ART[i%STUDENT_ART.size()],Rect2(slot+Vector2(41,6),Vector2(71,63)),Color.WHITE if i<4 else Color(.86,1.0,.94))
			portrait.flip_h = i>=4
		else:
			ui.mark(host,"lock",Rect2(slot+Vector2(57,13),Vector2(37,37)),UI.MUTE.darkened(.25))
		ui.label(host,State.PEOPLE[i] if available else "空席",Rect2(slot+Vector2(3,62),Vector2(147,30)),17,UI.PAPER if available else UI.MUTE,true)
	var full := people.size() >= State.PEOPLE.size()
	var name := "弟子已满员" if full else "收徒 %s · %d 灵石" % [State.PEOPLE[people.size()],game.recruit_cost()]
	if people.is_empty():
		name="收首徒 桃桃 · 免费"
	ui.button(host,name,Rect2(26,379,395,55),func(): game.recruit();open_scene("recruit",true),UI.GOLD,true,10,not full and game.data.stones>=game.recruit_cost())
	ui.button(host,"弟子派驻",Rect2(434,379,251,55),func():
		duty_selection=-1
		open_scene("duties"),UI.JADE)

func duties_window() -> void:
	var people: Array = game.data.people
	var host := window("弟子派驻","派驻次日生效。在岗弟子暂停供奉，撤回后方可随队出征。","hall",Vector2(1120,721))
	if people.is_empty():
		ui.label(host,"先在招贤台收一名弟子，再安排他的差事。",Rect2(28,133,1064,46),19,UI.PAPER,true)
	else:
		for member in people.size():
			var x := 28+member*134
			var post: String = game.member_duty(member)
			var away: bool = game.member_traveling(member)
			var chosen := member==duty_selection
			var caption := "待命"
			if away:
				caption="随队出征"
			elif not post.is_empty():
				caption="明日到岗" if game.duty_member(post,true)<0 else "正在驻岗"
			var tile := ui.button(host,"",Rect2(x,125,126,78),func(): duty_selection=member;open_scene("duties",true),UI.GOLD,chosen,10,not away)
			tile.tooltip_text=people[member]
			ui.label(tile,people[member],Rect2(6,9,114,33),17,UI.INK if chosen else UI.PAPER,true,true)
			ui.label(tile,caption,Rect2(6,42,114,26),13,UI.INK if chosen else UI.MUTE,true)
	for i in State.DUTIES.size():
		var row: Array = State.DUTIES[i]
		var post: String = row[0]
		var member: int = game.duty_member(post)
		var y := 223+i*132
		ui.framed(host,Rect2(28,y,1064,119))
		ui.mark(host,row[3],Rect2(52,y+29,50,50),UI.GOLD)
		ui.label(host,row[1],Rect2(120,y+17,356,33),21,UI.PAPER,false,true)
		ui.label(host,row[2],Rect2(120,y+49,548,31),15,UI.MUTE)
		var status: String = "暂无驻岗弟子" if member<0 else "%s · %s" % [people[member],"明日到岗" if game.duty_member(post,true)<0 else "在岗"]
		if post=="scout":
			status+=" · 已有 1 张勘察札" if game.data.scout_token>0 else " · 勘察进度 %d / 3 日" % game.data.scout_days
		ui.label(host,status,Rect2(120,y+79,548,24),14,UI.JADE)
		var can_post: bool = duty_selection>=0 and duty_selection!=member and not game.member_traveling(duty_selection)
		var label: String = ("改派%s" if member>=0 else "派驻%s") % people[duty_selection] if duty_selection>=0 else "先点选弟子"
		var dispatch := ui.button(host,label,Rect2(702,y+36,226,46),func():
			if game.assign_duty(post,duty_selection):
				open_scene("duties",true),UI.OCHRE,true,10,can_post)
		dispatch.tooltip_text="派驻%s" % row[1]
		ui.button(host,"撤回",Rect2(937,y+36,124,46),func():
			if game.assign_duty(post,-1):
				open_scene("duties",true),UI.JADE,false,10,member>=0)
	ui.button(host,"返回招贤台",Rect2(28,630,305,47),func():open_scene("recruit",true),UI.JADE)
	ui.button(host,"休整一日",Rect2(790,630,302,47),func():
		game.record("山门","宗门休整一日。")
		open_scene("duties",true),UI.GOLD)

func pet_window() -> void:
	var host := window("灵兽园","每只灵兽每日汇聚 3 修为。    持有 %d 株灵草" % game.data.herbs,"paw",Vector2(830,450))
	for i in State.PETS.size():
		var x := 26+i*196
		var present: bool = i < game.data.pets.size()
		ui.box(host,Rect2(x,126,185,168),UI.INK,UI.BORDER,12)
		ui.picture(host,FOE_ART[i],Rect2(x+24,133,137,114),Color.WHITE if present else Color(.22,.33,.28))
		ui.label(host,State.PETS[i] if present else "等待结缘",Rect2(x,250,185,31),17,UI.PAPER if present else UI.MUTE,true)
	var count: int = game.data.pets.size()
	var full: bool = count >= State.PETS.size()
	var caption := "灵兽园已住满" if full else "驯养%s · %d 株灵草" % [State.PETS[count],game.tame_cost()]
	ui.button(host,caption,Rect2(26,334,774,53),func(): game.tame();open_scene("pet",true),UI.COLORS[2],true,10,not full and game.data.herbs>=game.tame_cost())

func journey_window() -> void:
	var host := window("御剑历练","从%s御剑出发。每次历练耗时一日。" % State.MAPS[game.data.map][1],"compass",Vector2(780,514))
	var amount := 27 + (12 if game.data.map==2 else 0)
	for i in 2:
		var x := 27+i*370
		ui.box(host,Rect2(x,122,356,255),UI.WELL,UI.BORDER,13)
		if i == 0:
			ui.mark(host,"compass",Rect2(x+139,150,70,70),UI.COLORS[3])
		else:
			ui.picture(host,FOE_ART[game.data.map],Rect2(x+110,126,136,111))
		ui.label(host,["云间寻宝","山野斗法"][i],Rect2(x+10,232,336,45),23,UI.PAPER,true,true)
		var detail := "寻得 %d 灵石与 16 修为" % amount if i==0 else "对阵%s · 留意对手蓄力" % State.FOES[game.data.map]
		ui.label(host,detail,Rect2(x+10,278,336,27),15,UI.MUTE,true)
		var action: Callable = func(): game.treasure();open_scene("journey",true)
		if i==1:
			action = fight_start
		ui.button(host,["御剑寻宝","拔剑应战"][i],Rect2(x+13,314,330,45),action,UI.COLORS[3] if i==0 else UI.OCHRE,true,10,i==0 or game.data.stones>=10)
	ui.label(host,"斗法胜利取得修为和灵石，战败损失 10 灵石。",Rect2(26,392,728,31),14,UI.MUTE,true)
	ui.button(host,"前往遗灯秘境" if game.data.expedition.is_empty() else "继续遗灯秘境",Rect2(26,433,728,48),open_expedition,UI.OCHRE,true)

func rank_window() -> void:
	var current: int = game.data.rank
	var host := window("渡劫台","聚气修行，提升掌门境界与宗门等级。","spark",Vector2(830,461))
	for i in State.RANKS.size():
		var x := 29+i*157
		ui.box(host,Rect2(x,131,145,113),UI.WELL if i<=current else UI.INK,UI.GOLD if i==current else UI.BORDER,13)
		ui.mark(host,"spark" if i<=current else "lock",Rect2(x+52,147,41,41),UI.GOLD if i<=current else UI.MUTE)
		ui.label(host,State.RANKS[i],Rect2(x+2,198,141,30),18,UI.PAPER,true,true)
	var detail := "四处山门皆已开启，仍可继续经营宗门。"
	var next_step := "飞升圆满"
	if current<4:
		detail = "修为 %d / %d" % [game.data.qi,State.NEEDS[current]]
		next_step = "突破至%s" % State.RANKS[current+1]
		if current<=2:
			detail += "　·　突破后可迁入%s" % State.MAPS[current+1][1]
		else:
			detail += "　·　布阵需 95 灵石"
			next_step = "布阵渡劫"
	ui.label(host,detail,Rect2(30,267,770,43),16,UI.PAPER,true)
	ui.button(host,next_step,Rect2(31,327,768,52),func(): game.breakthrough();open_scene("rank",true),UI.COLORS[4],true,11,game.can_break())

func season_window() -> void:
	var m: Array = State.MAPS[season_preview]
	var host := window("%s季 · %s" % [m[0],m[1]],"%s　·　%s" % [m[2],m[3]],"mountain",Vector2(740,602))
	var mask := Control.new()
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(mask,host,Rect2(26,120,688,302))
	ui.picture(mask,atlas.maps[season_preview],Rect2(0,0,688,302),Color.WHITE,true)
	ui.label(host,m[4],Rect2(27,434,686,35),16,UI.MUTE,true)
	var unlocked: bool = season_preview <= game.data.rank
	var destination: int = season_preview
	var present: bool = destination==game.data.map
	var caption: String = "已在此处驻地" if present else "迁入%s" % m[1]
	if not unlocked:
		caption = "%s境解锁" % State.RANKS[season_preview]
	ui.button(host,caption,Rect2(27,487,686,54),func(): game.migrate(destination);close_scene(),UI.GOLD,true,10,unlocked and not present)

func ledger_window() -> void:
	var host := window("宗门簿","查看开宗任务、领取回礼和翻阅宗门见闻。","scroll",Vector2(850,693))
	for i in 2:
		ui.button(host,["开宗手记","宗门见闻"][i],Rect2(25+i*402,118,394,43),func(): ledger_tab=i;open_scene("ledger",true),UI.GOLD,ledger_tab==i,9)
	if ledger_tab == 0:
		for i in State.TASKS.size():
			var y := 177+i*59
			var task: Array = State.TASKS[i]
			var checked: bool = game.is_done(i)
			var claimed: bool = i in game.data.claimed
			ui.box(host,Rect2(25,y,798,50),UI.WELL if checked else UI.INK,UI.BORDER,8)
			ui.mark(host,"check" if checked else "scroll",Rect2(38,y+13,23,23),UI.JADE if checked else UI.MUTE)
			ui.label(host,task[0],Rect2(72,y+1,119,47),17,UI.PAPER,false,true)
			ui.label(host,task[1],Rect2(194,y+1,452,47),14,UI.MUTE)
			if checked and not claimed:
				ui.button(host,"领取 %d 灵石" % (120 if i==7 else 20),Rect2(657,y+7,154,36),func(): game.claim(i);open_scene("ledger",true),UI.GOLD,true,8)
			else:
				ui.label(host,"已领取" if claimed else "进行中",Rect2(662,y+3,143,43),14,UI.JADE if claimed else UI.MUTE,true)
	else:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ui.place(scroll,host,Rect2(23,179,802,482))
		var track := VBoxContainer.new()
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.add_theme_constant_override("separation",7)
		scroll.add_child(track)
		for entry: Array in game.data.log:
			var item := Control.new()
			item.custom_minimum_size = Vector2(748,50)
			item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			track.add_child(item)
			ui.box(item,Rect2(3,1,762,47),UI.WELL,UI.BORDER,8)
			ui.label(item,"第 %d 日" % entry[0],Rect2(15,2,96,43),14,UI.GOLD,true)
			ui.label(item,entry[1],Rect2(119,2,81,43),14,UI.JADE)
			ui.label(item,str(entry[2]).replace("小青团",game.hero_name()),Rect2(196,1,550,45),16,UI.PAPER)


func open_story() -> void:
	story_preview = mini(game.data.story_chapter,Chronicle.CHAPTERS.size()-1)
	open_scene("story")

func story_window() -> void:
	var count: int = game.data.story_chapter
	var chapter: Dictionary = Chronicle.CHAPTERS[story_preview]
	var host := window("长明灯","四季山门的主线故事","flame",Vector2(998,661))
	for i in Chronicle.CHAPTERS.size():
		var card := ui.button(host,"",Rect2(27,130+99*i,235,84),func(): story_preview=i; open_scene("story",true),UI.GOLD,i==story_preview,12,i<=count)
		var badge := ["壹","贰","叁","肆"][i] as String
		ui.label(card,badge,Rect2(18,12,45,55),24,UI.INK if i==story_preview else UI.GOLD,true,true)
		ui.label(card,Chronicle.CHAPTERS[i].title,Rect2(76,11,146,34),18,UI.INK if i==story_preview else UI.PAPER,false,true)
		var mark := "已完成" if i<count else ("当前篇章" if i==count else "未开启")
		ui.label(card,mark,Rect2(76,46,137,22),13,UI.INK if i==story_preview else UI.MUTE)
	var art := Control.new()
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(art,host,Rect2(281,129,691,230))
	ui.picture(art,atlas.maps[story_preview],Rect2(0,0,691,230),Color.WHITE,true)
	ui.box(art,Rect2(15,164,661,50),Color(.06,.13,.10,.88),UI.GOLD,8)
	ui.label(art,"第 %d 章 · %s" % [story_preview+1,chapter.title],Rect2(32,165,650,46),23,UI.PAPER,false,true)
	ui.label(host,chapter.summary,Rect2(287,377,678,70),17,UI.PAPER,false,false,true)
	var read: bool = story_preview in game.data.story_read
	ui.button(host,"重读剧情" if read else "阅读剧情",Rect2(287,478,206,50),func(): dialogue_page=0; open_scene("dialogue"),UI.OCHRE,not read,10,story_preview<=count)
	if story_preview<count:
		ui.label(host,chapter.reward,Rect2(287,539,683,81),16,UI.JADE,false,false,true)
		if count==4:
			ui.button(host,"查看结局" if game.data.story_ending>=0 else "决定长明灯去处",Rect2(515,478,452,50),func(): open_scene("ending"),UI.OCHRE,true)
		elif story_preview+1==count:
			ui.button(host,"前往下一章",Rect2(515,478,452,50),func(): story_preview=count;open_scene("story",true),UI.OCHRE,true)
		return
	if not read:
		ui.label(host,"读完这一章，即可准备守灵战。",Rect2(516,478,443,50),15,UI.MUTE)
		return
	var gate: String = game.story_requirement(story_preview)
	var forward := {"rank":"前往渡劫台","season":"查看本章山门","garden":"前往药圃","pet":"前往灵兽园","journey":"前往御剑台"}
	var hint := {
		"rank":"提升境界至%s，解锁本章山门。" % State.RANKS[story_preview],
		"season":"宗门需先迁入%s。" % State.MAPS[story_preview][1],
		"garden":"采收一畦灵草，备好救人用的药。",
		"pet":"驯养一只灵兽，请它辨认真火。",
		"journey":"完成一次云间寻宝，找回山外的线索。"
	}
	if gate.is_empty():
		ui.button(host,"挑战%s" % chapter.foe,Rect2(515,478,452,50),story_fight_start,UI.OCHRE,true)
		ui.label(host,"守灵战可重试。未损伤时无法使用灵草。",Rect2(289,559,684,45),15,UI.MUTE)
		return
	ui.button(host,forward[gate],Rect2(515,478,452,50),func():
		if gate=="season":
			season_preview=story_preview
		open_scene(gate),UI.GOLD)
	ui.label(host,hint[gate],Rect2(289,558,684,46),16,UI.JADE)

func dialogue_window() -> void:
	var chapter: Dictionary = Chronicle.CHAPTERS[story_preview]
	var lines: Array = chapter.lines
	var verse: Array = lines[dialogue_page]
	var host := window(chapter.title,"第 %d 章" % (story_preview+1),"flame",Vector2(1050,685))
	var veil := Control.new()
	veil.clip_contents = true
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(veil,host,Rect2(26,121,998,314))
	ui.picture(veil,atlas.maps[story_preview],Rect2(0,0,998,314),Color(.78,.88,.79),true)
	ui.box(veil,Rect2(0,0,998,314),Color(.02,.12,.09,.34),UI.BORDER,0)
	var old := load("res://assets/keeper.webp") as Texture2D
	ui.picture(veil,old,Rect2(51,38,316,272),Color.WHITE if verse[0]==1 else Color(.59,.68,.64))
	ui.picture(veil,hero_portrait(),Rect2(662,42,277,273),Color.WHITE if verse[0]==0 else Color(.59,.68,.64))
	ui.box(host,Rect2(26,438,998,118),Color("#223c2d"),Color("#94794b"),11)
	ui.label(host,game.hero_name() if verse[0]==0 else verse[1],Rect2(46,448,260,31),21,UI.GOLD,false,true)
	ui.label(host,verse[2],Rect2(47,482,949,62),18,UI.PAPER,false,false,true)
	var last := dialogue_page==lines.size()-1
	ui.button(host,"上一句",Rect2(27,581,165,46),func(): dialogue_page-=1;open_scene("dialogue",true),UI.JADE,false,10,dialogue_page>0)
	ui.label(host,"%d / %d" % [dialogue_page+1,lines.size()],Rect2(438,581,166,46),15,UI.MUTE,true)
	var next := ui.button(host,"打开本章任务" if last else "继续",Rect2(808,581,215,46),next_dialogue,UI.OCHRE,true)
	next.tooltip_text = "继续剧情 · 空格"

func next_dialogue() -> void:
	var chapter: Dictionary = Chronicle.CHAPTERS[story_preview]
	if dialogue_page<chapter.lines.size()-1:
		dialogue_page+=1
		open_scene("dialogue",true)
	else:
		game.read_chapter(story_preview)
		open_scene("story",true)

func story_fight_start() -> void:
	if game.start_battle(story_preview):
		open_scene("battle")

func ending_window() -> void:
	var decided: bool = game.data.story_ending>=0
	var host := window("四时有灯","长明灯 · 终章","flame",Vector2(895,623))
	var veil := Control.new()
	veil.clip_contents = true
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(veil,host,Rect2(27,126,841,279))
	ui.picture(veil,OPENING,Rect2(0,0,841,279),Color.WHITE,true)
	var note := "城门重新打开。灯是留在故乡，还是分出去给四季山门？"
	if decided:
		note = str(Chronicle.ENDINGS[game.data.story_ending][1]).replace("小青团",game.hero_name())
	ui.label(host,note,Rect2(31,418,833,85),18,UI.PAPER,false,false,true)
	if decided:
		ui.button(host,"回到山门",Rect2(27,520,841,50),close_scene,UI.GOLD,true)
	else:
		for i in Chronicle.ENDINGS.size():
			ui.button(host,Chronicle.ENDINGS[i][0],Rect2(27+i*425,520,416,50),func():
				if game.finish_story(i):
					open_scene("ending",true),UI.OCHRE if i==0 else UI.JADE,true)

func fight_start() -> void:
	if game.start_battle():
		open_scene("battle")

func battle_window() -> void:
	var b: Dictionary = game.battle
	if b.get("action_duel",false):
		action_window(false)
		return
	var plot_fight: bool = b.story>=0
	var expedition_fight: bool = b.get("expedition",false)
	var foe_name: String = Chronicle.CHAPTERS[b.story].foe if plot_fight else State.FOES[b.map]
	var title := "守灵战" if plot_fight else "山野斗法"
	if expedition_fight:
		foe_name=Expedition.BOSSES[b.map] if b.expedition_node=="boss" else Expedition.FOES[b.expedition_node]
		title="遗灯之门" if b.expedition_node=="boss" else ("封灯试炼" if b.expedition_node=="seal" else "秘境遭遇")
	var host := window(title,"%s · %s" % [State.MAPS[b.map][1],foe_name],"sword",Vector2(1124,744))
	var arena := Control.new()
	arena.clip_contents = true
	ui.place(arena,host,Rect2(24,119,1076,430))
	ui.picture(arena,expedition_art() if expedition_fight else atlas.maps[b.map],Rect2(0,0,1076,430),Color(.70,.81,.76),true)
	ui.box(arena,Rect2(0,0,1076,430),Color(.04,.12,.09,.41),UI.BORDER,0)
	ui.framed(arena,Rect2(19,18,323,79))
	ui.framed(arena,Rect2(733,18,324,79))
	ui.label(arena,game.hero_name(),Rect2(40,25,144,28),22,UI.PAPER,false,true)
	ui.label(arena,foe_name,Rect2(753,25,176,28),22,UI.PAPER,false,true)
	ui.label(arena,"%d / %d" % [b.hp,b.maxhp],Rect2(212,26,100,29),16,UI.JADE,true)
	ui.label(arena,"%d / %d" % [b.enemy,b.maxenemy],Rect2(930,26,104,29),16,UI.COLORS[2],true)
	ui.meter(arena,Rect2(41,61,279,11),float(b.hp)/b.maxhp,UI.JADE)
	ui.meter(arena,Rect2(755,61,279,11),float(b.enemy)/b.maxenemy,UI.COLORS[2])
	var hero := ui.picture(arena,hero_portrait(),Rect2(93,126,291,250))
	hero.flip_h=true
	var enemy_art: Texture2D = FOE_ART[b.map]
	var guardian_path := "res://assets/guardian%d.webp" % b.map
	if expedition_fight and b.expedition_node=="boss" and ResourceLoader.exists(guardian_path):
		enemy_art=load(guardian_path)
	elif expedition_fight and b.expedition_node=="seal" and ResourceLoader.exists("res://assets/duel_seal_mastiff.webp"):
		enemy_art=load("res://assets/duel_seal_mastiff.webp")
	var foe := ui.picture(arena,enemy_art,Rect2(683,126,285,246))
	if b.result>0:
		foe.modulate = Color(.62,.70,.65)
	elif b.result<0:
		hero.modulate = Color(.60,.68,.60)
	var signature: bool = b.result==0 and game.boss_signature_queued()
	ui.box(arena,Rect2(402,102,272,63),Color(.06,.16,.13,.94),UI.OCHRE if signature else UI.GOLD,12)
	if b.result==0:
		var move: Array = game.next_move()
		var move_tip: String = {"light":"连击","heavy":"重击 · 可打断","ward":"守势 · 御剑减伤"}[move[2]]
		if signature:
			move_tip="半血绝技 · 可打断"
		var tint := UI.COLORS[2] if move[2]=="heavy" or signature else (UI.COLORS[3] if move[2]=="ward" else UI.GOLD)
		ui.label(arena,move[0],Rect2(403,104,270,32),20,tint,true,true)
		ui.label(arena,"%s · %d 伤害" % [move_tip,game.foe_damage(move)],Rect2(403,136,270,21),13,UI.PAPER,true)
		if signature:
			ui.box(arena,Rect2(329,213,418,57),Color(.06,.16,.13,.96),UI.OCHRE,9)
			ui.label(arena,move[3],Rect2(346,216,384,48),14,UI.PAPER,true,false,true)
	else:
		ui.label(arena,"获胜" if b.result>0 else "败退",Rect2(403,104,270,57),28,UI.OCHRE,true,true)
	ui.label(arena,"剑意",Rect2(411,175,53,27),15,UI.PAPER)
	for i in 3:
		ui.box(arena,Rect2(477+i*30,184,18,13),UI.GOLD if i<b.focus else UI.WELL,UI.GOLD,4)
	ui.label(arena,"%d / 3" % b.focus,Rect2(570,175,73,27),15,UI.GOLD,true)
	if b.result==0 and b.get("frost",0)>0:
		ui.label(arena,"结霜 · 御剑基础伤害 −%d" % b.frost,Rect2(355,279,366,31),15,UI.COLORS[3],true)
	ui.box(arena,Rect2(19,380,1038,35),Color(.035,.13,.10,.89),UI.BORDER,8)
	ui.label(arena,str(b.note).replace("小青团",game.hero_name()),Rect2(27,381,1023,32),17,UI.PAPER,true)
	var relic: int = b.get("relic",-1)
	if relic>=0:
		var relic_note: String = b.get("relic_note","")
		var detail: String = relic_note if not relic_note.is_empty() else "携带 %s" % Expedition.RELICS[relic][0]
		ui.box(arena,Rect2(373,328,330,35),Color(.06,.16,.13,.92),UI.GOLD,9)
		ui.label(arena,detail,Rect2(381,329,314,33),14,UI.GOLD,true)
	var imprint: int = b.get("imprint",-1)
	if imprint>=0:
		var used := " · 已返还剑意" if b.get("imprint_spent",false) else ""
		ui.box(arena,Rect2(24,307,272,34),Color(.06,.16,.13,.92),UI.GOLD,9)
		ui.label(arena,Expedition.IMPRINTS[imprint].name+used,Rect2(30,308,260,32),14,UI.GOLD,true)
	if b.hit>0:
		damage_float(arena,"−%d" % b.hit,Vector2(809,164),UI.OCHRE)
		if game.data.motion:
			var shake := create_tween()
			shake.tween_property(foe,"position:x",701.0,.07)
			shake.tween_property(foe,"position:x",683.0,.15)
			var lunge := create_tween()
			lunge.tween_property(hero,"position:x",144.0,.10)
			lunge.tween_property(hero,"position:x",93.0,.18)
			combat_arc(arena,b.action in ["spell","spirit"])
	if b.taken>0:
		damage_float(arena,"−%d" % b.taken,Vector2(155,167),UI.COLORS[2])
	if b.healed>0:
		damage_float(arena,"+%d" % b.healed,Vector2(222,231),UI.JADE)
	if b.result!=0:
		if expedition_fight:
			var finished: bool = game.data.expedition.is_empty()
			ui.button(host,"查看远征结算" if finished else "继续远征",Rect2(25,590,1074,54),func():
				close_scene()
				open_scene("expedition_result" if finished else "expedition"),UI.OCHRE,true)
			return
		var caption := "阅读战后剧情" if plot_fight and b.result>0 else ("返回本章" if plot_fight else "返回山门")
		ui.button(host,caption,Rect2(25,590,1074,54),func():
			var previous_chapter: int = b.story
			close_scene()
			if previous_chapter>=0:
				story_preview = previous_chapter
				open_scene("story"),UI.OCHRE,true)
		return
	var actions := [
		["attack","如意棒" if game.data.hero_style==2 else "御剑斩","伤害 %d · 剑意 +1" % game.hit_preview(),"training","sword",UI.OCHRE],
		["guard","架剑","减伤 · 剑意 +2","none","shield",UI.COLORS[3]],
		["spell",State.HERO_TECHNIQUES[maxi(0,game.data.hero_style)],"伤害 %d · 剑意 −3" % game.spell_damage(),"rank","spark",UI.COLORS[4]],
		["herb","灵草疗伤","恢复 31 · 持有 %d 株" % game.expedition_herbs(),"garden","sprout",UI.JADE]
	]
	for i in actions.size():
		var action: Array = actions[i]
		var usable: bool = game.can_combat(action[0])
		var primary: bool = usable and (action[0]=="spell" or (action[0]=="attack" and b.focus<3))
		var tile := ui.button(host,"",Rect2(25+i*271,575,261,77),func(): combat(action[0]),action[5],primary,12,usable)
		tile.tooltip_text = "%s · 按 %d" % [action[2],i+1]
		if not usable:
			tile.tooltip_text = "需要 3 点剑意。御剑斩和架剑可以积攒剑意。" if action[0]=="spell" else ("气血已满。" if b.hp==b.maxhp else "没有可用于疗伤的灵草。")
		var art := ui.emblem(tile,action[3],action[4],Rect2(18,14,44,44),action[5])
		art.modulate.a=1.0 if usable else .42
		ui.lift_on_hover(tile,art,game.data.motion)
		ui.label(tile,action[1],Rect2(72,9,156,34),21,UI.INK if primary else UI.PAPER,false,true)
		ui.label(tile,action[2],Rect2(72,42,177,24),13,UI.INK if primary else UI.MUTE)
	var spirit: int = game.expedition_spirit()
	var brew_id: int = b.get("remedy",-1)
	if brew_id>=0:
		var recipe: Dictionary = Expedition.REMEDIES[brew_id]
		var reason := Expedition.remedy_block(b)
		var suffix := " · 护阵中" if b.get("remedy_ward",0)>0 else (" · 已用" if b.remedy_used else "")
		var dose := ui.button(host,"[F] "+recipe.name+suffix,Rect2(322,666,382,49),combat_remedy,UI.GOLD,reason.is_empty(),10,reason.is_empty())
		dose.tooltip_text=recipe.hint if reason.is_empty() else reason
	if spirit>=0:
		ui.label(host,"第 %d 回合 · 数字键 1–5 出招" % b.turn,Rect2(29,670,285,42),15,UI.MUTE)
		var technique: Array = Expedition.PET_MOVES[spirit]
		var available: bool = game.can_combat("spirit")
		var bond := ui.button(host,"[5] %s · %s" % [technique[0],"本趟可用 1 次" if available else "本趟已用"],Rect2(716,666,383,49),func():combat("spirit"),UI.JADE,available,12,available)
		bond.tooltip_text=technique[1] if spirit!=1 else "造成 %d 点伤害，可打断重击和守势。" % game.spirit_damage()
	elif brew_id<0:
		ui.label(host,"第 %d 回合 · 数字键 1–4 出招" % b.turn,Rect2(26,673,1074,29),15,UI.MUTE,true)
	else:
		ui.label(host,"第 %d 回合 · 数字键 1–4 出招" % b.turn,Rect2(29,670,285,42),15,UI.MUTE)

func combat_remedy() -> void:
	if game.use_turn_remedy():
		sound_tick("chime")
		open_scene("battle",true)


func open_expedition() -> void:
	if game.data.expedition.is_empty():
		draft_herbs = mini(2,game.data.herbs)
		draft_tier = 0
		draft_commission = ""
		draft_scout=false
		draft_remedy=-1
		draft_relic = int(game.data.expedition_relic_preset)
		if not game.relic_unlocked(draft_relic):
			draft_relic=-1
		draft_imprint=int(game.data.expedition_imprint_preset)
		if draft_relic<0 or not game.imprint_learned(draft_imprint):
			draft_imprint=-1
	else:
		route_choice = ""
	open_scene("expedition")

func expedition_window() -> void:
	if not game.data.expedition.is_empty():
		expedition_route()
		return
	draft_herbs=mini(draft_herbs,game.data.herbs)
	var region: int = game.data.map
	var host := window("遗灯秘境","%s · 单人远征整备" % State.MAPS[region][1],"compass",Vector2(1106,620))
	var veil := Control.new()
	veil.clip_contents = true
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.place(veil,host,Rect2(28,127,477,428))
	ui.picture(veil,expedition_art(),Rect2(0,0,477,428),Color.WHITE,true)
	ui.box(veil,Rect2(0,197,477,231),Color(.045,.12,.095,.93),UI.BORDER,8)
	ui.label(veil,"踏过五段山路，找到遗灯之门。",Rect2(21,206,435,36),21,UI.PAPER,false,true)
	ui.label(veil,"气血与灵草会带进下一场战斗。主动撤回能保住已得战利品，败退只带回一半灵石。",Rect2(21,266,431,62),16,UI.PAPER,false,false,true)
	if region==0 and action_expeditions:
		ui.label(veil,"青龙谷遭遇 · 横版即时斗法",Rect2(21,242,435,23),14,UI.GOLD)
	var forecast: Dictionary = game.expedition_forecast(draft_scout)
	var commission: String = Expedition.COMMISSIONS[draft_commission][0] if not draft_commission.is_empty() else "尚未接取委托"
	ui.label(veil,"本轮 %s  ·  %s" % [forecast.name,commission],Rect2(21,334,433,42),15,UI.GOLD)
	ui.button(veil,"看路况 · 选委托",Rect2(19,380,219,37),func(): open_scene("expedition_plan"),UI.JADE,true)
	if not game.data.expedition_last.is_empty():
		ui.button(veil,"上次远征战报",Rect2(245,380,214,37),func(): open_scene("expedition_result"),UI.JADE)
	prep_selector(host,0,"行囊灵草","%d 株" % draft_herbs,"远征中可用灵草疗伤，最多装 3 株。",func(amount: int):
		draft_herbs=posmod(draft_herbs+amount,mini(3,game.data.herbs)+1)
		open_scene("expedition",true),game.data.herbs>0)
	var risky: bool = game.data.expedition_wins[region]>0
	prep_selector(host,1,"远征难度","险途" if draft_tier else "初探","敌人更强，灯砂更多。" if draft_tier else ("按左右切换难度。" if risky else "首次破关后解锁险途。"),func(_amount: int):
		draft_tier=1-draft_tier
		open_scene("expedition",true),risky)
	var relic_name: String = Expedition.RELICS[draft_relic][0] if draft_relic>=0 else "未携带"
	if draft_imprint>=0:
		relic_name+=" / "+Expedition.IMPRINTS[draft_imprint].name
	ui.button(host,"镇门遗宝 · %s" % relic_name,Rect2(530,333,546,47),func():
		relic_return="expedition"
		open_scene("relics"),UI.GOLD)
	var scout_button := ui.button(host,"勘察札 · 已携带" if draft_scout else "勘察札 · %s" % ("可携带" if game.data.scout_token>0 else "暂无"),Rect2(530,392,546,47),func():
		draft_scout=not draft_scout
		open_scene("expedition",true),UI.JADE,draft_scout,10,game.data.scout_token>0)
	scout_button.tooltip_text="启程时消耗 1 张，给第三段增加无伤捷径。" if game.data.scout_token>0 else "安排弟子巡山，在岗 3 日后取得。"
	var remedy_name: String = Expedition.REMEDIES[draft_remedy].name if draft_remedy>=0 else "未携带"
	ui.button(host,"丹房备战 · "+remedy_name,Rect2(530,449,546,43),func():open_remedies("expedition"),UI.OCHRE,draft_remedy>=0)
	ui.button(host,"宗门营造",Rect2(530,501,189,54),func(): open_scene("facilities"),UI.JADE)
	ui.button(host,"启程入境",Rect2(731,501,345,54),launch_prepared_expedition,UI.OCHRE,true)

func launch_prepared_expedition() -> void:
	if game.start_expedition(-1,-1,draft_herbs,draft_tier,draft_commission,draft_relic,draft_scout,action_expeditions,draft_remedy,draft_imprint):
		route_choice=""
		open_scene("expedition",true)

func relic_window() -> void:
	var choosing := relic_return=="expedition"
	var host := window("镇门遗宝","首次击破各地灯门即可收录。每趟远征可携带一件。","spark",Vector2(1110,646))
	for i in Expedition.RELICS.size():
		var info: Array = Expedition.RELICS[i]
		var unlocked: bool = game.relic_unlocked(i)
		var x := 26+(i%2)*535
		var y := 126+int(i/2.0)*207
		ui.framed(host,Rect2(x,y,519,186))
		ui.box(host,Rect2(x+22,y+20,105,145),UI.INK,UI.BORDER,13)
		var path := "res://assets/relic%d.webp" % i
		if ResourceLoader.exists(path):
			var art := ui.picture(host,load(path),Rect2(x+27,y+30,94,123))
			if not unlocked:
				art.modulate=Color(.57,.65,.62,1)
		else:
			ui.mark(host,info[2],Rect2(x+44,y+57,62,62),UI.GOLD if unlocked else UI.MUTE)
		ui.label(host,info[0],Rect2(x+142,y+20,347,33),21,UI.PAPER,false,true)
		ui.label(host,info[1],Rect2(x+143,y+52,346,54),15,UI.MUTE,false,false,true)
		if unlocked and choosing:
			var selected := draft_relic==i
			var equip := ui.button(host,"已选携带" if selected else "携带%s" % info[0],Rect2(x+144,y+117,348,42),func():
				draft_relic=i
				open_scene("expedition",true),UI.OCHRE,not selected,10,not selected)
			equip.tooltip_text=info[1]
		else:
			ui.label(host,"已收录" if unlocked else "首通%s的遗灯之门后解锁" % State.MAPS[i][1],Rect2(x+144,y+117,348,42),15,UI.GOLD)
	if choosing:
		ui.button(host,"本趟不携带",Rect2(26,559,367,49),func():
			draft_relic=-1
			draft_imprint=-1
			open_scene("expedition",true),UI.JADE)
		ui.button(host,"返回远征整备",Rect2(712,559,368,49),func():open_scene("expedition",true),UI.JADE)
	else:
		ui.button(host,"前往远征整备",Rect2(26,559,367,49),open_expedition,UI.OCHRE,true)
		ui.button(host,"返回远征战报",Rect2(712,559,368,49),func():open_scene("expedition_result",true),UI.JADE)
	var imprint_button := ui.button(host,"铭印台",Rect2(406,559,294,49),func():open_imprints("relics"),UI.GOLD,false,10,game.has_relic())
	imprint_button.tooltip_text="用战利品领悟铭印。" if game.has_relic() else "首次取得遗宝后开放。"

func open_imprints(from: String) -> void:
	imprint_return=from
	open_scene("imprints")

func imprints_window() -> void:
	var choosing := imprint_return=="relics" and relic_return=="expedition"
	var host := window("遗宝铭印","持有 %d 灵石 · %d 灯砂    每趟远征可在一件遗宝上装配一种铭印。" % [game.data.stones,game.data.dust],"spark",Vector2(979,604))
	for i in Expedition.IMPRINTS.size():
		var mark: Dictionary = Expedition.IMPRINTS[i]
		var accent := UI.OCHRE if i==Expedition.Imprint.COUNTER else UI.JADE
		var learned: bool = game.imprint_learned(i)
		var selected := choosing and draft_imprint==i
		var x := 27+i*471
		ui.framed(host,Rect2(x,124,454,365))
		ui.box(host,Rect2(x+20,143,414,104),UI.WELL,accent,10)
		ui.emblem(host,mark.art,mark.icon,Rect2(x+34,152,88,85),accent)
		ui.label(host,mark.name,Rect2(x+145,151,278,41),24,UI.PAPER,false,true)
		ui.label(host,mark.timing,Rect2(x+145,193,278,33),15,accent)
		ui.label(host,mark.hint,Rect2(x+31,267,391,62),16,UI.PAPER,false,false,true)
		if learned:
			ui.label(host,"已领悟",Rect2(x+31,335,391,42),16,accent,true)
		else:
			ui.button(host,"领悟"+mark.name,Rect2(x+26,336,402,48),func():
				if game.learn_imprint(i):
					open_scene("imprints",true),accent,true,10,game.can_learn_imprint(i))
			ui.label(host,"%d 灵石 · %d 灯砂" % [Expedition.IMPRINT_STONES,Expedition.IMPRINT_DUST],Rect2(x+26,387,402,34),15,UI.MUTE,true)
		if choosing and learned:
			ui.button(host,"已装配" if selected else "装配"+mark.name,Rect2(x+26,416,402,47),func():
				draft_imprint=i
				open_scene("imprints",true),accent,not selected,10,draft_relic>=0 and not selected)
	if choosing and draft_relic<0:
		ui.label(host,"先在镇门遗宝选择一件遗宝。",Rect2(30,515,477,48),15,UI.MUTE)
	elif choosing and draft_imprint>=0:
		ui.button(host,"卸下当前铭印",Rect2(27,515,327,48),func():
			draft_imprint=-1
			open_scene("imprints",true),UI.JADE)
	elif not choosing:
		ui.button(host,"前往远征整备",Rect2(27,515,327,48),open_expedition,UI.OCHRE)
	var returning := "返回镇门遗宝" if imprint_return=="relics" else "返回远征战报"
	ui.button(host,returning,Rect2(617,515,337,48),func():open_scene(imprint_return,true),UI.JADE)

func expedition_plan_window() -> void:
	var forecast: Dictionary = game.expedition_forecast(draft_scout)
	var host := window(forecast.name,"启程前可查看全部路段，并从两份委托中接取一份。","compass",Vector2(1120,704))
	var board := Control.new()
	board.clip_contents=true
	board.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.place(board,host,Rect2(26,121,1068,225))
	ui.picture(board,expedition_art(),Rect2(0,0,1068,225),Color(.58,.68,.60),true)
	ui.box(board,Rect2(0,0,1068,225),Color(.06,.17,.13,.65),UI.BORDER,6)
	for index in forecast.steps.size():
		var x: int = 14+index*210
		ui.label(board,"%d  %s" % [index+1,Expedition.KINDS[index]],Rect2(x,16,197,33),17,UI.GOLD,true,true)
		for lane in forecast.steps[index].size():
			var id: String = forecast.steps[index][lane]
			var node: Array = Expedition.OPTIONS[id]
			var y: int = 59+lane*53
			var edge := UI.OCHRE if id=="seal" else (UI.JADE if id=="survey" else UI.BORDER)
			var tile := ui.box(board,Rect2(x,y,197,48),UI.WELL,edge,7)
			tile.mouse_filter=Control.MOUSE_FILTER_PASS
			tile.tooltip_text=seal_brief(draft_tier) if id=="seal" else node[2]
			ui.mark(board,node[3],Rect2(x+11,y+14,24,24),UI.OCHRE if id=="seal" else UI.JADE)
			ui.label(board,node[0],Rect2(x+46,y,141,48),16,UI.PAPER)
	ui.label(host,"随行委托",Rect2(27,357,1066,36),19,UI.GOLD,false,true)
	for index in forecast.offers.size():
		var key: String = forecast.offers[index]
		var offer: Array = Expedition.COMMISSIONS[key]
		var x: int = 26+index*540
		var chosen := key==draft_commission
		ui.framed(host,Rect2(x,401,527,179))
		ui.label(host,offer[0],Rect2(x+27,414,473,36),20,UI.PAPER,false,true)
		ui.label(host,Expedition.commission_brief(key,forecast.steps),Rect2(x+27,452,473,48),15,UI.MUTE,false,false,true)
		ui.label(host,"赏  %d 灵石 / %d 灯砂" % [offer[2],offer[3]],Rect2(x+27,518,235,43),16,UI.GOLD)
		var accept := ui.button(host,"已接取" if chosen else "接取委托",Rect2(x+279,516,231,45),func():
			draft_commission=key
			open_scene("expedition",true),UI.OCHRE,true)
		accept.tooltip_text=offer[0]
	ui.button(host,"不接委托",Rect2(26,608,299,53),func(): draft_commission="";open_scene("expedition",true),UI.JADE)
	ui.button(host,"返回远征整备",Rect2(761,608,332,53),func(): open_scene("expedition",true),UI.JADE)

func prep_selector(host: Node,index: int,title: String,value: String,description: String,change: Callable,adjustable: bool) -> void:
	var y := 126+index*101
	ui.box(host,Rect2(530,y,546,88),UI.WELL,UI.BORDER,10)
	ui.label(host,title,Rect2(544,y+13,133,26),15,UI.GOLD,false,true)
	ui.label(host,value,Rect2(674,y+8,258,34),20,UI.PAPER,false,true)
	ui.label(host,description,Rect2(544,y+48,509,28),14,UI.MUTE)
	ui.button(host,"‹",Rect2(952,y+8,52,38),func(): change.call(-1),UI.JADE,false,9,adjustable)
	ui.button(host,"›",Rect2(1010,y+8,52,38),func(): change.call(1),UI.JADE,false,9,adjustable)

func expedition_art() -> Texture2D:
	var path := "res://assets/lantern-depths.webp"
	return load(path) if ResourceLoader.exists(path) else atlas.maps[game.data.map]

func seal_brief(tier: int) -> String:
	return "花费战利品中的 %d 灯砂挑战封灯獒。取胜后守关战伤害 +%d，击破灯门可领取封存的 %d 灯砂。" % [Expedition.SEAL_ENTRY,Expedition.SEAL_BOOST,Expedition.seal_reward(tier)]

func route_points(board: Node,point_a: Vector2,point_b: Vector2,tint: Color,emphasis: bool) -> void:
	var road := Line2D.new()
	var joint := (point_a.x+point_b.x)*.5
	road.points=PackedVector2Array([point_a,Vector2(joint,point_a.y),Vector2(joint,point_b.y),point_b])
	road.width=3.1 if emphasis else 1.3
	road.default_color=tint
	road.antialiased=true
	road.joint_mode=Line2D.LINE_JOINT_ROUND
	board.add_child(road)

func expedition_route() -> void:
	var route: Dictionary = game.data.expedition
	var subtitle := "%s · %s · %s" % [State.MAPS[route.area][1],"险途" if route.tier else "初探",game.hero_name()]
	var imprint: int = route.get("imprint",-1)
	if imprint>=0:
		subtitle+=" · "+Expedition.IMPRINTS[imprint].name
	var host := window(route.get("route_name","遗灯秘境"),subtitle,"compass",Vector2(1160,755))
	var options: Array = game.expedition_choices()
	if route_choice not in options:
		route_choice=""
		for id in options:
			if game.expedition_can_take(id):
				route_choice=id
				break
	var pending: bool = not route.combat.is_empty()
	var veil := Control.new()
	veil.clip_contents=true
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.place(veil,host,Rect2(25,122,1110,373))
	ui.picture(veil,expedition_art(),Rect2(0,0,1110,373),Color(.53,.70,.65),true)
	ui.box(veil,Rect2(0,0,1110,373),Color(.04,.16,.12,.61),UI.BORDER,3)
	var locations: Dictionary = {}
	var ordered: Array = []
	for depth in Expedition.DEPTH:
		var slots: Array = Expedition.run_step(route,depth)
		ordered.append(slots)
		var x := 102+depth*224
		for rank in slots.size():
			var y := 163.0 if slots.size()==1 else (95.0+rank*89.0 if slots.size()==3 else 112.0+rank*143.0)
			var point := Vector2(x,y)
			locations[slots[rank]]=point
		ui.label(veil,"%d  %s" % [depth+1,Expedition.KINDS[depth]],Rect2(x-89,20,178,32),17,UI.GOLD if depth==route.step else UI.MUTE,true,true)
	for depth in Expedition.DEPTH-1:
		for left in ordered[depth]:
			for right in ordered[depth+1]:
				var known: bool = depth+1<route.history.size() and left==route.history[depth] and right==route.history[depth+1]
				var current: bool = depth+1==route.step and depth<route.history.size() and left==route.history[depth] and right==route_choice
				route_points(veil,locations[left]+Vector2(81,0),locations[right]-Vector2(81,0),UI.GOLD if known else (UI.JADE if current else Color("#588474")),known or current)
	for depth in ordered.size():
		for id: String in ordered[depth]:
			var scene: Array = Expedition.OPTIONS[id]
			var here: Vector2 = locations[id]
			var active: bool = depth==route.step and not pending
			var visited: bool = depth<route.history.size() and route.history[depth]==id
			var chosen: bool = route_choice==id and active
			var label_color := UI.INK if chosen else (UI.JADE if visited else UI.PAPER)
			var accent := UI.OCHRE if id=="seal" else UI.JADE
			var coin := ui.button(veil,"",Rect2(here-Vector2(81,39),Vector2(162,78)),func(): route_choice=id;open_scene("expedition",true),accent,chosen,12,active)
			coin.tooltip_text=scene[2]
			ui.mark(coin,"check" if visited and not active else scene[3],Rect2(66,8,30,28),UI.INK if chosen else UI.GOLD)
			ui.label(coin,scene[0],Rect2(6,36,150,30),15,label_color,true,true)
	ui.label(host,"气血 %d / %d    灵草 %d" % [route.hp,route.maxhp,route.herbs],Rect2(27,506,459,35),18,UI.JADE)
	var remedy: int = route.get("remedy",-1)
	if remedy>=0:
		var status := "已用" if route.get("remedy_used",false) else "可用"
		ui.label(host,"%s · %s" % [Expedition.REMEDIES[remedy].name,status],Rect2(295,506,215,35),16,UI.GOLD,true)
	if int(route.get("spirit_index",-1))>=0:
		ui.label(host,"灵契  %d / 1" % route.spirit_charges,Rect2(501,506,183,35),16,UI.JADE,true)
	ui.label(host,"战利品  %d 灵石 · %d 灯砂" % [route.coins,route.dust],Rect2(686,506,443,35),18,UI.GOLD,true)
	ui.line(host,Vector2(27,550),Vector2(1131,550))
	var selected: Array = Expedition.OPTIONS.get(route_choice,[])
	var detail := "战斗进度已存档，可以接着打。"
	if not pending and not selected.is_empty():
		detail=seal_brief(route.tier) if route_choice=="seal" else "%s · %s" % [selected[1],selected[2]]
		if not game.expedition_can_take(route_choice):
			detail += "  " + game.expedition_block_reason(route_choice)
	ui.label(host,detail,Rect2(28,554,1094,44),17,UI.PAPER,false,false,true)
	var commission_id: String = route.get("commission","")
	var sealed: int = route.get("sealed_dust",0)
	if not commission_id.is_empty():
		var offer: Array = Expedition.COMMISSIONS[commission_id]
		ui.label(host,"委托 %s  ·  %s" % [offer[0],game.expedition_commission_progress(route)],Rect2(29,601,688,30),15,UI.GOLD)
	if sealed>0:
		ui.label(host,"封存 %d 灯砂 · 破关领取" % sealed,Rect2(777,601,355,30),15,UI.OCHRE,true)
	ui.button(host,"带上战利品撤回",Rect2(27,643,316,52),func(): open_scene("extraction"),UI.JADE,false,10,route.step>0 and not pending)
	if pending:
		ui.button(host,"继续战斗",Rect2(790,643,344,52),func():
			if game.resume_expedition_battle():
				open_scene("battle"),UI.OCHRE,true)
	elif not selected.is_empty():
		var option := route_choice
		ui.button(host,"踏入%s" % selected[0],Rect2(790,643,344,52),func():
			if game.expedition_take(option):
				route_choice=""
				if game.battle.is_empty():
					open_scene("expedition",true)
				else:
					open_scene("battle"),UI.OCHRE,true,10,game.expedition_can_take(option))

func extraction_window() -> void:
	var host := window("撤回宗门","立刻结算已经获得的战利品。","compass",Vector2(630,302))
	var run: Dictionary = game.data.expedition
	if run.is_empty():
		return
	var fulfilled: bool = game.expedition_commission_met(run,"撤回")
	var offer: Array = Expedition.COMMISSIONS[run.commission] if fulfilled else []
	var bonus_coins: int = offer[2] if fulfilled else 0
	var bonus_dust: int = offer[3] if fulfilled else 0
	ui.label(host,"本次可带回 %d 灵石和 %d 灯砂。" % [run.coins+bonus_coins,run.dust+bonus_dust],Rect2(31,121,568,35),18,UI.PAPER,true)
	var details: Array[String] = []
	if not String(run.get("commission","")).is_empty():
		details.append("已包含委托赏金" if fulfilled else "本轮委托结束")
	var sealed: int = run.get("sealed_dust",0)
	if sealed>0:
		details.append("放弃封存的 %d 灯砂" % sealed)
	if not details.is_empty():
		ui.label(host,"    ·    ".join(details),Rect2(30,157,570,28),14,UI.GOLD,true)
	ui.button(host,"继续深入",Rect2(28,191,278,53),func():open_scene("expedition"),UI.JADE)
	ui.button(host,"确认撤回",Rect2(320,191,281,53),func():
		if game.extract_expedition():
			open_scene("expedition_result"),UI.OCHRE,true)

func expedition_result_window() -> void:
	var result: Dictionary = game.data.expedition_last
	if result.is_empty():
		return
	var host := window("远征"+result.result,State.MAPS[result.area][1]+" · 战利品已送回宗门","spark",Vector2(815,556))
	for i in 4:
		var display: Array = [["灵石",result.coins,"gem"],["灯砂",result.dust,"flame"],["灵草",result.herbs,"sprout"],["修为",result.qi,"spark"]][i]
		var x := 28+i*190
		ui.framed(host,Rect2(x,151,176,176))
		ui.mark(host,display[2],Rect2(x+57,168,62,60),UI.GOLD)
		ui.label(host,str(display[1]),Rect2(x+7,232,162,49),30,UI.PAPER,true)
		ui.label(host,display[0],Rect2(x+7,281,162,30),17,UI.MUTE,true,true)
	var commission_id: String = result.get("commission","")
	if not commission_id.is_empty():
		var caption: String = Expedition.COMMISSIONS[commission_id][0]
		var state_text := "已结算赏金 %d 灵石 / %d 灯砂" % [result.bonus_coins,result.bonus_dust] if result.commission_done else "未达委托条件"
		ui.label(host,"%s  ·  %s" % [caption,state_text],Rect2(28,337,751,37),16,UI.GOLD,true)
	var relic: int = result.get("relic_unlocked",-1)
	if relic>=0:
		ui.label(host,"首通遗宝  ·  %s 已收录" % Expedition.RELICS[relic][0],Rect2(28,375,751,42),18,UI.GOLD,true,true)
		ui.button(host,"宗门营造",Rect2(28,432,238,49),func():open_scene("facilities"),UI.JADE)
		ui.button(host,"查看遗宝",Rect2(284,432,238,49),func():
			relic_return="expedition_result"
			open_scene("relics"),UI.OCHRE,true)
		ui.button(host,"返回山门",Rect2(540,432,239,49),close_scene,UI.JADE)
	elif game.has_relic():
		ui.button(host,"宗门营造",Rect2(28,432,238,49),func():open_scene("facilities"),UI.OCHRE,true)
		ui.button(host,"铭印台",Rect2(284,432,238,49),func():open_imprints("expedition_result"),UI.GOLD)
		ui.button(host,"返回山门",Rect2(540,432,239,49),close_scene,UI.JADE)
	else:
		ui.button(host,"宗门营造",Rect2(28,402,365,54),func():open_scene("facilities"),UI.OCHRE,true)
		ui.button(host,"返回山门",Rect2(407,402,372,54),close_scene,UI.JADE)
	var returned: int = result.get("remedy_returned",-1)
	var details: Array[String] = []
	if returned>=0:
		details.append(Expedition.REMEDIES[returned].name+"已退回")
	var sealed: int = result.get("sealed_dust",0)
	if sealed>0:
		details.append("封灯奖励 +%d 灯砂" % result.sealed_paid if result.sealed_paid>0 else "已放弃封存的 %d 灯砂" % sealed)
	var restored: int = result.get("imprint_healed",0)
	if restored>0:
		details.append("回息铭共恢复 %d 气血" % restored)
	if not details.is_empty():
		ui.label(host,"    ·    ".join(details),Rect2(28,486,751,44),16,UI.JADE,true)

func facilities_window() -> void:
	var host := window("宗门营造","当前持有 %d 灵石 · %d 灯砂" % [game.data.stones,game.data.dust],"hall",Vector2(915,620))
	for i in Expedition.BUILDINGS.size():
		var item: Array = Expedition.BUILDINGS[i]
		var grade: int = game.data.facilities[item[0]]
		var cost: Array = game.facility_cost(item[0])
		var y := 128+i*132
		ui.framed(host,Rect2(27,y,860,110))
		ui.emblem(host,item[3],item[4],Rect2(53,y+17,70,70))
		ui.label(host,"%s · %d / 3 级" % [item[1],grade],Rect2(142,y+12,431,40),22,UI.PAPER,false,true)
		ui.label(host,item[2],Rect2(143,y+59,469,37),16,UI.MUTE)
		var label := "升阶 · %d 灵石 / %d 灯砂" % cost if grade<3 else "已升满"
		ui.button(host,label,Rect2(612,y+27,252,53),func():
			if game.upgrade_facility(item[0]):
				open_scene("facilities",true),UI.OCHRE,true,10,grade<3 and game.data.stones>=cost[0] and game.data.dust>=cost[1])
	ui.label(host,"营造加成在下次启程时生效。" if game.duty_member("works",true)<0 else "营造弟子在岗，本次所需灵石已减免 12。",Rect2(29,536,839,44),15,UI.MUTE,true)

func combat_arc(arena: Node,spell: bool) -> void:
	var cut := Line2D.new()
	cut.points = PackedVector2Array([Vector2(399,292),Vector2(512,258),Vector2(615,207),Vector2(743,167)])
	cut.joint_mode = Line2D.LINE_JOINT_ROUND
	cut.width = 8 if spell else 3
	cut.default_color = Color("#f7d387") if spell else Color("#c9f3e5")
	cut.antialiased = true
	arena.add_child(cut)
	cut.scale = Vector2(.87,.93)
	var animate := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD)
	animate.tween_property(cut,"modulate:a",0.0,.33)
	animate.tween_property(cut,"scale",Vector2.ONE,.33)

func damage_float(host: Node,value: String,point: Vector2,shade: Color) -> void:
	var mark := ui.label(host,value,Rect2(point,Vector2(110,52)),30,shade,true,true)
	if game.data.motion:
		create_tween().tween_property(mark,"position:y",point.y-38,.6).set_trans(Tween.TRANS_CUBIC)
		create_tween().tween_property(mark,"modulate:a",0.0,.84)

func combat(action: String) -> void:
	if not game.can_combat(action):
		return
	var sound := "sword" if action=="attack" else ("chime" if action=="spell" else "guard")
	sound_tick(sound)
	game.strike(action)
	open_scene("battle",true)

func open_practice() -> void:
	if not game.hero_unlocked(game.data.hero_style):
		open_hero_select("practice")
		return
	practice_boss=false
	open_scene("practice",true)

func action_window(practice: bool) -> void:
	var cap := 101 if practice_boss else 51
	var values: Dictionary = {
		"expedition_node":"boss" if practice_boss else "trail","tier":0,"result":0,
		"hp":92,"maxhp":92,"enemy":cap,"maxenemy":cap,"focus":0,"relic":-1
	} if practice else game.battle
	var arena := ActionDuel.new()
	duel=arena
	var run: Dictionary = game.data.expedition
	arena.setup(values,1 if practice else run.herbs,-1 if practice else run.get("spirit_index",-1),0 if practice else run.get("spirit_charges",0),game.data.motion,practice,game.data.hero_style,game.hero_name())
	ui.place(arena,modal,Rect2(Vector2.ZERO,VIEW))
	arena.sounded.connect(sound_tick)
	if not practice:
		arena.changed.connect(func():
			run.herbs=arena.herbs
			run.spirit_charges=arena.charges
			if values.result==0:
				arena.snapshot()
				game.store_expedition_battle()
			else:
				game.resolve_expedition_fight(values.result>0))
	arena.finished.connect(func(won: bool): action_result(practice,won))
	ui.button(modal,"退出试炼" if practice else "返回山门 · 已记录战况",Rect2(1121,28,224,44),close_scene,UI.JADE,false,11)
	if practice:
		ui.button(modal,"挑战古甲" if not practice_boss else "练习巡灯兽",Rect2(939,28,170,44),func():
			practice_boss=not practice_boss
			open_scene("practice",true),UI.GOLD,false,10)

func action_result(practice: bool,won: bool) -> void:
	var panel := ui.framed(modal,Rect2(456,293,528,228))
	ui.label(panel,"破阵成功" if won else "气血耗尽",Rect2(27,21,474,49),32,UI.PAPER,true,true)
	var message: String = "熟悉剑势后，可挑战沉潭古甲。" if not practice_boss else "等甲心外露，出手会更有效。"
	if practice and practice_boss and won and game.unlock_wukong():
		have_save=true
		message="齐天大圣已解锁，可在选择掌门中使用。"
	if not practice:
		message=game.battle.note
	ui.label(panel,message,Rect2(23,75,482,59),17,UI.MUTE,true,false,true)
	if practice:
		ui.button(panel,"挑战古甲" if won and not practice_boss else "再试一次",Rect2(38,147,218,49),func():
			practice_boss=practice_boss or won
			open_scene("practice",true),UI.OCHRE,true)
		ui.button(panel,"选择掌门" if practice_boss and won else "退出试炼",Rect2(273,147,218,49),func():
			if practice_boss and won:
				close_scene()
				open_hero_select("practice")
			else:
				close_scene(),UI.JADE)
	else:
		var completed: bool = game.data.expedition.is_empty()
		ui.button(panel,"查看远征结算" if completed else "继续远征",Rect2(38,147,453,49),func():
			close_scene()
			open_scene("expedition_result" if completed else "expedition",true),UI.OCHRE,true)

func settings_window() -> void:
	var host := window("设置","L 主线 · E 秘境 · J 宗门簿 · H 观景 · F11 全屏","cog",Vector2(686,554))
	var values := [
		["音乐", "music", "山谷背景曲"],["音效", "sound", "按键、出招与采收提示"],
		["画面动画", "motion", "瀑布、天气、场景过渡与战斗动作"]
	]
	for i in values.size():
		var row: Array = values[i]
		var y := 119+i*67
		ui.box(host,Rect2(26,y,633,57),UI.WELL,UI.BORDER,8)
		ui.label(host,row[0],Rect2(39,y+2,137,52),17,UI.PAPER,false,true)
		ui.label(host,row[2],Rect2(189,y+2,307,52),14,UI.MUTE)
		var kind: String = row[1]
		ui.button(host,"开启" if game.data[kind] else "关闭",Rect2(524,y+9,119,39),func(): flip_setting(kind),UI.JADE,game.data[kind],8)
	var fullscreen: bool = get_window().mode == Window.MODE_FULLSCREEN
	ui.button(host,"退出全屏" if fullscreen else "切换全屏",Rect2(26,341,302,45),func(): flip_fullscreen();open_scene("settings",true),UI.JADE)
	ui.button(host,"重新开宗",Rect2(341,341,318,45),func(): open_scene("reset"),UI.OCHRE)
	if not is_menu:
		ui.button(host,"返回标题画面",Rect2(26,401,302,45),show_title,UI.JADE)
		ui.button(host,"保存并退出",Rect2(341,401,318,45),func(): game.save_game();quit_game(),UI.GOLD)
	else:
		ui.button(host,"返回标题",Rect2(26,401,633,45),close_scene,UI.GOLD)
	ui.button(host,"选择掌门",Rect2(26,466,302,35),func(): open_hero_select("title" if is_menu else "master"),UI.JADE,false,8)
	ui.button(host,"开源许可",Rect2(341,466,318,35),func(): open_scene("credits"),UI.GOLD,false,8)

func credits_window() -> void:
	var host := window("开源许可","Godot Engine · MIT    Noto SC · SIL OFL","scroll",Vector2(760,600))
	var text := RichTextLabel.new()
	text.add_theme_font_override("normal_font",ui.sans)
	text.add_theme_font_size_override("normal_font_size",14)
	text.text = Engine.get_license_text() + "\n\n" + FileAccess.get_file_as_string("res://assets/NotoSans-OFL.txt") + "\n\n" + FileAccess.get_file_as_string("res://assets/NotoSerif-OFL.txt")
	ui.place(text,host,Rect2(27,124,707,428))

func reset_window() -> void:
	var host := window("重新开宗","此操作会覆盖本机的宗门进度。","mountain",Vector2(600,292))
	ui.button(host,"保留存档",Rect2(26,145,266,49),func(): open_scene("settings"),UI.JADE,true)
	ui.button(host,"确认重新开宗",Rect2(306,145,268,49),func(): close_scene();game.reset();have_save=false;begin_game(),UI.OCHRE)

func flip_setting(kind: String) -> void:
	game.data[kind] = not game.data[kind]
	if kind=="music":
		if game.data.music and music.stream:
			music.play()
		else:
			music.stop()
	game.save_game()
	refresh()
	open_scene("settings",true)

func flip_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and is_instance_valid(tray):
		var pointer := get_global_mouse_position()
		if event.button_index==MOUSE_BUTTON_LEFT and not tray_rect.has_point(pointer) and not DOCK.has_point(pointer):
			close_tray()
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		flip_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if is_instance_valid(modal):
			close_scene()
		elif is_instance_valid(tray):
			close_tray()
		elif scenic_mode:
			toggle_scenery()
		else:
			open_scene("settings")
		get_viewport().set_input_as_handled()
	elif scene_key=="battle" and not is_instance_valid(duel) and event.keycode>=KEY_1 and event.keycode<=KEY_5:
		combat(["attack","guard","spell","herb","spirit"][event.keycode-KEY_1])
		get_viewport().set_input_as_handled()
	elif scene_key=="battle" and (event.keycode==KEY_F or event.physical_keycode==KEY_F):
		if is_instance_valid(duel):
			duel.use_remedy()
		else:
			combat_remedy()
		get_viewport().set_input_as_handled()
	elif scene_key=="dialogue" and event.keycode==KEY_SPACE:
		next_dialogue()
		get_viewport().set_input_as_handled()
	elif not is_menu and not is_instance_valid(modal):
		if event.keycode == KEY_H:
			toggle_scenery()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			open_scene(ACTIONS[event.keycode-KEY_1][3])
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_J:
			open_scene("ledger")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L:
			open_story()
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_E:
			open_expedition()
			get_viewport().set_input_as_handled()
	elif is_menu and not is_instance_valid(modal) and event.keycode==KEY_ENTER:
		begin_game()
		get_viewport().set_input_as_handled()

func training_test() -> bool:
	for turn in 18:
		if game.battle.result!=0:
			break
		var stance: String = game.next_move()[2]
		var action := "spell" if game.can_combat("spell") and stance!="light" else ("guard" if stance in ["heavy","ward"] else "attack")
		game.strike(action)
	var won: bool = game.battle.result==1
	game.leave_battle()
	return won

func smoke_test() -> void:
	game.transient = true
	var ok: bool = not game.migrate(1) and game.plant(0,0) and not game.harvest(0) and game.recruit()
	game.record("测试","休整")
	ok = ok and game.harvest(0) and game.tame() and game.start_battle()
	if ok:
		ok = training_test()
	game.treasure()
	for chapter in Chronicle.CHAPTERS.size():
		if chapter>0:
			for day in 16:
				game.treasure()
			ok = ok and game.breakthrough() and game.migrate(chapter)
		game.read_chapter(chapter)
		if ok:
			ok = game.start_battle(chapter) and training_test() and game.data.story_chapter==chapter+1
	ok = ok and game.finish_story(1) and not game.finish_story(0)
	for day in 16:
		game.treasure()
	ok = ok and game.breakthrough()
	ok = ok and game.quest_count()==8 and game.claim(7) and not game.claim(7)
	print("CAMPAIGN_SMOKE_", "PASS" if ok else "FAIL")
	var expeditions := smoke_expedition()
	print("EXPEDITION_SMOKE_", "PASS" if expeditions else "FAIL")
	var tactics := smoke_tactics()
	print("TACTICS_SMOKE_", "PASS" if tactics else "FAIL")
	var relics := smoke_relics()
	print("RELICS_SMOKE_", "PASS" if relics else "FAIL")
	var duties := smoke_duties()
	print("DUTIES_SMOKE_", "PASS" if duties else "FAIL")
	var action := smoke_action()
	print("ACTION_DUEL_SMOKE_", "PASS" if action else "FAIL")
	var heroes := smoke_hero_selection()
	print("HERO_SELECTION_SMOKE_", "PASS" if heroes else "FAIL")
	var remedies := smoke_remedies()
	print("REMEDY_SMOKE_", "PASS" if remedies else "FAIL")
	var seal := smoke_seal_trial(0,"破关") and smoke_seal_trial(1,"撤回") and smoke_seal_trial(0,"败退")
	print("SEAL_TRIAL_SMOKE_", "PASS" if seal else "FAIL")
	var imprints := smoke_imprints() and smoke_action_imprint()
	print("IMPRINT_SMOKE_", "PASS" if imprints else "FAIL")
	music.free()
	sfx.free()
	get_tree().quit(0 if ok and expeditions and tactics and relics and duties and action and heroes and remedies and seal and imprints else 1)

func smoke_imprints() -> bool:
	game=State.new()
	game.transient=true
	game.data.dust=2*Expedition.IMPRINT_DUST
	var counter := Expedition.Imprint.COUNTER
	var recovery := Expedition.Imprint.RECOVERY
	if game.learn_imprint(counter):
		return false
	game.data.expedition_wins[0]=1
	if game.start_expedition(-1,-1,0,0,"",0,false,false,-1,counter):
		return false
	if not game.learn_imprint(counter) or game.learn_imprint(counter) or not game.learn_imprint(recovery):
		return false
	if game.data.dust!=0 or game.data.stones!=110-2*Expedition.IMPRINT_STONES or game.start_expedition(-1,-1,0,0,"",-1,false,false,-1,counter):
		return false
	if not game.start_expedition(-1,-1,0,0,"",0,false,false,-1,counter) or not game.expedition_take("trail"):
		return false
	game.battle.enemy=150
	game.battle.focus=3
	game.strike("spell")
	if game.battle.focus!=0 or game.battle.imprint_spent:
		return false
	game.battle.focus=3
	game.strike("spell")
	if game.battle.focus!=1 or not game.battle.imprint_spent:
		return false
	game.leave_battle()
	if not game.resume_expedition_battle() or not game.battle.imprint_spent:
		return false
	game.battle.focus=3
	game.strike("spell")
	if game.battle.focus!=0:
		return false
	game.battle.enemy=1
	game.strike("attack")
	game.leave_battle()
	if not game.extract_expedition() or not game.start_expedition(-1,-1,0,0,"",0,false,false,-1,recovery):
		return false
	if not game.expedition_take("reeds") or not game.expedition_take("tower") or not game.expedition_take("elite"):
		return false
	game.battle.enemy=1
	game.strike("attack")
	if game.battle.hp!=game.battle.maxhp or game.data.expedition.imprint_healed!=9:
		return false
	game.leave_battle()
	if not game.expedition_take("camp") or not game.expedition_take("boss"):
		return false
	game.battle.hp=10
	game.battle.enemy=1
	game.strike("attack")
	return game.battle.hp==10 and game.data.expedition_last.imprint_healed==9 and game.data.expedition_imprint_preset==recovery

func smoke_action_imprint() -> bool:
	var arena := ActionDuel.new()
	var stats := {"expedition_node":"trail","tier":0,"result":0,"hp":83,"maxhp":83,"enemy":100,"maxenemy":100,"focus":3,"relic":-1,"imprint":Expedition.Imprint.COUNTER}
	arena.setup(stats,0,-1,0,false,false)
	arena.player.x=arena.enemy.x-255
	arena.move="rush"
	arena.set_phase("tell",.75)
	arena.burst()
	var refunded: bool = stats.focus==1 and stats.get("imprint_spent",false) and arena.phase=="open"
	arena.free()
	return refunded

func smoke_seal_trial(tier: int,settlement: String) -> bool:
	game=State.new()
	game.transient=true
	game.data.dust=11
	game.data.expedition_wins[0]=tier
	if not game.start_expedition(-1,-1,0,tier) or not game.expedition_take("pool") or not game.expedition_take("rest") or not game.expedition_take("bridge"):
		return false
	var run: Dictionary = game.data.expedition
	run.dust=1
	if "seal" not in game.expedition_choices() or game.expedition_take("seal") or run.history.size()!=3:
		return false
	run.dust=2
	if not game.expedition_take("seal") or game.battle.expedition_node!="seal":
		return false
	if run.dust!=0 or game.data.dust!=11 or game.expedition_take("seal") or game.extract_expedition():
		return false
	game.leave_battle()
	if not game.resume_expedition_battle() or game.next_move()[2]!="heavy" or run.dust!=0:
		return false
	if settlement=="败退":
		game.battle.hp=1
		game.strike("attack")
		return game.data.expedition_last.result==settlement and game.data.expedition_last.sealed_paid==0 and game.data.dust==11
	if not training_test():
		return false
	var sealed := Expedition.seal_reward(tier)
	if run.step!=4 or run.sealed_dust!=sealed or run.boost!=Expedition.SEAL_BOOST or run.dust!=0:
		return false
	if settlement=="撤回":
		return game.extract_expedition() and game.data.expedition_last.sealed_dust==sealed and game.data.expedition_last.sealed_paid==0 and game.data.dust==11
	if not game.expedition_take("boss") or game.battle.slash!=Expedition.SEAL_BOOST or game.battle.spell!=Expedition.SEAL_BOOST or not training_test():
		return false
	var wallet: int = 11+Expedition.ENCOUNTERS.boss[3]+sealed
	if game.data.expedition_last.sealed_paid!=sealed or game.data.dust!=wallet:
		return false
	var cost: Array = game.facility_cost("observatory")
	if not game.upgrade_facility("observatory") or game.data.dust!=wallet-cost[1]:
		return false
	return game.start_expedition(-1,-1,0,0) and game.expedition_take("trail") and game.battle.focus==1

func smoke_remedies() -> bool:
	game=State.new()
	game.transient=true
	var heal := Expedition.Remedy.HEAL
	var ward := Expedition.Remedy.WARD
	if game.brew_remedy(heal) or game.start_expedition(-1,-1,0,0,"",-1,false,false,heal):
		return false
	game.data.herbs=7
	var day: int = game.data.day
	if not game.brew_remedy(heal) or not game.brew_remedy(ward):
		return false
	if game.data.stones!=84 or game.data.herbs!=2 or game.data.day!=day:
		return false
	if not game.start_expedition(-1,-1,0,0,"",-1,false,false,heal) or game.data.remedies[heal]!=0 or not game.expedition_take("pool") or not game.extract_expedition():
		return false
	if game.data.remedies[heal]!=1 or game.data.expedition_last.remedy_returned!=heal:
		return false
	game.data.map=1
	if not game.start_expedition(-1,-1,1,0,"",-1,false,false,ward):
		return false
	game.start_expedition_battle("boss")
	game.battle.enemy=int(game.battle.maxenemy/2.0)
	if not game.use_turn_remedy() or game.battle.turn!=1 or game.use_turn_remedy():
		return false
	game.leave_battle()
	if not game.resume_expedition_battle() or not game.data.expedition.remedy_used:
		return false
	game.strike("attack")
	if game.battle.taken!=21 or game.data.expedition.herbs!=1 or game.battle.get("remedy_ward",0)!=0:
		return false
	game.battle.hp=1
	game.strike("attack")
	game.leave_battle()
	if game.data.expedition_last.result!="败退" or game.data.remedies[ward]!=0:
		return false
	if not game.start_expedition(-1,-1,0,0,"",-1,false,false,heal):
		return false
	game.start_expedition_battle("trail")
	if game.use_turn_remedy():
		return false
	game.battle.hp-=8
	if not game.use_turn_remedy() or game.battle.healed!=8 or game.battle.turn!=1:
		return false
	var arena := ActionDuel.new()
	var values := {"expedition_node":"trail","tier":0,"result":0,"hp":90,"maxhp":90,"enemy":51,"maxenemy":51,"focus":1,"relic":-1,"remedy":ward,"remedy_used":false}
	arena.setup(values,0,-1,0,false,false)
	arena.use_remedy()
	arena.dash=.1
	var dodged: bool = not arena.damage_player(23) and values.remedy_ward==16
	arena.dash=0
	var guarded: bool = arena.damage_player(23) and values.hp==83 and values.get("remedy_ward",0)==0
	arena.free()
	return dodged and guarded

func smoke_expedition() -> bool:
	game=State.new()
	game.transient=true
	game.data.herbs=5
	var ok: bool = game.recruit() and game.recruit() and game.tame()
	ok=ok and not game.start_expedition(1,0,3,0,"trace") and game.start_expedition(1,0,3,0,"herbs") and game.data.expedition.maxhp==113
	ok=ok and game.expedition_take("trail")
	if not ok:
		return false
	game.strike("attack")
	var health: int = game.battle.hp
	game.leave_battle()
	if not game.resume_expedition_battle() or game.battle.hp!=health or game.battle.turn!=2 or not training_test():
		return false
	if not game.expedition_take("relay") or not game.expedition_take("bridge") or not game.expedition_take("camp") or not game.expedition_take("boss"):
		return false
	if not training_test() or game.data.expedition_last.result!="破关" or game.data.expedition_wins[0]!=1 or not game.data.expedition_last.commission_done or game.data.expedition_commissions!=1 or game.data.expedition_last.relic_unlocked!=0:
		return false
	if not game.upgrade_facility("sword_hall") or not game.start_expedition(0,-1,0,1,"trace") or game.data.expedition.slash!=9:
		return false
	if game.expedition_take("pool") or not game.expedition_take("reeds") or game.expedition_can_take("caravan") or not game.expedition_take("tower") or not game.expedition_take("tunnel") or not game.expedition_take("beacon") or not game.extract_expedition():
		return false
	if game.data.expedition_last.result!="撤回" or game.data.expedition_last.dust!=6 or game.data.expedition_last.coins!=37 or not game.data.expedition_last.commission_done or game.extract_expedition():
		return false
	if not game.start_expedition(-1,-1,0,0,"safe") or not game.expedition_take("pool") or not game.expedition_take("rest") or not game.expedition_take("elite"):
		return false
	game.battle.hp=1
	game.strike("attack")
	var lost: bool = game.battle.result==-1 and game.data.expedition_last.result=="败退" and game.data.expedition_last.coins==4 and game.data.expedition_last.dust==0 and not game.data.expedition_last.commission_done
	game.leave_battle()
	if not lost or not game.start_expedition(-1,-1,0,0) or not game.expedition_take("reeds") or not game.expedition_take("ambush"):
		return false
	if game.next_move()[2]!="heavy" or not training_test() or game.data.expedition.herbs!=3 or not game.extract_expedition():
		return false
	game.data.expedition_serial=1
	if not game.start_expedition(-1,-1,0,0,"safe") or not game.expedition_take("reeds") or not game.expedition_take("tower") or not game.expedition_take("tunnel"):
		return false
	return game.extract_expedition() and game.data.expedition_last.commission_done and game.data.expedition_last.bonus_dust==2

func setup_tactics_test(area: int,spirit: int,node := "boss") -> bool:
	game=State.new()
	game.transient=true
	game.data.map=area
	game.data.rank=area
	game.data.herbs=3
	game.data.pets=State.PETS.duplicate()
	if not game.start_expedition(-1,spirit,3,0):
		return false
	game.start_expedition_battle(node)
	if node=="boss":
		game.battle.enemy=int(game.battle.maxenemy/2.0)
		return game.boss_signature_queued()
	return not game.boss_signature_queued()

func smoke_tactics() -> bool:
	if not setup_tactics_test(0,0):
		return false
	var hp: int = game.battle.hp
	var foe: int = game.battle.enemy
	game.strike("spirit")
	if game.battle.hp!=hp or game.battle.enemy!=foe or game.can_combat("spirit"):
		return false
	game.leave_battle()
	if not game.resume_expedition_battle() or game.boss_signature_queued() or game.can_combat("spirit"):
		return false
	if not setup_tactics_test(0,-1):
		return false
	foe=game.battle.enemy
	game.strike("guard")
	if game.battle.enemy!=foe+16 or not game.battle.signature_used:
		return false
	if not setup_tactics_test(1,1):
		return false
	game.strike("spirit")
	if not game.battle.interrupt or game.battle.hit!=26 or game.expedition_herbs()!=3:
		return false
	if not setup_tactics_test(1,-1):
		return false
	game.strike("attack")
	if game.expedition_herbs()!=2:
		return false
	if not setup_tactics_test(2,-1):
		return false
	game.battle.focus=1
	game.strike("guard")
	if game.battle.focus!=1:
		return false
	if not setup_tactics_test(2,2,"trail"):
		return false
	game.strike("spirit")
	if game.battle.focus!=3 or game.battle.taken!=6:
		return false
	if not setup_tactics_test(3,3):
		return false
	game.strike("attack")
	if game.battle.frost!=12 or game.hit_preview()!=18:
		return false
	game.strike("spirit")
	if game.battle.healed!=22 or game.battle.taken!=28 or game.battle.frost!=0:
		return false
	if not setup_tactics_test(3,0):
		return false
	game.leave_battle()
	for key in ["spirit_index","spirit_charges","boss_tactics"]:
		game.data.expedition.erase(key)
	for key in ["boss_tactics","signature_used"]:
		game.data.expedition.combat.erase(key)
	return game.resume_expedition_battle() and not game.boss_signature_queued() and not game.can_combat("spirit")

func equip_relic_test(relic: int) -> bool:
	game=State.new()
	game.transient=true
	game.data.herbs=3
	game.data.expedition_wins[relic]=1
	return game.start_expedition(-1,-1,2,0,"",relic)

func smoke_relics() -> bool:
	game=State.new()
	game.transient=true
	game.data.herbs=2
	if game.start_expedition(-1,-1,1,0,"",0) or game.data.expedition_serial!=0 or game.data.herbs!=2:
		return false
	if not equip_relic_test(Expedition.Relic.TIDE):
		return false
	game.start_expedition_battle("boss")
	game.battle.turn=2
	game.strike("guard")
	if game.battle.relic_spent:
		return false
	game.battle.turn=2
	game.strike("attack")
	if game.battle.taken!=19 or not game.battle.relic_spent:
		return false
	game.leave_battle()
	if not game.resume_expedition_battle() or not game.battle.relic_spent:
		return false
	game.battle.turn=2
	game.strike("attack")
	if game.battle.taken!=33:
		return false
	if not equip_relic_test(Expedition.Relic.FLAME):
		return false
	game.start_expedition_battle("boss")
	game.battle.turn=2
	game.battle.focus=3
	if game.spell_damage()!=46:
		return false
	game.strike("spell")
	if game.battle.hit!=46 or not game.battle.interrupt or not game.battle.relic_spent or game.spell_damage()!=34:
		return false
	game.finish_expedition("撤回")
	if game.data.expedition_last.relic_unlocked!=-1 or game.relic_unlocked(0):
		return false
	if not equip_relic_test(Expedition.Relic.MIRROR):
		return false
	game.start_expedition_battle("boss")
	game.battle.hp=45
	game.strike("herb")
	if game.battle.focus!=2 or game.battle.healed!=31 or game.expedition_herbs()!=1:
		return false
	if not equip_relic_test(Expedition.Relic.FROST):
		return false
	game.data.expedition.hp=40
	game.start_expedition_battle("trail")
	if game.battle.hp!=58 or game.data.expedition.hp!=58:
		return false
	game.leave_battle()
	return game.resume_expedition_battle() and game.battle.hp==58 and game.data.expedition_relic_preset==Expedition.Relic.FROST

func smoke_duties() -> bool:
	game=State.new()
	game.transient=true
	if not game.recruit() or not game.recruit() or not game.assign_duty("garden",0) or not game.assign_duty("works",1):
		return false
	if game.duty_member("garden",true)>=0 or game.facility_cost("sword_hall")[0]!=35 or game.start_expedition(0,-1,0,0):
		return false
	var before: int = game.data.stones
	game.record("测试","推进一日")
	if game.data.stones!=before or game.facility_cost("sword_hall")[0]!=23:
		return false
	game.data.plots[0]=[0,game.data.day]
	game.data.dust=2
	if not game.harvest(0) or game.data.herbs!=6 or not game.upgrade_facility("sword_hall") or game.data.stones!=before-23:
		return false
	if not game.assign_duty("scout",1) or game.duty_member("works")!=-1 or game.facility_cost("medicine_hall")[0]!=35:
		return false
	for i in 2:
		game.record("测试","推进一日")
	if game.data.scout_days!=2 or game.data.scout_token!=0 or game.start_expedition(-1,-1,0,0,"",-1,true):
		return false
	game.record("测试","推进一日")
	if game.data.scout_token!=1 or "survey" in game.expedition_forecast().steps[2] or "survey" not in game.expedition_forecast(true).steps[2]:
		return false
	for i in 5:
		game.record("测试","推进一日")
	if game.data.scout_token!=1 or not game.assign_duty("garden",-1) or not game.start_expedition(0,-1,0,0,"",-1,true):
		return false
	if game.data.scout_token!=0 or game.assign_duty("works",0) or not game.expedition_take("pool") or not game.expedition_take("rest"):
		return false
	var health: int = game.data.expedition.hp
	if not game.expedition_take("survey") or game.data.expedition.hp!=health or game.data.expedition.coins!=23 or game.data.expedition.dust!=1:
		return false
	return game.extract_expedition() and game.assign_duty("works",0)

func smoke_action() -> bool:
	game=State.new()
	game.transient=true
	if not game.start_expedition(-1,-1,0,0,"",-1,false,true) or not game.expedition_take("trail") or not game.battle.action_duel:
		return false
	var arena := ActionDuel.new()
	arena.setup(game.battle,0,-1,0,false,false)
	var enemy_hp: int = game.battle.enemy
	arena.strike(false)
	var ok: bool = game.battle.enemy==enemy_hp
	arena.player.x=arena.enemy.x-125
	arena.strike(false)
	ok=ok and game.battle.enemy==enemy_hp-14 and game.battle.focus==1
	arena.player.y=arena.FLOOR-105
	arena.on_ground=false
	arena.player.x=arena.enemy.x
	arena.strike(true)
	ok=ok and arena.velocity.y<0 and game.battle.enemy==enemy_hp-32 and game.battle.focus==2
	arena.dash=.1
	ok=ok and not arena.damage_player(25) and game.battle.hp==game.battle.maxhp
	arena.dash=0
	ok=ok and arena.damage_player(25) and game.battle.hp==game.battle.maxhp-25
	arena.snapshot()
	game.leave_battle()
	ok=ok and game.resume_expedition_battle() and game.battle.duel_snapshot.player==arena.player
	arena.free()
	return ok and smoke_action_guardian()

func smoke_action_guardian() -> bool:
	var arena := ActionDuel.new()
	var stats := {"expedition_node":"boss","tier":0,"result":0,"hp":90,"maxhp":90,"enemy":87,"maxenemy":87,"focus":0,"relic":-1}
	arena.setup(stats,1,-1,0,false,true)
	var ok := true
	for expected in ["rush","wave","slam"]:
		arena.set_phase("wait",0.0)
		arena.update_enemy(1.0/60.0)
		ok=ok and arena.phase=="tell" and arena.move==expected
	arena.player.x=arena.enemy.x-230
	arena.player.y=arena.FLOOR-82
	arena.move="wave"
	arena.wave=220.0
	arena.attack_enemy(1.0/60.0,false)
	ok=ok and stats.hp==90
	arena.player.y=arena.FLOOR
	arena.attack_enemy(1.0/60.0,false)
	ok=ok and stats.hp==65
	stats.focus=3
	arena.set_phase("tell",.5)
	arena.burst()
	ok=ok and arena.phase=="open" and stats.focus==0 and stats.enemy==60
	arena.use_herb()
	ok=ok and arena.herbs==0 and stats.hp==90
	arena.free()
	return ok

func smoke_hero_selection() -> bool:
	game=State.new()
	game.transient=true
	var ok: bool = game.hero_name()=="掌门" and not game.choose_hero(-1) and not game.choose_hero(2)
	ok=ok and game.choose_hero(0) and game.hero_name()=="洛神" and game.choose_hero(1) and game.hero_name()=="应龙"
	var balance: int = game.data.stones
	ok=ok and game.recruit_cost()==0 and game.recruit() and game.recruit_cost()>0 and game.data.stones>=balance
	ok=ok and game.unlock_wukong() and not game.unlock_wukong() and game.choose_hero(2) and game.hero_name()=="悟空"
	var values := {"expedition_node":"trail","tier":0,"result":0,"hp":90,"maxhp":90,"enemy":51,"maxenemy":51,"focus":3,"relic":-1}
	for i in State.HEROES.size():
		var arena := ActionDuel.new()
		arena.setup(values.duplicate(true),0,-1,0,false,true,i,State.HEROES[i])
		arena.player.x=arena.enemy.x-185
		arena.burst()
		ok=ok and arena.stats.enemy==24 and arena.stats.focus==0 and arena.technique==State.HERO_TECHNIQUES[i]
		arena.free()
	return ok

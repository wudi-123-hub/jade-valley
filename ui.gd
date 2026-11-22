extends RefCounted

const INK := Color("#0f201e")
const PANEL := Color("#142925")
const WELL := Color("#1a3630")
const BORDER := Color("#516051")
const GOLD := Color("#dfc18b")
const PAPER := Color("#f5ebd3")
const MUTE := Color("#abbcac")
const JADE := Color("#99d2ac")
const OCHRE := Color("#e1ad72")
const COLORS := [Color("#9ec487"),Color("#e8bb78"),Color("#dfa4ad"),Color("#8dc9cf"),Color("#cbb0de")]
const Edgework = preload("res://edgework.gd")
const MEDALS = {
	"work":0,"training":1,"seasons":2,"ledger":3,"garden":4,"recruit":5,
	"pet":6,"journey":7,"rank":8,"master":9,"inventory":10,"settings":11
}
const PATHS = {
	"mountain":'M2 20 9 8l4 6 3-5 6 11H2zm5-9 2 2 2-2m6-7h4m-2-2v4',
	"gem":'m6 4-4 6 10 11 10-11-4-6H6Zm-4 6h20M9 4l-2 6 5 11 5-11-2-6',
	"flame":'M12 22a7 7 0 0 0 7-7c0-4-2-6-4-8 0 3-2 4-2 4 1-6-3-9-3-9 0 5-5 8-5 13a7 7 0 0 0 7 7Zm0-9c1 2 3 3 3 5a3 3 0 0 1-6 0c0-2 2-3 3-5Z',
	"sprout":'M12 22v-9m0 3C4 16 3 10 3 6c6 0 9 3 9 8m0 0c0-6 3-9 9-9 0 6-3 9-9 9M7 22h10',
	"hall":'M2 10c5-1 8-4 10-7 2 3 5 6 10 7H2Zm3 10h14M7 10v10m10-10v10m-7 0v-5h4v5',
	"paw":'M7 20c-5-2-1-6 1-8 2-2 6-2 8 0 2 2 6 6 1 8-2 1-3-1-5-1s-3 2-5 1Z M4 7a2 2 0 1 0 0 4 2 2 0 0 0 0-4Zm5-4a2 2 0 1 0 0 4 2 2 0 0 0 0-4Zm6 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4Zm5 4a2 2 0 1 0 0 4 2 2 0 0 0 0-4Z',
	"compass":'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Zm4 5-2 6-6 2 2-6 6-2Z',
	"spark":'M12 2c0 6 4 10 10 10-6 0-10 4-10 10 0-6-4-10-10-10 6 0 10-4 10-10Z',
	"scroll":'M7 3h12a2 2 0 0 1 2 2v3h-5V6a3 3 0 0 0-3-3H7a3 3 0 0 0-3 3v12a3 3 0 0 0 3 3h11a2 2 0 0 0 2-2v-3H9v2a3 3 0 0 1-3 3m2-13h5m-5 4h5',
	"moon":'M21 15a9 9 0 0 1-12-12 9 9 0 1 0 12 12Zm-5-11v5m-2-3h5',
	"user":'M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8ZM4 21v-2a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v2H4Z',
	"bag":'M8 4h8l-2 5c4 2 6 5 6 8 0 3-3 4-8 4s-8-1-8-4c0-3 2-6 6-8L8 4Zm2 5h4m-6 4h8',
	"lock":'M5 10h14v11H5Zm3 0V7a4 4 0 0 1 8 0v3',
	"sword":'m9 15 9-11 3-1-1 4-10 10m-4-4 6 6m-5-2-4 4',
	"shield":'M12 3 4 6v5c0 6 4 9 8 11 4-2 8-5 8-11V6l-8-3Zm-4 8 3 3 5-6',
	"cog":'M12 3v3m0 12v3M3 12h3m12 0h3M6 6l2 2m8 8 2 2m0-12-2 2m-8 8-2 2m6-10a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z',
	"close":'m6 6 12 12m0-12L6 18',
	"check":'m4 12 5 5 11-11'
}

var sans: Font
var serif: Font
var icons: Dictionary = {}
var plates: Dictionary = {}

func _init() -> void:
	var backup := SystemFont.new()
	backup.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei","Arial"])
	var heading := SystemFont.new()
	heading.font_names = PackedStringArray(["SimSun","Microsoft YaHei","Arial"])
	sans = load("res://assets/Body.ttf") if ResourceLoader.exists("res://assets/Body.ttf") else backup
	serif = load("res://assets/Title.ttf") if ResourceLoader.exists("res://assets/Title.ttf") else heading

func place(node: Control, parent: Node, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)

func skin(fill: Color, edge: Color, curve := 14, border_width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_corner_radius_all(curve)
	s.set_border_width_all(border_width)
	s.content_margin_left = 13
	s.content_margin_right = 13
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	s.anti_aliasing_size = 1.15
	return s

func box(parent: Node, rect: Rect2, fill := PANEL, edge := BORDER, curve := 14, shadow := false) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := skin(fill,edge,curve)
	if shadow:
		s.shadow_size = 9
		s.shadow_color = Color(.02,.06,.04,.50)
		s.shadow_offset = Vector2(0,4)
	p.add_theme_stylebox_override("panel",s)
	place(p,parent,rect)
	return p

func label(parent: Node, value: String, rect: Rect2, size := 18,color := PAPER, center := false, title := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_override("font",serif if title else sans)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	place(l,parent,rect)
	return l

func button(parent: Node,value: String,rect: Rect2,run: Callable,accent := GOLD,primary := false,curve := 10,enabled := true) -> Button:
	var b := Button.new()
	b.text = value
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",sans)
	b.add_theme_font_size_override("font_size",17)
	var seal := rect.size.x<=56 and rect.size.y<=56 and value.is_empty() and curve>=18
	var path := "ui_seal_" if seal else "ui_"
	b.add_theme_stylebox_override("normal",plate("ui_gold" if primary else path+"normal",seal))
	b.add_theme_stylebox_override("hover",plate("ui_gold_hover" if primary else path+"hover",seal))
	b.add_theme_stylebox_override("pressed",plate("ui_gold_press" if primary else path+"press",seal))
	b.add_theme_stylebox_override("hover_pressed",plate("ui_gold_press" if primary else path+"hover",seal))
	b.add_theme_stylebox_override("disabled",plate("ui_disabled"))
	var focus := skin(Color(0,0,0,0),accent.lightened(.47),curve,2)
	b.add_theme_stylebox_override("focus",focus)
	var fore := INK if primary else PAPER
	for name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		b.add_theme_color_override(name,fore)
	b.add_theme_color_override("font_disabled_color",Color("#a7b0a6"))
	b.disabled = not enabled
	b.pressed.connect(run)
	place(b,parent,rect)
	return b

func plate(name: String,seal := false) -> StyleBox:
	if plates.has(name):
		return plates[name]
	var location := "res://assets/%s.png" % name
	if not ResourceLoader.exists(location):
		return skin(WELL,GOLD,11)
	var style := StyleBoxTexture.new()
	style.texture = load(location)
	if not seal:
		style.set_texture_margin(SIDE_LEFT,23)
		style.set_texture_margin(SIDE_RIGHT,23)
		style.set_texture_margin(SIDE_TOP,14)
		style.set_texture_margin(SIDE_BOTTOM,14)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	plates[name] = style
	return style

func framed(parent: Node,rect: Rect2,decorated_dock := false) -> Panel:
	var shell := box(parent,rect,Color("#132b23"),Color("#a79161"),14,true)
	box(shell,Rect2(Vector2(6,6),rect.size-Vector2(12,12)),Color.TRANSPARENT,Color("#51694e"),10)
	var edge: Control = Edgework.new()
	edge.dock = decorated_dock
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(edge,shell,Rect2(Vector2.ZERO,rect.size))
	return shell

func ornament(parent: Node,rect: Rect2) -> void:
	if ResourceLoader.exists("res://assets/filigree.webp"):
		picture(parent,load("res://assets/filigree.webp"),rect)

func emblem(parent: Node,key: String,glyph: String,rect: Rect2,accent := GOLD) -> TextureRect:
	var name := "res://assets/keeper.webp" if key=="story" else "res://assets/medal%d.webp" % int(MEDALS.get(key,-1))
	return picture(parent,load(name),rect) if ResourceLoader.exists(name) else mark(parent,glyph,rect,accent)

func lift_on_hover(button_node: Button,visual: Control,enabled := true) -> void:
	if not enabled:
		return
	var base := visual.position
	visual.pivot_offset = visual.size*.5
	button_node.mouse_entered.connect(func():
		if is_instance_valid(visual) and not button_node.disabled:
			var animate := visual.create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
			animate.tween_property(visual,"position",base-Vector2(0,3),.15)
			animate.tween_property(visual,"scale",Vector2.ONE*1.10,.15))
	button_node.mouse_exited.connect(func():
		if is_instance_valid(visual):
			var animate := visual.create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
			animate.tween_property(visual,"position",base,.18)
			animate.tween_property(visual,"scale",Vector2.ONE,.18))

func icon(key: String) -> Texture2D:
	if icons.has(key):
		return icons[key]
	var markup := '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>' % PATHS.get(key,PATHS.spark)
	var image := Image.new()
	image.load_svg_from_string(markup)
	var t := ImageTexture.create_from_image(image)
	icons[key] = t
	return t

func picture(parent: Node, tex: Texture2D, rect: Rect2, tint := Color.WHITE,cover := false) -> TextureRect:
	var view := TextureRect.new()
	view.texture = tex
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.modulate = tint
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(view,parent,rect)
	return view

func mark(parent: Node,key: String,rect: Rect2,tint := GOLD) -> TextureRect:
	return picture(parent,icon(key),rect,tint)

func meter(parent: Node, rect: Rect2, ratio: float, color := JADE) -> void:
	box(parent,rect,INK,BORDER,6)
	if ratio > 0.01:
		box(parent,Rect2(rect.position+Vector2(2,2),Vector2(maxf(4,(rect.size.x-4)*clampf(ratio,0,1)),rect.size.y-4)),color,color,4)

func line(parent: Node, from: Vector2, to: Vector2, color := BORDER) -> void:
	var rule := Line2D.new()
	rule.points = PackedVector2Array([from,to])
	rule.width = 1.0
	rule.default_color = color
	parent.add_child(rule)

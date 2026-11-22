extends "res://main.gd"

func _ready() -> void:
	super()
	game.transient = true
	action_expeditions=false
	game.data = State.DEFAULT.duplicate(true)
	game.data.music = false
	game.data.sound = false
	music.stop()
	have_save = false
	show_title()
	await capture("title")
	begin_game()
	await capture("hero-selection")
	if not find_text_button(modal,"击败悬云观古甲解锁").disabled or hero_portrait(0).resource_path!="res://assets/hero_portrait_0.webp" or hero_portrait(1).resource_path!="res://assets/hero_portrait_1.webp":
		get_tree().quit(19)
		return
	find_text_button(modal,"选择洛神").pressed.emit()
	if game.hero_name()!="洛神" or scene_key!="dialogue":
		get_tree().quit(20)
		return
	await capture("dialogue")
	for i in 3:
		next_dialogue()
	await capture("story")
	close_scene()
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("world")
	find_button(frame_overlay,"宗务").pressed.emit()
	if tray_key!="work" or not frame_overlay.visible:
		get_tree().quit(7)
		return
	await capture("work-tray")
	find_button(tray,"药圃").pressed.emit()
	if scene_key!="garden" or is_instance_valid(tray):
		get_tree().quit(8)
		return
	game.plant(0,0)
	game.plant(1,0)
	game.record("山门","山门休整了一日。")
	open_scene("garden",true)
	await capture("garden")
	game.harvest(0)
	game.tame()
	game.recruit()
	close_scene()
	find_button(frame_overlay,"掌门").pressed.emit()
	await capture("master")
	find_text_button(modal,"更换掌门").pressed.emit()
	find_text_button(modal,"选择应龙").pressed.emit()
	if game.hero_name()!="应龙" or scene_key!="master":
		get_tree().quit(21)
		return
	close_scene()
	find_button(frame_overlay,"行囊").pressed.emit()
	await capture("inventory")
	close_scene()
	find_button(frame_overlay,"四季").pressed.emit()
	await capture("seasons-tray")
	find_button(tray,"玄霜城").pressed.emit()
	if scene_key!="season" or season_preview!=3:
		get_tree().quit(9)
		return
	close_scene()
	toggle_scenery()
	if frame_overlay.visible or not reveal_hud.visible:
		get_tree().quit(10)
		return
	await capture("scenery")
	toggle_scenery()
	find_button(frame_overlay,"宗门簿").pressed.emit()
	await capture("ledger")
	ledger_tab=1
	open_scene("ledger",true)
	await capture("journal")
	open_scene("journey")
	fight_start()
	await capture("battle")
	combat("attack")
	combat("guard")
	combat("spell")
	if game.battle.result != 1:
		get_tree().quit(5)
		return
	close_scene()
	find_button(frame_overlay,"主线").pressed.emit()
	story_fight_start()
	if scene_key!="battle" or game.battle.story!=0:
		get_tree().quit(11)
		return
	combat("attack")
	combat("guard")
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("guardian")
	combat("spell")
	combat("attack")
	if game.battle.result!=1 or game.data.story_chapter!=1:
		get_tree().quit(12)
		return
	close_scene()
	if not await play_expedition():
		get_tree().quit(14)
		return
	if not await play_duties():
		get_tree().quit(15)
		return
	if not await play_action_duel():
		get_tree().quit(17)
		return
	if not await play_seal_trial():
		get_tree().quit(22)
		return
	if not await play_imprints():
		get_tree().quit(23)
		return
	game.data.rank=3
	game.migrate(1)
	await capture("summer")
	game.migrate(2)
	await capture("autumn")
	game.migrate(3)
	await capture("winter")
	var isolated := OS.get_environment("JADE_QA_OUT") + "/test-save"
	var original = State.new()
	original.save_prefix = isolated
	original.read_save()
	original.reset()
	original.choose_hero(1)
	original.treasure()
	original.plant(2,0)
	original.recruit()
	original.assign_duty("scout",0)
	original.record("山门","宗门休整一日。")
	var restored = State.new()
	restored.save_prefix = isolated
	if not restored.read_save() or restored.data.day != original.data.day or restored.data.plots != original.data.plots or restored.data.stones != original.data.stones or restored.duty_member("scout",true)!=0 or restored.data.scout_days!=1 or restored.hero_name()!="应龙":
		get_tree().quit(6)
		return
	var old_save := FileAccess.open(isolated+"-legacy-0.save",FileAccess.WRITE)
	old_save.store_var({"seq":500,"day":21,"rank":2,"stones":421,"expedition_wins":[1,0,0,0]},false)
	old_save.close()
	var migrated = State.new()
	migrated.save_prefix = isolated+"-legacy"
	if not migrated.read_save() or migrated.data.rank!=2 or migrated.data.story_chapter!=0 or migrated.data.stones!=421 or not migrated.relic_unlocked(0) or migrated.data.expedition_relic_preset!=-1 or not migrated.data.duty_orders.is_empty() or migrated.data.scout_token!=0 or migrated.data.hero_style!=-1 or not migrated.hero_unlocked(2) or migrated.data.remedies!=[0,0,0] or migrated.data.imprints!=[false,false] or migrated.data.expedition_imprint_preset!=-1:
		get_tree().quit(13)
		return
	print("WINDOWED_RENDER_PASS")
	get_tree().quit()

func play_expedition() -> bool:
	find_button(frame_overlay,"修行").pressed.emit()
	find_button(tray,"遗灯秘境").pressed.emit()
	await capture("expedition-setup")
	find_text_button(modal,"看路况 · 选委托").pressed.emit()
	await capture("expedition-plan")
	for accept: Button in modal.find_children("*","Button",true,false):
		if accept.tooltip_text=="两株续灯草":
			accept.pressed.emit()
			break
	find_text_button(modal,"启程入境").pressed.emit()
	if game.data.expedition.is_empty() or game.data.expedition.commission!="herbs":
		return false
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("expedition-route")
	choose_node("trail")
	combat("attack")
	var hp: int = game.battle.hp
	close_scene()
	open_expedition()
	find_text_button(modal,"继续战斗").pressed.emit()
	if game.battle.hp!=hp or game.battle.turn!=2:
		return false
	combat("guard")
	combat("spell")
	if game.battle.result!=1:
		return false
	find_text_button(modal,"继续远征").pressed.emit()
	choose_node("relay")
	choose_node("bridge")
	choose_node("camp")
	choose_node("boss")
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("expedition-boss")
	var captured_tactics := false
	for turn in 16:
		if game.battle.result!=0:
			break
		if game.boss_signature_queued() and game.can_combat("spirit") and not captured_tactics:
			await capture("expedition-signature")
			var support := find_text_button(modal,"[5] 磐鳞守护 · 本趟可用 1 次")
			if support==null or support.disabled:
				return false
			support.pressed.emit()
			if game.can_combat("spirit") or game.battle.taken!=0:
				return false
			captured_tactics=true
			continue
		var stance: String = game.next_move()[2]
		combat("spell" if game.can_combat("spell") and stance!="light" else ("guard" if stance in ["heavy","ward"] else "attack"))
	if game.battle.result!=1 or not captured_tactics:
		return false
	find_text_button(modal,"查看远征结算").pressed.emit()
	if not game.data.expedition_last.commission_done or game.data.expedition_last.bonus_dust!=3 or game.data.expedition_last.relic_unlocked!=0:
		return false
	await capture("expedition-result")
	find_text_button(modal,"查看遗宝").pressed.emit()
	await capture("expedition-relics")
	find_text_button(modal,"返回远征战报").pressed.emit()
	find_text_button(modal,"宗门营造").pressed.emit()
	await capture("expedition-facilities")
	find_text_button(modal,"升阶 · 35 灵石 / 2 灯砂").pressed.emit()
	if game.data.facilities.sword_hall!=1:
		return false
	close_scene()
	if game.expedition_forecast().name!="雾岚水路":
		return false
	open_expedition()
	find_text_button(modal,"看路况 · 选委托").pressed.emit()
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("expedition-plan-2")
	find_text_button(modal,"返回远征整备").pressed.emit()
	find_text_button(modal,"镇门遗宝 · 未携带").pressed.emit()
	find_text_button(modal,"携带潮甲印").pressed.emit()
	find_text_button(modal,"启程入境").pressed.emit()
	if game.data.expedition.relic!=0:
		return false
	choose_node("trail")
	combat("guard")
	combat("herb")
	if not game.battle.relic_spent or game.battle.taken!=10:
		return false
	await capture("expedition-relic-trigger")
	for turn in 16:
		if game.battle.result!=0:
			break
		var stance: String = game.next_move()[2]
		combat("spell" if game.can_combat("spell") and stance!="light" else ("guard" if stance in ["heavy","ward"] else "attack"))
	if game.battle.result!=1:
		return false
	find_text_button(modal,"继续远征").pressed.emit()
	find_text_button(modal,"带上战利品撤回").pressed.emit()
	find_text_button(modal,"确认撤回").pressed.emit()
	if game.data.expedition_last.relic_unlocked!=-1 or game.data.expedition_relic_preset!=0:
		return false
	close_scene()
	var isolated := OS.get_environment("JADE_QA_OUT")+"/expedition-save"
	var saved = State.new()
	saved.save_prefix=isolated
	saved.read_save()
	saved.reset()
	saved.data.pets=[State.PETS[0]]
	saved.data.expedition_wins[0]=1
	if not saved.start_expedition(-1,0,0,0,"",0) or not saved.expedition_take("trail"):
		return false
	saved.strike("attack")
	saved.strike("spirit")
	var restored = State.new()
	restored.save_prefix=isolated
	if not restored.read_save() or not restored.resume_expedition_battle() or restored.battle.turn!=3 or restored.battle.hp!=saved.battle.hp or restored.can_combat("spirit"):
		return false
	if restored.data.expedition.itinerary!=saved.data.expedition.itinerary or restored.battle.relic!=0 or restored.data.expedition_relic_preset!=0:
		return false
	# Persist a v1.2-shaped expedition mid-run and verify its old options remain available.
	var legacy = State.new()
	legacy.save_prefix=isolated+"-legacy"
	legacy.read_save()
	legacy.reset()
	legacy.data.expedition_serial=2
	if not legacy.start_expedition(-1,-1,0,0):
		return false
	for key in ["itinerary","route_name","commission","spirit_index","spirit_charges","boss_tactics","relic"]:
		legacy.data.expedition.erase(key)
	legacy.save_game()
	var old_run = State.new()
	old_run.save_prefix=legacy.save_prefix
	return old_run.read_save() and old_run.expedition_choices()==Expedition.route_step(0,0,3) and old_run.expedition_take("pool") and old_run.expedition_choices()==Expedition.route_step(1,0,3)

func choose_node(key: String) -> void:
	var target: Array = Expedition.OPTIONS[key]
	for child: Button in modal.find_children("*","Button",true,false):
		if child.tooltip_text==target[2]:
			child.pressed.emit()
			break
	find_text_button(modal,"踏入"+target[0]).pressed.emit()

func play_duties() -> bool:
	open_scene("recruit")
	find_text_button(modal,"弟子派驻").pressed.emit()
	press_tooltip("桃桃")
	press_tooltip("派驻巡山勘察")
	if game.duty_member("scout")!=0 or game.duty_member("scout",true)>=0:
		return false
	for day in 3:
		find_text_button(modal,"休整一日").pressed.emit()
	if game.data.scout_token!=1:
		return false
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("disciple-duties")
	close_scene()
	open_expedition()
	if game.guide_available(0):
		return false
	find_text_button(modal,"勘察札 · 可携带").pressed.emit()
	find_text_button(modal,"看路况 · 选委托").pressed.emit()
	await capture("expedition-survey-plan")
	find_text_button(modal,"返回远征整备").pressed.emit()
	find_text_button(modal,"启程入境").pressed.emit()
	if game.data.scout_token!=0 or not game.data.expedition.surveyed:
		return false
	choose_node("pool")
	choose_node("rest")
	var health: int = game.data.expedition.hp
	choose_node("survey")
	if game.data.expedition.hp!=health or game.data.expedition.dust!=1:
		return false
	find_text_button(modal,"带上战利品撤回").pressed.emit()
	find_text_button(modal,"确认撤回").pressed.emit()
	close_scene()
	return true

func launch_prepared_expedition() -> void:
	if action_expeditions:
		super()
		return
	var guide := 0 if game.guide_available(0) else -1
	var pet := 0 if not game.data.pets.is_empty() else -1
	if game.start_expedition(guide,pet,draft_herbs,draft_tier,draft_commission,draft_relic,draft_scout):
		route_choice=""
		open_scene("expedition",true)

func press_tooltip(caption: String) -> void:
	for found: Button in modal.find_children("*","Button",true,false):
		if found.tooltip_text==caption and not found.disabled:
			found.pressed.emit()
			return

func send_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)

func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func play_action_duel() -> bool:
	show_title()
	find_text_button(root,"横版试炼 · 断灯栈道").pressed.emit()
	var start: Vector2 = duel.player
	send_key(KEY_D,true)
	await physics_frames(7)
	send_key(KEY_D,false)
	if duel.player.x<=start.x+14:
		return false
	send_key(KEY_SPACE,true)
	await physics_frames(5)
	send_key(KEY_SPACE,false)
	if duel.player.y>=start.y-30:
		return false
	var before_dash: float = duel.player.x
	send_key(KEY_K,true)
	await physics_frames(6)
	send_key(KEY_K,false)
	if duel.player.x<before_dash+60 or duel.dash<=0:
		return false
	await capture("duel-trail")
	find_text_button(modal,"挑战古甲").pressed.emit()
	if not duel.boss or duel.scenery.resource_path!="res://assets/duel_depths.webp":
		return false
	duel.player.x=580
	duel.enemy.x=1000
	duel.move="wave"
	duel.move_index=2
	duel.set_phase("tell",1.3)
	await capture("duel-cloud")
	var earlier_clears: int = game.data.expedition_wins[0]
	game.data.expedition_wins[0]=0
	duel.damage_enemy(duel.stats.enemy)
	await get_tree().create_timer(.55).timeout
	game.data.expedition_wins[0]=earlier_clears
	if not game.data.wukong_unlocked:
		return false
	find_text_button(modal,"选择掌门").pressed.emit()
	find_text_button(modal,"选择悟空").pressed.emit()
	if duel.player_name!="悟空" or duel.technique!="大闹天宫" or duel.hero_art.resource_path!="res://assets/hero_action_2.webp":
		return false
	find_text_button(modal,"挑战古甲").pressed.emit()
	duel.stats.focus=3
	duel.player.x=565
	duel.enemy.x=899
	send_key(KEY_L,true)
	await physics_frames(3)
	send_key(KEY_L,false)
	if duel.stats.focus!=0 or duel.stats.enemy>=duel.stats.maxenemy:
		return false
	await capture("duel-wukong",.06)
	close_scene()
	show_world()
	action_expeditions=true
	if game.data.herbs<2:
		game.plant(1,0)
		game.advance()
		game.advance()
		game.harvest(1)
	var herbs_before: int = game.data.herbs
	if herbs_before<2:
		return false
	open_scene("garden")
	find_text_button(modal,"丹房备战").pressed.emit()
	find_text_button(modal,"炼制 · 2 草 / 14 石").pressed.emit()
	if game.data.herbs!=herbs_before-2 or game.data.remedies[Expedition.Remedy.FOCUS]!=1:
		return false
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("remedies-workshop")
	close_scene()
	open_expedition()
	find_text_button(modal,"丹房备战 · 未携带").pressed.emit()
	find_text_button(modal,"携带凝锋丸").pressed.emit()
	await capture("remedies-packed",.06)
	find_text_button(modal,"启程入境").pressed.emit()
	if game.data.expedition.remedy!=Expedition.Remedy.FOCUS or game.data.remedies[Expedition.Remedy.FOCUS]!=0:
		printerr("Remedy was not transferred to the expedition.")
		return false
	choose_node("trail")
	if not is_instance_valid(duel) or not game.battle.action_duel or game.data.expedition.spirit_index!=-1 or game.data.expedition.guide!="独行":
		printerr("Expected a solo action battle with a remedy.")
		return false
	duel.player.x=duel.enemy.x-125
	send_key(KEY_J,true)
	await physics_frames(3)
	send_key(KEY_J,false)
	var remaining: int = game.battle.enemy
	if remaining>=game.battle.maxenemy or game.battle.focus!=1:
		printerr("Expected one focus after striking. Focus ",game.battle.focus," enemy ",remaining)
		return false
	close_scene()
	open_expedition()
	find_text_button(modal,"继续战斗").pressed.emit()
	if game.battle.enemy!=remaining or game.battle.focus!=1:
		printerr("Initial action progress changed when reopening the fight.")
		return false
	duel.enemy.x=duel.player.x+100
	duel.set_phase("open",6.0)
	await physics_frames(2)
	send_key(KEY_F,true)
	Input.flush_buffered_events()
	await physics_frames(3)
	send_key(KEY_F,false)
	if game.battle.focus!=3 or not game.data.expedition.remedy_used or not duel.remedy_button.disabled:
		printerr("F did not spend the remedy. Focus ",game.battle.focus," used ",game.data.expedition.remedy_used," button ",duel.remedy_button.disabled," arena focus ",duel.focused," active ",duel.active," remedy ",duel.stats.get("remedy")," scene ",scene_key)
		return false
	await capture("remedies-use",.07)
	close_scene()
	open_expedition()
	find_text_button(modal,"继续战斗").pressed.emit()
	if game.battle.focus!=3 or not duel.remedy_button.disabled:
		return false
	send_key(KEY_L,true)
	await physics_frames(3)
	send_key(KEY_L,false)
	if game.battle.focus!=0 or game.battle.enemy>=remaining:
		return false
	await physics_frames(30)
	for i in 4:
		send_key(KEY_J,true)
		await physics_frames(2)
		send_key(KEY_J,false)
		await physics_frames(25)
		if game.battle.result!=0:
			break
	await get_tree().create_timer(.55).timeout
	if game.battle.result!=1 or game.data.expedition.step!=1 or game.data.expedition.coins!=15:
		return false
	find_text_button(modal,"继续远征").pressed.emit()
	find_text_button(modal,"带上战利品撤回").pressed.emit()
	find_text_button(modal,"确认撤回").pressed.emit()
	close_scene()
	if game.data.expedition_last.remedy_returned!=-1 or game.data.remedies[Expedition.Remedy.FOCUS]!=0:
		return false
	print("REMEDIES_WINDOWED_PASS")
	print("ACTION_DUEL_WINDOWED_PASS")
	return true

func play_seal_trial() -> bool:
	open_expedition()
	find_text_button(modal,"启程入境").pressed.emit()
	choose_node("pool")
	choose_node("rest")
	choose_node("bridge")
	for child: Button in modal.find_children("*","Button",true,false):
		if child.tooltip_text==Expedition.OPTIONS.seal[2]:
			child.pressed.emit()
			break
	await capture("seal-route")
	find_text_button(modal,"踏入封灯试炼").pressed.emit()
	if game.battle.expedition_node!="seal" or game.data.expedition.dust!=0 or duel.enemy_art.resource_path!="res://assets/duel_seal_mastiff.webp":
		return false
	var resumed := State.new()
	resumed.save_prefix=save_test_checkpoint("seal-checkpoint")
	if not resumed.read_save() or not resumed.resume_expedition_battle() or resumed.battle.expedition_node!="seal" or resumed.data.expedition.dust!=0 or resumed.expedition_take("seal"):
		return false
	duel.player.x=duel.enemy.x-222
	duel.set_phase("wait",.01)
	await physics_frames(4)
	if duel.move!="wave" or duel.phase!="tell":
		return false
	await capture("seal-mastiff",.12)
	var health: int = game.battle.hp
	for i in 54:
		if duel.phase_time<=.10:
			break
		await physics_frames(1)
	send_key(KEY_SPACE,true)
	await physics_frames(2)
	send_key(KEY_SPACE,false)
	await physics_frames(33)
	if game.battle.hp!=health or duel.move_hit or duel.wave<=222:
		printerr("Seal trial jump failed to avoid a passing shockwave. HP ",game.battle.hp," wave ",duel.wave," y ",duel.player.y)
		return false
	if not await win_action_with_attacks():
		return false
	if game.data.expedition.sealed_dust!=Expedition.seal_reward(0) or game.data.expedition.dust!=0:
		return false
	find_text_button(modal,"继续远征").pressed.emit()
	find_text_button(modal,"带上战利品撤回").pressed.emit()
	await capture("seal-retreat")
	find_text_button(modal,"继续深入").pressed.emit()
	choose_node("boss")
	if game.battle.slash!=Expedition.SEAL_BOOST+game.data.facilities.sword_hall*4:
		return false
	if not await win_action_with_attacks():
		return false
	find_text_button(modal,"查看远征结算").pressed.emit()
	if game.data.expedition_last.sealed_paid!=Expedition.seal_reward(0) or game.data.expedition_last.dust!=10:
		return false
	await capture("seal-result")
	close_scene()
	print("SEAL_TRIAL_WINDOWED_PASS")
	return true

func win_action_with_attacks() -> bool:
	duel.player=Vector2(duel.enemy.x-105,duel.FLOOR)
	duel.set_phase("open",8.0)
	for i in 6:
		send_key(KEY_J,true)
		await physics_frames(2)
		send_key(KEY_J,false)
		await physics_frames(26)
		if game.battle.result!=0:
			break
	await get_tree().create_timer(.55).timeout
	return game.battle.result==1

func play_imprints() -> bool:
	open_expedition()
	find_text_button(modal,"上次远征战报").pressed.emit()
	find_text_button(modal,"铭印台").pressed.emit()
	var dust: int = game.data.dust
	var stones: int = game.data.stones
	find_text_button(modal,"领悟破势铭").pressed.emit()
	find_text_button(modal,"领悟回息铭").pressed.emit()
	if game.data.dust!=dust-2*Expedition.IMPRINT_DUST or game.data.stones!=stones-2*Expedition.IMPRINT_STONES:
		return false
	open_expedition()
	find_text_button(modal,"镇门遗宝 · 潮甲印").pressed.emit()
	find_text_button(modal,"铭印台").pressed.emit()
	find_text_button(modal,"装配破势铭").pressed.emit()
	if is_instance_valid(toast_panel):
		toast_panel.free()
	await capture("imprint-workshop")
	find_text_button(modal,"返回镇门遗宝").pressed.emit()
	find_text_button(modal,"返回远征整备").pressed.emit()
	find_text_button(modal,"启程入境").pressed.emit()
	choose_node("trail")
	if game.battle.imprint!=Expedition.Imprint.COUNTER:
		return false
	duel.player.x=duel.enemy.x-255
	duel.stats.focus=3
	duel.move="rush"
	duel.set_phase("tell",.75)
	await physics_frames(2)
	send_key(KEY_L,true)
	Input.flush_buffered_events()
	await physics_frames(3)
	send_key(KEY_L,false)
	if game.battle.focus!=1 or not game.battle.imprint_spent or duel.phase!="open":
		printerr("Counter imprint interrupt: focus ",game.battle.focus," spent ",game.battle.imprint_spent," phase ",duel.phase," enemy ",game.battle.enemy," active ",duel.active," focused ",duel.focused)
		return false
	await capture("imprint-counter",.06)
	var restored := State.new()
	restored.save_prefix=save_test_checkpoint("imprint-checkpoint")
	if not restored.read_save() or not restored.imprint_learned(Expedition.Imprint.RECOVERY) or restored.data.expedition_imprint_preset!=Expedition.Imprint.COUNTER or not restored.resume_expedition_battle() or not restored.battle.imprint_spent or restored.battle.focus!=1:
		return false
	close_scene()
	open_expedition()
	find_text_button(modal,"继续战斗").pressed.emit()
	if game.battle.focus!=1 or not game.battle.imprint_spent or not await win_action_with_attacks():
		return false
	withdraw_imprint_run()
	open_expedition()
	find_text_button(modal,"镇门遗宝 · 潮甲印 / 破势铭").pressed.emit()
	find_text_button(modal,"铭印台").pressed.emit()
	find_text_button(modal,"装配回息铭").pressed.emit()
	find_text_button(modal,"返回镇门遗宝").pressed.emit()
	find_text_button(modal,"返回远征整备").pressed.emit()
	find_text_button(modal,"启程入境").pressed.emit()
	choose_node("pool")
	choose_node("ambush")
	if game.battle.imprint!=Expedition.Imprint.RECOVERY or not duel.damage_player(16):
		return false
	var worn_hp: int = game.battle.hp
	if not await win_action_with_attacks():
		return false
	if game.battle.hp!=worn_hp+Expedition.IMPRINT_RECOVERY or game.data.expedition.imprint_healed!=Expedition.IMPRINT_RECOVERY:
		printerr("Recovery imprint did not heal after the ambush.")
		return false
	await capture("imprint-recovery")
	withdraw_imprint_run()
	if game.data.expedition_last.imprint_healed!=Expedition.IMPRINT_RECOVERY:
		return false
	print("IMPRINT_WINDOWED_PASS")
	return true

func withdraw_imprint_run() -> void:
	find_text_button(modal,"继续远征").pressed.emit()
	find_text_button(modal,"带上战利品撤回").pressed.emit()
	find_text_button(modal,"确认撤回").pressed.emit()
	close_scene()

func save_test_checkpoint(name: String) -> String:
	var saved := State.new()
	saved.save_prefix=OS.get_environment("JADE_QA_OUT")+"/"+name
	saved.read_save()
	var sequence: int = saved.data.seq
	saved.data=game.data.duplicate(true)
	saved.data.seq=sequence
	saved.save_game()
	return saved.save_prefix

func find_text_button(container: Node,target: String) -> Button:
	for child: Button in container.find_children("*","Button",true,false):
		if child.text==target:
			return child
	return null

func find_button(container: Node, tip: String) -> Button:
	for child in container.get_children():
		if child is Button and child.tooltip_text==tip:
			return child
	return null

func capture(name: String,settle := .49) -> void:
	await get_tree().create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var destination := OS.get_environment("JADE_QA_OUT") + "/" + name + ".png"
	var result := image.save_png(destination)
	print("CAPTURE ",name," ",image.get_size()," ",result)

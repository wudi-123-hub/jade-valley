extends RefCounted

signal changed(message: String)
const Chronicle = preload("res://chronicle.gd")
const Expedition = preload("res://expedition.gd")
const MAPS = [
	["春","青龙谷","龙蟠形","龙脊环湖，飞瀑入潭。","采收额外获得 1 株灵草","spring"],
	["夏","双翎谷","蝴蝶形","翠岭展翅，梯田沿溪铺开。","驯养灵兽少花 1 株灵草","summer"],
	["秋","照枫台","漏光形","天光穿过山隙，照亮枫林祭台。","寻宝额外获得 12 灵石","autumn"],
	["冬","玄霜城","齿轮形","冰渠环绕机关城台。","斗法胜利额外获得 14 修为","winter"]
]
const RANKS = ["炼气","筑基","金丹","元婴","飞升"]
const NEEDS = [78,115,165,230]
const PEOPLE = ["桃桃","石小满","竹阿七","丹栗","白小羽","松果儿","绵绵","霜阿宝"]
const HEROES = ["洛神","应龙","悟空"]
const HERO_TECHNIQUES = ["洛水汤汤","龙战于野","大闹天宫"]
const PETS = ["苔苔","赤绒","枫啾","雪团"]
const FOES = ["苔团兽","赤尾灵狐","枫火灵雀","玄霜雪狸"]
const CROPS = [["青露草",9,3,3],["火纹芝",18,4,5]]
const DUTIES = [
	["garden","药圃照料","每次采收额外获得 2 株灵草。","sprout"],
	["works","营造协作","每次升级宗门设施少付 12 灵石。","hall"],
	["scout","巡山勘察","在岗每满 3 日取得一张勘察札，最多存 1 张。","compass"]
]
const TASKS = [
	["初开药圃","采收任意一块药田。","harvest"],
	["门下新徒","从招贤台收下第一名弟子。","recruits"],
	["山间有伴","用灵草驯养一只灵兽。","tamed"],
	["御剑入云","完成一次云间寻宝。","trips"],
	["剑试山野","赢下一场山野斗法。","victories"],
	["筑基立宗","完成第一次境界突破。","rank"],
	["四境来客","迁入玄霜城，踏访冬季山门。","winter"],
	["雷过天明","布阵渡劫，飞升仙门。","ascended"]
]
const DEFAULT = {
	"seq":0,"day":1,"stones":110,"qi":34,"herbs":0,"rank":0,"map":0,"plots":[[],[],[]],"hero_style":-1,"wukong_unlocked":false,
	"people":[],"pets":[],"harvest":0,"recruits":0,"tamed":0,"trips":0,"victories":0,
	"winter":0,"ascended":0,"claimed":[],"log":[[1,"山门","青龙谷开宗立派。"]],
	"story_chapter":0,"story_read":[],"story_ending":-1,
	"dust":0,"facilities":{"sword_hall":0,"medicine_hall":0,"observatory":0},
	"expedition":{},"expedition_last":{},"expedition_serial":0,"expedition_wins":[0,0,0,0],
	"expedition_commissions":0,
	"expedition_relic_preset":-1,
	"remedies":[0,0,0],
	"duty_orders":{},"scout_days":0,"scout_token":0,
	"sound":true,"music":true,"motion":true
}

var data: Dictionary = DEFAULT.duplicate(true)
var battle: Dictionary = {}
var transient := false
var save_prefix := "user://jade"

func read_save() -> bool:
	var most_recent: Dictionary = {}
	for index in 2:
		var file := FileAccess.open("%s-%d.save" % [save_prefix,index], FileAccess.READ)
		if file == null:
			continue
		var saved: Variant = file.get_var(false)
		if saved is Dictionary and saved.has("day") and saved.has("seq"):
			if most_recent.is_empty() or int(saved.seq) > int(most_recent.seq):
				most_recent = saved
	if most_recent.is_empty():
		return false
	data.merge(most_recent,true)
	return true

func save_game() -> void:
	if transient:
		return
	data.seq += 1
	var file := FileAccess.open("%s-%d.save" % [save_prefix,int(data.seq) % 2],FileAccess.WRITE)
	if file != null:
		file.store_var(data,false)

func hero_name() -> String:
	return HEROES[data.hero_style] if data.hero_style>=0 and data.hero_style<HEROES.size() else "掌门"

func hero_unlocked(style: int) -> bool:
	return style in [0,1] or (style==2 and (data.wukong_unlocked or data.expedition_wins[0]>0))

func choose_hero(style: int) -> bool:
	if not hero_unlocked(style):
		return false
	data.hero_style=style
	return true

func unlock_wukong() -> bool:
	if hero_unlocked(2):
		return false
	data.wukong_unlocked=true
	record("掌门","击败沉潭古甲，解锁齐天大圣。",false,false)
	return true

func reset() -> void:
	var sequence: int = data.seq
	data = DEFAULT.duplicate(true)
	data.seq = sequence
	battle.clear()
	record("山门","青龙谷开宗立派。",false,false)

func advance() -> void:
	data.day += 1
	var assigned := 0
	for post in DUTIES:
		if duty_member(post[0],true)>=0:
			assigned+=1
	data.stones += (data.people.size()-assigned)*4
	data.qi += data.pets.size() * 3
	if duty_member("scout",true)>=0 and data.scout_token==0:
		data.scout_days+=1
		if data.scout_days>=3:
			data.scout_days=0
			data.scout_token=1

func record(group: String, message: String, spend_day := true, keep_log := true) -> void:
	if spend_day:
		advance()
	if keep_log:
		data.log.push_front([data.day,group,message])
		if data.log.size()>100:
			data.log.resize(100)
	save_game()
	changed.emit(message)

func can_plant(plot: int,crop: int) -> bool:
	return data.plots[plot].is_empty() and data.stones >= CROPS[crop][1] and (crop == 0 or data.rank > 0)

func plant(plot: int,crop: int) -> bool:
	if not can_plant(plot,crop):
		return false
	data.stones -= CROPS[crop][1]
	data.plots[plot] = [crop,data.day + CROPS[crop][2]]
	record("药圃","第 %d 畦播下%s。" % [plot+1,CROPS[crop][0]])
	return true

func harvest(plot: int) -> bool:
	var planted: Array = data.plots[plot]
	if planted.is_empty() or data.day < planted[1]:
		return false
	var amount: int = CROPS[planted[0]][3] + int(data.map == 0) + (2 if duty_member("garden",true)>=0 else 0)
	data.herbs += amount
	data.harvest += 1
	data.plots[plot] = []
	record("药圃","采收%s，获得 %d 株灵草。" % [CROPS[planted[0]][0],amount])
	return true

func refine() -> bool:
	if data.herbs < 1:
		return false
	data.herbs -= 1
	data.qi += 23
	record("修行","炼化一株灵草，修为增加 23。")
	return true

func recruit_cost() -> int:
	return 0 if data.people.is_empty() else 34 + data.people.size()*8

func recruit() -> bool:
	var index: int = data.people.size()
	if index >= PEOPLE.size() or data.stones < recruit_cost():
		return false
	data.stones -= recruit_cost()
	data.people.append(PEOPLE[index])
	data.recruits += 1
	record("弟子","%s拜入山门，每日供奉 4 灵石。" % PEOPLE[index])
	return true

func duty_member(post: String,active_only := false) -> int:
	var order: Dictionary = data.duty_orders.get(post,{})
	if order.is_empty() or (active_only and data.day<order.ready):
		return -1
	return int(order.member)

func member_duty(member: int) -> String:
	if member<0:
		return ""
	for post in DUTIES:
		if duty_member(post[0])==member:
			return post[0]
	return ""

func member_traveling(member: int) -> bool:
	if member<0 or member>=data.people.size() or data.expedition.is_empty():
		return false
	return data.people[member]==data.expedition.guide

func guide_available(member: int) -> bool:
	return member==-1 or (member>=0 and member<data.people.size() and member_duty(member).is_empty())

func assign_duty(post: String,member: int) -> bool:
	var title := ""
	for row in DUTIES:
		if row[0]==post:
			title=row[1]
			break
	if title.is_empty() or member< -1 or member>=data.people.size() or duty_member(post)==member or member_traveling(member):
		return false
	var previous := member_duty(member)
	if not previous.is_empty():
		data.duty_orders.erase(previous)
	if previous=="scout" or post=="scout":
		data.scout_days=0
	if member<0:
		data.duty_orders.erase(post)
		record("弟子","已撤回%s的驻岗弟子。" % title,false)
	else:
		data.duty_orders[post]={"member":member,"ready":data.day+1}
		record("弟子","%s将于明日到岗，负责%s。" % [data.people[member],title],false)
	return true

func tame_cost() -> int:
	return 1 if data.map == 1 else 2

func tame() -> bool:
	var index: int = data.pets.size()
	if index >= PETS.size() or data.herbs < tame_cost():
		return false
	data.herbs -= tame_cost()
	data.pets.append(PETS[index])
	data.tamed += 1
	record("灵兽","%s加入山门，每日汇聚 3 修为。" % PETS[index])
	return true

func treasure() -> void:
	var stones := 27 + (12 if data.map == 2 else 0)
	data.stones += stones
	data.qi += 16
	data.trips += 1
	record("历练","御剑寻宝，带回 %d 灵石与 16 修为。" % stones)

func can_break() -> bool:
	var rank: int = data.rank
	return rank < NEEDS.size() and data.qi >= NEEDS[rank] and (rank != 3 or data.stones >= 95)

func breakthrough() -> bool:
	if not can_break():
		return false
	data.qi -= NEEDS[data.rank]
	data.rank += 1
	if data.rank == 4:
		data.stones -= 95
		data.ascended = 1
		record("境界","%s引雷入阵，渡劫飞升。" % hero_name())
	else:
		record("境界","突破至%s，解锁%s。" % [RANKS[data.rank],MAPS[data.rank][1]])
	return true

func migrate(index: int) -> bool:
	if index < 0 or index > mini(data.rank,3) or index == data.map:
		return false
	data.map = index
	if index == 3:
		data.winter = 1
	record("山门","宗门迁入%s。" % MAPS[index][1],false)
	return true

func is_done(index: int) -> bool:
	return int(data.get(TASKS[index][2],0)) > 0

func quest_count() -> int:
	var count := 0
	for index in TASKS.size():
		count += int(is_done(index))
	return count

func claim(index: int) -> bool:
	if index < 0 or index >= TASKS.size() or not is_done(index) or index in data.claimed:
		return false
	var reward := 120 if index == 7 else 20
	data.stones += reward
	data.claimed.append(index)
	record("手记","领取「%s」回礼，获得 %d 灵石。" % [TASKS[index][0],reward],false)
	return true

func story_requirement(index: int) -> String:
	if data.rank < index:
		return "rank"
	if data.map != index:
		return "season"
	match index:
		0:
			if data.harvest==0:
				return "garden"
		1:
			if data.pets.is_empty():
				return "pet"
		2:
			if data.trips==0:
				return "journey"
	return ""

func read_chapter(index: int) -> void:
	if index>data.story_chapter or index in data.story_read:
		return
	data.story_read.append(index)
	record("主线","已读「%s」。" % Chronicle.CHAPTERS[index].title,false)

func finish_story(choice: int) -> bool:
	if data.story_chapter!=Chronicle.CHAPTERS.size() or data.story_ending>=0 or choice<0 or choice>=Chronicle.ENDINGS.size():
		return false
	data.story_ending=choice
	record("主线","长明灯续燃 · %s。" % Chronicle.ENDINGS[choice][0],false)
	return true

func start_battle(story_index := -1) -> bool:
	var in_story: bool = story_index>=0
	if not battle.is_empty() or (not in_story and data.stones<10):
		return false
	if in_story and (story_index!=data.story_chapter or story_index>=Chronicle.CHAPTERS.size() or story_index not in data.story_read or not story_requirement(story_index).is_empty()):
		return false
	var cap: int = 69 + int(data.rank)*9 + data.pets.size()*4
	var foe: int = [69,94,119,144][story_index] if in_story else 49+int(data.map)*13
	battle = {
		"map":data.map,"story":story_index,"turn":1,"hp":cap,"maxhp":cap,"enemy":foe,"maxenemy":foe,
		"charge":false,"focus":0,"note":"%s拔剑，静待先机。" % hero_name(),"result":0,"hit":0,"taken":0,
		"action":"","interrupt":false,"healed":0
	}
	return true

func next_move() -> Array:
	if boss_signature_queued():
		return Expedition.BOSS_SIGNATURES[battle.map]
	var moves: Array = Expedition.MOVES[battle.map] if battle.get("expedition",false) else Chronicle.MOVES[battle.map]
	var offset := 0
	if battle.get("expedition_node","") in ["ambush","seal"]:
		for i in moves.size():
			if moves[i][2]=="heavy":
				offset=i
				break
	return moves[(int(battle.turn)-1+offset)%moves.size()]

func boss_signature_queued() -> bool:
	return battle.get("boss_tactics",false) and not battle.get("signature_used",false) and int(battle.enemy)*2<=int(battle.maxenemy)

func expedition_spirit() -> int:
	return int(data.expedition.get("spirit_index",-1)) if battle.get("expedition",false) else -1

func spirit_damage() -> int:
	return 24+int(battle.get("rank",data.rank))*2

func foe_damage(move: Array) -> int:
	if battle.get("expedition",false):
		var advantage: int = Expedition.ENCOUNTERS[battle.expedition_node][1]
		return maxi(5,int(move[1])-advantage+int(battle.tier)*5)
	return int(move[1]) if battle.story>=0 else maxi(6,int(move[1])-5)

func hit_preview() -> int:
	var strength: int = 21+int(battle.get("rank",data.rank))*3+int(battle.get("slash",0))+(17 if battle.charge else 0)
	strength=maxi(1,strength-int(battle.get("frost",0)))
	return ceili(strength*.52) if next_move()[2]=="ward" else strength

func spell_damage() -> int:
	var bonus: int = 12 if flame_relic_ready(next_move()) else 0
	return 34+int(battle.get("rank",data.rank))*5+int(battle.get("spell",0))+bonus

func flame_relic_ready(move: Array) -> bool:
	return battle.get("relic",-1)==Expedition.Relic.FLAME and not battle.get("relic_spent",false) and move[2] in ["heavy","ward"]

func can_combat(tactic: String) -> bool:
	if battle.is_empty() or battle.result!=0:
		return false
	match tactic:
		"attack","guard":
			return true
		"spell":
			return battle.focus>=3
		"herb":
			return expedition_herbs()>0 and battle.hp<battle.maxhp
		"spirit":
			return expedition_spirit()>=0 and int(data.expedition.get("spirit_charges",0))>0
	return false

func strike(tactic: String) -> void:
	if not can_combat(tactic):
		return
	var guard := tactic=="guard"
	var heal := tactic=="herb"
	var spell := tactic=="spell"
	var is_expedition: bool = battle.get("expedition",false)
	var spirit := expedition_spirit() if tactic=="spirit" else -1
	var signature := boss_signature_queued()
	var move: Array = next_move()
	var relic: int = battle.get("relic",-1)
	battle.relic_note=""
	battle.action = tactic
	battle.interrupt = (spell or spirit==1) and move[2] in ["heavy","ward"]
	battle.healed = 0
	battle.hit = spell_damage() if spell else (hit_preview() if tactic=="attack" else 0)
	if spell and flame_relic_ready(move):
		battle.relic_spent=true
		battle.relic_note="焰纹剑穗 · 破阵伤害 +12"
	if battle.get("frost",0)>0:
		battle.frost=0
	if signature:
		battle.signature_used=true
	var focus_gain := {"attack":1,"guard":2,"spell":-3}.get(tactic,0) as int
	if heal and relic==Expedition.Relic.MIRROR:
		focus_gain=mini(2,3-battle.focus)
		if focus_gain>0:
			battle.relic_note="镜台羽铃 · 剑意 +%d" % focus_gain
	if spirit>=0:
		data.expedition.spirit_charges-=1
		if spirit==0:
			focus_gain=1
		elif spirit==1:
			battle.hit=spirit_damage()
		elif spirit==2:
			focus_gain=3
	battle.taken = 0
	battle.enemy = maxi(0,battle.enemy-battle.hit)
	battle.focus = clampi(battle.focus+focus_gain,0,3)
	if battle.enemy == 0:
		battle.result = 1
		if is_expedition:
			resolve_expedition_fight(true)
			return
		var story_win: bool = battle.story>=0
		var reward: int = (45+int(battle.map)*15 if story_win else 31) + data.people.size()*3 + (14 if data.map==3 else 0)
		var coins := 32 if story_win else 8
		data.qi += reward
		data.stones += coins
		data.victories += 1
		if story_win:
			data.story_chapter = battle.story+1
		battle.note = "获胜 · 修为 +%d · 灵石 +%d" % [reward,coins]
		var opponent: String = Chronicle.CHAPTERS[battle.story].foe if story_win else FOES[battle.map]
		record("主线" if story_win else "斗法","战胜%s，修为 +%d，灵石 +%d。" % [opponent,reward,coins])
		return
	if heal:
		if is_expedition:
			data.expedition.herbs-=1
		else:
			data.herbs-=1
		battle.healed = mini(31,battle.maxhp-battle.hp)
		battle.hp += battle.healed
		if not is_expedition:
			save_game()
	if spirit==3:
		battle.healed=mini(22,battle.maxhp-battle.hp)
		battle.hp+=battle.healed
	var force := foe_damage(move)
	var damage: int = ceili(force*.22) if guard else force
	if spirit==2:
		damage=ceili(force*.5)
	elif spirit==3:
		damage=maxi(0,damage-14)
	battle.taken = 0 if battle.interrupt or spirit==0 else maxi(0,damage-int(battle.get("guard",0)))
	if relic==Expedition.Relic.TIDE and move[2]=="heavy" and not guard and battle.taken>0 and not battle.get("relic_spent",false):
		var absorbed: int = mini(14,int(battle.taken))
		battle.taken-=absorbed
		battle.relic_spent=true
		battle.relic_note="潮甲印 · 抵消 %d 伤害" % absorbed
	var warded := Expedition.absorb_remedy_ward(battle,battle.taken)
	battle.taken-=warded
	battle.hp = maxi(0,battle.hp-battle.taken)
	battle.charge = guard or (heal and battle.charge)
	battle.turn += 1
	if spirit>=0:
		battle.note = "%s · 造成 %d · 恢复 %d · 承伤 %d。" % [Expedition.PET_MOVES[spirit][0],battle.hit,battle.healed,battle.taken]
	elif battle.interrupt:
		battle.note = "破阵诀打断%s，造成 %d 伤害。" % [move[0],battle.hit]
	elif guard:
		battle.note = "架剑承伤 %d，获得 2 点剑意，下一次御剑斩蓄力。" % battle.taken
	elif heal:
		battle.note = "气血恢复 %d，承受 %d 点反击。" % [battle.healed,battle.taken]
	else:
		battle.note = "造成 %d 伤害，承受 %d 点反击。" % [battle.hit,battle.taken]
	if warded>0:
		battle.note+=" 镇煞符减伤 %d。" % warded
	if signature and not battle.interrupt and spirit!=0 and warded==0:
		apply_boss_signature(guard)
	if battle.hp==0:
		battle.result = -1
		if is_expedition:
			resolve_expedition_fight(false)
			return
		var lost := 0 if battle.story>=0 else 10
		data.stones -= lost
		battle.note = "%s力竭。可调整招式再战。" % hero_name()
		record("斗法",("%s撤回山门。" if lost==0 else "%s撤回山门，损失 10 灵石。") % hero_name())
	elif is_expedition:
		store_expedition_battle()

func apply_boss_signature(guarded: bool) -> void:
	match int(battle.map):
		0:
			var restored: int = mini(16,int(battle.maxenemy)-int(battle.enemy))
			battle.enemy+=restored
			battle.note+=" 古甲恢复 %d 气血。" % restored
		1:
			if not guarded and data.expedition.herbs>0:
				data.expedition.herbs-=1
				battle.note+=" 一株灵草被烧毁。"
		2:
			var drained: int = mini(2,int(battle.focus))
			battle.focus-=drained
			battle.note+=" 失去 %d 点剑意。" % drained
		3:
			if not guarded:
				battle.frost=12
				battle.note+=" 结霜，下回合御剑斩减 12 伤害。"

func leave_battle() -> void:
	if battle.is_empty():
		return
	if battle.get("expedition",false):
		if battle.result==0:
			store_expedition_battle()
		battle.clear()
		return
	if battle.result==0:
		record("斗法","%s收剑离开了战场。" % hero_name())
	battle.clear()

func facility_cost(building: String) -> Array:
	var current: int = data.facilities[building]
	return [35+current*24-(12 if duty_member("works",true)>=0 else 0),2+current*2]

func upgrade_facility(building: String) -> bool:
	if not data.facilities.has(building) or data.facilities[building]>=3:
		return false
	var cost := facility_cost(building)
	if data.stones<cost[0] or data.dust<cost[1]:
		return false
	data.stones-=cost[0]
	data.dust-=cost[1]
	data.facilities[building]+=1
	for item in Expedition.BUILDINGS:
		if item[0]==building:
			record("宗门","%s升至 %d 级。下次启程时生效。" % [item[1],data.facilities[building]],false)
			break
	return true

func expedition_forecast(use_scout := false) -> Dictionary:
	var forecast := Expedition.plan(data.map,int(data.expedition_serial)+1)
	if use_scout and data.scout_token>0:
		forecast.steps[2].append("survey")
	return forecast

func relic_unlocked(relic: int) -> bool:
	return relic>=0 and relic<Expedition.RELICS.size() and data.expedition_wins[relic]>0

func can_brew_remedy(id: int) -> bool:
	if id<0 or id>=Expedition.REMEDIES.size():
		return false
	var recipe: Dictionary = Expedition.REMEDIES[id]
	return data.herbs>=recipe.herbs and data.stones>=recipe.stones

func brew_remedy(id: int) -> bool:
	if not can_brew_remedy(id):
		return false
	var recipe: Dictionary = Expedition.REMEDIES[id]
	data.herbs-=recipe.herbs
	data.stones-=recipe.stones
	data.remedies[id]+=1
	record("丹房","炼成一份%s。" % recipe.name,false)
	return true

func use_turn_remedy() -> bool:
	if battle.get("action_duel",false) or not battle.get("expedition",false):
		return false
	var hp: int = battle.hp
	var message := Expedition.apply_remedy(battle)
	if message.is_empty():
		return false
	battle.healed=battle.hp-hp
	battle.hit=0
	battle.taken=0
	battle.relic_note=""
	battle.note=message+" · 可继续出招。"
	store_expedition_battle()
	return true

func start_expedition(guide: int,pet: int,packed: int,tier: int,commission := "",relic := -1,use_scout := false,action := false,remedy := -1) -> bool:
	if not data.expedition.is_empty() or not battle.is_empty() or not guide_available(guide) or pet< -1 or pet>=data.pets.size():
		return false
	if packed<0 or packed>3 or packed>data.herbs or tier<0 or tier>1 or (tier==1 and data.expedition_wins[data.map]<1):
		return false
	if use_scout and data.scout_token<1:
		return false
	var forecast := expedition_forecast(use_scout)
	if not commission.is_empty() and commission not in forecast.offers:
		return false
	if relic!=-1 and not relic_unlocked(relic):
		return false
	if remedy!=-1 and (remedy<0 or remedy>=Expedition.REMEDIES.size() or data.remedies[remedy]<=0):
		return false
	var group := guide%Expedition.ROLES.size() if guide>=0 else -1
	var cap: int = 83 + int(data.rank)*9 + data.facilities.medicine_hall*12 + (18 if group==1 else 0) + (12 if pet==0 else 0)
	var attack: int = data.facilities.sword_hall*4
	data.herbs-=packed
	if use_scout:
		data.scout_token-=1
	if remedy>=0:
		data.remedies[remedy]-=1
	data.expedition_serial+=1
	data.expedition_relic_preset=relic
	data.expedition = {
		"area":data.map,"rank":data.rank,"serial":data.expedition_serial,"step":0,"tier":tier,"history":[],
		"hp":cap,"maxhp":cap,"herbs":packed+int(group==2),"coins":0,"dust":0,"combat":{},
		"guide":data.people[guide] if guide>=0 else "独行","pet":data.pets[pet] if pet>=0 else "无随行灵兽",
		"itinerary":forecast.steps,"route_name":forecast.name,"commission":commission,
		"surveyed":use_scout,
		"action":action and data.map==0,
		"boss_tactics":true,"spirit_index":pet,"spirit_charges":int(pet>=0),
		"relic":relic,
		"remedy":remedy,"remedy_used":false,
		"boost":0,"focus":data.facilities.observatory+int(pet==2),"guard":4 if pet==3 else 0,
		"slash":attack+(5 if group==0 else 0),"spell":attack+(8 if pet==1 else 0)
	}
	record("远征","从%s启程，进入遗灯秘境。" % MAPS[data.map][1],false)
	return true

func expedition_choices() -> Array:
	var run: Dictionary = data.expedition
	if run.is_empty() or not run.combat.is_empty() or run.step>=Expedition.DEPTH:
		return []
	return Expedition.run_step(run,run.step)

func expedition_can_take(option: String) -> bool:
	return option in expedition_choices() and expedition_block_reason(option).is_empty()

func expedition_block_reason(option: String) -> String:
	var run: Dictionary = data.expedition
	if option in ["relay","tunnel"] and run.herbs<1:
		return "需要 1 株灵草。"
	var risk: int = {"bridge":14,"reeds":9,"beacon":12}.get(option,0)
	if risk>0 and run.hp<=risk:
		return "气血须高于 %d。" % risk
	if option=="caravan" and run.coins<8:
		return "本轮战利品须有 8 灵石。"
	if option=="medicine_cache" and run.dust<1:
		return "本轮战利品须有 1 灯砂。"
	if option=="seal" and run.dust<Expedition.SEAL_ENTRY:
		return "本轮战利品须有 %d 灯砂。" % Expedition.SEAL_ENTRY
	return ""

func expedition_take(option: String) -> bool:
	if not expedition_can_take(option):
		return false
	var run: Dictionary = data.expedition
	run.history.append(option)
	match option:
		"trail","ambush","elite","seal","boss":
			if option=="seal":
				run.dust-=Expedition.SEAL_ENTRY
			start_expedition_battle(option)
			return true
		"pool":
			run.herbs+=1
			run.coins+=9+int(run.area)*3
		"rest":
			run.hp=mini(run.maxhp,run.hp+24)
		"relay":
			run.herbs-=1
			run.dust+=2+int(run.tier)
			run.focus+=1
		"bridge":
			run.hp-=14
			run.coins+=19
			run.dust+=2
		"survey":
			run.coins+=14
			run.dust+=1
		"camp":
			run.hp=mini(run.maxhp,run.hp+36)
			run.herbs+=1
		"shrine":
			run.boost+=7
		"reeds":
			run.hp-=9
			run.herbs+=2
		"tower":
			run.coins+=8
			run.focus+=1
		"caravan":
			run.coins-=8
			run.hp=mini(run.maxhp,run.hp+36)
			run.herbs+=1
		"tunnel":
			run.herbs-=1
			run.coins+=13
			run.dust+=2
		"beacon":
			run.hp-=12
			run.dust+=1
			run.boost+=7
		"medicine_cache":
			run.dust-=1
			run.hp=mini(run.maxhp,run.hp+42)
			run.herbs+=1
	run.step+=1
	record("远征","经过%s，继续深入秘境。" % Expedition.OPTIONS[option][0],false)
	return true

func start_expedition_battle(option: String) -> void:
	var run: Dictionary = data.expedition
	var power: int = int(run.area)*14+int(run.tier)*25
	var cap: int = Expedition.ENCOUNTERS[option][0]+power
	var relic: int = run.get("relic",-1)
	var restored := 0
	if relic==Expedition.Relic.FROST and int(run.hp)*2<=int(run.maxhp):
		restored=mini(18,int(run.maxhp)-int(run.hp))
		run.hp+=restored
	battle = {
		"map":run.area,"rank":run.rank,"story":-1,"expedition":true,"expedition_node":option,"turn":1,"tier":run.tier,
		"hp":run.hp,"maxhp":run.maxhp,"enemy":cap,"maxenemy":cap,"charge":false,
		"focus":mini(3,run.focus),"note":"从上一段路线带入 %d 气血。" % run.hp,
		"result":0,"hit":0,"taken":0,"action":"","interrupt":false,"healed":0,
		"boss_tactics":option=="boss" and run.get("boss_tactics",false),"signature_used":false,
		"action_duel":run.get("action",false),
		"remedy":run.get("remedy",-1),"remedy_used":run.get("remedy_used",false),
		"relic":relic,"relic_spent":false,"relic_note":"玄霜灯芯 · 开场恢复 %d 气血" % restored if restored>0 else "",
		"slash":run.slash+run.boost,"spell":run.spell+run.boost,"guard":run.guard
	}
	store_expedition_battle()

func store_expedition_battle() -> void:
	if not data.expedition.is_empty():
		data.expedition.remedy_used=battle.get("remedy_used",false)
		data.expedition.combat=battle.duplicate(true)
		data.expedition.hp=battle.hp
		save_game()

func resume_expedition_battle() -> bool:
	if not battle.is_empty() or data.expedition.is_empty() or data.expedition.combat.is_empty():
		return false
	battle=data.expedition.combat.duplicate(true)
	return true

func expedition_herbs() -> int:
	return data.expedition.herbs if battle.get("expedition",false) else data.herbs

func resolve_expedition_fight(won: bool) -> void:
	var run: Dictionary = data.expedition
	run.hp=battle.hp
	run.remedy_used=battle.get("remedy_used",false)
	run.combat.clear()
	if not won:
		battle.note="%s败退，带回一半灵石。" % hero_name()
		finish_expedition("败退")
		return
	var node: String = battle.expedition_node
	var encounter: Array = Expedition.ENCOUNTERS[node]
	var coins: int = encounter[2]+int(run.area)*6+int(run.tier)*12
	var grains: int = 0 if node=="seal" else encounter[3]+int(run.tier)*2
	run.coins+=coins
	run.dust+=grains
	run.step+=1
	battle.note="缴获 %d 灵石与 %d 灯砂。" % [coins,grains]
	if node=="ambush":
		run.herbs+=1
		battle.note+=" 找到 1 株灵草。"
	if node=="seal":
		run.boost+=Expedition.SEAL_BOOST
		run.sealed_dust=Expedition.seal_reward(run.tier)
		battle.note="封灯试炼告捷 · 伤害 +%d · 封存 %d 灯砂 · 缴获 %d 灵石。" % [Expedition.SEAL_BOOST,run.sealed_dust,coins]
	if node=="boss":
		finish_expedition("破关")
	else:
		record("远征",battle.note,false)

func extract_expedition() -> bool:
	var run: Dictionary = data.expedition
	if run.is_empty() or not run.combat.is_empty() or run.step<1:
		return false
	finish_expedition("撤回")
	return true

func expedition_commission_met(run: Dictionary,result: String) -> bool:
	if result=="败退":
		return false
	var visited: Array = run.history.slice(0,run.step)
	match run.get("commission",""):
		"hunt": return result=="破关" and ("elite" in visited or "ambush" in visited)
		"herbs": return result=="破关" and run.herbs>=2
		"safe": return run.step>=3 and run.hp*3>=run.maxhp*2
		"trace": return Expedition.trace_site(run.itinerary) in visited
	return false

func expedition_commission_progress(run: Dictionary) -> String:
	var visited: Array = run.history.slice(0,run.step)
	match run.get("commission",""):
		"hunt": return "额外守卫已击退，继续挑战灯门。" if "elite" in visited or "ambush" in visited else "还需击退裂石阵守卫或拦灯伏兵。"
		"herbs": return "可带回 %d / 2 株灵草，仍须破关。" % run.herbs
		"safe": return "%d / 3 段，气血 %d / %d（须保有 %d）" % [mini(run.step,3),run.hp,run.maxhp,ceili(2.0*run.maxhp/3.0)]
		"trace": return "已找到遗迹，可破关或撤回。" if Expedition.trace_site(run.itinerary) in visited else "沿途寻找委托指定的遗迹。"
	return ""

func finish_expedition(result: String) -> void:
	var run: Dictionary = data.expedition
	var survived := result!="败退"
	var coins: int = run.coins if survived else int(run.coins/2.0)
	var grains: int = run.dust if survived else 0
	var herbs: int = run.herbs if survived else 0
	var experience: int = 35+int(run.area)*16+int(run.tier)*20 if result=="破关" else 0
	var commission: String = run.get("commission","")
	var completed := expedition_commission_met(run,result)
	var bonus_coins: int = Expedition.COMMISSIONS[commission][2] if completed else 0
	var bonus_dust: int = Expedition.COMMISSIONS[commission][3] if completed else 0
	var sealed: int = run.get("sealed_dust",0)
	var sealed_paid := sealed if result=="破关" else 0
	coins+=bonus_coins
	grains+=bonus_dust+sealed_paid
	if completed:
		data.expedition_commissions+=1
	var new_relic := -1
	if result=="破关":
		if not relic_unlocked(run.area):
			new_relic=run.area
		data.expedition_wins[run.area]+=1
	data.stones+=coins
	data.dust+=grains
	data.herbs+=herbs
	data.qi+=experience
	var returned: int = run.get("remedy",-1) if survived and not run.get("remedy_used",false) else -1
	if returned>=0:
		data.remedies[returned]+=1
	data.expedition_last = {"result":result,"coins":coins,"dust":grains,"herbs":herbs,"qi":experience,"area":run.area,"steps":run.step,"tier":run.tier}
	data.expedition_last.merge({"commission":commission,"commission_done":completed,"bonus_coins":bonus_coins,"bonus_dust":bonus_dust})
	data.expedition_last.relic_unlocked=new_relic
	data.expedition_last.remedy_returned=returned
	data.expedition_last.merge({"sealed_dust":sealed,"sealed_paid":sealed_paid})
	data.expedition={}
	var note := "远征%s，入账 %d 灵石、%d 灯砂。" % [result,coins,grains]
	if new_relic>=0:
		note="首次破关，收获「%s」。" % Expedition.RELICS[new_relic][0]
	record("远征",note)

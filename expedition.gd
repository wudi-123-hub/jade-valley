extends RefCounted

const DEPTH = 5
const SEAL_ENTRY = 2
const SEAL_BOOST = 9
const SEQUENCES = [["trail","pool"],["relay","rest"],["elite","bridge"],["camp","shrine"],["boss"]]
const ROUTES = [
	["旧灯驿道",[["trail","pool"],["relay","rest"],["elite","bridge"],["camp","shrine"],["boss"]]],
	["雾岚水路",[["trail","reeds"],["caravan","tower"],["elite","tunnel"],["camp","beacon"],["boss"]]],
	["断桥山径",[["pool","tower"],["ambush","rest"],["elite","bridge"],["medicine_cache","shrine"],["boss"]]],
	["悬灯古峡",[["trail","reeds"],["ambush","rest"],["elite","bridge"],["camp","beacon"],["boss"]]]
]
const OPTIONS = {
	"trail":["巡灯石径","斗法", "用一场短战换取灵石与灯砂。","sword"],
	"pool":["引泉小径","补给", "沿水采集野生灵草，并拾取少量灵石。","sprout"],
	"relay":["守灯人","交换", "交出一株行囊灵草，换取灯砂与接下来战斗的剑意。","flame"],
	"rest":["回音洞","休整", "停下来处理伤口，恢复 24 气血。","moon"],
	"elite":["裂石阵","强敌", "与精英守卫交手，掉落比石径更多的灯砂。","spark"],
	"bridge":["悬索桥","捷径", "绕开守卫，但攀爬会损失 14 气血。","compass"],
	"survey":["勘察小径","捷径","按弟子的标记绕开险地，不损失气血，找到 14 灵石和 1 灯砂。","compass"],
	"camp":["山间营火","休整", "恢复 36 气血，并补充一株灵草。","moon"],
	"shrine":["故人灯龛","祝福", "放弃休整，换取余下战斗的御剑与破阵伤害。","hall"],
	"reeds":["寒露苇滩","采药","损失 9 气血，采得 2 株灵草。","sprout"],
	"tower":["观星木楼","整备","拾得 8 灵石，之后每场战斗开局获得 1 点剑意。","compass"],
	"caravan":["山脚药担","交易","用本轮战利品中的 8 灵石换取 36 气血和 1 株灵草。","sprout"],
	"tunnel":["旧祭密道","绕行","交出 1 株灵草引路，得到 13 灵石和 2 灯砂。","compass"],
	"beacon":["悬崖孤灯","祝福","损失 12 气血，得到 1 灯砂，余下战斗的御剑与破阵伤害各 +7。","flame"],
	"medicine_cache":["行医石龛","补给","消耗 1 灯砂，恢复 42 气血并补充 1 株灵草。","sprout"],
	"ambush":["拦灯伏兵","遭遇","伏兵第一招便是重击。取胜可带走灵石、灯砂和 1 株灵草。","sword"],
	"seal":["封灯试炼","试炼","消耗灯砂挑战封灯獒。取胜可强化守关战，击破灯门才兑现封存灯砂。","flame"],
	"boss":["遗灯之门","守关", "击败守关灵兽，带回灯砂与远征赏金。","lock"]
}
const ENCOUNTERS = {
	"trail":[51,9,15,1],"ambush":[62,6,20,2],"elite":[72,5,28,3],"seal":[68,4,16,0],"boss":[87,0,52,4]
}
const COMMISSIONS = {
	"hunt":["破阵请帖", "击退裂石阵守卫或拦灯伏兵，再击破遗灯之门。", 24, 4],
	"herbs":["两株续灯草", "击破遗灯之门，结算时带回至少 2 株灵草。", 28, 3],
	"safe":["护命归途", "走完至少 3 段，保持三分之二以上气血，再破关或主动撤回。", 18, 2],
	"trace":["访旧寻迹", "经过%s后破关或主动撤回。", 16, 3]
}
const COMMISSION_PAIRS = [["hunt","herbs"],["trace","safe"],["herbs","safe"],["trace","hunt"]]
const KINDS = ["启程","林间","险地","整备","灯门"]
const BOSSES = ["沉潭古甲","焰翎蜃龙","霜枫镜鸮","寒阙雪狮"]
const FOES = {"trail":"巡灯兽","elite":"披甲巡灯兽","ambush":"伏灯山灵","seal":"封灯獒"}
enum Remedy { HEAL, FOCUS, WARD }
const REMEDIES = [
	{"name":"回春散","herbs":2,"stones":10,"amount":26,"hint":"立刻恢复至多 26 气血。适合少走休整点的路线。"},
	{"name":"凝锋丸","herbs":2,"stones":14,"amount":2,"hint":"立刻获得至多 2 点剑意。留给需要打断的敌招。"},
	{"name":"镇煞符","herbs":3,"stones":16,"amount":16,"hint":"本场下一次受伤减免至多 16 点，抵消这次绝技的附带效果。"}
]
enum Relic { TIDE, FLAME, MIRROR, FROST }
const RELICS = [
	["潮甲印","每场首次未架剑而承受重击时，减免至多 14 伤害。","shield"],
	["焰纹剑穗","每场首次用破阵诀打断敌招时，额外造成 12 伤害。","sword"],
	["镜台羽铃","每次使用行囊灵草疗伤，同时获得 2 点剑意。","spark"],
	["玄霜灯芯","带着半血或更低的气血进战时，开场恢复 18 气血。","flame"]
]
const MOVES = [
	[["碧岩扑",12,"light"],["灯甲砸阵",33,"heavy"],["镇潮合甲",17,"ward"]],
	[["焰尾横扫",16,"light"],["双尾吞焰",38,"heavy"],["回卷火鳞",17,"ward"]],
	[["碎叶扫翼",20,"light"],["折光镜盾",19,"ward"],["十里枫焰",43,"heavy"]],
	[["霜爪扫击",23,"light"],["晶柱坠阵",46,"heavy"],["冰脊护甲",20,"ward"]]
]
const BOSS_SIGNATURES = [
	["地脉回壳",16,"ward","未打断则古甲恢复 16 气血。"],
	["焚灯迸火",37,"heavy","未架剑或打断则烧掉 1 株行囊灵草。"],
	["借镜封剑",22,"ward","未打断则失去至多 2 点剑意。"],
	["寒灯合围",48,"heavy","未架剑或打断则结霜，下回合御剑基础伤害 −12。"]
]
const BUILDINGS = [
	["sword_hall","剑阁","御剑斩与破阵诀每级 +4 伤害。","training","sword"],
	["medicine_hall","炼药房","远征气血上限每级 +12。","garden","sprout"],
	["observatory","观灯台","每级使远征开战时获得 1 点剑意。","seasons","flame"]
]
const ROLES = [
	["剑修","御剑斩 +5 伤害。"],["医修","气血上限 +18。"],["寻灯使","启程时额外携带 1 株野生灵草。"]
]
const PET_TRAITS = [
	"苔苔护身，气血上限 +12。","赤绒借火，破阵诀 +8 伤害。",
	"枫啾鸣警，开战时剑意 +1。","雪团护阵，每次承伤 −4。"
]
const PET_MOVES = [
	["磐鳞守护","抵消本回合攻击及绝技效果，剑意 +1。"],
	["借火破阵","造成随境界成长的伤害，可打断重击和守势。"],
	["风鸣引剑","立即攒满剑意，将本回合承伤减半。"],
	["霜息疗护","恢复至多 22 气血，本回合再减免 14 伤害。"]
]

static func route_step(step: int,area: int,serial: int) -> Array:
	var row: Array = SEQUENCES[step].duplicate()
	if row.size()==2 and (step+area+serial)%2==0:
		row.reverse()
	return row

static func plan(area: int,serial: int) -> Dictionary:
	var index := posmod(area+serial-1,ROUTES.size())
	var route: Array = ROUTES[index]
	var itinerary: Array = route[1].duplicate(true)
	for step in itinerary.size():
		if itinerary[step].size()==2 and (step+area+serial)%2==0:
			itinerary[step].reverse()
	itinerary[3].append("seal")
	return {"name":route[0],"steps":itinerary,"offers":COMMISSION_PAIRS[index].duplicate()}

static func seal_reward(tier: int) -> int:
	return 6+tier*2

static func run_step(run: Dictionary,depth: int) -> Array:
	if run.has("itinerary"):
		return run.itinerary[depth]
	return route_step(depth,run.area,run.serial)

static func trace_site(steps: Array) -> String:
	return "beacon" if "beacon" in steps[3] else "shrine"

static func commission_brief(key: String,steps: Array) -> String:
	var brief: String = COMMISSIONS[key][1]
	return brief % OPTIONS[trace_site(steps)][0] if key=="trace" else brief

static func remedy_block(battle: Dictionary) -> String:
	var id: int = battle.get("remedy",-1)
	if id<0 or battle.result!=0:
		return "当前无法用药。"
	if battle.get("remedy_used",false):
		return "本趟已用。"
	if id==Remedy.HEAL and battle.hp>=battle.maxhp:
		return "气血已满。"
	if id==Remedy.FOCUS and battle.focus>=3:
		return "剑意已满。"
	return ""

static func apply_remedy(battle: Dictionary) -> String:
	if not remedy_block(battle).is_empty():
		return ""
	var recipe: Dictionary = REMEDIES[battle.remedy]
	battle.remedy_used=true
	match int(battle.remedy):
		Remedy.HEAL:
			var healed: int = mini(recipe.amount,battle.maxhp-battle.hp)
			battle.hp+=healed
			return "%s · 气血 +%d" % [recipe.name,healed]
		Remedy.FOCUS:
			var gained: int = mini(recipe.amount,3-battle.focus)
			battle.focus+=gained
			return "%s · 剑意 +%d" % [recipe.name,gained]
		_:
			battle.remedy_ward=recipe.amount
			return "%s · 已护阵" % recipe.name

static func absorb_remedy_ward(battle: Dictionary,damage: int) -> int:
	if damage<=0:
		return 0
	var absorbed := mini(damage,battle.get("remedy_ward",0))
	battle.erase("remedy_ward")
	return absorbed

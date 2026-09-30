"""Phase 4 — the coast and the sea: "the sea is not empty space between
coasts; it is another part of the world".

South sea network (all reachable from the Dawn wreck shore):
  Gull Current (swim or sail) -> Tidewarden Light (relight at night: chart)
  -> current -> Vigil Rock (climb the spire, glide) -> Gull's Promise (wreck
  on a shoal: deck hatch / hull breach / stern windows, a jammed cabin)
  -> return current to the shore.
  Further out (the Bellhull's sea): Castaways' Islet (a story told in
  objects, a castaway at dusk), Crystal Reef (safe and rich in fair weather,
  lightning spires in storms), the Iron Leviathan (deep wreck, dive), the
  Vanishing Bar (an isle that exists only at low tide), deep-water fishing.
West coast: Tide Isle (sandbar at low tide, surf at high tide, drowned side
tunnel, storm blowhole) with a kelp lagoon and a sunk smugglers' skiff.
Everything reuses the lake's water systems.
"""
import math
from qdsl import L
from world import npc


def yaw_to(a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dz)
    return round(math.degrees(math.atan2(-dx / n, -dz / n)), 1), round(n, 1)


# --- Terrain: islets and reefs (world.json "islets") ----------------------------------------------------
ISLETS = [
    {"id": "lighthouse_rock", "pos": [150, 1000], "radius": 20, "height": 9.0, "shape": "mound"},
    {"id": "vigil_rock", "pos": [-60, 1160], "radius": 22, "height": 7.0, "shape": "mound"},
    {"id": "promise_shoal", "pos": [30, 1250], "radius": 30, "height": -4.0, "shape": "shelf"},
    {"id": "castaway_islet", "pos": [-420, 1060], "radius": 32, "height": 6.0, "shape": "mound"},
    {"id": "crystal_reef", "pos": [560, 1020], "radius": 55, "height": -0.9, "shape": "shelf"},
    {"id": "vanishing_bar", "pos": [320, 1280], "radius": 36, "height": -0.9, "shape": "bar"},
    {"id": "tide_isle", "pos": [-800, 300], "radius": 24, "height": 7.0, "shape": "mound"},
    {"id": "skiff_shoal", "pos": [-835, 262], "radius": 16, "height": -7.0, "shape": "shelf"},
    # Silt bed under the Iron Leviathan: the keel rests on it instead of floating.
    {"id": "leviathan_bed", "pos": [720, 1260], "radius": 30, "height": -18.0, "shape": "shelf"},
]


# --- Places ----------------------------------------------------------------------------------------------
def poi(pid, typ, name, pos, **kw):
    d = {"id": pid, "type": typ, "name_key": "POI_" + pid.upper(), "pos": list(pos)}
    d.update(kw)
    return d, {"POI_" + pid.upper(): name}


POIS = [
    poi("tidewarden_light", "lighthouse", L("Tidewarden Light", "Faro del Guardamareas", "Farol do Guarda-Marés", "Phare du Gardien des marées", "Gezeitenwacht-Leuchtturm", "潮守りの灯台", "조수지기 등대", "守潮灯塔"),
        (150, 1000), flatten=9, pad_height=8.5, clear_radius=14, discover_radius=30, flag="lighthouse_lit", discovery="sea_tidewarden_light",
        reveals=[{"pos": [30, 1250], "radius": 3}, {"pos": [720, 1260], "radius": 3}, {"pos": [-420, 1060], "radius": 3}], reward=[{"id": "tidewarden_chart", "count": 1}]),
    poi("vigil_rock", "sea_spire", L("Vigil Rock", "Islote del Vigía", "Rochedo do Vigia", "Rocher de la Vigie", "Wachtfels", "見張り岩", "망루 바위", "望哨礁"),
        (-60, 1160), flatten=8, pad_height=7.0, clear_radius=14, discover_radius=40, height=44.0, reward=[{"id": "driftwood_charm", "count": 1}]),
    poi("gulls_promise", "wreck", L("The Gull's Promise", "La Promesa de la Gaviota", "A Promessa da Gaivota", "La Promesse de la Mouette", "Das Möwenversprechen", "鴎の約束号", "갈매기의 약속호", "鸥之诺号"),
        (30, 1250), clear_radius=22, discover_radius=36, length=26.0, beam=7.0, sunk=0.3, pitch=6.0, yaw=35.0, roll=14.0, mast=8.0, breach=3,
        cabin_gate="gulls_cabin_open", loot="chest_rare", reward=[{"id": "lake_pearl", "count": 1}],
        guardians=[["ENEMY_HULL_LURKER", 0.5, -3.0, -6.0]],
        pages=[{"id": "gulls_log", "look": "scroll", "at": [1.2, 0.3, 9.6], "item": "gulls_log", "prompt": "PROMPT_TAKE", "radius": 1.6,
                "lines": ["LINE_GULLS_LOG"], "speaker": "POI_GULLS_PROMISE"},
               {"id": "keel_bell", "look": "bell", "at": [-1.5, -3.3, 2.0], "radius": 2.0, "hide_used": False, "sound": "chime", "element": "wind"}]),
    poi("iron_leviathan", "wreck", L("The Iron Leviathan", "El Leviatán de Hierro", "O Leviatã de Ferro", "Le Léviathan de fer", "Der Eiserne Leviathan", "鉄の巨鯨号", "강철 리바이어던", "铁鲸号"),
        (720, 1260), clear_radius=30, discover_radius=30, length=34.0, beam=9.0, sunk=-15.0, pitch=-3.0, yaw=-50.0, roll=-9.0, mast=16.5, breach=5,
        cabin_gate="leviathan_cabin_open", loot="chest_rare", reward=[{"id": "deepwater_mask", "count": 1}, {"id": "abyssal_pearl", "count": 1}],
        guardians=[["ENEMY_HULL_LURKER", -1.0, -3.0, 4.0], ["ENEMY_HULL_LURKER", 1.5, -3.0, -8.0]]),
    poi("smugglers_skiff", "wreck", L("Smugglers' Skiff", "El esquife de los contrabandistas", "O esquife dos contrabandistas", "L'esquif des contrebandiers", "Das Schmugglerboot", "密輸人の小舟", "밀수꾼의 쪽배", "走私小艇"),
        (-835, 262), clear_radius=10, discover_radius=14, length=12.0, beam=4.0, sunk=-5.0, pitch=2.0, yaw=80.0, roll=25.0, mast=5.0, breach=1, vent=False,
        loot="chest_common", reward=[{"id": "resin_bomb", "count": 3}]),
    poi("castaway_islet", "castaway_camp", L("Castaways' Islet", "Islote de los Náufragos", "Ilhota dos Náufragos", "Îlot des Naufragés", "Schiffbrüchigen-Insel", "漂流者の小島", "조난자의 섬", "漂流者小岛"),
        (-420, 1060), flatten=12, pad_height=5.0, clear_radius=18, discover_radius=36, loot="chest_common", reward=[{"id": "castaway_compass", "count": 1}]),
    poi("tide_isle", "tide_cave", L("Tide Isle", "Isla de las Mareas", "Ilha das Marés", "Île des Marées", "Gezeiteninsel", "潮の島", "조수의 섬", "潮汐岛"),
        (-800, 300), flatten=12, pad_height=1.4, clear_radius=16, discover_radius=30, loot="chest_common", reward=[{"id": "lake_pearl", "count": 1}],
        storm_reward=[{"id": "storm_glass", "count": 2}, {"id": "abyssal_pearl", "count": 1}]),
]
# Sabel, the tidekeeper, salvages by the Dawn wreck: the sea's person.
POI_PATCHES = {"dawn_wreck": {"npcs": [["NPC_TIDEKEEPER", -9, -7]]}}

# --- People ---------------------------------------------------------------------------------------------
NPCS = [
    npc("NPC_TIDEKEEPER", "#44a57b", L("Sabel, tidekeeper", "Sabel, guardamareas", "Sabel, guarda-marés", "Sabel, gardienne des marées", "Sabel, Gezeitenwärterin", "潮守りサベル", "조수지기 사벨", "守潮人萨贝尔"),
        [L("The sea keeps a clock. Learn the tides and it opens doors.", "El mar lleva un reloj. Aprende las mareas y abre puertas.", "O mar tem um relógio. Aprenda as marés e ele abre portas.", "La mer a une horloge. Apprenez les marées, elle ouvre des portes.", "Das Meer hat eine Uhr. Lern die Gezeiten, und es öffnet Türen.", "海には時計がある。潮を覚えれば扉が開く。", "바다엔 시계가 있어. 조수를 익히면 문이 열리지.", "海有自己的钟。摸清潮汐，它就为你开门。")],
        night=L("Look south. If the light is dark, nobody's kept it.", "Mira al sur. Si el faro está apagado, nadie lo ha cuidado.", "Olhe ao sul. Se o farol está apagado, ninguém cuidou dele.", "Regardez au sud. Si le phare est éteint, personne ne l'a gardé.", "Schau nach Süden. Ist das Licht dunkel, hat es keiner gehütet.", "南を見ろ。灯が消えていれば、誰も守っていない。", "남쪽을 봐. 불이 꺼져 있으면 아무도 지키지 않은 거야.", "往南看。灯要是黑的，就是没人守。"),
        schedule=[[0, [0, 0]], [6, [4, 6]], [12, [-3, 2]], [18, [0, 0]]]),
    npc("NPC_CASTAWAY", "#bfb370", L("Maren, castaway", "Maren, náufraga", "Maren, náufraga", "Maren, naufragée", "Maren, Schiffbrüchige", "漂流者マレン", "조난자 마렌", "漂流者玛伦"),
        [L("I row back every dusk. Someone should remember them here.", "Vuelvo remando cada atardecer. Alguien debe recordarlos aquí.", "Volto remando todo entardecer. Alguém deve lembrá-los aqui.", "Je reviens à la rame chaque soir. Quelqu'un doit se souvenir d'eux ici.", "Ich rudere jeden Abend her. Jemand muss sich hier an sie erinnern.", "毎夕、漕いで戻る。誰かがここで彼らを覚えていないと。", "매일 해 질 녘에 노 저어 와. 누군가는 여기서 그들을 기억해야지.", "我每个傍晚划船回来。总得有人在这儿记着他们。")],
        schedule=[[0, [0, 0]]]),
]

# --- Creatures ------------------------------------------------------------------------------------------


def atk(aid, typ, **kw):
    d = {"id": aid, "type": typ}
    d.update(kw)
    return d


def ent(eid, kind, color, name, hp, collider, stats, attacks, ai, loot, visual, mult=None, locomotion=None):
    key = "NAME_" + eid.split("_", 1)[1]
    d = {"id": eid, "kind": kind, "name_key": key, "placeholder_color": color, "placeholder_shape": "quadruped", "model": "",
         "collider": collider, "stats": dict({"max_health": hp}, **stats), "ai": ai, "attacks": attacks, "loot_table": loot}
    if mult:
        d["element_mult"] = mult
    if locomotion:
        d["locomotion"] = locomotion
    fam = "enemy" if kind == "ENEMY" else "wildlife"
    return d, {key: name}, dict({"id": eid, "family": fam}, **visual)


_E = [
    # Surface predator: the fin cuts the water while it shadows you; then it strikes.
    ent("ENEMY_FINBACK", "ENEMY", "#0c70b9", L("Finback", "Aletalomo", "Dorso-de-barbatana", "Dos-d'aileron", "Flossenrücken", "背ビレ", "등지느러미", "背鳍鲨"), 70,
        {"radius": 0.7, "height": 0.9}, {"poise": 18, "walk_speed": 2.6, "run_speed": 6.8, "turn_speed": 4, "mass": 90},
        [atk("maul", "lunge", range_min=0, range_max=5.5, windup=0.55, active=0.35, recovery=0.9, cooldown=2.0, damage=16, knockback=8, reach=2.0, arc=45, lunge_speed=13)],
        {"sight_range": 26, "fov": 300, "hearing": 1.8, "leash": 60, "wander_radius": 16, "respawn_hours": 48,
         "behaviors": ["submerge"], "surface_range": 9, "surface_time": 3.0, "deep_depth": 3.2, "fin_depth": 0.55, "swim_depth": 0.6},
        "drop_finback", {"rank": "elite", "species": "finback", "features": []}, {"electric": 1.4, "fire": 0.5}, locomotion="aquatic"),
    # Swarm: a glinting school that rings you and darts in one at a time.
    ent("ENEMY_NEEDLEFIN", "ENEMY", "#82c3bf", L("Needlefin", "Agujaleta", "Agulha-barbatana", "Aiguillon", "Nadelflosse", "針ビレ", "바늘지느러미", "针鳍鱼"), 10,
        {"radius": 0.25, "height": 0.35}, {"poise": 2, "walk_speed": 3.0, "run_speed": 7.5, "turn_speed": 12, "mass": 4},
        [atk("dart", "lunge", range_min=0, range_max=3.5, windup=0.35, active=0.25, recovery=0.6, cooldown=1.6, damage=3, knockback=1, reach=1.0, arc=60, lunge_speed=12)],
        {"sight_range": 18, "fov": 360, "hearing": 2.0, "leash": 40, "wander_radius": 8, "respawn_hours": 24, "swim_depth": 1.0, "behaviors": ["swarm"]},
        "drop_needlefin", {"species": "finback", "rank": "common", "features": [], "scale": 0.32}, {"electric": 2.0}, locomotion="aquatic"),
    # Storm creature: exists only in storms, skims the waves, drinks the lightning.
    ent("ENEMY_STORM_RAY", "ENEMY", "#4723a5", L("Storm Ray", "Raya de tormenta", "Raia-da-tempestade", "Raie d'orage", "Sturmrochen", "嵐エイ", "폭풍 가오리", "雷鳐"), 55,
        {"radius": 0.8, "height": 0.6}, {"poise": 12, "walk_speed": 3.5, "run_speed": 8.5, "turn_speed": 5, "mass": 40},
        [atk("swoop", "module", windup=0.8, damage=12, knockback=7, charge_speed=20, element="electric"),
         atk("arc", "projectile", range_min=5, range_max=18, windup=0.6, recovery=0.8, cooldown=3.0, damage=8, element="electric", projectile_speed=22)],
        {"sight_range": 30, "fov": 360, "hearing": 1.5, "leash": 70, "wander_radius": 20, "respawn_hours": 12, "hover": 1.6, "storm_only": True,
         "behaviors": ["swoop", "storm_charged"], "swoop_height": 6, "swoop_every": 6.0},
        "drop_storm_ray", {"rank": "elite", "species": "ray", "features": []}, {"electric": 0.0, "fire": 1.3}, locomotion="flying"),
    # Wreck guardian: a big crab that sits in a hold, armoured in front, walks the sea bed.
    ent("ENEMY_HULL_LURKER", "ENEMY", "#a42b4a", L("Hull Lurker", "Acechador del casco", "Espreitador do casco", "Guetteur de coque", "Rumpflauerer", "船底の潜み", "선체 잠복자", "船腹潜伏者"), 90,
        {"radius": 0.9, "height": 1.0}, {"defense": 2, "poise": 40, "walk_speed": 1.6, "run_speed": 3.8, "turn_speed": 3.5, "mass": 180},
        [atk("pinch", "melee", range_min=0, range_max=2.6, windup=0.6, recovery=0.8, cooldown=1.4, damage=14, knockback=6, reach=2.2, arc=55, weight=2),
         atk("slam", "slam", range_min=0, range_max=3.2, windup=1.1, recovery=1.2, cooldown=5.0, damage=18, radius=3.2, knockback=9, blockable=False)],
        {"sight_range": 10, "fov": 200, "hearing": 1.4, "leash": 20, "wander_radius": 3, "respawn_hours": 96, "amphibious": True,
         "behaviors": ["ambush", "front_armor"], "ambush_range": 4.5, "armor_arc": 70, "armor_mult": 0.15, "flipped_time": 3.5},
        "drop_hull_lurker", {"rank": "elite", "species": "crab", "features": ["pincers", "back_plates"], "scale": 1.3}, {"electric": 1.6}),
    # The gentle giant: rises to breathe (a spout seen from far), never attacks.
    ent("ANIMAL_DRIFT_WHALE", "ANIMAL", "#7e446e", L("Drift whale", "Ballena errante", "Baleia-errante", "Baleine dérivante", "Treibwal", "漂い鯨", "떠도는 고래", "漂鲸"), 400,
        {"radius": 2.2, "height": 2.2}, {"poise": 200, "walk_speed": 1.6, "run_speed": 3.2, "turn_speed": 1.2, "mass": 3000},
        [], {"sight_range": 20, "fov": 300, "hearing": 1.0, "skittish": 0.9, "wander_radius": 60, "respawn_hours": 48,
             "swim_depth": 2.5, "behaviors": ["surfacer"], "breathe_every": 14, "breathe_time": 5},
        "drop_whale", {"species": "whale", "features": [], "scale": 1.0}, locomotion="aquatic"),
]
ENTITIES = [(d, l) for d, l, _v in _E]
VISUALS = [v for _d, _l, v in _E] + [
    {"id": "NPC_TIDEKEEPER", "family": "human", "role": "tidekeeper", "build": "slim", "age": "adult", "hair": "ponytail", "headwear": "bandana", "outfit": "coat", "accessories": ["rope", "lantern", "scarf"]},
    {"id": "NPC_CASTAWAY", "family": "human", "role": "castaway", "build": "average", "age": "elder", "hair": "wild", "headwear": "hat_wide", "outfit": "cloak", "accessories": ["rod", "gourd"]},
]

LOOT = {
    "drop_finback": [{"id": "finback_tooth", "chance": 1.0, "count": [1, 2]}, {"id": "raw_fish", "chance": 0.5, "count": [1, 2]}],
    "drop_needlefin": [{"id": "raw_fish", "chance": 0.3, "count": [1, 1]}],
    "drop_storm_ray": [{"id": "storm_glass", "chance": 0.6, "count": [1, 1]}, {"id": "ray_wing", "chance": 0.8, "count": [1, 1]}],
    "drop_hull_lurker": [{"id": "carapace_shard", "chance": 1.0, "count": [2, 3]}, {"id": "lake_pearl", "chance": 0.25, "count": [1, 1]}],
    "drop_whale": [{"id": "raw_fish", "chance": 0.0, "count": [1, 1]}],
}

# --- Items ------------------------------------------------------------------------------------------------


def item(iid, cat, name, desc, **kw):
    d = {"id": iid, "category": cat}
    d.update(kw)
    return d, {"ITEM_" + iid.upper(): name, "ITEM_" + iid.upper() + "_DESC": desc}


def fish(iid, name, desc, heal, cook, value, rarity=1):
    kw = {"icon": "res://assets/icons/food_meat.svg", "use_action": "eat", "value": value, "effects": [{"type": "heal", "amount": heal}], "cook": cook, "tags": ["fish"]}
    if rarity > 1:
        kw["rarity"] = rarity
    return item(iid, "food", name, desc, **kw)


ITEMS = [
    fish("bluewater_runner", L("Bluewater runner", "Corredor de altamar", "Corredor-de-alto-mar", "Coureur du large", "Hochseeläufer", "外洋の走り魚", "먼바다 질주어", "远洋奔鱼"),
         L("Only out where the water goes dark blue. Fast, lean, full of go.", "Solo donde el agua se vuelve azul oscuro. Rápido y magro.", "Só onde a água fica azul-escura. Rápido e magro.", "Seulement là où l'eau devient bleu sombre. Rapide et maigre.", "Nur draußen, wo das Wasser dunkelblau wird. Schnell und mager.", "水が紺になる沖だけ。速く、身は締まる。", "물이 짙푸러지는 먼바다에서만. 빠르고 날렵하다.", "只在水色转深的外海，身快肉紧。"), 18, {"heal": 1.5, "swift": 1.0}, 10),
    fish("lantern_squid", L("Lantern squid", "Calamar farol", "Lula-lanterna", "Calmar lanterne", "Laternenkalmar", "灯りイカ", "등불 오징어", "灯乌贼"),
         L("Rises from the deep at night, glowing. Cooks into something that steadies the breath.", "Sube de lo hondo de noche, brillando. Cocinado ayuda a aguantar la respiración.", "Sobe do fundo à noite, brilhando. Cozido ajuda a segurar o fôlego.", "Remonte des profondeurs la nuit, lumineux. Cuisiné, il tient le souffle.", "Steigt nachts leuchtend aus der Tiefe. Gekocht beruhigt es den Atem.", "夜、光りながら深みから上がる。煮れば息が長く続く。", "밤에 빛나며 깊은 곳에서 올라온다. 요리하면 숨이 길어진다.", "夜里发着光从深处浮上，煮了能让气息绵长。"), 16, {"heal": 1.5, "vigor": 1.0}, 22, 2),
    fish("wreck_grouper", L("Wreck grouper", "Mero de pecio", "Garoupa-de-naufrágio", "Mérou d'épave", "Wrackzackenbarsch", "沈船ハタ", "난파선 농어", "沉船石斑"),
         L("Lives in drowned hulls and grows fat on what's inside.", "Vive en cascos hundidos y engorda con lo que hay dentro.", "Vive em cascos afundados e engorda com o que há dentro.", "Vit dans les coques noyées et grossit de ce qu'elles contiennent.", "Lebt in versunkenen Rümpfen und wird dick von dem, was drin ist.", "沈んだ船体に棲み、中のもので肥える。", "가라앉은 선체에 살며 안의 것으로 살찐다.", "住在沉船里，靠船里的东西长得肥硕。"), 26, {"heal": 2.0, "stout": 1.0}, 14),
    fish("glass_shrimp", L("Glass shrimp", "Camarón de cristal", "Camarão-de-vidro", "Crevette de verre", "Glasgarnele", "硝子エビ", "유리 새우", "玻璃虾"),
         L("See-through, from the crystal reef. In a storm they glow blue.", "Transparente, del arrecife de cristal. Con tormenta brilla azul.", "Transparente, do recife de cristal. Na tempestade brilha azul.", "Transparente, du récif de cristal. Dans l'orage, elle luit bleu.", "Durchsichtig, vom Kristallriff. Im Sturm leuchtet sie blau.", "透き通った水晶礁のエビ。嵐には青く光る。", "수정 산호의 투명한 새우. 폭풍엔 푸르게 빛난다.", "水晶礁的透明虾，暴风雨时泛蓝光。"), 8, {"heal": 1.0, "cool": 1.0}, 9),
    item("finback_tooth", "material", L("Finback tooth", "Diente de aletalomo", "Dente de dorso-de-barbatana", "Dent de dos-d'aileron", "Flossenrückenzahn", "背ビレの牙", "등지느러미 이빨", "背鳍鲨牙"),
         L("Serrated, heavy, still sharp. Smiths set them in blades.", "Serrado, pesado, aún afilado. Los herreros los engastan en hojas.", "Serrilhado, pesado, ainda afiado. Ferreiros os cravam em lâminas.", "Dentelée, lourde, encore aiguisée. Les forgerons la sertissent dans des lames.", "Gezackt, schwer, noch scharf. Schmiede setzen sie in Klingen.", "鋸歯で重く、まだ鋭い。鍛冶屋が刃にはめる。", "톱니 모양에 묵직하고 아직 날카롭다. 대장장이가 칼날에 박는다.", "带锯齿，沉，仍锋利，铁匠拿它镶刃。"),
         icon="res://assets/icons/mat_fang.svg", value=12),
    item("ray_wing", "material", L("Storm ray wing", "Ala de raya de tormenta", "Asa de raia-da-tempestade", "Aile de raie d'orage", "Sturmrochenflügel", "嵐エイの翼", "폭풍 가오리 날개", "雷鳐翼"),
         L("Leathery and faintly charged. Your hair stands up holding it.", "Correosa y levemente cargada. Se te eriza el pelo al sostenerla.", "Coriácea e levemente carregada. Arrepia o cabelo ao segurá-la.", "Coriace et faiblement chargée. Vos cheveux se dressent à la tenir.", "Ledrig und leicht geladen. Dir stehen die Haare zu Berge.", "革のようで微かに帯電。持つと髪が逆立つ。", "가죽 같고 은근히 전기를 띤다. 들면 머리칼이 선다.", "皮质，微带电，拿着头发都竖起来。"),
         icon="res://assets/icons/mat_hide.svg", value=20, rarity=2),
    item("abyssal_pearl", "material", L("Abyssal pearl", "Perla abisal", "Pérola abissal", "Perle abyssale", "Abgrundperle", "深淵の真珠", "심연의 진주", "深渊珍珠"),
         L("Black, heavy, cold. Only the deep wrecks give these up.", "Negra, pesada, fría. Solo los pecios profundos las entregan.", "Negra, pesada, fria. Só os naufrágios fundos as entregam.", "Noire, lourde, froide. Seules les épaves profondes les cèdent.", "Schwarz, schwer, kalt. Nur die tiefen Wracks geben sie her.", "黒く重く冷たい。深い沈船だけが手放す。", "검고 무겁고 차갑다. 깊은 난파선만이 내놓는다.", "乌黑、沉、冷，只有深处的沉船才有。"),
         icon="res://assets/icons/mat_gem.svg", value=120, rarity=3),
    item("deepwater_mask", "armor", L("Deepwater mask", "Máscara de aguas hondas", "Máscara de águas fundas", "Masque des eaux profondes", "Tiefwassermaske", "深水の面", "심해 가면", "深水面罩"),
         L("A diver's mask from the Leviathan's cabin. Dives last far longer.", "Una máscara de buzo de la cabina del Leviatán. Las inmersiones duran mucho más.", "Máscara de mergulho da cabine do Leviatã. Mergulhos duram muito mais.", "Un masque de plongée de la cabine du Léviathan. Les plongées durent bien plus.", "Eine Taucherbrille aus der Kajüte des Leviathan. Tauchgänge dauern viel länger.", "巨鯨号の船室の潜水面。ずっと長く潜れる。", "리바이어던 선실의 잠수 가면. 훨씬 오래 잠수한다.", "铁鲸号船舱里的潜水面罩，潜得更久。"),
         icon="res://assets/icons/armor_head.svg", value=140, rarity=3, armor={"slot": "head", "defense": 1, "breath": 0.4}),
    item("driftwood_charm", "armor", L("Driftwood charm", "Amuleto de madera a la deriva", "Amuleto de madeira à deriva", "Charme de bois flotté", "Treibholzamulett", "流木の護符", "유목 부적", "漂木护符"),
         L("The old watcher's charm. The sea carries you: swim faster, hold your breath longer.", "El amuleto del viejo vigía. El mar te lleva: nadas más rápido y aguantas más.", "O amuleto do velho vigia. O mar te leva: nada mais rápido, segura mais o fôlego.", "Le charme du vieux guetteur. La mer vous porte : nagez plus vite, respirez plus longtemps.", "Das Amulett des alten Wächters. Das Meer trägt dich: schneller schwimmen, länger atmen.", "古い見張りの護符。海があなたを運ぶ。速く泳ぎ、長く息が続く。", "옛 파수꾼의 부적. 바다가 너를 실어 준다. 더 빨리 헤엄치고 숨이 길어진다.", "老哨兵的护符。海托着你：游得快，憋得久。"),
         icon="res://assets/icons/armor_accessory.svg", value=90, rarity=2, armor={"slot": "accessory", "defense": 0, "swim_speed": 0.3, "breath": 0.15}),
    item("tidewarden_chart", "key", L("Tidewarden's chart", "Carta del Guardamareas", "Carta do Guarda-Marés", "Carte du Gardien des marées", "Karte des Gezeitenwächters", "潮守りの海図", "조수지기의 해도", "守潮人海图"),
         L("Currents inked in blue, wrecks in red, a tide table in the margin.", "Corrientes en azul, pecios en rojo, una tabla de mareas al margen.", "Correntes em azul, naufrágios em vermelho, uma tábua de marés na margem.", "Courants à l'encre bleue, épaves en rouge, table des marées en marge.", "Strömungen in Blau, Wracks in Rot, eine Gezeitentafel am Rand.", "青で潮流、赤で沈船、余白に潮汐表。", "파랑은 해류, 빨강은 난파선, 여백엔 조수표.", "蓝墨画洋流，红墨标沉船，页边一张潮汐表。"),
         icon="res://assets/icons/key_journal.svg", max_stack=1),
    item("gulls_log", "key", L("The Gull's log", "Bitácora de la Gaviota", "Diário da Gaivota", "Journal de la Mouette", "Logbuch der Möwe", "鴎号の航海日誌", "갈매기호 항해일지", "鸥号航海日志"),
         L("Water-stained. The last page is in a different hand.", "Manchada de agua. La última página es de otra mano.", "Manchado de água. A última página é de outra mão.", "Tachée d'eau. La dernière page est d'une autre main.", "Wasserfleckig. Die letzte Seite ist in anderer Handschrift.", "水染み。最後の頁だけ筆跡が違う。", "물 얼룩이 졌다. 마지막 장은 다른 필체다.", "水渍斑斑，最后一页换了笔迹。"),
         icon="res://assets/icons/key_journal.svg", max_stack=1),
    item("castaway_compass", "key", L("Castaway's compass", "Brújula del náufrago", "Bússola do náufrago", "Boussole du naufragé", "Kompass des Schiffbrüchigen", "漂流者の羅針盤", "조난자의 나침반", "漂流者罗盘"),
         L("Its needle drifts toward the Vanishing Bar at low tide.", "Su aguja se desvía hacia el Banco Fantasma con marea baja.", "A agulha deriva para o Banco Fantasma na maré baixa.", "Son aiguille dérive vers le Banc fantôme à marée basse.", "Die Nadel treibt bei Ebbe zur Verschwindenden Bank.", "干潮になると針が消える砂州のほうへ流れる。", "간조엔 바늘이 사라지는 모래톱 쪽으로 기운다.", "退潮时，指针会偏向消失沙洲。"),
         icon="res://assets/icons/key_seed.svg", max_stack=1),
    item("deepwater_broth", "food", L("Deepwater broth", "Caldo de aguas hondas", "Caldo de águas fundas", "Bouillon des profondeurs", "Tiefwasserbrühe", "深水の汁", "심해 국", "深水汤"),
         L("Runner and lantern squid. Warm in the chest; your breath comes slow and long.", "Corredor y calamar farol. Calienta el pecho; respiras lento y largo.", "Corredor e lula-lanterna. Aquece o peito; o fôlego vem lento e longo.", "Coureur et calmar lanterne. Chaud au cœur ; le souffle vient lent et long.", "Läufer und Laternenkalmar. Warm in der Brust; der Atem geht langsam und lang.", "走り魚と灯りイカ。胸が温まり、息が長くなる。", "질주어와 등불 오징어. 가슴이 따뜻하고 숨이 길어진다.", "奔鱼和灯乌贼，胸口暖，气息绵长。"),
         icon="res://assets/icons/food_dish.svg", use_action="eat", value=40, rarity=2, effects=[{"type": "heal", "amount": 20}, {"type": "buff", "buff": "breath", "amount": 1, "duration": 240}]),
]
SPECIALS = [{"id": "deepwater_broth", "ingredients": ["bluewater_runner", "lantern_squid", "frostmint"], "item": "deepwater_broth", "potency": 1.0}]
BUFFS = {"breath": {"name_key": "BUFF_BREATH"}}
COSMETICS = [({"id": "ribbon_tide", "slot": "glider_trail", "name_key": "COS_RIBBON_TIDE", "color": "#3fd6c0"},
              {"COS_RIBBON_TIDE": L("Tidewater ribbon", "Cinta de marea", "Fita da maré", "Ruban des marées", "Gezeitenband", "潮の帯", "조수 리본", "潮汐绸带")})]

# --- Spawns: the sea's own mix ---------------------------------------------------------------------------


def sp(entity, weight, group, **kw):
    d = {"entity": entity, "weight": weight, "group": group}
    d.update(kw)
    return d


REGION_SPAWNS = {"coast": {
    "enemy_spawns": [sp("ENEMY_TIDE_SPITTER", 2.5, [1, 2]), sp("ENEMY_SHELLBACK", 1.2, [1, 1]), sp("ENEMY_GALE_KITE", 1, [1, 2]),
                     sp("ENEMY_GLINT_THIEF", 0.5, [1, 1], period="day"), sp("ENEMY_THORNLING", 0.7, [2, 2]),
                     sp("ENEMY_GALE_KITE", 1, [1, 1], habitat="cliff"),
                     # Shallows: needlefin schools, the odd finback.
                     sp("ENEMY_NEEDLEFIN", 3, [4, 6], habitat="water"), sp("ENEMY_FINBACK", 1, [1, 1], habitat="water"),
                     # Open sea: finbacks; in storms, storm rays over the waves.
                     sp("ENEMY_FINBACK", 3, [1, 1], habitat="deep"), sp("ENEMY_NEEDLEFIN", 1, [5, 7], habitat="deep"),
                     sp("ENEMY_STORM_RAY", 6, [1, 2], habitat="deep", weather=["storm"]), sp("ENEMY_STORM_RAY", 2, [1, 1], habitat="water", weather=["storm"])],
    "animal_spawns": [sp("ANIMAL_TIDE_CRAB", 3, [2, 4]), sp("ANIMAL_BURROWHOP", 0.6, [1, 2]), sp("ANIMAL_DRIFT_WHALE", 1, [1, 1], habitat="deep")],
}}

FISHING = {"sea": [{"item": "silverback", "weight": 6}, {"item": "stormfin", "weight": 2, "weather": ["storm"]}, {"item": "raw_fish", "weight": 2}],
           "reef": [{"item": "reef_glint", "weight": 2, "hours": [10, 15], "weather": ["clear"]}, {"item": "glass_shrimp", "weight": 4},
                    {"item": "glass_shrimp", "weight": 6, "weather": ["storm"]}, {"item": "silverback", "weight": 3}],
           "deep": [{"item": "bluewater_runner", "weight": 5, "period": "day"}, {"item": "lantern_squid", "weight": 4, "period": "night"},
                    {"item": "stormfin", "weight": 5, "weather": ["storm"]}, {"item": "silverback", "weight": 1}],
           "wreck": [{"item": "wreck_grouper", "weight": 5}, {"item": "silverback", "weight": 2}, {"item": "stormfin", "weight": 2, "weather": ["storm"]}]}

# --- Sites: currents, tide, storm fields, kelp, fishing --------------------------------------------------------
SITES = []


def site(feature, sid, pos, **kw):
    d = {"kind": "feature", "feature": feature, "id": sid, "pos": list(pos)}
    d.update(kw)
    SITES.append(d)


def current(sid, a, b, width=16.0, strength=3.5):
    yaw, length = yaw_to(a, b)
    site("current", sid, a, yaw=yaw, length=length, width=width, strength=strength, float=True, lift=0.0)


current("gull_current", (110, 835), (150, 985))           # shore -> Tidewarden Light
current("light_current", (135, 1015), (-40, 1150))        # light -> Vigil Rock
current("home_current", (-60, 1135), (-30, 880), strength=3.0)   # Vigil Rock -> shore
current("reef_rip", (540, 990), (560, 1160), width=22.0, strength=5.0)   # the reef's rip: pulls you out
for i, x in enumerate([-733, -743, -753, -763, -773]):
    site("tide_bar", "tide_causeway_%d" % i, (x, 303), size=[10.5, 1.0, 4.5], float=True, lift=0.0)
for i, (dx, dz) in enumerate([(-12, 0), (0, 0), (12, 0), (-6, 7), (6, -7)]):
    site("tide_bar", "vanishing_bar_%d" % i, (320 + dx, 1280 + dz), size=[12.0, 1.0, 8.0], float=True, lift=0.0)
site("surf", "tide_mouth_surf", (-800, 312), radius=5.5, yaw=180.0, float=True, lift=0.0)
SITES.append({"kind": "zone", "zone": "updraft", "id": "vigil_updraft", "pos": [-45, 1175], "radius": 7.0, "height": 70.0, "strength": 11.0})
SITES.append({"kind": "zone", "zone": "updraft", "id": "tide_blowhole", "pos": [-800, 300], "radius": 3.5, "height": 12.0, "strength": 13.0,
              "conditions": {"weather": ["storm"]}})
for i, (dx, dz) in enumerate([(-30, -10), (-12, 18), (6, -22), (20, 10), (34, -4), (-4, 36), (28, 30)]):
    site("storm_spire", "reef_spire_%d" % i, (560 + dx, 1020 + dz))
for i in range(8):
    a = i / 8 * math.tau
    site("storm_buoy", "squall_buoy_%d" % i, (round(720 + math.cos(a) * 30, 1), round(1260 + math.sin(a) * 30, 1)), float=True, lift=0.0)
site("storm_spire", "leviathan_mast", (715, 1256), float=True, lift=-2.0)
for sid, pos, r, n in [("kelp_tide_lagoon", (-835, 262), 11, 30), ("kelp_reef_edge", (600, 1075), 12, 30), ("kelp_leviathan", (705, 1272), 14, 36), ("kelp_promise", (12, 1266), 9, 22)]:
    site("kelp", sid, pos, radius=r, count=n)
for sid, pos, waters in [("fish_reef_0", (530, 1005), "reef"), ("fish_reef_1", (585, 1040), "reef"), ("fish_deep_0", (-150, 1260), "deep"),
                         ("fish_deep_1", (760, 1210), "deep"), ("fish_deep_2", (380, 1420), "deep"), ("fish_wreck_0", (44, 1236), "wreck"),
                         ("fish_tide_0", (-790, 280), "sea")]:
    site("fishing_spot", sid, pos, waters=waters, float=True, lift=0.05)

# --- Discoveries ------------------------------------------------------------------------------------------------


def disc(did, name, desc, hint, pos, reward, radius=10.0, trigger="reach", conditions=None, spawns=None, persist=False, icon="≈", region="coast", **kw):
    d = {"id": did, "region": region, "name_key": "DISC_" + did.upper(), "desc_key": "DISC_" + did.upper() + "_DESC",
         "hint_key": "DISC_" + did.upper() + "_HINT", "pos": list(pos), "radius": radius, "trigger": trigger, "reward": reward, "icon": icon}
    if conditions:
        d["conditions"] = conditions
    if spawns:
        d["spawns"] = spawns
    if persist:
        d["persist"] = True
    d.update(kw)
    return d, {d["name_key"]: name, d["desc_key"]: desc, d["hint_key"]: hint}


PAGE_LINES = [
    L("Day 3. The Promise broke on the shoal south of the Vigil. Six of us made this rock.", "Día 3. La Promesa se partió en el bajío al sur del Vigía. Seis llegamos a esta roca.", "Dia 3. A Promessa se partiu no baixio ao sul do Vigia. Seis chegamos a esta rocha.", "Jour 3. La Promesse s'est brisée sur le haut-fond au sud de la Vigie. Six d'entre nous ont atteint ce rocher.", "Tag 3. Die Promise zerbrach auf der Untiefe südlich des Wachtfelsens. Sechs von uns erreichten diesen Fels.", "三日目。約束号は見張り岩の南の浅瀬で砕けた。六人がこの岩に着いた。", "3일째. 약속호가 망루 바위 남쪽 여울에서 부서졌다. 여섯이 이 바위에 닿았다.", "第三天。鸥之诺号在望哨礁南边的浅滩上撞碎了，我们六个爬上了这块礁。"),
    L("Day 9. The light has gone dark. No keeper. We burn driftwood in the pit every night.", "Día 9. El faro se apagó. No hay guardián. Quemamos madera en el pozo cada noche.", "Dia 9. O farol apagou. Sem guardião. Queimamos madeira no poço toda noite.", "Jour 9. Le phare s'est éteint. Pas de gardien. Nous brûlons du bois flotté chaque nuit.", "Tag 9. Das Licht ist dunkel. Kein Wärter. Wir verbrennen jede Nacht Treibholz in der Grube.", "九日目。灯台は消えた。番人はいない。毎晩穴で流木を燃やす。", "9일째. 등대가 꺼졌다. 지기가 없다. 매일 밤 구덩이에 유목을 태운다.", "第九天。灯塔灭了，没人守。我们每晚在坑里烧漂木。"),
    L("Day 14. At low water, at midnight, a bar of sand rises east of here. Something was buried on it.", "Día 14. Con marea baja, a medianoche, surge un banco de arena al este. Algo enterraron en él.", "Dia 14. Na maré baixa, à meia-noite, surge um banco de areia a leste. Algo foi enterrado ali.", "Jour 14. À marée basse, à minuit, un banc de sable émerge à l'est. Quelque chose y a été enterré.", "Tag 14. Bei Niedrigwasser um Mitternacht taucht östlich eine Sandbank auf. Darauf wurde etwas vergraben.", "十四日目。干潮の真夜中、東に砂州が現れる。何かが埋められていた。", "14일째. 간조의 한밤중, 동쪽에 모래톱이 솟는다. 거기 뭔가 묻혀 있었다.", "第十四天。退潮的午夜，东边会冒出一道沙洲，上面埋着东西。"),
]
PAGE_KEYS = ["LINE_CASTAWAY_PAGE_%d" % (i + 1) for i in range(3)]

DISCOVERIES = [
    disc("sea_tidewarden_light", L("The Tidewarden Light", "El Faro del Guardamareas", "O Farol do Guarda-Marés", "Le Phare du Gardien", "Das Gezeitenwacht-Licht", "潮守りの灯台", "조수지기 등대", "守潮灯塔"),
         L("Relit at night, its beam sweeps the south sea again — and the keeper's chart marks the wrecks.", "Encendido de noche, su haz barre de nuevo el mar del sur, y la carta del guardián marca los pecios.", "Aceso à noite, o facho varre de novo o mar do sul — e a carta do guardião marca os naufrágios.", "Rallumé la nuit, son faisceau balaie de nouveau la mer du sud — et la carte du gardien marque les épaves.", "Nachts neu entzündet, fegt sein Strahl wieder übers Südmeer — und die Karte des Wärters zeigt die Wracks.", "夜に灯せば光が南の海を再び掃く。番人の海図は沈船を示す。", "밤에 다시 켜면 빛줄기가 남쪽 바다를 쓸고, 지기의 해도가 난파선을 알려 준다.", "夜里重新点亮，光束再度扫过南海——守灯人的海图标着沉船。"),
         L("Sabel: 'The Gull Current runs from my shore to the old light. Swim it — it carries you.'", "Sabel: 'La Corriente de la Gaviota va de mi orilla al viejo faro. Nádala: te lleva.'", "Sabel: 'A Corrente da Gaivota vai da minha praia ao velho farol. Nade nela — ela te leva.'", "Sabel : « Le courant de la Mouette va de ma rive au vieux phare. Nagez-y — il vous porte. »", "Sabel: „Die Möwenströmung läuft von meinem Ufer zum alten Licht. Schwimm darin — sie trägt dich.“", "サベル「鴎の潮は私の浜から古い灯台へ流れる。泳げ、運んでくれる」", "사벨: '갈매기 해류가 내 해변에서 옛 등대로 흘러. 타고 헤엄쳐, 데려다줄 거야.'", "萨贝尔：“鸥流从我的岸边流到老灯塔，顺着游，它会带你过去。”"),
         (150, 1000), {"items": [{"id": "lake_pearl", "count": 1}]}, trigger="interact", found_in_poi="tidewarden_light", conditions={"period": "night"}, icon="☼"),
    disc("sea_vigil_top", L("Top of the Vigil", "Cima del Vigía", "Topo do Vigia", "Sommet de la Vigie", "Gipfel der Wacht", "見張りの頂", "망루 꼭대기", "望哨之巅"),
         L("From the nest the whole south sea lies open — and the Gull's Promise is a glide away.", "Desde el nido se abre todo el mar del sur, y la Promesa de la Gaviota queda a un planeo.", "Do ninho todo o mar do sul se abre — e a Promessa da Gaivota fica a um planar.", "Du nid, toute la mer du sud s'ouvre — et la Promesse de la Mouette est à un vol plané.", "Vom Nest liegt das ganze Südmeer offen — das Möwenversprechen ist einen Gleitflug entfernt.", "巣から南の海が一望。鴎の約束号は滑空ひとつ。", "둥지에서 남쪽 바다가 훤히 보인다. 갈매기의 약속호는 활공 한 번 거리.", "从巢上望，整片南海尽收眼底，鸥之诺号一次滑翔就到。"),
         L("Gulls wheel around a crooked rock south-west of the light. Something nests up there.", "Las gaviotas giran en torno a una roca torcida al suroeste del faro. Algo anida arriba.", "Gaivotas giram em torno de uma rocha torta a sudoeste do farol. Algo faz ninho lá.", "Des mouettes tournent autour d'un rocher tordu au sud-ouest du phare. Quelque chose y niche.", "Möwen kreisen um einen krummen Fels südwestlich des Lichts. Dort oben nistet etwas.", "灯台の南西、曲がった岩を鴎が回る。上に何かが巣を作る。", "등대 남서쪽 굽은 바위 주위를 갈매기가 돈다. 위에 뭔가 둥지를 틀었다.", "灯塔西南一块歪斜的礁石上群鸥盘旋，上面有东西筑巢。"),
         (-58, 1161), {"items": [{"id": "gale_feather", "count": 2}], "reveal": {"pos": [30, 1250], "radius": 3}}, radius=6.0, conditions={"min_y": 50.0}, icon="⬆"),
    disc("sea_gulls_promise", L("The Gull's Promise", "La Promesa de la Gaviota", "A Promessa da Gaivota", "La Promesse de la Mouette", "Das Möwenversprechen", "鴎の約束号", "갈매기의 약속호", "鸥之诺号"),
         L("Half-sunk on a shoal. In by the deck hatch, the breach below the waterline or the stern windows.", "Medio hundida en un bajío. Se entra por la escotilla, la brecha bajo la línea de flotación o las ventanas de popa.", "Meio afundada num baixio. Entra-se pela escotilha, pela brecha sob a linha d'água ou pelas janelas de popa.", "À moitié coulée sur un haut-fond. On entre par l'écoutille, la brèche sous la ligne de flottaison ou les fenêtres de poupe.", "Halb versunken auf einer Untiefe. Hinein über die Luke, das Leck unter der Wasserlinie oder die Heckfenster.", "浅瀬に半ば沈む。甲板の昇降口、喫水下の破孔、船尾の窓から入れる。", "여울에 반쯤 가라앉았다. 갑판 해치, 흘수선 아래 구멍, 선미 창으로 들어간다.", "半沉在浅滩上。可从甲板舱口、水线下破洞或船尾窗进入。"),
         L("The castaways' pages name the shoal south of the Vigil.", "Las páginas de los náufragos nombran el bajío al sur del Vigía.", "As páginas dos náufragos citam o baixio ao sul do Vigia.", "Les pages des naufragés nomment le haut-fond au sud de la Vigie.", "Die Seiten der Schiffbrüchigen nennen die Untiefe südlich der Wacht.", "漂流者の頁は見張り岩の南の浅瀬を語る。", "조난자의 쪽지는 망루 남쪽 여울을 말한다.", "漂流者的手记提到望哨礁南边的浅滩。"),
         (30, 1250), {"items": [{"id": "gale_feather", "count": 1}]}, radius=18),
    disc("sea_leviathan", L("The Iron Leviathan", "El Leviatán de Hierro", "O Leviatã de Ferro", "Le Léviathan de fer", "Der Eiserne Leviathan", "鉄の巨鯨号", "강철 리바이어던", "铁鲸号"),
         L("A metal ship twenty metres down. Its mast still breaks the surface — and draws lightning in storms.", "Un barco de metal a veinte metros. Su mástil aún asoma y atrae rayos en las tormentas.", "Um navio de metal a vinte metros. O mastro ainda aflora — e atrai raios nas tempestades.", "Un navire de métal à vingt mètres. Son mât perce encore la surface — et attire la foudre dans l'orage.", "Ein Metallschiff in zwanzig Metern Tiefe. Sein Mast ragt noch heraus — und zieht im Sturm Blitze an.", "水深二十メートルの鉄の船。帆柱はまだ水面に出て、嵐には雷を呼ぶ。", "수심 20미터의 쇠배. 돛대가 아직 수면 위로 솟아 폭풍엔 번개를 부른다.", "二十米深处的铁船，桅杆仍露出水面——暴风雨时引雷。"),
         L("Out past the reef, buoys ring something big under the water.", "Más allá del arrecife, unas boyas rodean algo grande bajo el agua.", "Além do recife, boias cercam algo grande sob a água.", "Au-delà du récif, des bouées entourent quelque chose de grand sous l'eau.", "Hinter dem Riff umringen Bojen etwas Großes unter Wasser.", "礁の先、ブイが水中の大きな何かを囲む。", "산호초 너머, 부표들이 물속 큰 무언가를 둘러싼다.", "越过礁石，一圈浮标围着水下的庞然大物。"),
         (720, 1260), {"items": [{"id": "abyssal_pearl", "count": 1}]}, radius=16, conditions={"state": ["dive"], "max_y": -8.0}),
    disc("sea_crystal_reef", L("Crystal Reef", "Arrecife de Cristal", "Recife de Cristal", "Récif de cristal", "Kristallriff", "水晶礁", "수정 산호초", "水晶礁"),
         L("Shallow and bright in fair weather. In a storm its spires take the lightning and the water sings.", "Poco profundo y brillante con buen tiempo. En tormenta sus agujas atraen rayos y el agua canta.", "Raso e claro no bom tempo. Na tempestade as agulhas atraem raios e a água canta.", "Peu profond et clair par beau temps. Dans l'orage, ses aiguilles prennent la foudre et l'eau chante.", "Flach und hell bei gutem Wetter. Im Sturm fangen seine Spitzen Blitze, und das Wasser singt.", "晴れの日は浅く明るい。嵐には尖塔が雷を受け、水が歌う。", "맑은 날엔 얕고 밝다. 폭풍엔 첨탑이 번개를 받고 물이 노래한다.", "晴天里水浅而明亮，暴风雨时尖晶引雷，海水鸣响。"),
         L("East of the light, pale spikes stand in the sea.", "Al este del faro, púas pálidas se alzan en el mar.", "A leste do farol, pontas pálidas se erguem no mar.", "À l'est du phare, des pointes pâles se dressent dans la mer.", "Östlich des Lichts ragen bleiche Spitzen aus dem Meer.", "灯台の東、海に白い棘が立つ。", "등대 동쪽 바다에 창백한 가시들이 솟아 있다.", "灯塔以东，海里立着一根根白刺。"),
         (560, 1020), {"items": [{"id": "glass_shard", "count": 2}]}, radius=30),
    disc("sea_crystal_storm", L("Reef in the Storm", "El arrecife en la tormenta", "O recife na tempestade", "Le récif dans l'orage", "Das Riff im Sturm", "嵐の礁", "폭풍 속 산호초", "风暴中的礁"),
         L("You crossed the reef while the spires burned. Rare glass for a dangerous route.", "Cruzaste el arrecife mientras ardían las agujas. Cristal raro por una ruta peligrosa.", "Você cruzou o recife enquanto as agulhas ardiam. Vidro raro por uma rota perigosa.", "Vous avez traversé le récif pendant que les aiguilles brûlaient. Du verre rare pour une route dangereuse.", "Du hast das Riff überquert, während die Spitzen brannten. Seltenes Glas für einen gefährlichen Weg.", "尖塔が燃える中、礁を渡った。危険な道に稀な硝子。", "첨탑이 타오르는 중에 산호초를 건넜다. 위험한 길에 드문 유리.", "尖晶燃烧时你穿过了礁石——险路换来稀有晶体。"),
         L("Sabel: 'In a storm the reef is death. It's also where the stormglass grows.'", "Sabel: 'Con tormenta el arrecife es la muerte. También es donde crece el cristal de tormenta.'", "Sabel: 'Na tempestade o recife é a morte. É também onde cresce o vidro-tempestade.'", "Sabel : « Dans l'orage, le récif, c'est la mort. C'est aussi là que pousse le verre d'orage. »", "Sabel: „Im Sturm ist das Riff der Tod. Dort wächst aber auch das Sturmglas.“", "サベル「嵐の礁は死だ。嵐硝子が育つ場所でもある」", "사벨: '폭풍 속 산호초는 죽음이야. 폭풍유리가 자라는 곳이기도 하고.'", "萨贝尔：“暴风雨里的礁就是鬼门关，可雷晶也长在那儿。”"),
         (560, 1020), {"items": [{"id": "storm_glass", "count": 2}]}, radius=30, conditions={"weather": ["storm"]}, icon="ϟ"),
    disc("sea_castaways", L("The Castaways", "Los náufragos", "Os náufragos", "Les naufragés", "Die Schiffbrüchigen", "漂流者たち", "조난자들", "漂流者"),
         L("Three pages, a grave, a cold signal pit. Six made it to this rock.", "Tres páginas, una tumba, un pozo de señales frío. Seis llegaron a esta roca.", "Três páginas, uma cova, um poço de sinais frio. Seis chegaram a esta rocha.", "Trois pages, une tombe, une fosse à signaux froide. Six ont atteint ce rocher.", "Drei Seiten, ein Grab, eine kalte Signalgrube. Sechs erreichten diesen Fels.", "三枚の頁、墓、冷えた狼煙の穴。六人がこの岩に辿り着いた。", "쪽지 세 장, 무덤 하나, 식은 봉화 구덩이. 여섯이 이 바위에 닿았다.", "三页手记、一座坟、一口冷掉的烽火坑。六个人到过这块礁。"),
         L("From the south shore at dusk, a small boat rows out west.", "Desde la orilla sur, al atardecer, un bote pequeño rema hacia el oeste.", "Da praia sul ao entardecer, um barquinho rema para oeste.", "De la rive sud au crépuscule, une petite barque rame vers l'ouest.", "Vom Südufer rudert in der Dämmerung ein kleines Boot nach Westen.", "夕暮れの南の浜から、小舟が西へ漕ぎ出す。", "해 질 녘 남쪽 해변에서 작은 배가 서쪽으로 노 저어 간다.", "黄昏时分，一条小船从南岸往西划去。"),
         (-420, 1060), {"items": [{"id": "castaway_compass", "count": 1}]}, trigger="interact", icon="✎",
         spawns=[{"kind": "object", "id": "castaway_page_%d" % (i + 1), "look": "scroll", "pos": p, "prompt": "PROMPT_READ", "radius": 1.6,
                  "lines": [PAGE_KEYS[i]], "speaker": "POI_CASTAWAY_ISLET", "hide_used": False, **({"discover": "sea_castaways"} if i == 2 else {})}
                 for i, p in enumerate([[-424, 1063], [-413, 1054], [-416, 1070]])]
         + [{"kind": "creature", "entity": "NPC_CASTAWAY", "group": "castaway", "pos": [-423, 1058], "conditions": {"hours": [16, 21]}}], persist=True),
    disc("sea_vanishing_bar", L("The Vanishing Bar", "El Banco Fantasma", "O Banco Fantasma", "Le Banc fantôme", "Die Verschwindende Bank", "消える砂州", "사라지는 모래톱", "消失沙洲"),
         L("An isle of sand that exists only at low water. What the castaways buried is still there.", "Una isla de arena que solo existe con marea baja. Lo que enterraron los náufragos sigue ahí.", "Uma ilha de areia que só existe na maré baixa. O que os náufragos enterraram ainda está lá.", "Une île de sable qui n'existe qu'à marée basse. Ce que les naufragés ont enterré y est encore.", "Eine Sandinsel, die nur bei Niedrigwasser existiert. Was die Schiffbrüchigen vergruben, ist noch da.", "干潮にだけ現れる砂の島。漂流者の埋めたものがまだある。", "간조에만 존재하는 모래섬. 조난자들이 묻은 것이 아직 있다.", "只在退潮时出现的沙岛，漂流者埋的东西还在。"),
         L("The castaways' last page: 'at low water, at midnight, a bar rises east'.", "La última página de los náufragos: 'con marea baja, a medianoche, surge un banco al este'.", "A última página dos náufragos: 'na maré baixa, à meia-noite, surge um banco a leste'.", "La dernière page des naufragés : « à marée basse, à minuit, un banc émerge à l'est ».", "Die letzte Seite der Schiffbrüchigen: „bei Niedrigwasser, um Mitternacht, taucht im Osten eine Bank auf“.", "漂流者の最後の頁「干潮の真夜中、東に砂州が現れる」", "조난자의 마지막 쪽지: '간조의 한밤중, 동쪽에 모래톱이 솟는다.'", "漂流者最后一页：“退潮的午夜，东边会冒出沙洲。”"),
         (320, 1280), {"cosmetic": "ribbon_tide"}, radius=14, conditions={"tide": "low"}, icon="◌",
         spawns=[{"kind": "chest", "id": "vanishing_bar:buried", "table": "chest_rare", "pos": [322, 1281], "snap": "top", "items": [{"id": "abyssal_pearl", "count": 1}], "grand": True, "conditions": {"tide": "low"}}], persist=True),
    disc("sea_tide_cave", L("The Tide Cave", "La Cueva de las Mareas", "A Caverna das Marés", "La Grotte des marées", "Die Gezeitenhöhle", "潮の洞", "조수 동굴", "潮汐洞"),
         L("Walk in at low water; dive the side tunnel at high water; ride the blowhole up in a storm.", "Entra a pie con marea baja; bucea el túnel lateral con marea alta; sube por el bufadero con tormenta.", "Entre a pé na maré baixa; mergulhe o túnel lateral na maré alta; suba pelo respiradouro na tempestade.", "Entrez à pied à marée basse ; plongez dans le tunnel latéral à marée haute ; montez par le souffleur dans l'orage.", "Bei Ebbe hineingehen, bei Flut durch den Seitentunnel tauchen, im Sturm mit dem Blasloch hinauf.", "干潮は歩いて、満潮は横穴を潜って、嵐には潮吹き穴で上へ。", "간조엔 걸어서, 만조엔 옆 굴을 잠수해서, 폭풍엔 분수공을 타고 위로.", "退潮走进去，涨潮潜侧洞，暴风雨时乘喷水孔上去。"),
         L("Sabel: 'West coast, Tide Isle. The sandbar only shows at low water.'", "Sabel: 'Costa oeste, Isla de las Mareas. El banco de arena solo aparece con marea baja.'", "Sabel: 'Costa oeste, Ilha das Marés. O banco de areia só aparece na maré baixa.'", "Sabel : « Côte ouest, île des Marées. Le banc de sable n'apparaît qu'à marée basse. »", "Sabel: „Westküste, Gezeiteninsel. Die Sandbank zeigt sich nur bei Niedrigwasser.“", "サベル「西の海岸、潮の島。砂州は干潮にだけ出る」", "사벨: '서쪽 해안, 조수의 섬. 모래톱은 간조에만 드러나.'", "萨贝尔：“西海岸潮汐岛，沙坝只在退潮时露出来。”"),
         (-800, 300), {"items": [{"id": "lake_pearl", "count": 1}]}, radius=6),
    disc("sea_drift_whale", L("The Drift Whale", "La ballena errante", "A baleia-errante", "La baleine dérivante", "Der Treibwal", "漂い鯨", "떠도는 고래", "漂鲸"),
         L("A spout far out at sea at dusk: the biggest thing in the world, and it means no harm.", "Un chorro mar adentro al atardecer: lo más grande del mundo, y no hace daño.", "Um jorro em alto-mar ao entardecer: a maior coisa do mundo, e não faz mal.", "Un jet au large au crépuscule : la plus grande chose au monde, et elle ne veut aucun mal.", "Ein Blas weit draußen in der Dämmerung: das Größte der Welt, und es tut niemandem etwas.", "夕暮れの沖に潮吹き。世界でいちばん大きく、害はない。", "해 질 녘 먼바다의 물줄기: 세상에서 가장 큰 존재, 해를 끼치지 않는다.", "黄昏的外海一道水柱：世上最大的生灵，毫无恶意。"),
         L("Watch the open sea from high cliffs at dusk.", "Observa el mar abierto desde acantilados altos al atardecer.", "Observe o mar aberto de penhascos altos ao entardecer.", "Observez le large depuis de hautes falaises au crépuscule.", "Beobachte in der Dämmerung von hohen Klippen das offene Meer.", "夕暮れ、高い崖から沖を見よ。", "해 질 녘 높은 절벽에서 먼바다를 봐.", "黄昏时从高崖眺望外海。"),
         (-250, 1380), {"cosmetic": "echo_storm"}, radius=40, conditions={"hours": [16, 21]}, icon="✧",
         spawns=[{"kind": "creature", "entity": "ANIMAL_DRIFT_WHALE", "group": "drift_whale", "pos": [-250, 1380]}]),
    disc("sea_lantern_squid", L("Lights from the Deep", "Luces del abismo", "Luzes do abismo", "Lumières des profondeurs", "Lichter aus der Tiefe", "深みの灯", "심연의 빛", "深渊之光"),
         L("At night, out where the water turns black, the squid rise glowing. You caught one.", "De noche, donde el agua se vuelve negra, suben los calamares brillando. Pescaste uno.", "À noite, onde a água fica negra, as lulas sobem brilhando. Você pescou uma.", "La nuit, là où l'eau devient noire, les calmars remontent en luisant. Vous en avez pris un.", "Nachts, wo das Wasser schwarz wird, steigen die Kalmare leuchtend auf. Du hast einen gefangen.", "夜、水が黒くなる沖でイカが光って上がる。一杯釣った。", "밤, 물이 검어지는 곳에서 오징어가 빛나며 올라온다. 하나를 낚았다.", "夜里，海水发黑的地方乌贼发着光浮上来。你钓到了一只。"),
         L("Sabel: 'Deep-water fish won't come near the shore. You need to be out there.'", "Sabel: 'Los peces de altamar no se acercan a la orilla. Tienes que estar allá afuera.'", "Sabel: 'Peixes de águas fundas não chegam à praia. Você precisa estar lá fora.'", "Sabel : « Les poissons du large ne viennent pas près du rivage. Il faut être là-bas. »", "Sabel: „Tiefwasserfische kommen nicht ans Ufer. Du musst da draußen sein.“", "サベル「外洋の魚は浜に寄らない。沖に出ないと」", "사벨: '먼바다 물고기는 해안에 오지 않아. 거기까지 나가야지.'", "萨贝尔：“深海鱼不靠岸，你得出海去。”"),
         (-150, 1260), {"recipes": [["bluewater_runner", "lantern_squid", "frostmint"]]}, trigger="catch", catch="lantern_squid", icon="☾"),
]

# --- Rumours ----------------------------------------------------------------------------------------------------
_SABEL_R = ["RUMOR_TIDEKEEPER_%d" % (i + 1) for i in range(5)]
_SABEL_LOC = dict(zip(_SABEL_R, [
    L("Low water around midnight and noon, high around dawn and dusk. The sea keeps that clock.", "Marea baja hacia medianoche y mediodía, alta hacia el alba y el ocaso. El mar lleva ese reloj.", "Maré baixa perto da meia-noite e do meio-dia, alta na aurora e no crepúsculo.", "Marée basse vers minuit et midi, haute vers l'aube et le crépuscule. La mer tient cette horloge.", "Niedrigwasser um Mitternacht und Mittag, Hochwasser um Morgen- und Abenddämmerung.", "干潮は真夜中と正午、満潮は夜明けと夕暮れ。海はその時計を守る。", "간조는 자정과 정오, 만조는 새벽과 해 질 녘. 바다는 그 시계를 지켜.", "午夜和正午退潮，黎明和黄昏涨潮。大海守着这座钟。"),
    L("Swimmers ride the Gull Current to the light, and the light's current on to the Vigil. The home current brings you back.", "Los nadadores toman la Corriente de la Gaviota hasta el faro, y la del faro hasta el Vigía. La de regreso te trae.", "Nadadores pegam a Corrente da Gaivota até o farol, e a do farol até o Vigia. A de volta te traz.", "Les nageurs prennent le courant de la Mouette jusqu'au phare, puis celui du phare jusqu'à la Vigie. Le courant du retour vous ramène.", "Schwimmer reiten die Möwenströmung zum Licht und die Lichtströmung weiter zur Wacht. Die Heimströmung bringt dich zurück.", "泳ぐ者は鴎の潮で灯台へ、灯台の潮で見張りへ。帰りの潮が戻してくれる。", "헤엄치는 이는 갈매기 해류로 등대까지, 등대 해류로 망루까지 가. 귀환 해류가 데려다주지.", "游泳的人顺鸥流到灯塔，再顺灯塔流到望哨礁，回程流会送你回来。"),
    L("Farther than the Vigil you want a hull under you. That Vantrel capsule would do.", "Más allá del Vigía te conviene un casco bajo los pies. Esa cápsula de Vantrel serviría.", "Além do Vigia você quer um casco sob os pés. Aquela cápsula da Vantrel serviria.", "Au-delà de la Vigie, mieux vaut une coque sous les pieds. Cette capsule Vantrel ferait l'affaire.", "Weiter als die Wacht willst du einen Rumpf unter dir. Diese Vantrel-Kapsel wäre gut.", "見張りより先は船体が要る。ヴァントレルのカプセルならいい。", "망루보다 멀리 가려면 선체가 필요해. 반트렐 캡슐이면 되겠지.", "过了望哨礁，你得有个船壳垫脚，凡特雷尔那个舱就行。"),
    L("A fin cutting the water is a finback shadowing you. Get out, or face it when it rises.", "Una aleta cortando el agua es un aletalomo siguiéndote. Sal, o enfréntalo cuando suba.", "Uma barbatana cortando a água é um dorso-de-barbatana te seguindo. Saia, ou enfrente-o quando subir.", "Un aileron qui fend l'eau, c'est un dos-d'aileron qui vous suit. Sortez, ou affrontez-le quand il monte.", "Eine Flosse, die das Wasser schneidet, ist ein Flossenrücken, der dir folgt. Raus, oder stell dich, wenn er auftaucht.", "水を切るヒレは背ビレがつけてくる印。上がるか、浮いた時に迎え撃て。", "물을 가르는 지느러미는 등지느러미가 따라온다는 뜻. 나가든지, 솟아오를 때 맞서.", "水面划过背鳍，就是背鳍鲨跟着你。要么上岸，要么等它冒头时迎战。"),
    L("In a storm stay off iron and crystal. Or don't — that's where the glass is.", "Con tormenta aléjate del hierro y el cristal. O no: ahí es donde está el cristal bueno.", "Na tempestade fique longe do ferro e do cristal. Ou não — é lá que está o vidro.", "Dans l'orage, évitez le fer et le cristal. Ou pas — c'est là qu'est le verre.", "Im Sturm bleib weg von Eisen und Kristall. Oder nicht — da ist das Glas.", "嵐の時は鉄と水晶に近づくな。いや――硝子はそこにある。", "폭풍엔 쇠와 수정을 피해. 아니면 말고, 유리는 거기 있으니까.", "暴风雨时离铁和水晶远点。或者别——晶体就长在那儿。"),
]))
ENTITY_PATCHES = {"NPC_TIDEKEEPER": {"dialogue": {"rumors": _SABEL_R}}}

STRINGS = dict(_SABEL_LOC, **dict(zip(PAGE_KEYS, PAGE_LINES)))
STRINGS.update({
    "TIDE_LOW": L("Low tide", "Marea baja", "Maré baixa", "Marée basse", "Niedrigwasser", "干潮", "간조", "退潮"),
    "TIDE_HIGH": L("High tide", "Marea alta", "Maré alta", "Marée haute", "Hochwasser", "満潮", "만조", "涨潮"),
    "TIDE_RISING": L("Tide rising", "Marea subiendo", "Maré subindo", "Marée montante", "Flut steigt", "上げ潮", "밀물", "潮涨中"),
    "TIDE_FALLING": L("Tide falling", "Marea bajando", "Maré baixando", "Marée descendante", "Ebbe fällt", "下げ潮", "썰물", "潮落中"),
    "HINT_SURF": L("The surf throws you back. It will be calmer at low tide.", "El oleaje te echa atrás. Con marea baja estará más calmo.", "A arrebentação te joga para trás. Na maré baixa estará mais calmo.", "Le ressac vous repousse. Ce sera plus calme à marée basse.", "Die Brandung wirft dich zurück. Bei Niedrigwasser ist es ruhiger.", "波に押し戻される。干潮なら穏やかだ。", "파도에 밀려난다. 간조엔 잔잔할 것이다.", "浪把你推回去了，退潮时会平静些。"),
    "HINT_LAMP_NIGHT": L("The lamp only matters after dark.", "El farol solo importa de noche.", "A lanterna só importa depois de escurecer.", "La lampe ne compte qu'à la nuit tombée.", "Die Lampe zählt erst nach Einbruch der Dunkelheit.", "灯は暗くなってから意味がある。", "등불은 어두워진 뒤에야 의미가 있다.", "灯只有天黑后才有用。"),
    "LINE_LAMP_LIT": L("The wick catches. The lens turns. A beam walks out over the south sea.", "La mecha prende. La lente gira. Un haz sale a caminar sobre el mar del sur.", "O pavio pega. A lente gira. Um facho sai caminhando sobre o mar do sul.", "La mèche prend. La lentille tourne. Un faisceau s'avance sur la mer du sud.", "Der Docht fängt Feuer. Die Linse dreht sich. Ein Strahl wandert übers Südmeer.", "芯に火が移り、レンズが回る。光が南の海を渡っていく。", "심지에 불이 붙고 렌즈가 돈다. 빛줄기가 남쪽 바다 위로 걸어 나간다.", "灯芯燃起，镜片转动，一束光走过南海。"),
    "LINE_WRECK_LEVER": L("Something heavy shifts astern. A door groans open.", "Algo pesado se mueve en popa. Una puerta cruje al abrirse.", "Algo pesado se move na popa. Uma porta range ao abrir.", "Quelque chose de lourd bouge à la poupe. Une porte s'ouvre en gémissant.", "Achtern verschiebt sich etwas Schweres. Eine Tür ächzt auf.", "船尾で重いものが動き、扉が軋んで開く。", "선미에서 무거운 게 움직이고 문이 삐걱 열린다.", "船尾有重物挪动，一扇门吱呀着开了。"),
    "LINE_GULLS_LOG": L("The last entry: 'Light's out. Steering by the Vigil. God keep the shoal off our—'", "Última entrada: 'Faro apagado. Rumbo por el Vigía. Que Dios aparte el bajío de nuestro—'", "Última entrada: 'Farol apagado. Rumo pelo Vigia. Que o bajo fique longe do nosso—'", "Dernière entrée : « Phare éteint. Cap sur la Vigie. Que le haut-fond épargne notre— »", "Letzter Eintrag: „Licht aus. Kurs nach der Wacht. Möge die Untiefe unseren—“", "最後の記述「灯台消灯。見張りを目印に。浅瀬が我らの――」", "마지막 기록: '등대 꺼짐. 망루를 보고 조타. 여울이 우리—'", "最后一条：“灯灭了，照望哨礁掌舵，愿浅滩别碰到我们的——”"),
    "PROMPT_READ": L("Read", "Leer", "Ler", "Lire", "Lesen", "読む", "읽기", "阅读"),
    "COND_BY_BOAT": L("by boat", "en barco", "de barco", "en bateau", "mit dem Boot", "船で", "배로", "乘船"),
    "BUFF_BREATH": L("Deep breath", "Aliento largo", "Fôlego longo", "Souffle long", "Langer Atem", "長い息", "긴 숨", "长息"),
    "NAME_TIDEKEEPER": L("Sabel, tidekeeper", "Sabel, guardamareas", "Sabel, guarda-marés", "Sabel, gardienne des marées", "Sabel, Gezeitenwärterin", "潮守りサベル", "조수지기 사벨", "守潮人萨贝尔"),
})

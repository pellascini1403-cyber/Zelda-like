"""Phase 3 — the forest and the lake as places with their own rules.

Forest (Threshold Wood): glowcaps open at night (light paths, spores that
hide you), bellcaps swell in rain (bounce you high), brambles burn in dry
weather. The Canopy Walk, the Hollow Tree (three weather-chosen ways in)
and the Moon Shrine hang off those rules; a hunter's ribbon trail, a rare
mist fox and the weeping grove are wonders you simply find.

Lake (Mirror Lake): fishing (species by hour/weather), diving (breath,
bubble vents), the Sunken Shrine (three drowned bells), the storm buoys
that drink lightning, drowned lanterns at night, a white heron at dawn.

Water systems (FishingSpot, DiveState, AirVent, StormBuoy) are the same for
coast and sea — the coast fishing spots below prove it.
"""
import math
from qdsl import L

# --- Places -------------------------------------------------------------------------------------------
SHRINE_POS = (635, 195)
TRAIL_ABS = [(548, 262), (560, 252), (572, 244), (585, 235), (597, 226), (608, 217), (617, 209), (625, 202)]
TRAIL = [[x - SHRINE_POS[0], z - SHRINE_POS[1]] for x, z in TRAIL_ABS]


def poi(pid, typ, name, pos, **kw):
    d = {"id": pid, "type": typ, "name_key": "POI_" + pid.upper(), "pos": list(pos)}
    d.update(kw)
    return d, {"POI_" + pid.upper(): name}


POIS = [
    poi("canopy_walk", "canopy_walk", L("Canopy Walk", "Pasarela de las Copas", "Passarela das Copas", "Passerelle des cimes", "Wipfelpfad", "樹冠の渡り", "나무 꼭대기 길", "林冠栈道"),
        (430, 280), clear_radius=22, discover_radius=34, reward=[{"id": "gale_feather", "count": 3}]),
    poi("hollow_tree", "hollow_tree", L("The Hollow Tree", "El Árbol Hueco", "A Árvore Oca", "L'Arbre creux", "Der Hohle Baum", "うろの大樹", "속 빈 나무", "空心古树"),
        (390, 318), flatten=15, pad_height=14.0, pit=[4.8, 7.5], clear_radius=34, discover_radius=36,
        reward=[{"id": "rootgrip_charm", "count": 1}, {"id": "heartwood", "count": 2}]),
    poi("moon_shrine", "moon_shrine", L("Moon Shrine", "Santuario Lunar", "Santuário Lunar", "Sanctuaire lunaire", "Mondschrein", "月の祠", "달의 사당", "月之祠"),
        SHRINE_POS, flatten=10, pad_height=20.5, clear_radius=14, discover_radius=24, yaw=0.4, loot="chest_rare",
        trail=TRAIL, gate_flag="moon_gate_open", discovery="forest_moon_gate", reward=[{"id": "hush_tea", "count": 2}]),
    poi("sunken_shrine", "sunken_shrine", L("Sunken Shrine", "Santuario Hundido", "Santuário Submerso", "Sanctuaire englouti", "Versunkener Schrein", "沈んだ祠", "가라앉은 사당", "沉没之祠"),
        (-420, 100), flatten=12, pad_height=-8.5, clear_radius=16, discover_radius=18, loot="chest_rare", gate_flag="sunken_bells",
        reward=[{"id": "tide_charm", "count": 1}, {"id": "lake_pearl", "count": 1}]),
]

# --- Items --------------------------------------------------------------------------------------------


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
    item("glowcap", "food", L("Glowcap", "Luzcapuchón", "Lumichapéu", "Luminelle", "Glimmhut", "光茸", "빛버섯", "萤光菇"),
         L("Opens only at night. Offered, cooked, or simply carried for its faint light.", "Solo se abre de noche. Se ofrenda, se cocina o se lleva por su tenue luz.", "Só abre à noite. Oferecido, cozido ou levado pela luz tênue.", "Ne s'ouvre que la nuit. Offert, cuisiné, ou porté pour sa faible lueur.", "Öffnet sich nur nachts. Geopfert, gekocht oder wegen seines Schimmers getragen.", "夜にだけ開く。供えても、煮ても、灯りにしてもいい。", "밤에만 핀다. 바치거나, 요리하거나, 은은한 빛에 들고 다닌다.", "只在夜里张开。可供奉、可入菜，也能借它微光照路。"),
         icon="res://assets/icons/food_mushroom.svg", use_action="eat", value=6, effects=[{"type": "heal", "amount": 6}], cook={"mending": 1.0}),
    item("bellcap_membrane", "material", L("Bellcap skin", "Piel de campanilla", "Pele de campânula", "Peau de clochette", "Glockenhaut", "鐘茸の皮", "종버섯 껍질", "钟菇皮"),
         L("Rubbery and waterproof. It still springs back when pressed.", "Gomosa e impermeable. Aún rebota al presionarla.", "Borrachuda e impermeável. Ainda volta ao apertar.", "Caoutchouteuse et imperméable. Elle rebondit encore quand on la presse.", "Gummiartig und wasserdicht. Federt noch zurück, wenn man drückt.", "ゴムのようで水を通さない。押すとまだ跳ね返る。", "고무 같고 물이 새지 않는다. 누르면 아직 튀어 오른다.", "像橡胶，不透水，一按还会弹回来。"),
         icon="res://assets/icons/mat_hide.svg", value=8),
    item("heartwood", "material", L("Heartwood", "Duramen", "Cerne", "Cœur de bois", "Kernholz", "心材", "심재", "心材"),
         L("From the root-heart of the Hollow Tree. Pale, hard, warm to the touch.", "Del corazón de raíces del Árbol Hueco. Pálido, duro, tibio al tacto.", "Do coração de raízes da Árvore Oca. Pálido, duro, morno ao toque.", "Du cœur de racines de l'Arbre creux. Pâle, dur, tiède au toucher.", "Aus dem Wurzelherz des Hohlen Baums. Blass, hart, warm.", "うろの大樹の根の心から。白く硬く、ほのかに温かい。", "속 빈 나무의 뿌리 심장에서. 창백하고 단단하며 따뜻하다.", "取自空心古树的根心，色浅质坚，摸着微温。"),
         icon="res://assets/icons/mat_wood.svg", value=40, rarity=2),
    item("mist_fur", "material", L("Mist fox fur", "Pelo de zorro de niebla", "Pelo de raposa-névoa", "Fourrure de renard de brume", "Nebelfuchsfell", "霧狐の毛", "안개여우 털", "雾狐毛"),
         L("A tuft it left on a bramble. Silver, and cold as the dawn it ran through.", "Un mechón que dejó en una zarza. Plateado y frío como el alba.", "Um tufo deixado num espinheiro. Prateado e frio como a aurora.", "Une touffe laissée sur une ronce. Argentée, froide comme l'aube.", "Ein Büschel an einem Dornbusch. Silbern und kalt wie der Morgen.", "茨に残った一房。銀色で、夜明けのように冷たい。", "가시덤불에 남긴 한 줌. 은빛이고 새벽처럼 차갑다.", "挂在荆棘上的一撮，银白，冷如黎明。"),
         icon="res://assets/icons/mat_hide.svg", value=80, rarity=3),
    item("mossweave_hood", "armor", L("Mossweave hood", "Capucha de musgo tejido", "Capuz de musgo trançado", "Capuche de mousse tissée", "Moosgewebe-Kapuze", "苔織りの頭巾", "이끼 엮은 두건", "苔织兜帽"),
         L("Varra's spare. Soft steps, soft outline: creatures notice you later.", "La de repuesto de Varra. Pasos suaves, silueta suave: te notan más tarde.", "O reserva da Varra. Passos leves, silhueta suave: notam você mais tarde.", "Celle de rechange de Varra. Pas feutrés, silhouette floue : on vous remarque plus tard.", "Varras Ersatz. Leise Schritte, weiche Kontur: Wesen bemerken dich später.", "ヴァラの予備。足音も輪郭もやわらぐ。気づかれにくい。", "바라의 여분. 발소리도 윤곽도 부드러워 늦게 들킨다.", "瓦拉的备用兜帽。步轻影淡，生灵更晚察觉你。"),
         icon="res://assets/icons/armor_head.svg", value=70, rarity=2, armor={"slot": "head", "defense": 1, "stealth": 0.25}),
    item("rootgrip_charm", "armor", L("Rootgrip charm", "Amuleto de raíz", "Amuleto de raiz", "Charme de racine", "Wurzelgriff-Amulett", "根掴みの護符", "뿌리손 부적", "根握护符"),
         L("A knot of heartwood roots. Your hands find holds faster; your feet fall quieter.", "Un nudo de raíces de duramen. Tus manos encuentran agarre antes; tus pasos suenan menos.", "Um nó de raízes de cerne. As mãos acham apoio mais rápido; os passos soam menos.", "Un nœud de racines. Vos mains trouvent prise plus vite ; vos pas font moins de bruit.", "Ein Knoten aus Kernholzwurzeln. Die Hände finden schneller Halt, die Schritte sind leiser.", "心材の根の結び目。手は早く掴み、足音は静かに。", "심재 뿌리 매듭. 손은 더 빨리 붙잡고 발소리는 조용해진다.", "心材根结。手更快抓稳，脚步更轻。"),
         icon="res://assets/icons/armor_accessory.svg", value=110, rarity=3, armor={"slot": "accessory", "defense": 0, "climb_speed": 0.2, "stealth": 0.1}),
    item("hush_tea", "food", L("Hush tea", "Té del silencio", "Chá do silêncio", "Thé du silence", "Stilletee", "静寂の茶", "고요의 차", "静息茶"),
         L("Glowcap and frostmint. For a while, the world has to strain to hear you.", "Luzcapuchón y menta helada. Por un rato, al mundo le cuesta oírte.", "Lumichapéu e menta-gelada. Por um tempo, o mundo mal te ouve.", "Luminelle et menthe-givre. Un temps, le monde peine à vous entendre.", "Glimmhut und Frostminze. Eine Weile muss die Welt sich anstrengen, dich zu hören.", "光茸と霜ミント。しばらく世界はあなたの音を聞き取れない。", "빛버섯과 서리박하. 한동안 세상은 네 소리를 듣기 어렵다.", "萤光菇配霜薄荷。一阵子里，世界很难听见你。"),
         icon="res://assets/icons/food_dish.svg", use_action="eat", value=30, rarity=2, effects=[{"type": "heal", "amount": 10}, {"type": "buff", "buff": "stealth", "amount": 1, "duration": 180}]),
    item("fishing_rod", "key", L("Fishing rod", "Caña de pescar", "Vara de pesca", "Canne à pêche", "Angelrute", "釣り竿", "낚싯대", "钓竿"),
         L("Ilo's old bamboo rod. Find rings on the water, cast, wait for the dip, pull.", "La vieja caña de bambú de Ilo. Busca anillos en el agua, lanza, espera el tirón, recoge.", "A velha vara de bambu do Ilo. Ache anéis na água, lance, espere o puxão, puxe.", "La vieille canne en bambou d'Ilo. Cherchez des ronds dans l'eau, lancez, attendez la touche, tirez.", "Ilos alte Bambusrute. Ringe im Wasser suchen, auswerfen, auf das Zucken warten, ziehen.", "イロの古い竹竿。水の輪を探し、投げ、沈むのを待ち、引く。", "일로의 낡은 대나무 낚싯대. 물의 파문을 찾아 던지고, 찌가 잠기면 당긴다.", "伊洛的旧竹竿。找水面涟漪，抛竿，等浮漂一沉，提竿。"),
         icon="res://assets/icons/tool_whetstone.svg", max_stack=1, value=20),
    fish("mirror_perch", L("Mirror perch", "Perca espejo", "Perca-espelho", "Perche miroir", "Spiegelbarsch", "鏡スズキ", "거울농어", "镜鲈"),
         L("The lake's everyday fish. Silver as its name.", "El pez de todos los días del lago. Plateado como su nombre.", "O peixe de todo dia do lago. Prateado como o nome.", "Le poisson ordinaire du lac. Argenté comme son nom.", "Der Alltagsfisch des Sees. Silbern wie sein Name.", "湖のいつもの魚。名のとおり銀色。", "호수의 흔한 물고기. 이름처럼 은빛이다.", "湖里的家常鱼，银亮如其名。"), 12, {"heal": 1.5}, 4),
    fish("reed_pike", L("Reed pike", "Lucio de juncos", "Lúcio-dos-juncos", "Brochet des roseaux", "Schilfhecht", "葦カマス", "갈대창꼬치", "芦苇狗鱼"),
         L("Hunts the reeds at dawn and dusk. Firm, rich meat.", "Caza entre los juncos al alba y al ocaso. Carne firme y sabrosa.", "Caça nos juncos na aurora e no crepúsculo. Carne firme.", "Chasse dans les roseaux à l'aube et au crépuscule. Chair ferme.", "Jagt im Schilf bei Morgen- und Abenddämmerung. Festes Fleisch.", "朝夕に葦間で狩る。身は締まって濃い。", "새벽과 해질녘 갈대 사이서 사냥한다. 살이 단단하다.", "晨昏在芦苇间捕食，肉质紧实。"), 18, {"heal": 1.5, "fierce": 1.0}, 8),
    fish("moon_carp", L("Moon carp", "Carpa lunar", "Carpa-lua", "Carpe de lune", "Mondkarpfen", "月鯉", "달잉어", "月鲤"),
         L("Rises only at night. Its scales hold a little of the moon.", "Solo sube de noche. Sus escamas guardan algo de luna.", "Só sobe à noite. As escamas guardam um pouco da lua.", "Ne monte que la nuit. Ses écailles gardent un peu de lune.", "Steigt nur nachts auf. Seine Schuppen halten ein wenig Mond.", "夜にだけ浮かぶ。鱗に月が少し宿る。", "밤에만 떠오른다. 비늘에 달빛이 조금 남아 있다.", "只在夜里浮起，鳞片里存着一点月光。"), 30, {"heal": 2.0, "mending": 1.0}, 40, 3),
    fish("stormfin", L("Stormfin", "Aleta de tormenta", "Barbatana-tempestade", "Nageoire d'orage", "Sturmflosse", "嵐ビレ", "폭풍지느러미", "风暴鳍"),
         L("Only bites when thunder shakes the water. Tingles on the tongue.", "Solo pica cuando el trueno sacude el agua. Cosquillea en la lengua.", "Só morde quando o trovão sacode a água. Formiga na língua.", "Ne mord que quand le tonnerre secoue l'eau. Picote sur la langue.", "Beißt nur, wenn Donner das Wasser schüttelt. Kribbelt auf der Zunge.", "雷が水を揺らすときだけ食う。舌がぴりっとする。", "천둥이 물을 흔들 때만 문다. 혀가 찌릿하다.", "只在雷震水面时咬钩，吃着舌头发麻。"), 20, {"heal": 1.5, "swift": 1.0}, 25, 2),
    fish("silverback", L("Silverback", "Lomo de plata", "Dorso-de-prata", "Dos-d'argent", "Silberrücken", "銀背", "은등고기", "银背鱼"),
         L("Salt-water schooling fish. The coast lives on it.", "Pez de banco de agua salada. La costa vive de él.", "Peixe de cardume do mar. A costa vive dele.", "Poisson de banc d'eau salée. La côte en vit.", "Salzwasser-Schwarmfisch. Die Küste lebt davon.", "群れる海の魚。海辺の暮らしを支える。", "무리 짓는 바닷고기. 해안은 이걸로 산다.", "成群的海鱼，海边人家靠它过活。"), 14, {"heal": 1.5}, 5),
    fish("reef_glint", L("Reef glint", "Destello de arrecife", "Lampejo-do-recife", "Éclat de récif", "Riffglitzer", "礁のきらめき", "산호 반짝이", "礁光鱼"),
         L("A flash of orange in clear noon water. Rare, and gone in a blink.", "Un destello naranja en el agua clara del mediodía. Raro y fugaz.", "Um lampejo laranja na água clara do meio-dia. Raro e fugaz.", "Un éclair orange dans l'eau claire de midi. Rare et fugace.", "Ein orangefarbener Blitz im klaren Mittagswasser. Selten, im Nu fort.", "澄んだ昼の水に橙のひらめき。まれで一瞬。", "맑은 한낮 물속의 주황 번쩍임. 드물고 순식간이다.", "正午清水里一闪橙光，罕见，转瞬即逝。"), 22, {"heal": 1.5, "vigor": 1.0}, 35, 3),
    item("storm_glass", "material", L("Stormglass", "Cristal de tormenta", "Vidro-tempestade", "Verre d'orage", "Sturmglas", "嵐硝子", "폭풍유리", "雷晶"),
         L("Lightning fused into glass on an iron buoy. It hums in the hand.", "Rayo fundido en vidrio sobre una boya de hierro. Zumba en la mano.", "Raio fundido em vidro numa boia de ferro. Zumbe na mão.", "La foudre fondue en verre sur une bouée de fer. Il bourdonne dans la main.", "Zu Glas geschmolzener Blitz auf einer Eisenboje. Summt in der Hand.", "鉄のブイで雷が溶けてできた硝子。手の中で唸る。", "쇠 부표 위에 번개가 녹아 된 유리. 손안에서 웅웅댄다.", "雷落铁浮标熔成的晶体，握在手里嗡嗡作响。"),
         icon="res://assets/icons/mat_gem.svg", value=45, rarity=2, tags=["metal"]),
    item("lake_pearl", "material", L("Lake pearl", "Perla del lago", "Pérola do lago", "Perle du lac", "Seeperle", "湖の真珠", "호수 진주", "湖珠"),
         L("Grey-green and perfectly round. Merchants pay well; smiths pay better.", "Gris verdosa y perfectamente redonda. Los mercaderes pagan bien; los herreros, mejor.", "Cinza-esverdeada e perfeitamente redonda. Mercadores pagam bem; ferreiros, melhor.", "Gris-vert et parfaitement ronde. Les marchands paient bien ; les forgerons, mieux.", "Graugrün und vollkommen rund. Händler zahlen gut, Schmiede besser.", "灰緑で完全な球。商人は高く、鍛冶屋はもっと高く買う。", "회녹색에 완벽히 둥글다. 상인은 잘 쳐 주고 대장장이는 더 잘 쳐 준다.", "灰绿浑圆，商人出价高，铁匠出价更高。"),
         icon="res://assets/icons/mat_gem.svg", value=60, rarity=2),
    item("tide_charm", "armor", L("Tide charm", "Amuleto de marea", "Amuleto da maré", "Charme des marées", "Gezeitenamulett", "潮の護符", "조수 부적", "潮汐护符"),
         L("From the drowned sanctum. You hold your breath far longer, and swim faster.", "Del santuario ahogado. Aguantas la respiración mucho más y nadas más rápido.", "Do santuário afogado. Prende a respiração muito mais e nada mais rápido.", "Du sanctuaire noyé. Vous retenez votre souffle bien plus longtemps et nagez plus vite.", "Aus dem versunkenen Heiligtum. Du hältst die Luft viel länger an und schwimmst schneller.", "沈んだ聖所から。息がずっと長く続き、速く泳げる。", "가라앉은 성소에서. 숨을 훨씬 오래 참고 더 빨리 헤엄친다.", "出自沉没的圣所。憋气更久，游得更快。"),
         icon="res://assets/icons/armor_accessory.svg", value=120, rarity=3, armor={"slot": "accessory", "defense": 0, "breath": 0.5, "swim_speed": 0.25}),
]

COSMETICS = [
    ({"id": "ribbon_moon", "slot": "glider_trail", "name_key": "COS_RIBBON_MOON", "color": "#bfe8ff"},
     {"COS_RIBBON_MOON": L("Moonlit ribbon", "Cinta de luna", "Fita enluarada", "Ruban lunaire", "Mondband", "月光の帯", "달빛 리본", "月光绸带")}),
    ({"id": "ribbon_heron", "slot": "glider_trail", "name_key": "COS_RIBBON_HERON", "color": "#f4f4ec"},
     {"COS_RIBBON_HERON": L("Heron plume", "Pluma de garza", "Pluma de garça", "Plume de héron", "Reiherfeder", "鷺の羽", "왜가리 깃", "鹭羽")}),
]

SPECIALS = [{"id": "hush_tea", "ingredients": ["glowcap", "glowcap", "frostmint"], "item": "hush_tea", "potency": 1.0}]
BUFFS = {"stealth": {"name_key": "BUFF_STEALTH"}}

# --- Creatures for the regions ------------------------------------------------------------------------


def variant(eid, base, color, name, visual=None, **kw):
    key = "NAME_" + eid.split("_", 1)[1]
    d = {"id": eid, "variant_of": base, "name_key": key, "placeholder_color": color}
    d.update(kw)
    v = dict({"id": eid}, **(visual or {}))
    return d, {key: name}, v


_V = [
    variant("ENEMY_ELDER_CARAPACE", "ENEMY_BRAMBLE_CARAPACE", "#2c8a1a", L("Elder Carapace", "Caparazón anciano", "Carapaça anciã", "Carapace ancienne", "Uralter Panzer", "古老の甲虫", "고목 갑충", "古甲虫"),
            {"rank": "elite", "features": ["back_spikes", "crystal_back"], "scale": 1.35},
            stats={"max_health": 150, "defense": 2, "poise": 55, "mass": 240}, loot_table="drop_elder_carapace", ai={"armor_mult": 0.05, "flipped_time": 4.0, "respawn_hours": 168},
            # The old ones carry a garden of sap on their backs: close in and
            # it bursts, gluing you in place for its roll.
            attacks=[{"id": "horn", "type": "melee", "range_min": 0, "range_max": 2.8, "windup": 0.7, "recovery": 0.8, "cooldown": 1.4, "damage": 16, "knockback": 7, "reach": 2.4, "arc": 45, "weight": 2},
                     {"id": "sap_burst", "type": "pulse", "range_min": 0, "range_max": 4.0, "windup": 1.0, "recovery": 1.0, "cooldown": 6.0, "damage": 6, "radius": 4.0, "knockback": 2, "element": "web", "blockable": False, "weight": 2},
                     {"id": "roll", "type": "charge", "range_min": 5, "range_max": 16, "windup": 0.9, "active": 1.1, "recovery": 1.2, "cooldown": 5.0, "damage": 20, "knockback": 11, "reach": 16, "charge_speed": 14, "poise_damage": 30}]),
    variant("ANIMAL_BRUSH_FOX", "ANIMAL_DUNE_FOX", "#d55f0c", L("Brush fox", "Zorro de maleza", "Raposa-do-mato", "Renard des fourrés", "Buschfuchs", "藪ギツネ", "덤불여우", "灌木狐")),
    variant("ANIMAL_MIST_FOX", "ANIMAL_DUNE_FOX", "#c6b1c4", L("Mist fox", "Zorro de niebla", "Raposa-névoa", "Renard de brume", "Nebelfuchs", "霧狐", "안개여우", "雾狐"),
            {"features": ["big_ears", "tail", "shimmer"], "scale": 0.6}, active_period="any", loot_table="drop_mist_fox", ai={"skittish": 0.02, "respawn_hours": 999999}),
    variant("ANIMAL_WHITE_HERON", "ANIMAL_REED_HERON", "#ffe7d0", L("White heron", "Garza blanca", "Garça-branca", "Héron blanc", "Silberreiher", "白鷺", "흰왜가리", "白鹭"),
            {"species": "wader", "scale": 1.25}, loot_table="drop_white_heron", ai={"respawn_hours": 999999}),
]
ENTITIES = [(d, l) for d, l, _v in _V]
VISUALS = [v for _d, _l, v in _V]

LOOT = {
    "drop_elder_carapace": [{"id": "carapace_shard", "chance": 1.0, "count": [3, 4]}, {"id": "heartwood", "chance": 0.35, "count": [1, 1]}, {"id": "amber_sap", "chance": 0.8, "count": [2, 3]}],
    "drop_mist_fox": [{"id": "mist_fur", "chance": 1.0, "count": [1, 1]}],
    "drop_white_heron": [{"id": "gale_feather", "chance": 1.0, "count": [2, 3]}],
}


def sp(entity, weight, group, **kw):
    d = {"entity": entity, "weight": weight, "group": group}
    d.update(kw)
    return d


# Forest: ground carapaces, a rare elder, climbers on cliffs and decks, night
# swarms and foxes — no thornling packs (that is the valley's signature).
REGION_SPAWNS = {
    "forest": {
        "enemy_spawns": [sp("ENEMY_BRAMBLE_CARAPACE", 3, [1, 2]), sp("ENEMY_ELDER_CARAPACE", 0.25, [1, 1], period="day"),
                         sp("ENEMY_SPITTER", 1, [1, 1]), sp("ENEMY_DUSKWING", 2.5, [3, 5], period="night"),
                         sp("ENEMY_WISP", 1, [1, 2], period="night"), sp("ENEMY_CRAG_WEAVER", 1, [1, 1], habitat="cliff")],
        "animal_spawns": [sp("ANIMAL_BURROWHOP", 2, [1, 3]), sp("ANIMAL_WOOLHORN", 0.6, [2, 3]), sp("ANIMAL_BRUSH_FOX", 1.5, [1, 2], period="night")],
    },
    "lakeshore": {
        "enemy_spawns": [sp("ENEMY_SPITTER", 2, [1, 2]), sp("ENEMY_GLINT_THIEF", 0.4, [1, 1], period="day"), sp("ENEMY_WISP", 2, [1, 2], period="night"),
                         sp("ENEMY_MIRE_EEL", 3, [1, 2], habitat="water"), sp("ENEMY_MIRE_EEL", 4, [2, 3], habitat="water", weather=["storm"])],
        "animal_spawns": [sp("ANIMAL_REED_HERON", 3, [1, 2]), sp("ANIMAL_BURROWHOP", 1.5, [1, 2]), sp("ANIMAL_WOOLHORN", 0.7, [2, 3])],
    },
}

# --- Fishing --------------------------------------------------------------------------------------------
FISHING = {"waters": {
    "lake": [{"item": "mirror_perch", "weight": 6, "period": "day"}, {"item": "mirror_perch", "weight": 2, "period": "night"},
             {"item": "reed_pike", "weight": 4, "hours": [5, 8]}, {"item": "reed_pike", "weight": 4, "hours": [17, 20]},
             {"item": "moon_carp", "weight": 1.5, "period": "night"}, {"item": "stormfin", "weight": 5, "weather": ["storm"]},
             {"item": "raw_fish", "weight": 1}],
    "sea": [{"item": "silverback", "weight": 6}, {"item": "reef_glint", "weight": 1, "hours": [10, 15], "weather": ["clear"]},
            {"item": "stormfin", "weight": 2, "weather": ["storm"]}, {"item": "raw_fish", "weight": 2}],
}}

# --- Always-present features (sites) -----------------------------------------------------------------------
SITES = []
for i, (x, z) in enumerate([(-268, 94), (-299, 160), (-471, -42), (-506, 164)]):
    SITES.append({"kind": "feature", "feature": "fishing_spot", "id": "fish_lake_%d" % i, "waters": "lake", "pos": [x, z], "float": True, "lift": 0.05})
for i, (x, z) in enumerate([(141, 802), (327, 781), (-605, 548)]):
    SITES.append({"kind": "feature", "feature": "fishing_spot", "id": "fish_sea_%d" % i, "waters": "sea", "pos": [x, z], "float": True, "lift": 0.05})
_B0, _B1 = (-282.0, 26.0), (-313.0, 12.0)
for i in range(8):
    f = i / 7.0
    SITES.append({"kind": "feature", "feature": "storm_buoy", "id": "buoy_%d" % i, "pos": [round(_B0[0] + (_B1[0] - _B0[0]) * f, 1), round(_B0[1] + (_B1[1] - _B0[1]) * f + math.sin(i * 1.3) * 1.2, 1)], "float": True, "lift": 0.0})

# --- Discoveries --------------------------------------------------------------------------------------------


def disc(did, region, name, desc, hint, pos, reward, radius=8.0, trigger="reach", conditions=None, spawns=None, persist=False, icon="✦", **kw):
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


DISCOVERIES = [
    disc("forest_glowcap_trail", "forest",
         L("The Glowcap Trail", "El sendero de luzcapuchones", "A trilha de lumichapéus", "La piste des luminelles", "Der Glimmhutpfad", "光茸の小道", "빛버섯 길", "萤光菇小径"),
         L("At night the caps open in a line through the wood. Their dust muffles your steps.", "De noche los capuchones se abren en fila por el bosque. Su polvo apaga tus pasos.", "À noite os chapéus abrem em fila pela mata. O pó abafa seus passos.", "La nuit, les chapeaux s'ouvrent en file à travers le bois. Leur poussière étouffe vos pas.", "Nachts öffnen sich die Hüte in einer Reihe durch den Wald. Ihr Staub dämpft deine Schritte.", "夜、茸が一列に森を照らす。胞子が足音を消す。", "밤이면 버섯이 숲을 가로질러 줄지어 핀다. 포자가 발소리를 죽인다.", "夜里菌伞在林中连成一线，孢子掩住你的脚步。"),
         L("Varra: 'Pale caps east of the Elder Tree. Walk there after dark.'", "Varra: 'Capuchones pálidos al este del Árbol Anciano. Camina por allí de noche.'", "Varra: 'Chapéus pálidos a leste da Árvore Anciã. Ande por lá à noite.'", "Varra : « Des chapeaux pâles à l'est de l'Arbre ancien. Marchez-y la nuit. »", "Varra: „Blasse Hüte östlich des Ältesten Baums. Geh nach Einbruch der Dunkelheit hin.“", "ヴァラ「長老樹の東に白い茸。暗くなってから歩け」", "바라: '장로 나무 동쪽에 창백한 버섯이 있다. 어두워지면 걸어 봐.'", "瓦拉：“古树以东有白菇，天黑后去走走。”"),
         (585, 235), {"items": [{"id": "glowcap", "count": 1}], "reveal": {"pos": [635, 195], "radius": 4}}, radius=12, conditions={"period": "night"}, icon="☾",
         spawns=[{"kind": "creature", "entity": "ENEMY_DUSKWING", "group": "glowcap_roost", "pos": [603, 222], "count": 4, "spread": 4, "conditions": {"period": "night"}}], persist=True),
    disc("forest_weeping_grove", "forest",
         L("The Weeping Grove", "La Arboleda Llorona", "O Bosque que Chora", "Le Bosquet qui pleure", "Der Weinende Hain", "泣く木立", "우는 숲", "垂泪林"),
         L("In rain the bellcaps under the willows swell taut. Land on one and it throws you skyward.", "Con lluvia los campanillas bajo los sauces se hinchan. Cae en uno y te lanza al cielo.", "Na chuva as campânulas sob os salgueiros incham. Caia numa e ela te lança ao céu.", "Sous la pluie, les clochettes sous les saules gonflent. Tombez dessus : elles vous lancent au ciel.", "Bei Regen schwellen die Glockenpilze unter den Weiden. Lande auf einem, und er wirft dich himmelwärts.", "雨が降ると柳の下の鐘茸が張りつめる。乗れば空へ弾き飛ばす。", "비가 오면 버드나무 아래 종버섯이 팽팽해진다. 올라서면 하늘로 튕겨 준다.", "下雨时柳下的钟菇鼓胀起来，踩上去会把你弹上天。"),
         L("Varra: 'When it rains, the grove west of the Hollow Tree weeps — and wakes.'", "Varra: 'Cuando llueve, la arboleda al oeste del Árbol Hueco llora... y despierta.'", "Varra: 'Quando chove, o bosque a oeste da Árvore Oca chora — e desperta.'", "Varra : « Quand il pleut, le bosquet à l'ouest de l'Arbre creux pleure — et s'éveille. »", "Varra: „Wenn es regnet, weint der Hain westlich des Hohlen Baums — und erwacht.“", "ヴァラ「雨の日、うろの大樹の西の木立は泣いて、目を覚ます」", "바라: '비가 오면 속 빈 나무 서쪽 숲이 울고, 깨어난다.'", "瓦拉：“下雨时，空心古树西边的林子会哭，也会醒。”"),
         (366, 318), {"items": [{"id": "bellcap_membrane", "count": 2}]}, radius=14, conditions={"weather": ["rain", "storm"]}, icon="☂"),
    disc("forest_highest_bough", "forest",
         L("The Highest Bough", "La rama más alta", "O galho mais alto", "La plus haute branche", "Der höchste Ast", "いちばん高い枝", "가장 높은 가지", "最高的枝头"),
         L("From the crow's nest the Hollow Tree's open crown is right there — a glide away.", "Desde la cofa, la copa abierta del Árbol Hueco está ahí mismo, a un planeo.", "Do cesto da gávea, a copa aberta da Árvore Oca está logo ali — a um planar.", "Du nid-de-pie, la couronne ouverte de l'Arbre creux est là — à un vol plané.", "Vom Krähennest aus ist die offene Krone des Hohlen Baums ganz nah — einen Gleitflug entfernt.", "見張り台から、うろの大樹の開いた樹冠がすぐそこに。滑空ひとつ。", "망루에서 속 빈 나무의 열린 꼭대기가 바로 보인다. 한 번의 활공 거리.", "从瞭望台看去，空心古树敞开的树冠近在眼前，一次滑翔即达。"),
         L("Kest: 'The canopy trunks have decks every ten metres. Rest on each.'", "Kest: 'Los troncos de las copas tienen plataformas cada diez metros. Descansa en cada una.'", "Kest: 'Os troncos da copa têm plataformas a cada dez metros. Descanse em cada uma.'", "Kest : « Les troncs des cimes ont une plateforme tous les dix mètres. Reposez-vous sur chacune. »", "Kest: „Die Wipfelstämme haben alle zehn Meter Plattformen. Ruh dich auf jeder aus.“", "ケスト「樹冠の幹には十メートルごとに足場がある。都度休め」", "케스트: '나무 줄기엔 10미터마다 발판이 있어. 하나씩 쉬어 가.'", "凯丝特：“林冠那几棵树每十米一层平台，一层层歇着爬。”"),
         (442, 288), {"items": [{"id": "gale_feather", "count": 2}], "reveal": {"pos": [390, 318], "radius": 3}}, radius=3.5, conditions={"min_y": 52.0}, icon="⬆"),
    disc("forest_hollow_heart", "forest",
         L("Heart of the Hollow Tree", "Corazón del Árbol Hueco", "Coração da Árvore Oca", "Cœur de l'Arbre creux", "Herz des Hohlen Baums", "うろの大樹の心", "속 빈 나무의 심장", "空心古树之心"),
         L("Below the ground, inside the tree: a knot of pale roots that glows. Three ways lead here — fire, rain or wings.", "Bajo el suelo, dentro del árbol: un nudo de raíces pálidas que brilla. Tres caminos llevan aquí: fuego, lluvia o alas.", "Sob o chão, dentro da árvore: um nó de raízes pálidas que brilha. Três caminhos levam aqui — fogo, chuva ou asas.", "Sous terre, dans l'arbre : un nœud de racines pâles qui luit. Trois chemins y mènent — le feu, la pluie ou les ailes.", "Unter der Erde, im Baum: ein Knoten bleicher Wurzeln, der leuchtet. Drei Wege führen her — Feuer, Regen oder Flügel.", "地の下、樹の中。白い根の結び目が光る。道は三つ――火、雨、翼。", "땅 밑, 나무 안: 빛나는 창백한 뿌리 매듭. 길은 셋 — 불, 비, 날개.", "地下、树中：一团发光的白根。三条路通到这里——火、雨、翼。"),
         L("A charred smell near the Hollow Tree's door. Old brambles burn well when it's dry.", "Olor a quemado junto a la puerta del Árbol Hueco. Las zarzas viejas arden bien en seco.", "Cheiro de queimado junto à porta da Árvore Oca. Espinheiros velhos queimam bem no seco.", "Une odeur de brûlé près de la porte de l'Arbre creux. Les vieilles ronces brûlent bien par temps sec.", "Brandgeruch an der Tür des Hohlen Baums. Alte Dornen brennen gut, wenn es trocken ist.", "うろの大樹の戸口に焦げの匂い。乾いた日なら古い茨はよく燃える。", "속 빈 나무 입구에 탄내. 마른 날엔 묵은 가시덤불이 잘 탄다.", "空心古树门口有焦味。天干时老荆棘烧得很旺。"),
         (390, 318), {"items": [{"id": "heartwood", "count": 1}]}, radius=4.5, conditions={"max_y": 9.5}, icon="❦"),
    disc("forest_moon_gate", "forest",
         L("The Moon Gate", "La Puerta de la Luna", "O Portão da Lua", "La Porte de la Lune", "Das Mondtor", "月の門", "달의 문", "月门"),
         L("Three glowcaps in the moon-pool, at night, and the round stone rolls aside.", "Tres luzcapuchones en el estanque lunar, de noche, y la piedra redonda rueda.", "Três lumichapéus no lago da lua, à noite, e a pedra redonda rola.", "Trois luminelles dans le bassin lunaire, la nuit, et la pierre ronde roule.", "Drei Glimmhüte ins Mondbecken, nachts, und der runde Stein rollt beiseite.", "夜、月の池に光茸を三つ。丸い石が転がり開く。", "밤에 달의 연못에 빛버섯 셋. 둥근 돌이 굴러 열린다.", "夜里往月池放三朵萤光菇，圆石便滚开。"),
         L("The shrine at the end of the glowcap trail is shut by day.", "El santuario al final del sendero de luzcapuchones está cerrado de día.", "O santuário no fim da trilha de lumichapéus fica fechado de dia.", "Le sanctuaire au bout de la piste des luminelles est clos le jour.", "Der Schrein am Ende des Glimmhutpfads ist tagsüber verschlossen.", "光茸の小道の果ての祠は、昼は閉じている。", "빛버섯 길 끝의 사당은 낮엔 닫혀 있다.", "萤光菇小径尽头的祠，白天是封着的。"),
         SHRINE_POS, {"cosmetic": "ribbon_moon", "recipes": [["glowcap", "glowcap", "frostmint"]]}, trigger="interact", icon="☾", conditions={"period": "night"},
         found_in_poi="moon_shrine"),
    disc("forest_mist_fox", "forest",
         L("The Mist Fox", "El zorro de niebla", "A raposa-névoa", "Le renard de brume", "Der Nebelfuchs", "霧狐", "안개여우", "雾狐"),
         L("On foggy dawns a silver fox hunts the grove. Few have seen it twice.", "En albas de niebla un zorro plateado caza en la arboleda. Pocos lo han visto dos veces.", "Em auroras de névoa uma raposa prateada caça no bosque. Poucos a viram duas vezes.", "Aux aubes brumeuses, un renard argenté chasse dans le bosquet. Rares sont ceux qui l'ont vu deux fois.", "In nebligen Morgenstunden jagt ein silberner Fuchs im Hain. Wenige sahen ihn zweimal.", "霧の夜明け、銀の狐が木立で狩る。二度見た者は少ない。", "안개 낀 새벽이면 은빛 여우가 숲에서 사냥한다. 두 번 본 이는 드물다.", "雾起的黎明，一只银狐在林间捕猎，见过两次的人很少。"),
         L("Hunters speak of a silver fox — only in fog, only at first light.", "Los cazadores hablan de un zorro plateado: solo con niebla, solo al alba.", "Caçadores falam de uma raposa prateada — só na névoa, só ao amanhecer.", "Les chasseurs parlent d'un renard argenté — seulement dans la brume, seulement à l'aube.", "Jäger erzählen von einem silbernen Fuchs — nur im Nebel, nur im ersten Licht.", "狩人は銀の狐を語る。霧の日の、夜明けだけ。", "사냥꾼들은 은빛 여우를 말한다. 안개 낀 날, 새벽에만.", "猎人说有只银狐——只在雾天，只在破晓。"),
         (358, 338), {"items": [{"id": "mist_fur", "count": 1}]}, radius=16, conditions={"weather": ["fog"], "hours": [4, 10]}, icon="✧",
         spawns=[{"kind": "creature", "entity": "ANIMAL_MIST_FOX", "group": "mist_fox", "pos": [358, 338]}]),
    disc("forest_hunters_blind", "forest",
         L("Varra's Blind", "El escondite de Varra", "O esconderijo da Varra", "L'affût de Varra", "Varras Ansitz", "ヴァラの隠れ場", "바라의 은신처", "瓦拉的猎棚"),
         L("Red ribbons on stakes lead from the lodge into the trees, to a hunter's hidden cache.", "Cintas rojas en estacas llevan del refugio a los árboles, hasta un escondite de cazador.", "Fitas vermelhas em estacas levam da cabana às árvores, até o esconderijo de um caçador.", "Des rubans rouges sur des piquets mènent du pavillon aux arbres, jusqu'à la cache d'un chasseur.", "Rote Bänder an Pflöcken führen von der Hütte in die Bäume, zu einem versteckten Jägerlager.", "赤い布の杭が小屋から森へ続き、狩人の隠し場所へ導く。", "붉은 리본 말뚝이 오두막에서 숲으로 이어져 사냥꾼의 은닉처로 이끈다.", "木桩上的红布条从猎屋延进林中，通往猎人的藏物处。"),
         L("Someone marked a path with red ribbons south of the hunters' lodge.", "Alguien marcó un camino con cintas rojas al sur del refugio de cazadores.", "Alguém marcou um caminho com fitas vermelhas ao sul da cabana dos caçadores.", "Quelqu'un a balisé un chemin de rubans rouges au sud du pavillon des chasseurs.", "Jemand hat südlich der Jägerhütte einen Weg mit roten Bändern markiert.", "狩人小屋の南、誰かが赤い布で道に印をつけた。", "사냥꾼 오두막 남쪽에 누군가 붉은 리본으로 길을 표시했다.", "猎人小屋以南，有人用红布条标了条路。"),
         (330, 212), {"items": [{"id": "mossweave_hood", "count": 1}]}, trigger="interact", icon="⚑",
         spawns=[{"kind": "feature", "feature": "ribbon", "id": "blind_rib_%d" % i, "pos": list(p)} for i, p in enumerate([(362, 178), (353, 189), (344, 199), (337, 206)])]
         + [{"kind": "object", "id": "hunters_blind_cache", "look": "crate", "pos": [330, 212], "discover": "forest_hunters_blind", "prompt": "PROMPT_TAKE", "radius": 1.8}]),
    # --- Lake ---
    disc("lake_sunken_shrine", "lakeshore",
         L("The Sunken Shrine", "El Santuario Hundido", "O Santuário Submerso", "Le Sanctuaire englouti", "Der Versunkene Schrein", "沈んだ祠", "가라앉은 사당", "沉没之祠"),
         L("A hall on the lake bed. Three drowned bells, one air pocket, one sealed sanctum.", "Un salón en el fondo del lago. Tres campanas ahogadas, una bolsa de aire, un santuario sellado.", "Um salão no fundo do lago. Três sinos afogados, um bolsão de ar, um santuário selado.", "Une salle au fond du lac. Trois cloches noyées, une poche d'air, un sanctuaire scellé.", "Eine Halle auf dem Seegrund. Drei ertrunkene Glocken, eine Lufttasche, ein versiegeltes Heiligtum.", "湖底の広間。沈んだ鐘が三つ、空気溜まりが一つ、封じられた聖所が一つ。", "호수 바닥의 전당. 잠긴 종 셋, 공기 주머니 하나, 봉인된 성소 하나.", "湖底的殿堂：三口沉钟、一处气穴、一间封住的圣所。"),
         L("Ilo: 'West of the isle the lake is deep. Things down there catch the light.'", "Ilo: 'Al oeste de la isla el lago es hondo. Algo allá abajo refleja la luz.'", "Ilo: 'A oeste da ilha o lago é fundo. Coisas lá embaixo refletem a luz.'", "Ilo : « À l'ouest de l'îlot, le lac est profond. Des choses en bas attrapent la lumière. »", "Ilo: „Westlich der Insel ist der See tief. Dort unten fängt etwas das Licht.“", "イロ「島の西は深い。底で何かが光を拾う」", "일로: '섬 서쪽은 깊어. 저 아래 뭔가 빛을 받아.'", "伊洛：“小岛西边湖很深，底下有东西在反光。”"),
         (-420, 100), {"items": [{"id": "lake_pearl", "count": 1}]}, radius=11, conditions={"state": ["dive"], "max_y": -4.0}, icon="≈"),
    disc("lake_drowned_lanterns", "lakeshore",
         L("The Drowned Lanterns", "Los faroles ahogados", "As lanternas afogadas", "Les lanternes noyées", "Die ertrunkenen Laternen", "沈んだ灯籠", "잠긴 등불", "沉灯"),
         L("At night, lights glow up through the water west of the isle. Something below is still lit.", "De noche, luces brillan bajo el agua al oeste de la isla. Algo allá abajo sigue encendido.", "À noite, luzes brilham sob a água a oeste da ilha. Algo lá embaixo segue aceso.", "La nuit, des lueurs montent de l'eau à l'ouest de l'îlot. Quelque chose en bas brûle encore.", "Nachts leuchtet es westlich der Insel durchs Wasser. Dort unten brennt noch etwas.", "夜、島の西の水の下から灯りが透ける。底でまだ何かが灯っている。", "밤이면 섬 서쪽 물밑에서 빛이 비친다. 아래서 아직 뭔가 타고 있다.", "夜里，小岛西边水下透出光来，底下还有东西亮着。"),
         L("Ilo: 'Fish bite best by lantern light. Mine — or the ones under the lake.'", "Ilo: 'Los peces pican mejor con farol. El mío... o los que hay bajo el lago.'", "Ilo: 'Os peixes mordem melhor com lanterna. A minha — ou as de baixo do lago.'", "Ilo : « Le poisson mord mieux à la lanterne. La mienne — ou celles sous le lac. »", "Ilo: „Bei Laternenlicht beißen sie am besten. Meine — oder die unterm See.“", "イロ「魚は灯りで食う。わしのか、湖の下のか」", "일로: '물고기는 등불 아래서 잘 물지. 내 것이든, 호수 밑의 것이든.'", "伊洛：“鱼在灯下最爱咬钩——我的灯，或者湖底那些。”"),
         (-420, 100), {"reveal": {"pos": [-420, 100], "radius": 2}, "items": [{"id": "glowcap", "count": 1}]}, radius=26, conditions={"period": "night", "state": ["swim", "dive", "drive"]}, icon="☾"),
    disc("lake_storm_buoys", "lakeshore",
         L("The Storm Buoys", "Las boyas de tormenta", "As boias da tempestade", "Les bouées d'orage", "Die Sturmbojen", "嵐のブイ", "폭풍 부표", "风暴浮标"),
         L("In a storm the old iron buoys drink lightning and grow stormglass — if you can reach them between strikes.", "En tormenta las viejas boyas de hierro beben rayos y crían cristal de tormenta, si llegas entre descargas.", "Na tempestade as velhas boias de ferro bebem raios e criam vidro-tempestade — se chegar entre as descargas.", "Dans l'orage, les vieilles bouées de fer boivent la foudre et font pousser du verre d'orage — si vous les atteignez entre deux éclairs.", "Im Sturm trinken die alten Eisenbojen Blitze und lassen Sturmglas wachsen — wenn du sie zwischen den Einschlägen erreichst.", "嵐の日、古い鉄のブイは雷を飲み、嵐硝子を生む。落雷の合間に届けば。", "폭풍이 오면 낡은 쇠 부표가 번개를 마시고 폭풍유리를 키운다. 벼락 사이에 닿을 수 있다면.", "暴风雨时旧铁浮标吸雷生晶——前提是你能在两道雷之间够到。"),
         L("Ilo won't fish the east water in a storm. 'The buoys sing,' he says.", "Ilo no pesca en el agua del este con tormenta. 'Las boyas cantan', dice.", "Ilo não pesca na água leste na tempestade. 'As boias cantam', diz.", "Ilo ne pêche pas à l'est par temps d'orage. « Les bouées chantent », dit-il.", "Ilo fischt im Sturm nicht im Ostwasser. „Die Bojen singen“, sagt er.", "イロは嵐の日、東の水では釣らない。「ブイが歌う」と言う。", "일로는 폭풍엔 동쪽 물에서 낚시하지 않는다. '부표가 노래해'라며.", "伊洛暴风雨天不在东边水面钓鱼，说“浮标在唱歌”。"),
         (-296, 19), {"items": [{"id": "storm_glass", "count": 1}]}, radius=14, conditions={"weather": ["storm"]}, icon="ϟ"),
    disc("lake_moon_carp", "lakeshore",
         L("Moon Carp", "La carpa lunar", "A carpa-lua", "La carpe de lune", "Der Mondkarpfen", "月鯉", "달잉어", "月鲤"),
         L("It rises only at night. You caught one.", "Solo sube de noche. Pescaste una.", "Só sobe à noite. Você pescou uma.", "Elle ne monte que la nuit. Vous en avez pris une.", "Er steigt nur nachts auf. Du hast einen gefangen.", "夜にだけ浮かぶ。あなたは一尾釣り上げた。", "밤에만 떠오른다. 한 마리를 낚았다.", "只在夜里浮起，你钓到了一条。"),
         L("Ilo swears the lake keeps one fish only the moon can call.", "Ilo jura que el lago guarda un pez que solo la luna llama.", "Ilo jura que o lago guarda um peixe que só a lua chama.", "Ilo jure que le lac garde un poisson que seule la lune appelle.", "Ilo schwört, der See hütet einen Fisch, den nur der Mond ruft.", "イロは湖に月だけが呼ぶ魚がいると誓う。", "일로는 호수에 달만이 부르는 물고기가 있다고 맹세한다.", "伊洛发誓，湖里有条只有月亮唤得来的鱼。"),
         (-268, 94), {"items": [{"id": "lake_pearl", "count": 1}]}, trigger="catch", catch="moon_carp", icon="☾"),
    disc("lake_white_heron", "lakeshore",
         L("The White Heron", "La garza blanca", "A garça-branca", "Le héron blanc", "Der Silberreiher", "白鷺", "흰왜가리", "白鹭"),
         L("At dawn, a white heron stands in the shallows by the isle. It never stays long.", "Al alba, una garza blanca se posa en los bajíos junto a la isla. Nunca se queda mucho.", "Ao amanhecer, uma garça-branca pousa nos baixios junto à ilha. Nunca fica muito.", "À l'aube, un héron blanc se tient dans les hauts-fonds près de l'îlot. Il ne reste jamais longtemps.", "Im Morgengrauen steht ein Silberreiher im Flachwasser bei der Insel. Er bleibt nie lange.", "夜明け、島の浅瀬に白鷺が立つ。長くはいない。", "새벽이면 섬 옆 얕은 물에 흰왜가리가 선다. 오래 머물지 않는다.", "破晓时，一只白鹭立在小岛边的浅水里，从不久留。"),
         L("Pilgrims say a white bird at dawn means a good road. Look by the lake isle.", "Los peregrinos dicen que un ave blanca al alba es buen camino. Mira junto a la isla del lago.", "Peregrinos dizem que uma ave branca ao amanhecer é bom caminho. Olhe junto à ilha do lago.", "Les pèlerins disent qu'un oiseau blanc à l'aube annonce une bonne route. Regardez près de l'îlot.", "Pilger sagen, ein weißer Vogel im Morgengrauen bedeute einen guten Weg. Sieh bei der Seeinsel nach.", "巡礼者は言う、夜明けの白い鳥は良い旅の印。湖の島のそばを見よ。", "순례자들은 새벽의 흰 새가 좋은 길을 뜻한다 한다. 호수 섬 근처를 보라.", "朝圣者说，黎明的白鸟预示好路。去湖心岛边看看。"),
         (-450, 72), {"cosmetic": "ribbon_heron"}, radius=18, conditions={"hours": [5, 8], "not_weather": ["storm", "rain"]}, icon="✧",
         spawns=[{"kind": "creature", "entity": "ANIMAL_WHITE_HERON", "group": "white_heron", "pos": [-452, 70]}]),
]

# --- People: rumours that point at the wonders ---------------------------------------------------------------


def rumors(prefix, lines):
    keys = ["RUMOR_%s_%d" % (prefix, i + 1) for i in range(len(lines))]
    return keys, dict(zip(keys, lines))


_VARRA, _VARRA_LOC = rumors("HUNTER", [
    L("The wood has rules. Caps glow at night, caps swell in rain, and dry thorns burn.", "El bosque tiene reglas. Hongos que brillan de noche, hongos que se hinchan con lluvia, y espinas secas que arden.", "A mata tem regras. Chapéus brilham à noite, incham na chuva, e espinhos secos queimam.", "Le bois a ses règles. Des chapeaux luisent la nuit, gonflent sous la pluie, et les épines sèches brûlent.", "Der Wald hat Regeln. Hüte leuchten nachts, schwellen im Regen, und trockene Dornen brennen.", "森には掟がある。夜に光る茸、雨に膨らむ茸、乾いた茨は燃える。", "숲엔 규칙이 있다. 밤에 빛나는 버섯, 비에 부푸는 버섯, 마른 가시는 탄다.", "林子有规矩：夜里菇发光，雨里菇鼓胀，干荆棘会烧。"),
    L("Walk through glowcap dust and nothing hears you. Good for a hunter. Better for a thief.", "Camina entre polvo de luzcapuchón y nada te oye. Bueno para un cazador. Mejor para un ladrón.", "Ande pelo pó de lumichapéu e nada te ouve. Bom para caçador. Melhor para ladrão.", "Marchez dans la poussière de luminelle et rien ne vous entend. Bon pour un chasseur. Meilleur pour un voleur.", "Geh durch Glimmhutstaub und nichts hört dich. Gut für Jäger. Besser für Diebe.", "光茸の粉を浴びれば誰にも聞こえない。狩人に良く、盗人にはもっと良い。", "빛버섯 가루를 지나면 아무도 못 듣는다. 사냥꾼에게 좋고, 도둑에겐 더 좋다.", "从萤光菇粉里走过，谁也听不见你。猎人用着好，小偷用着更好。"),
    L("Weavers wait on the canopy decks. Look up before you climb.", "Las tejedoras esperan en las plataformas de las copas. Mira arriba antes de trepar.", "Tecelãs esperam nas plataformas das copas. Olhe para cima antes de escalar.", "Les tisseuses attendent sur les plateformes des cimes. Regardez en haut avant de grimper.", "Weberinnen lauern auf den Wipfelplattformen. Schau hoch, bevor du kletterst.", "織り蜘蛛が樹冠の足場で待つ。登る前に上を見ろ。", "거미들이 나무 발판에서 기다린다. 오르기 전에 위를 봐.", "织蛛守在林冠平台上，爬之前先抬头看。"),
    L("I lost a hood somewhere south of here. Followed my own ribbons and still lost it.", "Perdí una capucha al sur de aquí. Seguí mis propias cintas y aun así la perdí.", "Perdi um capuz ao sul daqui. Segui minhas fitas e ainda assim perdi.", "J'ai perdu une capuche au sud d'ici. J'ai suivi mes propres rubans et je l'ai quand même perdue.", "Ich hab südlich von hier eine Kapuze verloren. Bin meinen eigenen Bändern gefolgt und hab sie trotzdem verloren.", "南でどこかに頭巾を落とした。自分の布をたどっても見つからん。", "여기 남쪽 어딘가에 두건을 잃었다. 내 리본을 따라가도 못 찾았지.", "我在南边丢了顶兜帽，顺着自己的布条走都没找着。"),
])
_ILO, _ILO_LOC = rumors("FISHER", [
    L("Perch by day, pike at dawn and dusk. At night… something else comes up.", "Percas de día, lucios al alba y al ocaso. De noche... sube otra cosa.", "Percas de dia, lúcios na aurora e no crepúsculo. À noite… sobe outra coisa.", "Perches le jour, brochets à l'aube et au crépuscule. La nuit… autre chose monte.", "Barsche am Tag, Hechte in der Dämmerung. Nachts … kommt etwas anderes hoch.", "昼はスズキ、朝夕はカマス。夜は……別のものが上がる。", "낮엔 농어, 새벽과 저녁엔 창꼬치. 밤엔… 다른 게 올라와.", "白天钓鲈，晨昏钓狗鱼。夜里嘛……会上来别的。"),
    L("Rain makes them bold. A bright still noon makes them sulk.", "La lluvia los envalentona. Un mediodía claro y quieto los enfurruña.", "A chuva os deixa ousados. Um meio-dia claro e parado os deixa amuados.", "La pluie les rend hardis. Un midi clair et calme les fait bouder.", "Regen macht sie kühn. Ein heller, stiller Mittag macht sie mürrisch.", "雨は魚を大胆にする。晴れて凪いだ昼はすねる。", "비는 물고기를 대담하게 해. 맑고 잔잔한 한낮엔 토라지고.", "下雨鱼就胆大，晴空无风的正午就闹脾气。"),
    L("West of the isle the lake goes deep. I've seen lights down there at night.", "Al oeste de la isla el lago se hunde. He visto luces allá abajo de noche.", "A oeste da ilha o lago afunda. Já vi luzes lá embaixo à noite.", "À l'ouest de l'îlot, le lac plonge. J'ai vu des lumières en bas, la nuit.", "Westlich der Insel wird der See tief. Nachts hab ich da unten Lichter gesehen.", "島の西は深い。夜、底に灯りを見た。", "섬 서쪽은 깊어져. 밤에 저 아래 불빛을 봤어.", "小岛西边湖水陡深，夜里我见过底下有光。"),
    L("Storm on the lake? Stay off the east water. The iron buoys sing, then they burn.", "¿Tormenta en el lago? Lejos del agua del este. Las boyas de hierro cantan y luego arden.", "Tempestade no lago? Fique longe da água leste. As boias de ferro cantam, depois queimam.", "Orage sur le lac ? Évitez l'eau de l'est. Les bouées de fer chantent, puis brûlent.", "Sturm auf dem See? Bleib vom Ostwasser weg. Die Eisenbojen singen, dann brennen sie.", "湖に嵐？東の水には近づくな。鉄のブイは歌い、そして燃える。", "호수에 폭풍? 동쪽 물은 피해. 쇠 부표가 노래하다 불타.", "湖上起风暴？离东边水面远点，铁浮标先唱歌，后冒火。"),
    L("Diving? Dodge under the surface. Your breath is your stamina — watch the bubbles in the ruins.", "¿Bucear? Esquiva bajo la superficie. Tu aliento es tu energía; busca las burbujas en las ruinas.", "Mergulhar? Esquive sob a superfície. Seu fôlego é sua energia — procure as bolhas nas ruínas.", "Plonger ? Esquivez sous la surface. Votre souffle, c'est votre endurance — cherchez les bulles dans les ruines.", "Tauchen? Weich unter die Oberfläche aus. Dein Atem ist deine Ausdauer — achte auf die Blasen in den Ruinen.", "潜る？水面で回避だ。息は体力と同じ。遺跡の泡を探せ。", "잠수? 수면에서 회피해. 숨이 곧 기력이야. 폐허의 거품을 찾아.", "潜水？在水面按闪避。你的气就是体力——留意遗迹里的气泡。"),
])
ENTITY_PATCHES = {
    "NPC_HUNTER": {"dialogue": {"rumors": _VARRA}},
    "NPC_FISHER": {"dialogue": {"rumors": _ILO}},
}

STRINGS = dict(_VARRA_LOC, **_ILO_LOC)
STRINGS.update({
    "TOAST_SPORED": L("Glowcap dust clings to you. Your steps go quiet.", "El polvo de luzcapuchón se te pega. Tus pasos se silencian.", "O pó de lumichapéu gruda em você. Seus passos silenciam.", "La poussière de luminelle s'accroche à vous. Vos pas se taisent.", "Glimmhutstaub haftet an dir. Deine Schritte werden leise.", "光茸の粉がまとわりつく。足音が消えた。", "빛버섯 가루가 달라붙는다. 발소리가 조용해진다.", "萤光菇粉沾了一身，脚步悄无声息。"),
    "PROMPT_PICK_GLOWCAP": L("Pick glowcap", "Coger luzcapuchón", "Colher lumichapéu", "Cueillir une luminelle", "Glimmhut pflücken", "光茸を摘む", "빛버섯 따기", "采萤光菇"),
    "HINT_BRAMBLE_BLADE": L("Blades just catch in the thorns. These want fire.", "Las hojas se enganchan en las espinas. Esto pide fuego.", "Lâminas só enroscam nos espinhos. Isto pede fogo.", "Les lames s'accrochent aux épines. Il faut du feu.", "Klingen verfangen sich nur in den Dornen. Hier braucht es Feuer.", "刃は茨に絡むだけ。火が要る。", "칼날이 가시에 걸릴 뿐이다. 불이 필요하다.", "刀刃只会被荆棘卡住，这得用火。"),
    "HINT_BRAMBLE_WET": L("Too wet to burn. Wait for dry weather.", "Demasiado mojado para arder. Espera a que seque.", "Molhado demais para queimar. Espere o tempo secar.", "Trop mouillé pour brûler. Attendez le temps sec.", "Zu nass zum Brennen. Warte auf trockenes Wetter.", "濡れていて燃えない。乾いた天気を待て。", "너무 젖어서 타지 않는다. 마른 날을 기다려.", "太湿烧不着，等天晴吧。"),
    "HINT_MOON_NIGHT": L("The pool is dark. Come back at night.", "El estanque está oscuro. Vuelve de noche.", "O lago está escuro. Volte à noite.", "Le bassin est sombre. Revenez la nuit.", "Das Becken ist dunkel. Komm nachts wieder.", "池は暗い。夜に来い。", "연못이 어둡다. 밤에 다시 와.", "池水漆黑，夜里再来。"),
    "LINE_MOON_GATE": L("The caps sink, the pool brightens, and the round stone rolls aside.", "Los capuchones se hunden, el estanque brilla y la piedra redonda rueda.", "Os chapéus afundam, o lago clareia e a pedra redonda rola.", "Les chapeaux coulent, le bassin s'éclaire, et la pierre ronde roule.", "Die Hüte sinken, das Becken erhellt sich, und der runde Stein rollt beiseite.", "茸が沈み、池が明るみ、丸い石が転がり開く。", "버섯이 가라앉고 연못이 밝아지며 둥근 돌이 굴러 비킨다.", "菌伞沉下，池水发亮，圆石滚到一边。"),
    "TOAST_BELLS_PROGRESS": L("A drowned bell answers. (%d/%d)", "Una campana ahogada responde. (%d/%d)", "Um sino afogado responde. (%d/%d)", "Une cloche noyée répond. (%d/%d)", "Eine ertrunkene Glocke antwortet. (%d/%d)", "沈んだ鐘が応えた。(%d/%d)", "잠긴 종이 응답한다. (%d/%d)", "一口沉钟回应了。(%d/%d)"),
    "TOAST_BELLS_DONE": L("All three bells ring together. Somewhere stone grinds open.", "Las tres campanas suenan juntas. En algún sitio se abre la piedra.", "Os três sinos tocam juntos. Em algum lugar a pedra se abre.", "Les trois cloches sonnent ensemble. Quelque part, la pierre s'ouvre.", "Alle drei Glocken klingen zusammen. Irgendwo mahlt Stein auf.", "三つの鐘が共に鳴る。どこかで石が開く。", "세 종이 함께 울린다. 어딘가에서 돌이 열린다.", "三口钟齐鸣，某处石门轧轧开启。"),
    "FISH_BITE": L("A bite! Pull!", "¡Pican! ¡Tira!", "Mordeu! Puxe!", "Ça mord ! Tirez !", "Biss! Zieh!", "かかった！引け！", "입질! 당겨!", "咬钩了！提竿！"),
    "FISH_ESCAPED": L("It got away.", "Se escapó.", "Escapou.", "Il s'est échappé.", "Er ist entkommen.", "逃げられた。", "놓쳤다.", "跑了。"),
    "FISH_TOO_SOON": L("Too soon — you spooked it.", "Demasiado pronto: lo asustaste.", "Cedo demais — você o assustou.", "Trop tôt — vous l'avez effrayé.", "Zu früh — du hast ihn verscheucht.", "早すぎた。驚かせた。", "너무 일렀다. 놀라서 달아났다.", "太早了，把鱼吓跑了。"),
    "FISH_CAUGHT": L("Caught: %s", "Pescado: %s", "Pescado: %s", "Pris : %s", "Gefangen: %s", "釣れた：%s", "낚았다: %s", "钓到：%s"),
    "HINT_NEED_ROD": L("Fish here — if you had a rod. Ilo at the lake hut has one.", "Aquí hay peces, si tuvieras caña. Ilo, en la cabaña del lago, tiene una.", "Há peixes aqui — se tivesse vara. Ilo, na cabana do lago, tem uma.", "Des poissons ici — si vous aviez une canne. Ilo, à la cabane du lac, en a une.", "Hier gibt's Fisch — wenn du eine Rute hättest. Ilo an der Seehütte hat eine.", "ここは魚がいる。竿があれば。湖の小屋のイロが持っている。", "여기 물고기가 있다. 낚싯대만 있다면. 호수 오두막의 일로가 갖고 있다.", "这儿有鱼——要是你有竿的话。湖边小屋的伊洛有。"),
    "PROMPT_FISH": L("Cast", "Lanzar", "Lançar", "Lancer", "Auswerfen", "投げる", "던지기", "抛竿"),
    "PROMPT_FISH_WAIT": L("Wait…", "Espera…", "Espere…", "Attendez…", "Warte …", "待て……", "기다려…", "等等……"),
    "PROMPT_FISH_PULL": L("Pull!", "¡Tira!", "Puxe!", "Tirez !", "Zieh!", "引け！", "당겨!", "提竿！"),
    "ARMOR_STEALTH": L("Quieter steps, harder to spot", "Pasos más silenciosos, más difícil de ver", "Passos mais silenciosos, mais difícil de ver", "Pas plus silencieux, plus dur à repérer", "Leisere Schritte, schwerer zu entdecken", "足音が静かで見つかりにくい", "발소리가 작고 들키기 어렵다", "脚步更轻，更难被发现"),
    "ARMOR_BREATH": L("Hold your breath longer underwater", "Aguantas más la respiración bajo el agua", "Prende mais o fôlego debaixo d'água", "Retenez votre souffle plus longtemps sous l'eau", "Unter Wasser länger die Luft anhalten", "水中で長く息が続く", "물속에서 숨을 더 오래 참는다", "水下憋气更久"),
    "ARMOR_SWIM_SPEED": L("Swim and dive faster", "Nadas y buceas más rápido", "Nada e mergulha mais rápido", "Nagez et plongez plus vite", "Schneller schwimmen und tauchen", "速く泳ぎ、潜れる", "더 빨리 헤엄치고 잠수한다", "游泳潜水更快"),
    "STATUS_SPORED": L("Spored (hushed)", "Esporas (sigilo)", "Esporos (furtivo)", "Spores (discret)", "Sporen (leise)", "胞子（静か）", "포자 (은밀)", "孢子（隐匿）"),
    "STATUS_WEBBED": L("Webbed", "Atrapado en tela", "Preso na teia", "Englué", "Eingesponnen", "糸まみれ", "거미줄에 걸림", "被蛛网缠住"),
    "BUFF_STEALTH": L("Hushed", "Silencio", "Silêncio", "Silence", "Leise", "静寂", "고요", "静息"),
    "ATLAS_CONDITIONS": L("When: %s", "Cuándo: %s", "Quando: %s", "Quand : %s", "Wann: %s", "条件：%s", "조건: %s", "条件：%s"),
    "COND_NIGHT": L("at night", "de noche", "à noite", "la nuit", "nachts", "夜", "밤", "夜里"),
    "COND_DAY": L("by day", "de día", "de dia", "le jour", "tagsüber", "昼", "낮", "白天"),
    "COND_RAIN": L("in rain", "con lluvia", "na chuva", "sous la pluie", "bei Regen", "雨", "비", "下雨"),
    "COND_STORM": L("in a storm", "con tormenta", "na tempestade", "dans l'orage", "bei Sturm", "嵐", "폭풍", "暴风雨"),
    "COND_FOG": L("in fog", "con niebla", "na névoa", "dans la brume", "bei Nebel", "霧", "안개", "起雾"),
    "COND_DAWN": L("at first light", "al alba", "ao amanhecer", "à l'aube", "im Morgengrauen", "夜明け", "새벽", "破晓"),
    "COND_HIGH": L("up high", "en lo alto", "no alto", "en hauteur", "hoch oben", "高所", "높은 곳", "高处"),
    "COND_DEEP": L("deep down", "en lo profundo", "no fundo", "en profondeur", "tief unten", "深く", "깊은 곳", "深处"),
    "COND_DIVE": L("diving", "buceando", "mergulhando", "en plongée", "tauchend", "潜って", "잠수", "潜水"),
    "COND_CATCH": L("with a rod", "con caña", "com vara", "à la canne", "mit der Rute", "釣りで", "낚시로", "钓鱼"),
    "COND_FIND": L("by finding it", "encontrándolo", "encontrando", "en le trouvant", "durch Finden", "見つけて", "찾아서", "找到它"),
    "COND_ON_WATER": L("on the water", "sobre el agua", "sobre a água", "sur l'eau", "auf dem Wasser", "水上で", "물 위에서", "水上"),
})

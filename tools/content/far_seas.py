"""Phase 4.5 — the far seas: "from the coast there must be something that
draws the eye to both horizons".

WEST — the Mist Sea (off the west coast, x -1430..-770). A bank of sea mist
with edges and its own clock (thick from dusk to mid-morning, thin on clear
afternoons, torn thin by storms). Inside: the Teeth (sea stacks standing as
silhouettes), a line of fog bells that answer each other out to a hidden
sanctuary, the Lance (a wreck standing on end against the tallest stack),
the Echo Cave in the coastal bluff, and at dawn, in the thick of it, a pale
ship that is gone when you reach it. Mist dwellers keep pace out of sight
and close in when you stop.

EAST — the Current Sea (south of the desert cliffs, x 900..1450). Tidal
currents (hard on the flood and ebb, slack at the turn) make roads: the
Great Rip along the cliffs, a spur to the Wind Rock, a long eddy back west
that glows at night. A whirlpool where they meet keeps what the sea loses.
The Wind Rock's spout throws a swimmer out of the sea into an updraft —
leave the Bellhull, ride the spout, glide to the High Isle. A ship broken in
two: bow aground, stern on a ledge offshore, the anchor chain between them.
Rip finbacks come down the currents at you.
"""
from qdsl import L
from seas import poi, ent, atk, item, fish, disc, sp

# --- Terrain -------------------------------------------------------------------------------------------------
ISLETS = [
    # The Teeth: sea stacks in the mist.
    {"id": "teeth_wall", "pos": [-1010, -190], "radius": 16, "height": 26.0, "shape": "stack"},
    {"id": "teeth_1", "pos": [-985, -148], "radius": 8, "height": 18.0, "shape": "stack"},
    {"id": "teeth_2", "pos": [-962, -205], "radius": 7, "height": 13.0, "shape": "stack"},
    {"id": "teeth_3", "pos": [-1043, -128], "radius": 8, "height": 20.0, "shape": "stack"},
    {"id": "teeth_4", "pos": [-972, -108], "radius": 6, "height": 11.0, "shape": "stack"},
    {"id": "bell_knoll", "pos": [-1255, 30], "radius": 22, "height": 5.0, "shape": "mound"},
    # The Current Sea.
    {"id": "isla_paso", "pos": [1060, 760], "radius": 26, "height": 4.0, "shape": "mound"},
    {"id": "paso_ledge", "pos": [1062, 815], "radius": 16, "height": -11.0, "shape": "shelf"},
    {"id": "wind_rock", "pos": [1300, 830], "radius": 11, "height": 26.0, "shape": "stack"},
    {"id": "high_isle", "pos": [1345, 880], "radius": 30, "height": 30.0, "shape": "mesa"},
]

MIST_CENTER = (-1100, -60)
MIST_RADIUS = 330
BELLS = [("mist_bell_1", (-878, -40), 1.25), ("mist_bell_2", (-968, -62), 1.1), ("mist_bell_3", (-1068, -18), 0.95), ("mist_bell_4", (-1160, 18), 0.82)]
GREAT_BELL = "mist_bell_great"
BELL_LINE = [b[0] for b in BELLS]
RIP_END = (1395, 662)

POIS = [
    poi("bell_sanctuary", "bell_shrine", L("Sanctuary of the Bells", "Santuario de las Campanas", "Santuário dos Sinos", "Sanctuaire des Cloches", "Heiligtum der Glocken", "鐘の聖域", "종의 성소", "钟之圣所"),
        (-1255, 30), flatten=10, pad_height=4.5, clear_radius=14, discover_radius=26, loot="chest_rare", reward=[{"id": "mistwalker_lantern", "count": 1}],
        bell={"id": GREAT_BELL, "big": True, "pitch": 0.6, "line_flag": "mist_bells_answered", "line": BELL_LINE}),
    poi("echo_cave", "sea_cave", L("The Echo Cave", "La Cueva del Eco", "A Caverna do Eco", "La Grotte de l'Écho", "Die Echohöhle", "木霊の洞", "메아리 동굴", "回声洞"),
        (-790, 36), flatten=11, pad_height=-3.0, clear_radius=14, discover_radius=10, length=8.0, loot="chest_rare", gather="echo_shell",
        reward=[{"id": "mist_pearl", "count": 1}, {"id": "echo_shell", "count": 2}], guardians=[["ENEMY_CAVE_WEAVER", 2.0, 6.0, 3.0]]),
    poi("the_lance", "standing_wreck", L("The Lance", "La Lanza", "A Lança", "La Lance", "Die Lanze", "槍の船", "창의 배", "长矛号"),
        (-1031, -190), clear_radius=8, discover_radius=12, above=9.0, tilt=12.0, loot="chest_rare",
        reward=[{"id": "mist_pearl", "count": 1}, {"id": "abyssal_pearl", "count": 1}]),
    poi("broken_pact", "split_wreck", L("The Broken Pact", "El Pacto Roto", "O Pacto Partido", "Le Pacte brisé", "Der Gebrochene Pakt", "割れた盟約号", "깨진 맹약호", "断约号"),
        (1061, 772), clear_radius=10, discover_radius=18, yaw=180.0, stern_yaw=0.0, stern=[0, -11.0, 30], loot="chest_rare",
        log_item="pact_log", log_line="LINE_PACT_LOG", reward=[{"id": "abyssal_pearl", "count": 1}, {"id": "storm_glass", "count": 2}]),
]

# --- Creatures -----------------------------------------------------------------------------------------------
_E = [
    # Only in the mist. Keeps its distance and follows; closes in when you stop.
    ent("ENEMY_MIST_DWELLER", "ENEMY", "#ccf2b4", L("Mist dweller", "Habitante de la Bruma", "Habitante da Bruma", "Hôte de la brume", "Nebelbewohner", "霧に棲むもの", "안개의 거주자", "雾中栖者"), 65,
        {"radius": 0.7, "height": 1.0}, {"poise": 16, "walk_speed": 3.0, "run_speed": 7.0, "turn_speed": 4, "mass": 80},
        [atk("coil", "lunge", range_min=0, range_max=5.0, windup=0.7, active=0.35, recovery=0.9, cooldown=2.2, damage=15, knockback=7, reach=2.0, arc=50, lunge_speed=12)],
        {"sight_range": 40, "fov": 360, "hearing": 2.0, "leash": 90, "wander_radius": 20, "respawn_hours": 24, "swim_depth": 0.6,
         "behaviors": ["stalker"], "born_of": "mist", "stalk_distance": 22, "stalk_depth": 0.3, "strike_after": 3.0},
        "drop_mist_dweller", {"rank": "elite", "species": "serpent", "features": [], "scale": 1.2}, {"fire": 1.5, "electric": 1.3}, locomotion="aquatic"),
    # Variant: a finback that comes down the currents at you.
    ent("ENEMY_RIP_FINBACK", "ENEMY", "#00bc72", L("Rip finback", "Aletalomo de corriente", "Dorso-de-barbatana da corrente", "Dos-d'aileron des courants", "Strömungsflossenrücken", "潮筋の背ビレ", "해류 등지느러미", "激流背鳍鲨"), 70,
        {"radius": 0.7, "height": 0.9}, {"poise": 18, "walk_speed": 2.6, "run_speed": 6.8, "turn_speed": 4, "mass": 90},
        [atk("maul", "lunge", range_min=0, range_max=5.5, windup=0.55, active=0.35, recovery=0.9, cooldown=2.0, damage=16, knockback=8, reach=2.0, arc=45, lunge_speed=13)],
        {"sight_range": 30, "fov": 300, "hearing": 1.8, "leash": 80, "wander_radius": 20, "respawn_hours": 48, "current_ride": 1.0,
         "behaviors": ["submerge", "current_rider"], "surface_range": 9, "surface_time": 3.0, "deep_depth": 3.2, "fin_depth": 0.55, "swim_depth": 0.6},
        "drop_rip_finback", {"rank": "elite", "species": "finback", "features": []}, {"electric": 1.4, "fire": 0.5}, locomotion="aquatic"),
]
ENTITIES = [(d, l) for d, l, _v in _E]
VISUALS = [v for _d, _l, v in _E]

LOOT = {
    "drop_mist_dweller": [{"id": "mist_pearl", "chance": 0.3, "count": [1, 1]}, {"id": "raw_fish", "chance": 0.6, "count": [1, 2]}],
    "drop_rip_finback": [{"id": "rip_scale", "chance": 1.0, "count": [1, 2]}, {"id": "finback_tooth", "chance": 0.5, "count": [1, 1]}],
}

# --- Items and rewards ----------------------------------------------------------------------------------------
ITEMS = [
    fish("mistfin", L("Mistfin", "Aletabruma", "Barbatana-da-bruma", "Nageoire-brume", "Nebelflosse", "霧ビレ", "안개지느러미", "雾鳍鱼"),
         L("Pale and nearly see-through. Bites from dusk to morning, when the mist is in.", "Pálido y casi transparente. Pica del anochecer a la mañana, con la bruma.", "Pálido e quase transparente. Morde do anoitecer à manhã, com a bruma.", "Pâle, presque transparent. Mord du soir au matin, quand la brume est là.", "Blass, fast durchsichtig. Beißt von der Dämmerung bis zum Morgen, wenn der Nebel da ist.", "白く透けるほどの魚。霧の出る夕方から朝に食いつく。", "창백하고 거의 투명하다. 안개가 낀 해 질 녘부터 아침까지 문다.", "苍白近乎透明。起雾的黄昏到清晨才咬钩。"),
         10, {"heal": 1.5}, 12, 2),
    fish("rip_mackerel", L("Rip mackerel", "Caballa de corriente", "Cavala da corrente", "Maquereau des courants", "Strömungsmakrele", "潮筋サバ", "해류 고등어", "激流鲭"),
         L("Swims against the rip all its life. Firm, fast, best when the current runs hard.", "Nada contra la corriente toda su vida. Firme y rápida; pica mejor con la corriente fuerte.", "Nada contra a corrente a vida toda. Firme e rápida; melhor com corrente forte.", "Nage contre le courant toute sa vie. Ferme, vif, meilleur quand le courant tire.", "Schwimmt ein Leben lang gegen die Strömung. Fest, schnell, am besten bei starker Strömung.", "一生潮に逆らって泳ぐ。身が締まり、潮の速い時によく釣れる。", "평생 해류를 거슬러 헤엄친다. 단단하고 빠르며 물살이 셀 때 잘 잡힌다.", "一生逆流而游。肉紧实，水流急时最好钓。"),
         12, {"heal": 1.5, "swift": 1.0}, 12, 1),
    item("echo_shell", "material", L("Echo shell", "Concha del eco", "Concha do eco", "Coquille d'écho", "Echomuschel", "木霊貝", "메아리 조개", "回声贝"),
         L("Hold it to your ear: the cave's drip, the sea outside. Crafters grind it for glaze.", "Acércala al oído: el goteo de la cueva, el mar afuera. Los artesanos la muelen para esmalte.", "Encoste no ouvido: o gotejar da caverna, o mar lá fora. Artesãos a moem para esmalte.", "Porte-la à l'oreille : l'égouttement de la grotte, la mer dehors. On la broie pour l'émail.", "Halt sie ans Ohr: das Tropfen der Höhle, das Meer draußen. Handwerker mahlen sie zu Glasur.", "耳に当てると洞の雫と外の海の音。職人は釉薬にする。", "귀에 대면 동굴의 물방울과 바깥 바다 소리. 장인들이 유약으로 간다.", "贴耳能听见洞里的滴水和外面的海。工匠磨来做釉。"),
         icon="res://assets/icons/mat_gem.svg", value=14),
    item("mist_pearl", "material", L("Mist pearl", "Perla de bruma", "Pérola de bruma", "Perle de brume", "Nebelperle", "霧真珠", "안개 진주", "雾珍珠"),
         L("Milky and cool, with a grey heart that shifts as you turn it.", "Lechosa y fría, con un corazón gris que se mueve al girarla.", "Leitosa e fria, com um coração cinza que muda ao girá-la.", "Laiteuse et fraîche, au cœur gris qui bouge quand on la tourne.", "Milchig und kühl, mit grauem Kern, der sich beim Drehen verschiebt.", "乳白で冷たく、回すと灰色の芯が揺れる。", "우윳빛에 서늘하고, 돌리면 회색 속심이 움직인다.", "乳白微凉，转动时灰色的芯会游移。"),
         icon="res://assets/icons/mat_gem.svg", value=80, rarity=2),
    item("rip_scale", "material", L("Rip scale", "Escama de corriente", "Escama da corrente", "Écaille des courants", "Strömungsschuppe", "潮筋の鱗", "해류 비늘", "激流鳞"),
         L("Slick as wet glass. Water slides off it the way the current slides off its owner.", "Resbaladiza como vidrio mojado. El agua se desliza como la corriente sobre su dueño.", "Lisa como vidro molhado. A água escorre como a corrente sobre o dono.", "Lisse comme du verre mouillé. L'eau glisse dessus comme le courant sur sa bête.", "Glatt wie nasses Glas. Wasser gleitet ab wie die Strömung an ihrem Träger.", "濡れた硝子のように滑らか。持ち主を流れが滑るように水が滑る。", "젖은 유리처럼 매끄럽다. 주인에게 해류가 미끄러지듯 물이 미끄러진다.", "滑如湿玻璃，水从上面滑过，就像水流滑过它的主人。"),
         icon="res://assets/icons/mat_hide.svg", value=22, rarity=2),
    item("mistwalker_lantern", "armor", L("Mistwalker's lantern", "Farol del caminante de la bruma", "Lanterna do andarilho da bruma", "Lanterne du marche-brume", "Nebelwandererlaterne", "霧歩きの提灯", "안개 걷는 이의 등불", "行雾者提灯"),
         L("The bell-keepers' lamp. In sea mist you see twice as far.", "La lámpara de los guardianes de las campanas. En la bruma marina ves el doble de lejos.", "A lâmpada dos guardiões dos sinos. Na bruma marinha você vê o dobro.", "La lampe des gardiens des cloches. Dans la brume marine, on voit deux fois plus loin.", "Die Lampe der Glockenhüter. Im Seenebel siehst du doppelt so weit.", "鐘守りの灯。海霧の中で倍遠くまで見える。", "종지기들의 등불. 바다 안개 속에서 두 배 멀리 보인다.", "守钟人的灯。海雾里能看远一倍。"),
         icon="res://assets/icons/armor_accessory.svg", value=120, rarity=3, armor={"slot": "accessory", "defense": 0, "mist_sight": 0.5}),
    item("riptide_anklet", "armor", L("Riptide anklet", "Tobillera de resaca", "Tornozeleira da ressaca", "Chevillière de ressac", "Brandungsfußreif", "潮筋の足環", "역조 발찌", "激流脚环"),
         L("Rip scales on a cord. Ride a current harder; cut across one you are fighting.", "Escamas de corriente en un cordón. Aprovechas más la corriente y cruzas mejor la que te frena.", "Escamas da corrente num cordão. Aproveita mais a corrente e cruza melhor a contrária.", "Des écailles sur un cordon. On file plus vite avec le courant, on le traverse mieux contre.", "Strömungsschuppen an einer Schnur. Nutze Strömungen stärker, quere sie leichter.", "潮筋の鱗の足環。潮に乗れば速く、逆らえば楽に横切れる。", "해류 비늘을 꿴 발찌. 해류를 더 잘 타고, 거슬러 가로지르기도 쉽다.", "激流鳞串成的脚环。顺流更快，逆流也更好横穿。"),
         icon="res://assets/icons/armor_accessory.svg", value=110, rarity=2, armor={"slot": "accessory", "defense": 0, "current_ride": 0.6}),
    item("pact_log", "key", L("The Pact's log", "Bitácora del Pacto", "Diário do Pacto", "Journal du Pacte", "Logbuch des Pakts", "盟約号の日誌", "맹약호 항해일지", "断约号日志"),
         L("'The stern went with the strongbox. The chain is still fast to both halves.'", "'La popa se fue con el cofre. La cadena sigue sujeta a las dos mitades.'", "'A popa foi com o cofre. A corrente ainda prende as duas metades.'", "« La poupe est partie avec le coffre. La chaîne tient encore les deux moitiés. »", "„Das Heck ging mit der Schatulle. Die Kette hält noch beide Hälften.“", "「船尾は金庫ごと沈んだ。鎖はまだ両方に繋がっている」", "'선미는 금고와 함께 가라앉았다. 사슬은 아직 두 쪽에 묶여 있다.'", "“船尾连着保险箱沉了。锚链还拴着两半。”"),
         icon="res://assets/icons/key_journal.svg", max_stack=1),
    item("clearsight_tea", "food", L("Clearsight tea", "Té de vista clara", "Chá da vista clara", "Thé de vue claire", "Klarsichttee", "澄み目の茶", "맑은 눈 차", "明目茶"),
         L("Mistfin broth steeped with shell and mint. For a while the mist seems thinner.", "Caldo de aletabruma con concha y menta. Por un rato la bruma parece más fina.", "Caldo de barbatana-da-bruma com concha e menta. Por um tempo a bruma parece mais fina.", "Bouillon de nageoire-brume, coquille et menthe. Un temps, la brume paraît moins épaisse.", "Nebelflossenbrühe mit Muschel und Minze. Eine Weile wirkt der Nebel dünner.", "霧ビレの出汁に貝とミント。しばらく霧が薄く見える。", "안개지느러미 국물에 조개와 박하. 한동안 안개가 옅어 보인다.", "雾鳍汤泡贝壳和薄荷。一阵子里雾似乎淡了。"),
         icon="res://assets/icons/food_dish.svg", use_action="eat", value=36, rarity=2, effects=[{"type": "heal", "amount": 15}, {"type": "buff", "buff": "mist_sight", "amount": 1, "duration": 300}]),
]
SPECIALS = [{"id": "clearsight_tea", "ingredients": ["mistfin", "echo_shell", "frostmint"], "item": "clearsight_tea", "potency": 1.0}]
BUFFS = {"mist_sight": {"name_key": "BUFF_MIST_SIGHT"}}
COSMETICS = [
    ({"id": "ribbon_bell", "slot": "glider_trail", "name_key": "COS_RIBBON_BELL", "color": "#d8c68a"},
     {"COS_RIBBON_BELL": L("Bell-ringer's ribbon", "Cinta del campanero", "Fita do sineiro", "Ruban du sonneur", "Glöcknerband", "鐘撞きの帯", "종지기 리본", "敲钟人绸带")}),
    ({"id": "ribbon_current", "slot": "glider_trail", "name_key": "COS_RIBBON_CURRENT", "color": "#39e0c8"},
     {"COS_RIBBON_CURRENT": L("Glowing current ribbon", "Cinta de corriente luminosa", "Fita da corrente luminosa", "Ruban du courant lumineux", "Leuchtstromband", "光る潮の帯", "빛나는 해류 리본", "荧流绸带")}),
]

# --- Spawns (appended to the coast tables) ---------------------------------------------------------------------
REGION_SPAWN_EXTRA = {"coast": {"enemy_spawns": [
    sp("ENEMY_MIST_DWELLER", 8, [1, 1], habitat="deep", mist=True, area=[MIST_CENTER[0], MIST_CENTER[1], MIST_RADIUS]),
    sp("ENEMY_MIST_DWELLER", 4, [1, 1], habitat="water", mist=True, area=[MIST_CENTER[0], MIST_CENTER[1], MIST_RADIUS]),
    sp("ENEMY_RIP_FINBACK", 6, [1, 1], habitat="deep", area=[1200, 860, 330]),
]}}

FISHING = {"mist": [{"item": "mistfin", "weight": 6, "hours": [18, 10]}, {"item": "silverback", "weight": 3}, {"item": "raw_fish", "weight": 2}],
           "rip": [{"item": "rip_mackerel", "weight": 6}, {"item": "bluewater_runner", "weight": 2, "period": "day"}, {"item": "stormfin", "weight": 3, "weather": ["storm"]}]}

# --- Sites ------------------------------------------------------------------------------------------------------
SITES = []


def site(feature, sid, pos, **kw):
    d = {"kind": "feature", "feature": feature, "id": sid, "pos": list(pos)}
    d.update(kw)
    SITES.append(d)


def current(sid, a, b, width, strength, **kw):
    import math
    dx, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dz)
    yaw = round(math.degrees(math.atan2(-dx / n, -dz / n)), 1)
    site("current", sid, a, yaw=yaw, length=round(n, 1), width=width, strength=strength, float=True, lift=0.0, range=500, **kw)


# West: the bank itself (seen from far: a wall of white on the horizon).
site("mist_bank", "mist_sea", MIST_CENTER, radius=MIST_RADIUS, edge=80, pockets=[[-1255, 30, 55], [-950, 160, 45]], range=1400, float=True, lift=0.0)
for i, (bid, pos, pitch) in enumerate(BELLS):
    nxt = BELLS[i + 1][0] if i + 1 < len(BELLS) else GREAT_BELL
    site("fog_bell", bid, pos, next=nxt, pitch=pitch, range=450, float=True, lift=-0.4)
site("mirage", "pale_ship", (-1120, -240), range=900, float=True, lift=0.0)
for sid, pos in [("fish_mist_0", (-930, 100)), ("fish_mist_1", (-1120, -300))]:
    site("fishing_spot", sid, pos, waters="mist", float=True, lift=0.05)
site("kelp", "kelp_teeth", (-995, -170), radius=14, count=30)
# East: tidal roads, the whirlpool, the spout and its updraft.
current("great_rip", (920, 650), RIP_END, 26.0, 4.5, tidal=True)
current("wind_spur", (1190, 668), (1282, 806), 18.0, 4.0, tidal=True)
current("long_eddy", (1430, 1010), (1010, 1070), 22.0, 3.2, tidal=True, glows=True)
site("whirlpool", "lost_eye", (1180, 940), radius=20.0, strength=3.2, float=True, lift=0.0, range=400)
site("spout", "wind_spout", (1288, 818), radius=2.8, period=7.0, float=True, lift=0.0, range=300)
# The column rises from the sea surface (float), not from the sea bed.
SITES.append({"kind": "zone", "zone": "updraft", "id": "wind_rock_updraft", "pos": [1290, 822], "radius": 7.0, "height": 48.0, "strength": 12.0,
              "float": True, "lift": 0.0})
for sid, pos in [("fish_rip_0", (1000, 662)), ("fish_rip_1", (1250, 700)), ("fish_rip_2", (1380, 1000))]:
    site("fishing_spot", sid, pos, waters="rip", float=True, lift=0.05)

# --- Discoveries --------------------------------------------------------------------------------------------------
DISCOVERIES = [
    disc("mist_teeth", L("The Teeth", "Los Dientes", "Os Dentes", "Les Dents", "Die Zähne", "牙岩", "이빨 바위", "齿岩"),
         L("Sea stacks standing in the mist like broken teeth. The tallest has a ship leaning on it.", "Farallones que asoman en la bruma como dientes rotos. En el más alto se apoya un barco.", "Rochedos que surgem na bruma como dentes partidos. No mais alto se apoia um navio.", "Des aiguilles dressées dans la brume comme des dents cassées. Un navire s'appuie sur la plus haute.", "Brandungspfeiler im Nebel wie abgebrochene Zähne. Am höchsten lehnt ein Schiff.", "霧に立つ折れた歯のような岩柱。一番高いものに船がもたれている。", "안개 속에 부러진 이빨처럼 선 바위 기둥들. 가장 높은 것에 배가 기대 있다.", "雾中矗立的海蚀柱像断齿，最高的那根上靠着一艘船。"),
         L("On a clear afternoon, dark shapes stand out west of the coast. By morning the mist swallows them.", "En una tarde clara se ven formas oscuras al oeste de la costa. Por la mañana la bruma se las traga.", "Numa tarde clara, formas escuras aparecem a oeste da costa. De manhã a bruma as engole.", "Par un après-midi clair, des formes sombres se dressent à l'ouest. Au matin la brume les avale.", "An klaren Nachmittagen stehen dunkle Formen westlich der Küste. Morgens schluckt sie der Nebel.", "晴れた午後、海岸の西に黒い影が立つ。朝には霧に呑まれる。", "맑은 오후면 해안 서쪽에 검은 형체가 보인다. 아침엔 안개가 삼킨다.", "晴朗的下午，海岸以西立着黑影；到了早上雾就把它们吞了。"),
         (-1000, -160), {"items": [{"id": "gale_feather", "count": 1}]}, radius=40, icon="▲"),
    disc("mist_bells", L("Voices in the Mist", "Voces en la bruma", "Vozes na bruma", "Voix dans la brume", "Stimmen im Nebel", "霧の声", "안개 속의 목소리", "雾中之声"),
         L("Ring a bell and the next one answers. The last answer came from the heart of the mist.", "Tocas una campana y responde la siguiente. La última respuesta llegó del corazón de la bruma.", "Toque um sino e o próximo responde. A última resposta veio do coração da bruma.", "Sonne une cloche, la suivante répond. La dernière réponse est venue du cœur de la brume.", "Läute eine Glocke, die nächste antwortet. Die letzte Antwort kam aus dem Herzen des Nebels.", "鐘を鳴らせば次が応える。最後の答えは霧の奥から来た。", "종을 치면 다음 종이 대답한다. 마지막 대답은 안개 한가운데서 왔다.", "敲响一口钟，下一口会回应。最后的回应来自雾的深处。"),
         L("From the west shore in the mist, a bell tolls out on the water. Then, further off, another.", "Desde la orilla oeste, con bruma, suena una campana en el agua. Luego, más lejos, otra.", "Da praia oeste, com bruma, um sino toca na água. Depois, mais longe, outro.", "Depuis la rive ouest, dans la brume, une cloche sonne sur l'eau. Puis, plus loin, une autre.", "Vom Westufer im Nebel läutet eine Glocke auf dem Wasser. Dann, weiter draußen, eine andere.", "霧の日、西の岸から水上に鐘が鳴る。さらに遠くでもう一つ。", "안개 낀 서쪽 해안에서 물 위로 종이 울린다. 그리고 더 멀리서 또 하나.", "起雾时从西岸能听见水上有钟声，更远处又一口。"),
         BELLS[3][1], {"cosmetic": "ribbon_bell"}, radius=30, conditions={"flag": "mist_bells_answered"}, icon="♪"),
    disc("mist_sanctuary", L("Sanctuary of the Bells", "Santuario de las Campanas", "Santuário dos Sinos", "Sanctuaire des Cloches", "Heiligtum der Glocken", "鐘の聖域", "종의 성소", "钟之圣所"),
         L("A drowned belfry on a knoll in the mist's clear eye. The bell-keepers left their lamp here.", "Un campanario ahogado en un otero, en el ojo claro de la bruma. Los guardianes dejaron aquí su farol.", "Um campanário afogado numa colina, no olho claro da bruma. Os guardiões deixaram aqui a lanterna.", "Un clocher noyé sur une butte, dans l'œil clair de la brume. Les gardiens y ont laissé leur lampe.", "Ein ertrunkener Glockenturm auf einem Hügel im klaren Auge des Nebels. Die Hüter ließen ihre Lampe hier.", "霧の晴れた目にある小丘の沈んだ鐘楼。鐘守りが灯を残した。", "안개의 맑은 눈 속 언덕 위, 가라앉은 종탑. 종지기들이 등불을 남겼다.", "雾中晴眼处小丘上的沉钟楼。守钟人把灯留在这里。"),
         L("Sabel: 'The bell-keepers rang the ships home through the mist. Follow the bells — they still answer.'", "Sabel: 'Los campaneros guiaban a los barcos por la bruma. Sigue las campanas: aún responden.'", "Sabel: 'Os sineiros guiavam os navios pela bruma. Siga os sinos — ainda respondem.'", "Sabel : « Les sonneurs ramenaient les navires à travers la brume. Suis les cloches : elles répondent encore. »", "Sabel: „Die Glöckner läuteten die Schiffe durch den Nebel heim. Folge den Glocken — sie antworten noch.“", "サベル「鐘守りは霧の中、船を鐘で導いた。鐘を追え、まだ応える」", "사벨: '종지기들은 안개 속에서 종으로 배를 불러들였지. 종을 따라가, 아직 대답해.'", "萨贝尔：“守钟人用钟声把船领回雾里的家。跟着钟走，它们还会应。”"),
         (-1255, 30), {"items": [{"id": "mist_pearl", "count": 1}]}, radius=18, icon="◉"),
    disc("mist_echo_cave", L("The Echo Cave", "La Cueva del Eco", "A Caverna do Eco", "La Grotte de l'Écho", "Die Echohöhle", "木霊の洞", "메아리 동굴", "回声洞"),
         L("Through a throat that dips under the sea into a dark chamber that repeats every drop.", "Por una garganta que se hunde bajo el mar hasta una cámara oscura que repite cada gota.", "Por uma garganta que afunda sob o mar até uma câmara escura que repete cada gota.", "Par une gorge qui plonge sous la mer jusqu'à une salle sombre qui répète chaque goutte.", "Durch einen Schlund unter dem Meer in eine dunkle Kammer, die jeden Tropfen wiederholt.", "海の下へ潜る喉を抜けると、雫の音を繰り返す暗い部屋。", "바다 밑으로 꺼지는 목을 지나 물방울마다 되울리는 어두운 방으로.", "穿过没入海面的狭喉，是一间把每滴水声都重复的暗室。"),
         L("Waves boom inside the west bluff at high water, as if the rock were hollow.", "Con marea alta las olas retumban dentro del acantilado oeste, como si la roca estuviera hueca.", "Na maré alta as ondas retumbam dentro da falésia oeste, como se a rocha fosse oca.", "À marée haute, les vagues grondent dans la falaise ouest, comme si la roche était creuse.", "Bei Hochwasser dröhnen Wellen im Westkliff, als wäre der Fels hohl.", "満潮になると西の崖の中で波が轟く。岩が空洞のように。", "만조면 서쪽 절벽 안에서 파도가 울린다. 바위가 속이 빈 것처럼.", "涨潮时浪在西崖里轰鸣，好像岩石是空的。"),
         (-786, 36), {"items": [{"id": "echo_shell", "count": 2}]}, radius=6, icon="◌"),
    disc("mist_lance", L("Inside the Lance", "Dentro de la Lanza", "Dentro da Lança", "Dans la Lance", "In der Lanze", "槍の船の内", "창의 배 안", "长矛号之内"),
         L("A ship standing on its bow. Down the shaft in the dark, a breath at the vent, the strongbox at the bottom.", "Un barco de pie sobre la proa. Por el pozo a oscuras, un respiro en el respiradero, el cofre al fondo.", "Um navio em pé sobre a proa. Pelo poço no escuro, um fôlego no respiro, o cofre no fundo.", "Un navire debout sur sa proue. Le puits dans le noir, un souffle à l'évent, le coffre au fond.", "Ein Schiff auf dem Bug. Den Schacht hinab im Dunkeln, Luft an der Quelle, die Schatulle unten.", "舳先で立つ船。暗い縦穴を潜り、気泡口で息をつぎ、底に金庫。", "뱃머리로 선 배. 어둠 속 수직 통로를 내려가 공기구멍에서 숨을 쉬고, 바닥에 금고.", "一艘船头朝下立着的船。摸黑潜下竖井，在气眼换口气，箱子在底下。"),
         L("The tallest of the Teeth has a mast leaning on it — no, a whole ship.", "El más alto de los Dientes tiene un mástil apoyado... no, un barco entero.", "O mais alto dos Dentes tem um mastro encostado... não, um navio inteiro.", "La plus haute des Dents porte un mât appuyé… non, un navire entier.", "Am höchsten Zahn lehnt ein Mast — nein, ein ganzes Schiff.", "牙岩の一番高いのに帆柱がもたれて…いや、船ごとだ。", "가장 높은 이빨 바위에 돛대가... 아니, 배 전체가 기대 있다.", "最高的齿岩上靠着根桅杆……不，是一整艘船。"),
         (-1031, -190), {"items": [{"id": "abyssal_pearl", "count": 1}]}, radius=7, conditions={"state": ["dive"], "max_y": -10.0}),
    disc("mist_mirage", L("The Pale Ship", "El barco pálido", "O navio pálido", "Le navire pâle", "Das bleiche Schiff", "白い船", "창백한 배", "白色之船"),
         L("Under full sail in the dawn mist — and gone when you reach it. Something floats where it stood.", "A toda vela en la bruma del alba, y desaparece al llegar. Algo flota donde estaba.", "A todo pano na bruma da aurora — e some quando você chega. Algo boia onde estava.", "Toutes voiles dehors dans la brume de l'aube, disparu quand on arrive. Quelque chose flotte là.", "Unter vollen Segeln im Morgennebel — und fort, wenn du ankommst. Wo es stand, treibt etwas.", "夜明けの霧に満帆で浮かび、近づくと消える。そこに何かが漂う。", "새벽 안개 속 돛을 활짝 편 배, 다가가면 사라진다. 그 자리에 뭔가 떠 있다.", "黎明雾里满帆而立，靠近便消失。它站过的地方漂着东西。"),
         L("Fishers swear a ship sails the western mist at first light. None has ever caught it.", "Los pescadores juran que un barco navega la bruma del oeste al alba. Nadie lo ha alcanzado.", "Pescadores juram que um navio cruza a bruma do oeste ao amanhecer. Ninguém o alcançou.", "Les pêcheurs jurent qu'un navire vogue dans la brume de l'ouest à l'aube. Personne ne l'a rattrapé.", "Fischer schwören, bei erstem Licht segle ein Schiff im Westnebel. Keiner hat es je erreicht.", "漁師は夜明けの西の霧に船が走ると言う。追いついた者はいない。", "어부들은 새벽 서쪽 안개에 배가 다닌다고 맹세한다. 따라잡은 사람은 없다.", "渔人发誓天刚亮时西边雾里有船在走，谁也没追上过。"),
         (-1120, -240), {"items": [{"id": "mist_pearl", "count": 1}], "recipes": [["mistfin", "echo_shell", "frostmint"]]}, radius=30,
         conditions={"hours": [4.5, 7.5], "mist": True}, icon="☾"),
    disc("rip_great", L("The Great Rip", "La Gran Resaca", "A Grande Ressaca", "Le Grand Courant", "Der Große Sog", "大潮筋", "대역조", "大激流"),
         L("You rode the current under the desert cliffs from end to end. It runs hardest between the tides.", "Recorriste la corriente bajo los acantilados del desierto de punta a punta. Corre más entre mareas.", "Você correu a corrente sob as falésias do deserto de ponta a ponta. Corre mais entre as marés.", "Tu as suivi le courant sous les falaises du désert d'un bout à l'autre. Il file surtout entre deux marées.", "Du bist die Strömung unter den Wüstenklippen ganz entlanggeritten. Sie läuft am stärksten zwischen den Gezeiten.", "砂漠の崖下の潮筋を端から端まで乗り切った。潮の合間に最も速い。", "사막 절벽 아래 해류를 끝에서 끝까지 탔다. 조수 사이에 가장 빠르다.", "你顺着沙漠崖下的激流从头漂到了尾。潮与潮之间它最急。"),
         L("From the desert cliffs, a white seam runs along the sea to the east. It moves.", "Desde los acantilados del desierto, una costura blanca corre por el mar hacia el este. Se mueve.", "Das falésias do deserto, uma costura branca corre pelo mar para leste. Ela se move.", "Des falaises du désert, une couture blanche file sur la mer vers l'est. Elle bouge.", "Von den Wüstenklippen läuft eine weiße Naht übers Meer nach Osten. Sie bewegt sich.", "砂漠の崖から、白い縫い目が東へ海を走る。動いている。", "사막 절벽에서 보면 흰 솔기가 바다를 따라 동쪽으로 뻗는다. 움직인다.", "从沙漠崖上看，一道白缝沿海往东延伸，还在动。"),
         RIP_END, {"items": [{"id": "rip_scale", "count": 1}]}, radius=26, conditions={"state": ["swim", "dive", "drive"], "flow": "strong"}, icon="➶"),
    disc("rip_whirlpool", L("Eye of the Lost", "El Ojo de los Perdidos", "O Olho dos Perdidos", "L'Œil des Perdus", "Auge der Verlorenen", "失せ物の目", "잃어버린 것들의 눈", "失物之眼"),
         L("Where two currents meet the sea turns in a slow circle — and under its eye lies everything it took.", "Donde se encuentran dos corrientes el mar gira despacio, y bajo su ojo yace todo lo que se llevó.", "Onde duas correntes se encontram o mar gira devagar — e sob seu olho está tudo o que levou.", "Là où deux courants se rencontrent, la mer tourne lentement — et sous son œil gît tout ce qu'elle a pris.", "Wo zwei Strömungen sich treffen, dreht das Meer langsam — und unter seinem Auge liegt alles, was es nahm.", "二つの潮が出会う所で海はゆっくり渦を巻き、その目の下に奪ったものが眠る。", "두 해류가 만나는 곳에서 바다가 천천히 돌고, 그 눈 아래엔 삼킨 모든 것이 있다.", "两股水流相遇处海水缓缓打转，漩涡眼下躺着它卷走的一切。"),
         L("A ring of foam turns south of the Wind Rock. Flotsam goes in; none comes out.", "Un anillo de espuma gira al sur de la Roca del Viento. Los restos entran; ninguno sale.", "Um anel de espuma gira ao sul da Rocha do Vento. Destroços entram; nada sai.", "Un anneau d'écume tourne au sud du Rocher du Vent. Les épaves entrent ; rien ne ressort.", "Südlich des Windfelsens dreht sich ein Schaumring. Treibgut geht hinein, nichts kommt heraus.", "風の岩の南で泡の輪が回る。漂流物は入るが出てこない。", "바람 바위 남쪽에서 거품 고리가 돈다. 표류물이 들어가고, 나오지 않는다.", "风岩以南有一圈泡沫在转。漂浮物进去就出不来。"),
         (1180, 940), {"items": [{"id": "gale_feather", "count": 2}]}, radius=8, conditions={"state": ["dive"], "max_y": -12.0}, icon="@",
         spawns=[{"kind": "chest", "id": "lost_eye:hoard", "table": "chest_rare", "pos": [1181, 941], "items": [{"id": "abyssal_pearl", "count": 1}, {"id": "mist_pearl", "count": 1}], "grand": True}],
         persist=True),
    disc("rip_split_wreck", L("The Other Half", "La otra mitad", "A outra metade", "L'autre moitié", "Die andere Hälfte", "もう半分", "나머지 반쪽", "另一半"),
         L("You followed the anchor chain from the grounded bow down to the stern on its ledge.", "Seguiste la cadena del ancla desde la proa varada hasta la popa en su repisa.", "Você seguiu a corrente da âncora da proa encalhada até a popa na borda.", "Tu as suivi la chaîne d'ancre de la proue échouée jusqu'à la poupe sur son rebord.", "Du folgtest der Ankerkette vom gestrandeten Bug hinab zum Heck auf seinem Sims.", "座礁した舳先から錨鎖をたどり、棚の上の船尾へ。", "좌초한 뱃머리에서 닻 사슬을 따라 턱 위의 선미까지 내려갔다.", "你顺着锚链从搁浅的船头一路找到了架在礁台上的船尾。"),
         L("Half a ship lies on the islet south of the desert. Where is the rest?", "Medio barco yace en el islote al sur del desierto. ¿Dónde está el resto?", "Meio navio jaz na ilhota ao sul do deserto. Onde está o resto?", "Un demi-navire gît sur l'îlot au sud du désert. Où est le reste ?", "Ein halbes Schiff liegt auf der Insel südlich der Wüste. Wo ist der Rest?", "砂漠の南の小島に船が半分。残りはどこに？", "사막 남쪽 섬에 배 반쪽이 있다. 나머지는 어디에?", "沙漠南边小岛上躺着半艘船。另一半呢？"),
         (1061, 807), {"items": [{"id": "rip_scale", "count": 1}]}, radius=9, conditions={"state": ["dive"], "max_y": -6.0}),
    disc("rip_high_isle", L("The High Isle", "La Isla Alta", "A Ilha Alta", "L'Île haute", "Die Hohe Insel", "高き島", "높은 섬", "高岛"),
         L("A table of rock thirty metres over the sea. The spout, the wind over the Rock, a long glide.", "Una mesa de roca a treinta metros sobre el mar. El géiser, el viento de la Roca, un largo planeo.", "Uma mesa de rocha a trinta metros do mar. O gêiser, o vento da Rocha, um longo voo.", "Une table de roche à trente mètres au-dessus de la mer. Le geyser, le vent du Rocher, un long vol.", "Ein Felstisch dreißig Meter über dem Meer. Die Fontäne, der Wind am Felsen, ein langer Gleitflug.", "海から三十メートルの岩の卓。潮吹き、岩の風、長い滑空。", "바다 위 삼십 미터의 바위 탁자. 물기둥, 바위의 바람, 긴 활공.", "高出海面三十米的岩台。喷泉、岩上的风、一次长滑翔。"),
         L("Nomads say the Wind Rock breathes. Swim to its foot and wait for the sea to rise under you.", "Los nómadas dicen que la Roca del Viento respira. Nada hasta su pie y espera a que el mar suba bajo ti.", "Os nômades dizem que a Rocha do Vento respira. Nade até o pé dela e espere o mar subir sob você.", "Les nomades disent que le Rocher du Vent respire. Nage jusqu'à son pied, attends que la mer monte sous toi.", "Nomaden sagen, der Windfels atmet. Schwimm zu seinem Fuß und warte, bis das Meer unter dir steigt.", "遊牧民いわく風の岩は息をする。麓まで泳ぎ、海が足元から湧くのを待て。", "유목민들은 바람 바위가 숨을 쉰다고 한다. 발치까지 헤엄쳐 바다가 밑에서 솟기를 기다려라.", "游牧人说风岩会呼吸。游到它脚下，等海水从你身下涌起。"),
         (1345, 880), {"cosmetic": "ribbon_current"}, radius=24, conditions={"min_y": 26.0}, icon="⬆",
         spawns=[{"kind": "chest", "id": "high_isle:cache", "table": "chest_rare", "pos": [1348, 884], "snap": "top", "items": [{"id": "riptide_anklet", "count": 1}], "grand": True}],
         persist=True),
    disc("rip_luminous", L("The Glowing Eddy", "El remolino luminoso", "O redemoinho luminoso", "Le remous lumineux", "Der leuchtende Wirbelstrom", "光る渦潮", "빛나는 소용돌이 해류", "发光的回流"),
         L("At night, on the flood or the ebb, the long eddy burns green with drifting light. You rode inside it.", "De noche, con la marea en movimiento, el remolino largo arde verde de luz a la deriva. Lo recorriste por dentro.", "À noite, com a maré correndo, o redemoinho longo arde verde de luz à deriva. Você o percorreu por dentro.", "La nuit, quand la marée court, le long remous brûle d'une lumière verte. Tu l'as parcouru de l'intérieur.", "Nachts, bei laufender Tide, glüht der lange Wirbelstrom grün. Du bist in ihm geritten.", "夜、潮が動くと長い渦潮が緑に光る。その中を乗った。", "밤에 물살이 셀 때 긴 소용돌이 해류가 초록빛으로 탄다. 그 안을 탔다.", "夜里潮水流动时，长长的回流泛着绿光。你在光里漂过。"),
         L("From the High Isle at night, a green road lies on the sea — but only while the tide runs.", "Desde la Isla Alta, de noche, un camino verde yace sobre el mar, pero solo mientras corre la marea.", "Da Ilha Alta à noite, uma estrada verde jaz no mar — mas só enquanto a maré corre.", "Depuis l'Île haute la nuit, une route verte s'étend sur la mer — mais seulement quand la marée court.", "Von der Hohen Insel liegt nachts eine grüne Straße auf dem Meer — nur solange die Tide läuft.", "夜、高き島から海に緑の道が見える。潮が動く間だけ。", "밤에 높은 섬에서 보면 바다에 초록 길이 놓인다. 물살이 흐를 때만.", "夜里从高岛看，海上铺着一条绿色的路——只在潮水流动时。"),
         (1220, 1040), {"items": [{"id": "rip_scale", "count": 1}, {"id": "glowcap", "count": 2}]}, radius=20,
         conditions={"period": "night", "flow": "strong", "state": ["swim", "dive", "drive"]}, icon="✦"),
]

# --- People: Sabel on the west, the nomad on the east -----------------------------------------------------------
_SABEL_W = ["RUMOR_TIDEKEEPER_%d" % i for i in (6, 7)]
_NOMAD_R = ["RUMOR_NOMAD_%d" % i for i in (1, 2, 3)]
_R_LOC = dict(zip(_SABEL_W + _NOMAD_R, [
    L("West of Tide Isle the mist comes in every night. The old bell-keepers rang ships home through it.", "Al oeste de la Isla de las Mareas la bruma entra cada noche. Los viejos campaneros guiaban a los barcos a través de ella.", "A oeste da Ilha das Marés a bruma entra toda noite. Os velhos sineiros guiavam os navios através dela.", "À l'ouest de l'Île des Marées, la brume vient chaque nuit. Les vieux sonneurs y guidaient les navires.", "Westlich der Gezeiteninsel kommt jede Nacht der Nebel. Die alten Glöckner läuteten Schiffe hindurch heim.", "潮の島の西は毎晩霧が来る。昔の鐘守りはその中を鐘で船を導いた。", "조수의 섬 서쪽엔 밤마다 안개가 온다. 옛 종지기들이 그 속으로 배를 불러들였지.", "潮汐岛以西每晚都起雾。老守钟人曾用钟声领船穿过去。"),
    L("Don't stop in the western mist. Something follows boats in there, and it only comes close when they stop.", "No te detengas en la bruma del oeste. Algo sigue a los botes allí, y solo se acerca cuando se paran.", "Não pare na bruma do oeste. Algo segue os barcos ali, e só chega perto quando param.", "Ne t'arrête pas dans la brume de l'ouest. Quelque chose suit les bateaux, et n'approche que s'ils s'arrêtent.", "Halt nicht im Westnebel. Dort folgt etwas den Booten, und es kommt nur nah, wenn sie stehen.", "西の霧で止まるな。何かが舟を追い、止まった時だけ寄ってくる。", "서쪽 안개에서 멈추지 마. 뭔가가 배를 따라다니다가 멈출 때만 다가와.", "在西边雾里别停下。有东西跟着船，只在船停时才靠近。"),
    L("The sea south of the cliffs runs like a river twice a day, then goes still as a pond. Learn when.", "El mar al sur de los acantilados corre como un río dos veces al día y luego queda quieto como un estanque. Aprende cuándo.", "O mar ao sul das falésias corre como rio duas vezes ao dia e depois fica parado como lago. Aprenda quando.", "La mer au sud des falaises coule comme un fleuve deux fois par jour, puis dort comme un étang. Apprends quand.", "Das Meer südlich der Klippen fließt zweimal am Tag wie ein Fluss und liegt dann still wie ein Teich. Lern, wann.", "崖の南の海は日に二度川のように流れ、池のように静まる。時を覚えろ。", "절벽 남쪽 바다는 하루 두 번 강처럼 흐르다 연못처럼 잠잠해진다. 때를 익혀라.", "崖南的海一天两次像河一样奔流，之后又静如池塘。记住时辰。"),
    L("A ship broke on the islet below the cliffs. Only half of it is on the sand. Its chain goes into the sea.", "Un barco se partió en el islote bajo los acantilados. Solo medio está en la arena. Su cadena se hunde en el mar.", "Um navio se partiu na ilhota sob as falésias. Só metade está na areia. A corrente dele entra no mar.", "Un navire s'est brisé sur l'îlot sous les falaises. La moitié seulement est sur le sable. Sa chaîne file dans la mer.", "Ein Schiff zerbrach an der Insel unter den Klippen. Nur die Hälfte liegt im Sand. Seine Kette führt ins Meer.", "崖下の小島で船が割れた。砂の上には半分だけ。鎖は海へ続く。", "절벽 아래 섬에서 배가 부서졌어. 모래 위엔 반쪽뿐이고 사슬이 바다로 이어져.", "崖下小岛上碎了一艘船，沙上只有半截，锚链伸进海里。"),
    L("The Wind Rock breathes. Swim to its foot when the water boils, and the sea will throw you to the sky.", "La Roca del Viento respira. Nada a su pie cuando el agua hierva y el mar te lanzará al cielo.", "A Rocha do Vento respira. Nade ao pé dela quando a água ferver, e o mar te lançará ao céu.", "Le Rocher du Vent respire. Nage à son pied quand l'eau bout, et la mer te jettera au ciel.", "Der Windfels atmet. Schwimm zu seinem Fuß, wenn das Wasser kocht, und das Meer wirft dich in den Himmel.", "風の岩は息をする。水が沸いたら麓へ泳げ。海が空へ放り上げる。", "바람 바위는 숨을 쉰다. 물이 끓을 때 발치로 헤엄쳐 가면 바다가 하늘로 던져 줄 거야.", "风岩会呼吸。水冒泡时游到它脚下，海会把你抛上天。"),
]))
ENTITY_PATCHES = {"NPC_NOMAD": {"dialogue": {"rumors": _NOMAD_R}}}
TIDEKEEPER_EXTRA_RUMORS = _SABEL_W

STRINGS = dict(_R_LOC)
STRINGS.update({
    "PROMPT_RING": L("Ring", "Tocar", "Tocar", "Sonner", "Läuten", "鳴らす", "치기", "敲钟"),
    "HINT_SPOUT": L("The sea throws you up — open the sail!", "¡El mar te lanza hacia arriba: abre la vela!", "O mar te lança para cima — abra a vela!", "La mer te projette — ouvre la voile !", "Das Meer wirft dich hoch — öffne das Segel!", "海に放り上げられた。帆を開け！", "바다가 너를 던져 올린다. 돛을 펴!", "海把你抛起来了——快张帆！"),
    "LINE_BELLS_ANSWERED": L("From the heart of the mist, a great bell answers. Somewhere a stone slides aside.", "Desde el corazón de la bruma responde una gran campana. En algún lugar se corre una piedra.", "Do coração da bruma, um grande sino responde. Em algum lugar uma pedra desliza.", "Du cœur de la brume, une grande cloche répond. Quelque part, une pierre glisse.", "Aus dem Herzen des Nebels antwortet eine große Glocke. Irgendwo gleitet ein Stein beiseite.", "霧の奥から大鐘が応えた。どこかで石がずれる音。", "안개 한가운데서 큰 종이 대답한다. 어딘가에서 돌이 밀려난다.", "雾的深处一口大钟应了一声。某处有块石头挪开了。"),
    "LINE_PACT_LOG": L("Last entry: 'She broke on the islet. The stern went down onto the ledge with the strongbox. The chain is still fast to both halves.'", "Última entrada: 'Se partió en el islote. La popa bajó a la repisa con el cofre. La cadena sigue sujeta a las dos mitades.'", "Última entrada: 'Partiu-se na ilhota. A popa desceu à borda com o cofre. A corrente ainda prende as duas metades.'", "Dernière entrée : « Brisé sur l'îlot. La poupe a coulé sur le rebord avec le coffre. La chaîne tient encore les deux moitiés. »", "Letzter Eintrag: „An der Insel zerbrochen. Das Heck sank mit der Schatulle aufs Sims. Die Kette hält noch beide Hälften.“", "最後の記録「小島で割れた。船尾は金庫ごと棚へ沈んだ。鎖はまだ両方に繋がっている」", "마지막 기록: '섬에서 부서졌다. 선미는 금고와 함께 턱으로 가라앉았다. 사슬은 아직 두 쪽에 묶여 있다.'", "最后一页：“在小岛上断了。船尾带着保险箱沉到礁台上。锚链还拴着两半。”"),
    "COND_MIST": L("in the mist", "en la bruma", "na bruma", "dans la brume", "im Nebel", "霧の中で", "안개 속에서", "雾中"),
    "COND_FLOW_STRONG": L("when the tide runs", "con la marea corriendo", "com a maré correndo", "quand la marée court", "bei laufender Tide", "潮が動く時", "물살이 흐를 때", "潮水流动时"),
    "COND_SLACK": L("at slack water", "con el repunte", "no estofo da maré", "à l'étale", "bei Stauwasser", "潮止まりに", "정조 때", "平潮时"),
    "BUFF_MIST_SIGHT": L("Clear sight", "Vista clara", "Vista clara", "Vue claire", "Klare Sicht", "澄み目", "맑은 시야", "明目"),
})

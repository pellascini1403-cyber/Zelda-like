"""World content for the quest layer: NPCs, mini-bosses, the rare creature,
quest items, places (camps, grottos, the road post, beacons...), boards,
altars and emergent events. Applied idempotently (upsert by id) to data/*.json
by tools/gen_content.py. Every species keeps a unique solid placeholder
colour (checked below)."""
from qdsl import L

# --- Entities -----------------------------------------------------------------------------------------


def npc(eid, color, name, lines, night=None, schedule=None, height=1.72, radius=0.35, extra=None):
    d = {"id": eid, "kind": "NPC", "name_key": "NAME_" + eid[4:], "placeholder_color": color,
         "placeholder_shape": "humanoid", "model": "", "collider": {"radius": radius, "height": height},
         "stats": {"walk_speed": 1.3, "run_speed": 3.0, "turn_speed": 5},
         "ai": {"schedule": schedule or [[0, [1, -2]], [7, [0, 3]], [13, [-3, 1]], [19, [0, 3]], [22, [1, -2]]]},
         "dialogue": {"default": ["DLG_%s_%d" % (eid[4:], i + 1) for i in range(len(lines))]}}
    if night:
        d["dialogue"]["night"] = ["DLG_%s_NIGHT" % eid[4:]]
    if extra:
        d.update(extra)
    loc = {"NAME_" + eid[4:]: name}
    for i, l in enumerate(lines):
        loc["DLG_%s_%d" % (eid[4:], i + 1)] = l
    if night:
        loc["DLG_%s_NIGHT" % eid[4:]] = night
    return d, loc


NPCS = [
    npc("NPC_SMITH", "#8f1d1d", L("Hadda, smith", "Hadda, herrera", "Hadda, ferreira", "Hadda, forgeronne", "Hadda, Schmiedin", "鍛冶屋ハッダ", "대장장이 하다", "铁匠哈达"),
        [L("Bring me ore and I'll bring you an edge.", "Tráeme mineral y te daré un buen filo.", "Traga minério e eu te dou um bom fio.", "Apportez du minerai, je vous rendrai un tranchant.", "Bring mir Erz, und ich bring dir eine Schneide.", "鉱石を持ってきな。いい刃にしてやる。", "광석을 가져오면 날을 세워 주지.", "拿矿石来，我还你一把好刃。")],
        night=L("The forge sleeps. So should you.", "La forja duerme. Tú también deberías.", "A forja dorme. Você também devia.", "La forge dort. Vous devriez aussi.", "Die Esse schläft. Du solltest es auch.", "炉は眠った。あんたも寝な。", "화로도 잠들었다. 너도 자라.", "炉火睡了，你也该睡了。")),
    npc("NPC_CHILD", "#ffb3c7", L("Lio", "Lio", "Lio", "Lio", "Lio", "リオ", "리오", "小里奥"),
        [L("When I grow up I'll glide higher than the pagoda!", "¡De mayor planearé más alto que la pagoda!", "Quando crescer vou planar mais alto que o pagode!", "Plus tard, je planerai plus haut que la pagode !", "Wenn ich groß bin, gleite ich höher als die Pagode!", "大きくなったら塔より高く飛ぶんだ！", "크면 탑보다 높이 날 거야!", "等我长大，要飞得比宝塔还高！")],
        height=1.25, radius=0.28),
    npc("NPC_COURIER", "#c2e05a", L("Pip, courier", "Pip, mensajera", "Pip, mensageira", "Pip, messagère", "Pip, Botin", "飛脚のピップ", "배달꾼 핍", "信使皮普"),
        [L("Letters, parcels, gossip. I carry it all.", "Cartas, paquetes, chismes. Lo llevo todo.", "Cartas, pacotes, fofocas. Levo tudo.", "Lettres, colis, ragots. Je porte tout.", "Briefe, Pakete, Klatsch. Ich trage alles.", "手紙に荷物にうわさ話。なんでも運ぶよ。", "편지, 소포, 소문. 뭐든 나른다.", "信件、包裹、闲话，我都送。")]),
    npc("NPC_FISHER", "#1f6f8b", L("Ilo, fisher", "Ilo, pescador", "Ilo, pescador", "Ilo, pêcheur", "Ilo, Fischer", "漁師イロ", "어부 일로", "渔夫伊洛"),
        [L("The lake keeps its secrets under the lilies.", "El lago guarda sus secretos bajo los nenúfares.", "O lago guarda segredos sob os lírios.", "Le lac garde ses secrets sous les nénuphars.", "Der See hütet seine Geheimnisse unter den Seerosen.", "湖は蓮の下に秘密を隠す。", "호수는 연잎 아래 비밀을 숨긴다.", "湖把秘密藏在睡莲底下。")],
        night=L("Fish bite best by lantern light.", "Los peces pican mejor a la luz del farol.", "Os peixes mordem melhor à luz da lanterna.", "Le poisson mord mieux à la lanterne.", "Bei Laternenlicht beißen sie am besten.", "魚は灯りの下でよく釣れる。", "물고기는 등불 아래서 잘 문다.", "鱼儿在灯下最爱咬钩。")),
    npc("NPC_HUNTER", "#3f5a1c", L("Varra, hunter", "Varra, cazadora", "Varra, caçadora", "Varra, chasseuse", "Varra, Jägerin", "狩人ヴァラ", "사냥꾼 바라", "猎人瓦拉"),
        [L("Walk soft. The forest listens.", "Pisa suave. El bosque escucha.", "Pise leve. A floresta escuta.", "Marchez doucement. La forêt écoute.", "Geh leise. Der Wald hört zu.", "静かに歩け。森は聞いている。", "조용히 걸어라. 숲이 듣고 있다.", "脚步放轻，森林在听。")]),
    npc("NPC_SCHOLAR", "#d9c89a", L("Quill, scholar", "Quill, erudito", "Quill, estudioso", "Quill, érudit", "Quill, Gelehrter", "学者クイル", "학자 퀼", "学者奎尔"),
        [L("Every stone here remembers the wind.", "Cada piedra aquí recuerda al viento.", "Cada pedra aqui lembra o vento.", "Chaque pierre ici se souvient du vent.", "Jeder Stein hier erinnert sich an den Wind.", "ここの石はみな風を覚えている。", "이곳의 돌은 모두 바람을 기억한다.", "这里的每块石头都记得风。")]),
    npc("NPC_KEEPER", "#cfc3f5", L("Mother Ansel, shrine keeper", "Madre Ansel, guardiana", "Madre Ansel, zeladora", "Mère Ansel, gardienne", "Mutter Ansel, Schreinhüterin", "祠守アンセル", "사당지기 안셀", "守祠人安瑟嬷嬷"),
        [L("Jade is the wind made still. Offer it, and it moves again — in you.", "El jade es viento quieto. Ofrécelo y volverá a moverse, en ti.", "O jade é vento parado. Ofereça-o e ele se move de novo, em você.", "Le jade est du vent figé. Offrez-le, il bougera à nouveau — en vous.", "Jade ist ruhender Wind. Opfere ihn, und er regt sich wieder — in dir.", "翡翠は止まった風。捧げれば、あなたの中でまた動き出す。", "비취는 멈춘 바람. 바치면 네 안에서 다시 움직인다.", "翡翠是静止的风。献上它，风会在你体内重新流动。")]),
    npc("NPC_CLIMBER", "#ff5c8a", L("Kest, climber", "Kest, escaladora", "Kest, escaladora", "Kest, grimpeuse", "Kest, Kletterin", "登攀家ケスト", "등반가 케스트", "攀岩者凯丝特"),
        [L("Rock doesn't care how you feel. Only how you grip.", "A la roca no le importa cómo te sientes. Solo cómo agarras.", "A rocha não liga pro que você sente. Só pra como segura.", "La roche se moque de vos humeurs. Seule la prise compte.", "Dem Fels ist egal, wie du dich fühlst. Nur dein Griff zählt.", "岩は気分など気にしない。握り方だけだ。", "바위는 기분 따윈 신경 안 써. 잡는 법만 봐.", "岩石不在乎你的心情，只在乎你怎么抓。")]),
    npc("NPC_GUARD", "#4a5a6a", L("Doran, road warden", "Doran, guardacaminos", "Doran, guarda da estrada", "Doran, garde des routes", "Doran, Wegwächter", "街道守りドラン", "길지기 도란", "巡路人多兰"),
        [L("East road's open. Mind the sand and the things in it.", "El camino del este está abierto. Cuidado con la arena y lo que hay en ella.", "A estrada leste está aberta. Cuidado com a areia e o que há nela.", "La route de l'est est ouverte. Méfiez-vous du sable et de ce qu'il cache.", "Die Oststraße ist offen. Hüte dich vor dem Sand und dem, was darin lebt.", "東の道は通れる。砂と、砂の中のものに気をつけろ。", "동쪽 길은 열렸다. 모래와 그 속의 것들을 조심해라.", "东路已通。当心沙子，还有沙里的东西。")]),
    npc("NPC_HERMIT", "#8fae6e", L("Old Wen, hermit", "Viejo Wen, ermitaño", "Velho Wen, eremita", "Vieux Wen, ermite", "Der alte Wen, Einsiedler", "隠者ウェン老", "은자 웬 노인", "隐士老温"),
        [L("Soup first. Questions after.", "Primero sopa. Luego preguntas.", "Primeiro sopa. Perguntas depois.", "La soupe d'abord. Les questions ensuite.", "Erst Suppe. Dann Fragen.", "まずは汁物だ。話はそれからだ。", "국부터 먹어. 질문은 그다음이다.", "先喝汤，再问话。")]),
    npc("NPC_PILGRIM", "#9b6fc9", L("Sister Maru, pilgrim", "Hermana Maru, peregrina", "Irmã Maru, peregrina", "Sœur Maru, pèlerine", "Schwester Maru, Pilgerin", "巡礼者マル", "순례자 마루 수녀", "朝圣者玛露修女"),
        [L("Past here, even the birds forget to sing.", "Más allá, hasta los pájaros olvidan cantar.", "Além daqui, até os pássaros esquecem de cantar.", "Au-delà, même les oiseaux oublient de chanter.", "Dahinter vergessen selbst die Vögel zu singen.", "この先では鳥さえ歌を忘れる。", "이 너머에선 새들조차 노래를 잊는다.", "再往前，连鸟都忘了歌唱。")]),
    npc("NPC_CARAVAN", "#0b6e4f", L("Tobb, caravan master", "Tobb, jefe de caravana", "Tobb, chefe de caravana", "Tobb, maître caravanier", "Tobb, Karawanenmeister", "隊商頭トッブ", "대상 우두머리 톱", "商队头领托布"),
        [L("One more crossing, then I'm done with sand forever.", "Una travesía más y adiós a la arena para siempre.", "Mais uma travessia e adeus à areia para sempre.", "Une traversée encore, puis adieu le sable.", "Noch eine Durchquerung, dann nie wieder Sand.", "もう一度渡ったら、砂とはおさらばだ。", "한 번만 더 건너면 모래와는 끝이다.", "再走一趟，我就跟沙子永别。")]),
    npc("NPC_TRAVELER", "#5e7b8c", L("Traveller", "Viajero", "Viajante", "Voyageur", "Reisender", "旅人", "나그네", "旅人"),
        [L("Roads are safer with you on them.", "Los caminos son más seguros contigo.", "As estradas são mais seguras com você.", "Les routes sont plus sûres avec vous.", "Mit dir sind die Wege sicherer.", "あんたがいると道が安全だ。", "네가 있으니 길이 안전하다.", "有你在，路上安全多了。")]),
    npc("NPC_MENTOR", "#00e5a0", L("Oren, Wind Warden", "Oren, Guardián del Viento", "Oren, Guardião do Vento", "Oren, Gardien du Vent", "Oren, Windhüter", "風守りオレン", "바람지기 오렌", "守风者奥伦"),
        [L("You found the wind again. Keep it moving.", "Encontraste de nuevo el viento. Mantenlo en marcha.", "Você reencontrou o vento. Mantenha-o em movimento.", "Vous avez retrouvé le vent. Gardez-le en mouvement.", "Du hast den Wind wiedergefunden. Halte ihn in Bewegung.", "風をまた見つけたな。止めるなよ。", "바람을 다시 찾았구나. 계속 흐르게 해라.", "你重新找回了风。别让它停下。")]),
]


def creature(eid, kind, color, shape, name, hp, collider, stats, attacks, ai, loot, mult=None, flying=False):
    d = {"id": eid, "kind": kind, "name_key": "NAME_" + eid.split("_", 1)[1], "placeholder_color": color,
         "placeholder_shape": shape, "model": "", "collider": collider,
         "stats": dict({"max_health": hp}, **stats), "ai": ai, "attacks": attacks, "loot_table": loot}
    if mult:
        d["element_mult"] = mult
    if flying:
        d["flying"] = True
    return d, {"NAME_" + eid.split("_", 1)[1]: name}


CREATURES = [
    creature("BOSS_THORN_CHIEF", "BOSS", "#ff2e63", "quadruped", L("Thornling Chief", "Jefe espinudo", "Chefe espinhoso", "Chef des ronceux", "Dornling-Häuptling", "トゲ獣の長", "가시짐승 우두머리", "棘兽首领"), 220,
             {"radius": 0.9, "height": 1.8}, {"defense": 2, "poise": 60, "walk_speed": 2.6, "run_speed": 7.0, "turn_speed": 5, "mass": 260},
             [{"id": "rake", "type": "melee", "range_min": 0, "range_max": 2.8, "windup": 0.55, "active": 0.15, "recovery": 0.7, "cooldown": 1.2, "damage": 14, "knockback": 6, "reach": 2.4, "arc": 70, "weight": 3, "telegraph": True},
              {"id": "leap", "type": "lunge", "range_min": 4, "range_max": 11, "windup": 0.7, "active": 0.45, "recovery": 0.9, "cooldown": 4, "damage": 20, "knockback": 9, "reach": 1.8, "arc": 60, "lunge_speed": 16, "weight": 2},
              {"id": "howl_thorns", "type": "volley", "range_min": 4, "range_max": 16, "windup": 0.8, "active": 0.2, "recovery": 0.7, "cooldown": 6, "damage": 8, "count": 4, "spread": 45, "projectile_speed": 15, "element": "thorn", "weight": 1}],
             {"sight_range": 30, "fov": 360, "hearing": 2.0, "leash": 40, "respawn_hours": 999999}, "drop_chief", {"fire": 1.5}),
    creature("BOSS_CRAG_HARRIER", "BOSS", "#1f3fa8", "orb", L("Crag Harrier", "Azor de los riscos", "Gavião dos rochedos", "Busard des crêtes", "Klippenweih", "岩場の鷂", "벼랑 매", "崖鹞"), 300,
             {"radius": 1.1, "height": 1.6}, {"defense": 1, "poise": 50, "walk_speed": 4, "run_speed": 9.0, "turn_speed": 6, "mass": 120},
             [{"id": "dive", "type": "charge", "range_min": 5, "range_max": 24, "windup": 0.9, "active": 1.0, "recovery": 1.1, "cooldown": 4.5, "damage": 18, "knockback": 10, "reach": 24, "charge_speed": 17, "poise_damage": 30, "blockable": False, "weight": 3},
              {"id": "talon", "type": "melee", "range_min": 0, "range_max": 3.2, "windup": 0.5, "active": 0.15, "recovery": 0.6, "cooldown": 1.3, "damage": 12, "knockback": 5, "reach": 2.6, "arc": 80, "weight": 2},
              {"id": "gale_feathers", "type": "volley", "range_min": 6, "range_max": 22, "windup": 0.8, "active": 0.2, "recovery": 0.8, "cooldown": 5, "damage": 9, "count": 5, "spread": 60, "projectile_speed": 18, "element": "wind", "weight": 2}],
             {"sight_range": 45, "fov": 360, "hearing": 2.0, "leash": 60, "respawn_hours": 999999}, "drop_harrier", {"electric": 1.5}, flying=True),
    creature("BOSS_STONEWARD", "BOSS", "#7d7461", "giant", L("Stoneward", "Guardapiedra", "Guarda-pedra", "Garde-pierre", "Steinwart", "石番", "돌파수꾼", "守石者"), 420,
             {"radius": 0.9, "height": 3.2}, {"defense": 5, "poise": 110, "walk_speed": 1.5, "run_speed": 3.4, "turn_speed": 3.5, "mass": 700},
             [{"id": "hammer", "type": "melee", "range_min": 0, "range_max": 3.4, "windup": 0.9, "active": 0.2, "recovery": 1.0, "cooldown": 1.8, "damage": 22, "knockback": 9, "reach": 3.0, "arc": 85, "poise_damage": 35, "weight": 3, "telegraph": True},
              {"id": "quarry_slam", "type": "slam", "range_min": 0, "range_max": 5, "windup": 1.3, "active": 0.2, "recovery": 1.4, "cooldown": 6, "damage": 28, "knockback": 12, "reach": 1.0, "radius": 5.5, "blockable": False, "poise_damage": 50, "weight": 2},
              {"id": "rock_rain", "type": "eruption", "range_min": 0, "range_max": 24, "windup": 0.9, "active": 0.2, "recovery": 1.1, "cooldown": 8, "damage": 14, "count": 4, "radius": 2.2, "delay": 1.0, "element": "", "weight": 1}],
             {"sight_range": 26, "fov": 200, "hearing": 1.0, "leash": 35, "respawn_hours": 999999}, "drop_stoneward", {"electric": 1.6}),
    creature("BOSS_GLASS_STALKER", "BOSS", "#a8ffee", "quadruped", L("Glass Stalker", "Acechador de vidrio", "Espreitador de vidro", "Traqueur de verre", "Glaspirscher", "玻璃の追跡者", "유리 추적자", "琉璃潜猎者"), 340,
             {"radius": 1.0, "height": 1.4}, {"defense": 3, "poise": 70, "walk_speed": 2.8, "run_speed": 8.0, "turn_speed": 6, "mass": 220},
             [{"id": "glass_sting", "type": "lunge", "range_min": 0, "range_max": 5, "windup": 0.5, "active": 0.3, "recovery": 0.7, "cooldown": 1.4, "damage": 16, "knockback": 6, "reach": 1.8, "arc": 50, "lunge_speed": 12, "weight": 3},
              {"id": "sand_dash", "type": "charge", "range_min": 6, "range_max": 20, "windup": 0.8, "active": 0.9, "recovery": 1.0, "cooldown": 5, "damage": 18, "knockback": 10, "reach": 20, "charge_speed": 16, "blockable": False, "weight": 2},
              {"id": "shard_burst", "type": "volley", "range_min": 3, "range_max": 16, "windup": 0.8, "active": 0.2, "recovery": 0.8, "cooldown": 6, "damage": 9, "count": 6, "spread": 90, "projectile_speed": 15, "element": "glass", "weight": 1}],
             {"sight_range": 30, "fov": 300, "hearing": 1.8, "leash": 45, "respawn_hours": 999999}, "drop_stalker", {"ice": 1.6}),
    creature("BOSS_HOLLOW_SHADE", "BOSS", "#3d0066", "humanoid", L("Hollow Shade", "Sombra hueca", "Sombra oca", "Ombre creuse", "Hohler Schatten", "虚ろな影", "텅 빈 그림자", "空洞之影"), 380,
             {"radius": 0.6, "height": 2.8}, {"defense": 3, "poise": 60, "walk_speed": 2.0, "run_speed": 5.2, "turn_speed": 6, "mass": 140},
             [{"id": "hollow_claw", "type": "melee", "range_min": 0, "range_max": 3.0, "windup": 0.6, "active": 0.15, "recovery": 0.7, "cooldown": 1.3, "damage": 18, "knockback": 6, "reach": 2.6, "arc": 70, "element": "still", "weight": 3},
              {"id": "hush_wave", "type": "pulse", "range_min": 0, "range_max": 5, "windup": 1.1, "active": 0.2, "recovery": 1.0, "cooldown": 6, "damage": 16, "radius": 5.0, "knockback": 8, "blockable": False, "element": "still", "weight": 2},
              {"id": "still_lances", "type": "volley", "range_min": 5, "range_max": 20, "windup": 0.9, "active": 0.2, "recovery": 0.9, "cooldown": 5, "damage": 11, "count": 3, "spread": 30, "projectile_speed": 17, "element": "still", "weight": 2}],
             {"sight_range": 30, "fov": 300, "hearing": 1.6, "leash": 45, "respawn_hours": 999999}, "drop_hollow", {"fire": 1.4, "electric": 0.7}),
    creature("ANIMAL_GILDED_HOP", "ANIMAL", "#fff176", "quadruped", L("Gilded Hop", "Saltarín dorado", "Saltador dourado", "Bondisseur doré", "Goldhüpfer", "金の跳ね兎", "황금 깡충이", "金跃兔"), 10,
             {"radius": 0.28, "height": 0.55}, {"poise": 2, "walk_speed": 1.8, "run_speed": 10.5, "turn_speed": 14, "mass": 6},
             [], {"sight_range": 22, "fov": 330, "hearing": 2.0, "skittish": 0.05, "wander_radius": 8, "respawn_hours": 24}, "drop_gilded"),
]

# --- Items & loot --------------------------------------------------------------------------------------


def item(iid, cat, name, desc, **kw):
    d = {"id": iid, "category": cat}
    d.update(kw)
    return d, {"ITEM_" + iid.upper(): name, "ITEM_" + iid.upper() + "_DESC": desc}


ITEMS = [
    item("lios_kite", "key", L("Lio's kite", "Cometa de Lio", "Pipa do Lio", "Cerf-volant de Lio", "Lios Drachen", "リオの凧", "리오의 연", "小里奥的风筝"),
         L("Red silk, bamboo ribs, one very brave paper crane painted on it.", "Seda roja, varillas de bambú y una grulla muy valiente pintada.", "Seda vermelha, varetas de bambu e um grou muito corajoso pintado.", "Soie rouge, baguettes de bambou, une grue très courageuse peinte dessus.", "Rote Seide, Bambusrippen, ein sehr mutiger Papierkranich darauf.", "赤い絹に竹の骨、勇ましい鶴の絵。", "붉은 비단, 대나무 살, 용감한 학 그림.", "红绸竹骨，画着一只勇敢的纸鹤。"), max_stack=1),
    item("oren_letter", "key", L("Oren's letter", "Carta de Oren", "Carta de Oren", "Lettre d'Oren", "Orens Brief", "オレンの手紙", "오렌의 편지", "奥伦的信"),
         L("\"Light the beacons, apprentice. The wind follows fire.\"", "\"Enciende las balizas, aprendiz. El viento sigue al fuego.\"", "\"Acenda os faróis, aprendiz. O vento segue o fogo.\"", "« Allume les fanaux, apprenti·e. Le vent suit le feu. »", "„Entzünde die Leuchtfeuer, Lehrling. Der Wind folgt dem Feuer.“", "「灯台に火を。風は火を追う」", "\"봉화를 밝혀라, 견습생. 바람은 불을 따른다.\"", "“点燃烽火，学徒。风随火走。”"), max_stack=1),
    item("fishing_net", "key", L("Ilo's net", "Red de Ilo", "Rede do Ilo", "Filet d'Ilo", "Ilos Netz", "イロの網", "일로의 그물", "伊洛的渔网"),
         L("Wet, tangled, smells of lake.", "Mojada, enredada, huele a lago.", "Molhada, emaranhada, cheira a lago.", "Mouillé, emmêlé, sent le lac.", "Nass, verheddert, riecht nach See.", "濡れて絡まり、湖の匂い。", "젖고 엉킨 채 호수 냄새가 난다.", "湿漉漉、缠成一团，一股湖水味。"), max_stack=1),
    item("sun_disc", "key", L("Sun disc", "Disco solar", "Disco solar", "Disque solaire", "Sonnenscheibe", "日輪の円盤", "태양 원반", "日轮圆盘"),
         L("Warm to the touch, even at night. It hums near fire.", "Tibio al tacto, incluso de noche. Zumba junto al fuego.", "Morno ao toque, mesmo à noite. Zumbe perto do fogo.", "Tiède au toucher, même la nuit. Il bourdonne près du feu.", "Warm, selbst nachts. Es summt nahe am Feuer.", "夜でも温かい。火のそばで唸る。", "밤에도 따뜻하다. 불 곁에서 웅웅 울린다.", "即使在夜里也温热，靠近火时会嗡鸣。"), max_stack=1),
    item("warden_breath", "key", L("Warden's Breath", "Aliento del Guardián", "Fôlego do Guardião", "Souffle du Gardien", "Hüteratem", "守り人の息吹", "지기의 숨결", "守风者之息"),
         L("A feather that never settles. The Still Heart cannot hold it.", "Una pluma que nunca se posa. El Corazón Quieto no puede retenerla.", "Uma pena que nunca pousa. O Coração Quieto não a segura.", "Une plume qui ne se pose jamais. Le Cœur Immobile ne peut la retenir.", "Eine Feder, die nie zur Ruhe kommt. Das Stille Herz hält sie nicht.", "決して落ち着かない羽。静寂の心も留められない。", "결코 가라앉지 않는 깃털. 고요한 심장도 붙잡지 못한다.", "一根永不落定的羽毛，静寂之心也留不住它。"), max_stack=1, rarity=3),
    item("charged_core", "key", L("Storm core", "Núcleo de tormenta", "Núcleo de tempestade", "Cœur d'orage", "Sturmkern", "嵐の核", "폭풍 핵", "雷暴之核"),
         L("It crackles when you hold it too long.", "Chisporrotea si lo sostienes demasiado.", "Estala se você o segura demais.", "Il crépite si on le tient trop longtemps.", "Es knistert, wenn man es zu lange hält.", "長く持つとぱちぱち鳴る。", "오래 쥐고 있으면 타닥거린다.", "握久了会噼啪作响。"), max_stack=1),
    item("pips_letter", "key", L("Stray letter", "Carta perdida", "Carta perdida", "Lettre égarée", "Verlorener Brief", "迷子の手紙", "잃어버린 편지", "遗失的信"),
         L("Addressed in Pip's hurried hand.", "Con la letra apresurada de Pip.", "Com a letra apressada de Pip.", "De l'écriture pressée de Pip.", "In Pips eiliger Handschrift.", "ピップの走り書きの宛名。", "핍의 급한 글씨로 적힌 주소.", "上面是皮普潦草的字迹。"), max_stack=5),
    item("gilded_fur", "material", L("Gilded fur", "Pelaje dorado", "Pelo dourado", "Fourrure dorée", "Goldfell", "金の毛皮", "황금 털가죽", "金色毛皮"),
         L("Soft as a sunrise. Traders pay well for it.", "Suave como un amanecer. Los mercaderes pagan bien.", "Macio como o amanhecer. Mercadores pagam bem.", "Douce comme l'aube. Les marchands paient bien.", "Weich wie ein Sonnenaufgang. Händler zahlen gut.", "朝日のように柔らかい。商人が高く買う。", "해돋이처럼 부드럽다. 상인들이 비싸게 산다.", "软如朝阳，商人肯出高价。"), value=90, rarity=2),
    item("river_lantern", "key", L("River lantern", "Farolillo de río", "Lanterna de rio", "Lanterne de rivière", "Flusslaterne", "灯籠流しの灯", "강 등불", "河灯"),
         L("Paper and a stub of candle. Set it on moving water at night.", "Papel y un cabo de vela. Ponlo en agua corriente de noche.", "Papel e um toco de vela. Ponha em água corrente à noite.", "Papier et bout de bougie. À poser sur l'eau vive, la nuit.", "Papier und ein Kerzenstummel. Nachts aufs fließende Wasser setzen.", "紙と短い蝋燭。夜、流れる水に置く。", "종이와 짧은 초. 밤에 흐르는 물에 띄운다.", "纸与半截蜡烛，夜里放在流水上。"), max_stack=3),
]

LOOT = {
    "drop_chief": [{"id": "thorn_fang", "chance": 1.0, "count": [4, 6]}, {"id": "fang_pepper", "chance": 1.0, "count": [2, 3]}, {"id": "glimmer_shard", "chance": 1.0, "count": [6, 10]}],
    "drop_harrier": [{"id": "wisp_filament", "chance": 1.0, "count": [2, 3]}, {"id": "glimmer_shard", "chance": 1.0, "count": [8, 12]}],
    "drop_stoneward": [{"id": "iron_ore", "chance": 1.0, "count": [4, 6]}, {"id": "iron_ingot", "chance": 1.0, "count": [1, 2]}, {"id": "glimmer_shard", "chance": 1.0, "count": [6, 9]}],
    "drop_stalker": [{"id": "glass_shard", "chance": 1.0, "count": [2, 4]}, {"id": "scuttler_chitin", "chance": 1.0, "count": [2, 3]}],
    "drop_hollow": [{"id": "shade_essence", "chance": 1.0, "count": [3, 4]}, {"id": "glimmer_shard", "chance": 1.0, "count": [8, 12]}],
    "drop_gilded": [{"id": "gilded_fur", "chance": 1.0, "count": [1, 1]}],
    "chest_hidden": [{"id": "glimmer_shard", "chance": 1.0, "count": [10, 16]}, {"id": "vital_seed", "chance": 0.5, "count": [1, 1]}, {"id": "stamina_bloom", "chance": 0.5, "count": [1, 1]}],
}

# --- Places ---------------------------------------------------------------------------------------------


def poi(pid, ptype, pos, name, **kw):
    d = {"id": pid, "type": ptype, "pos": pos, "name_key": "POI_" + pid.upper()}
    d.update(kw)
    return d, {"POI_" + pid.upper(): name}


NEW_POIS = [
    poi("hamlet_lookout", "watchtower", [-15, 210], L("Hamlet Lookout", "Atalaya de la aldea", "Mirante da aldeia", "Guet du hameau", "Dorfwarte", "村の物見台", "마을 망루", "村落望楼"),
        flatten=10, pad_height=24.9, clear_radius=14, discover_radius=30, lore="LORE_TOWER"),
    poi("lake_hut", "npc_camp", [-250, 100], L("Ilo's Landing", "Embarcadero de Ilo", "Cais do Ilo", "Ponton d'Ilo", "Ilos Anlegestelle", "イロの船着き場", "일로의 나루", "伊洛渡口"),
        style="fisher", tents=1, flatten=9, pad_height=6.4, clear_radius=16, discover_radius=30, yaw=1.4, npcs=[["NPC_FISHER", 2, 4]]),
    poi("lake_isle", "shrine", [-440, 60], L("Lily Isle", "Isla de los Lirios", "Ilha dos Lírios", "Île aux Lys", "Lilieninsel", "睡蓮の小島", "연꽃 섬", "睡莲小岛"),
        flatten=9, pad_height=1.6, clear_radius=10, discover_radius=26, yaw=0.3, lore="LORE_SHRINE", beacon="beacon_lake"),
    poi("hunters_lodge", "npc_camp", [370, 160], L("Varra's Lodge", "Refugio de Varra", "Abrigo de Varra", "Loge de Varra", "Varras Hütte", "ヴァラの小屋", "바라의 오두막", "瓦拉的小屋"),
        style="hunter", tents=2, flatten=12, pad_height=20.0, clear_radius=18, discover_radius=34, yaw=0.5,
        npcs=[["NPC_HUNTER", 1, 4], ["NPC_SCHOLAR", -3, 6, "quill_safe"]], board="lodge", board_at=[6, 6], board_yaw=-0.6),
    poi("road_post", "post", [700, 240], L("East Road Post", "Puesto del camino del este", "Posto da estrada leste", "Poste de la route de l'Est", "Posten an der Oststraße", "東街道の番所", "동쪽 길 초소", "东路哨所"),
        flatten=12, pad_height=19.6, clear_radius=18, discover_radius=36, yaw=1.6, smoke=True, smoke_at=[3, 3.5],
        npcs=[["NPC_GUARD", 0, 4]], altar=True, altar_at=[-4, 5]),
    poi("climbers_camp", "npc_camp", [320, -160], L("Kest's Camp", "Campamento de Kest", "Acampamento de Kest", "Camp de Kest", "Kests Lager", "ケストの野営地", "케스트의 야영지", "凯丝特营地"),
        style="climber", tents=1, flatten=9, pad_height=46.3, clear_radius=14, discover_radius=30, yaw=-0.8, npcs=[["NPC_CLIMBER", 2, 3]]),
    poi("hermit_hut", "npc_camp", [-300, -360], L("Wen's Hollow", "Hondonada de Wen", "Recanto de Wen", "Creux de Wen", "Wens Senke", "ウェンの窪地", "웬의 골짜기", "温老的山坳"),
        style="hermit", tents=1, flatten=9, pad_height=36.9, clear_radius=14, discover_radius=28, yaw=0.9, smoke=True, npcs=[["NPC_HERMIT", 2, 3]]),
    poi("pilgrim_camp", "npc_camp", [650, -650], L("Last Lantern Camp", "Campamento del Último Farol", "Acampamento da Última Lanterna", "Camp de la Dernière Lanterne", "Lager der Letzten Laterne", "最後の灯の野営地", "마지막 등불 야영지", "末灯营地"),
        style="pilgrim", tents=2, flatten=12, pad_height=8.8, clear_radius=18, discover_radius=34, yaw=-0.7,
        npcs=[["NPC_PILGRIM", 1, 4]], board="veil", board_at=[6, 5], altar=True, altar_at=[-6, 5]),
    poi("glow_grotto", "cave", [600, 330], L("Glowmoss Grotto", "Gruta del musgo luciente", "Gruta do musgo-luz", "Grotte de mousse-lueur", "Leuchtmoosgrotte", "光苔の洞", "빛이끼 동굴", "萤苔洞"),
        radius=9.0, yaw=2.2, flatten=11, pad_height=24.3, clear_radius=14, discover_radius=18, rock_color="#5f6a58", loot="chest_rare",
        nodes=[["glowmoss", -4, -2], ["glowmoss", 3, -4], ["glowmoss", 0, 2], ["glowmoss", -2, 4], ["glowmoss", 5, 1]]),
    poi("smugglers_cove", "cave", [-600, 520], L("Smugglers' Cove", "Cala de los contrabandistas", "Enseada dos contrabandistas", "Crique des contrebandiers", "Schmugglerbucht", "密輸人の入り江", "밀수꾼의 만", "走私者洞湾"),
        radius=10.0, yaw=-2.3, flatten=12, pad_height=7.0, clear_radius=16, discover_radius=20, rock_color="#7a6f60", loot="chest_camp"),
    poi("old_quarry", "quarry", [-330, -300], L("Old Quarry", "Cantera vieja", "Pedreira velha", "Vieille carrière", "Alter Steinbruch", "古い石切り場", "옛 채석장", "旧采石场"),
        flatten=16, pad_height=33.5, clear_radius=22, discover_radius=34, yaw=0.4, loot="chest_common",
        nodes=[["iron_vein", -8, -6], ["iron_vein", 6, -8], ["iron_vein", 10, 2], ["flint_rock", -4, 6]]),
    poi("dune_ruins", "ruins", [900, 480], L("Dune Ruins", "Ruinas de las dunas", "Ruínas das dunas", "Ruines des dunes", "Dünenruinen", "砂丘の遺跡", "모래언덕 유적", "沙丘遗迹"),
        flatten=18, pad_height=15.4, clear_radius=22, discover_radius=34, loot="chest_vault", lore="LORE_SUNKEN_HALL",
        npcs=[["NPC_CARAVAN", 3, 4, "tobb_arrived"]]),
    poi("veil_shrine", "shrine", [700, -720], L("Hushed Shrine", "Santuario silente", "Santuário silente", "Sanctuaire muet", "Stiller Schrein", "静寂の祠", "침묵의 사당", "寂静神祠"),
        yaw=-0.8, flatten=9, pad_height=35.8, clear_radius=10, discover_radius=26, lore="LORE_SHRINE"),
    poi("sea_bluff", "overlook", [300, 700], L("Gull Bluff", "Risco de las gaviotas", "Penhasco das gaivotas", "Falaise aux mouettes", "Möwenklippe", "鴎の崖", "갈매기 절벽", "鸥崖"),
        flatten=10, pad_height=34.0, clear_radius=12, discover_radius=28, lore="LORE_OVERLOOK"),
    poi("sea_stack", "shrine", [330, 792], L("Salt Stack", "Farallón de sal", "Rochedo de sal", "Aiguille de sel", "Salzfels", "潮の岩塔", "소금 바위", "盐岩柱"),
        yaw=2.8, flatten=6, pad_height=11.0, clear_radius=8, discover_radius=18, beacon="beacon_coast"),
    poi("hollow_ring", "arena", [1000, -790], L("Hollow Ring", "Anillo hueco", "Anel oco", "Cercle creux", "Hohler Ring", "虚ろの環", "텅 빈 고리", "空洞之环"),
        style="veil", radius=14, flatten=18, pad_height=15.0, clear_radius=20, discover_radius=40),
    poi("frost_shrine", "shrine", [-150, -500], L("Frost Shrine", "Santuario de escarcha", "Santuário de geada", "Sanctuaire du givre", "Frostschrein", "霜の祠", "서리 사당", "霜之神祠"),
        yaw=0.5, flatten=9, pad_height=207.5, clear_radius=10, discover_radius=24, lore="LORE_SHRINE"),
]

# Changes to existing places: who lives where, altars, boards, beacons, smoke.
POI_PATCHES = {
    "heath_hamlet": {"npcs": [["NPC_CARTOGRAPHER", 0, 6], ["NPC_MERCHANT", 3, 0], ["NPC_VILLAGER", -4, 10], ["NPC_SMITH", -9, -3], ["NPC_CHILD", 7, 9], ["NPC_COURIER", 5, -6]],
                     "board": "hamlet", "board_at": [-6, 14], "board_yaw": 0.4},
    "heath_shrine": {"npcs": [["NPC_KEEPER", 2, 3]], "altar": True, "altar_at": [0, 4.5]},
    "wayside_shrine": {"altar": True, "altar_at": [0, 4.5]},
    "sunscar_oasis": {"board": "oasis", "board_at": [6, 10], "altar": True, "altar_at": [-8, 12]},
    "cloud_temple": {"beacon": "beacon_valley", "npcs": [["NPC_MENTOR", 3, 8, "ending_reached"]]},
    "needles": {"beacon": "beacon_heights"},
    "glass_arena": {"beacon": "beacon_desert", "beacon_at": [19, 19]},
    "fang_camp": {"smoke": True},
    "thorn_den": {"smoke": True},
}

# --- Mini-bosses (bosses.json) -----------------------------------------------------------------------

MINI_BOSSES = [
    {"id": "thorn_chief", "entity": "BOSS_THORN_CHIEF", "title_key": "BOSS_THORN_CHIEF_TITLE", "element": "thorn", "loot": "chest_rare", "mini": True,
     "conditions": {"period": "night"}, "spawn_distance": 120,
     "arena": {"center": [-150, 432], "radius": 16, "home": [0, 0]},
     "rewards": [{"id": "fierce_skewer", "count": 2}],
     "phases": [{"at": 1.0, "attacks": ["rake", "leap"], "speed": 1.0},
                {"at": 0.5, "attacks": ["rake", "leap", "howl_thorns"], "speed": 1.25, "shockwave": 5, "summon": "ENEMY_THORNLING", "summon_count": 2, "title_key": "BOSS_THORN_CHIEF_P2"}]},
    {"id": "crag_harrier", "entity": "BOSS_CRAG_HARRIER", "title_key": "BOSS_CRAG_HARRIER_TITLE", "element": "wind", "loot": "chest_rare", "mini": True,
     "conditions": {"flag": "harrier_roused"}, "spawn_distance": 160,
     "arena": {"center": [390, -205], "radius": 28, "home": [0, 0]},
     "rewards": [{"id": "windrunner_band", "count": 1}],
     "phases": [{"at": 1.0, "attacks": ["dive", "talon"], "speed": 1.0},
                {"at": 0.5, "attacks": ["dive", "talon", "gale_feathers"], "speed": 1.3, "shockwave": 6, "title_key": "BOSS_CRAG_HARRIER_P2"}]},
    {"id": "stoneward", "entity": "BOSS_STONEWARD", "title_key": "BOSS_STONEWARD_TITLE", "element": "", "loot": "chest_rare", "mini": True,
     "spawn_distance": 120,
     "arena": {"center": [-330, -296], "radius": 18, "home": [0, 0]},
     "rewards": [{"id": "anvil_maul", "count": 1}, {"id": "forge_stone", "count": 1}],
     "phases": [{"at": 1.0, "attacks": ["hammer", "quarry_slam"], "speed": 1.0},
                {"at": 0.45, "attacks": ["hammer", "quarry_slam", "rock_rain"], "speed": 1.2, "shockwave": 6, "title_key": "BOSS_STONEWARD_P2"}]},
    {"id": "glass_stalker", "entity": "BOSS_GLASS_STALKER", "title_key": "BOSS_GLASS_STALKER_TITLE", "element": "glass", "loot": "chest_rare", "mini": True,
     "conditions": {"period": "night"}, "spawn_distance": 140,
     "arena": {"center": [1180, 520], "radius": 20, "home": [0, 0]},
     "rewards": [{"id": "sunglass_blade", "count": 1}],
     "phases": [{"at": 1.0, "attacks": ["glass_sting", "sand_dash"], "speed": 1.0},
                {"at": 0.5, "attacks": ["glass_sting", "sand_dash", "shard_burst"], "speed": 1.25, "shockwave": 6, "summon": "ENEMY_SCUTTLER", "summon_count": 2, "title_key": "BOSS_GLASS_STALKER_P2"}]},
    {"id": "hollow_shade", "entity": "BOSS_HOLLOW_SHADE", "title_key": "BOSS_HOLLOW_SHADE_TITLE", "element": "still", "loot": "chest_rare", "mini": True,
     "spawn_distance": 130,
     "arena": {"center": [1000, -790], "radius": 14, "home": [0, 0], "y": 15.0},
     "rewards": [{"id": "vital_seed", "count": 1}],
     "phases": [{"at": 1.0, "attacks": ["hollow_claw", "still_lances"], "speed": 1.0},
                {"at": 0.5, "attacks": ["hollow_claw", "still_lances", "hush_wave"], "speed": 1.2, "shockwave": 7, "summon": "ENEMY_SHADE", "summon_count": 2, "title_key": "BOSS_HOLLOW_SHADE_P2"}]},
]

BOSS_LOC = {
    "BOSS_THORN_CHIEF_TITLE": L("Terror of the Den", "Terror de la guarida", "Terror da toca", "Terreur de la tanière", "Schrecken des Baus", "巣穴の恐怖", "굴의 공포", "巢穴之恐"),
    "BOSS_THORN_CHIEF_P2": L("The pack answers", "La manada responde", "A matilha responde", "La meute répond", "Das Rudel antwortet", "群れが応える", "무리가 응답한다", "兽群回应"),
    "BOSS_CRAG_HARRIER_TITLE": L("Queen of the Needles", "Reina de las Agujas", "Rainha das Agulhas", "Reine des Aiguilles", "Königin der Nadeln", "針岩の女王", "바늘바위의 여왕", "针岩女王"),
    "BOSS_CRAG_HARRIER_P2": L("Storm on the wing", "Tormenta en las alas", "Tempestade nas asas", "L'orage sur les ailes", "Sturm auf den Schwingen", "翼に嵐", "날개에 폭풍", "翼卷风暴"),
    "BOSS_STONEWARD_TITLE": L("It still guards the quarry", "Aún guarda la cantera", "Ainda guarda a pedreira", "Il garde encore la carrière", "Es bewacht noch den Steinbruch", "今も石切り場を守る", "아직도 채석장을 지킨다", "仍在看守采石场"),
    "BOSS_STONEWARD_P2": L("The mountain shakes", "La montaña tiembla", "A montanha treme", "La montagne tremble", "Der Berg bebt", "山が揺れる", "산이 흔들린다", "山岳震动"),
    "BOSS_GLASS_STALKER_TITLE": L("It hunts by moonlight", "Caza a la luz de la luna", "Caça ao luar", "Il chasse au clair de lune", "Es jagt im Mondlicht", "月夜に狩る", "달빛 아래 사냥한다", "月下狩猎者"),
    "BOSS_GLASS_STALKER_P2": L("The sand cracks", "La arena se agrieta", "A areia racha", "Le sable se fend", "Der Sand bricht", "砂がひび割れる", "모래가 갈라진다", "沙地开裂"),
    "BOSS_HOLLOW_SHADE_TITLE": L("Silence given shape", "El silencio hecho forma", "O silêncio com forma", "Le silence fait forme", "Gestalt gewordene Stille", "形を得た沈黙", "형체를 얻은 침묵", "化形之寂"),
    "BOSS_HOLLOW_SHADE_P2": L("The hush deepens", "El silencio se ahonda", "O silêncio se aprofunda", "Le silence s'épaissit", "Die Stille vertieft sich", "静けさが深まる", "침묵이 깊어진다", "寂静愈深"),
}

# --- Emergent world events --------------------------------------------------------------------------------

EVENTS = [
    {"id": "traveler_attacked", "name_key": "EVENT_TRAVELER", "chance_per_hour": 0.22, "regions": ["valley", "forest", "lakeshore", "coast"],
     "distance": [45, 70], "period": "any",
     "encounter": {"mode": "protect", "actor": "NPC_TRAVELER", "actor_hp": 90, "shout_key": "SHOUT_HELP", "trigger_radius": 26, "element": "thorn",
                   "waves": [{"entity": "ENEMY_THORNLING", "count": 3, "dist": 12}],
                   "end_lines": ["DLG_TRAVELER_THANKS"], "reward": {"glimmer": 25, "items": [{"id": "sunpear", "count": 2}]}}},
    {"id": "nomad_raid", "name_key": "EVENT_NOMAD_RAID", "chance_per_hour": 0.2, "regions": ["desert"],
     "distance": [45, 70], "period": "any",
     "encounter": {"mode": "protect", "actor": "NPC_TRAVELER", "actor_hp": 110, "shout_key": "SHOUT_HELP", "trigger_radius": 26, "element": "sand",
                   "waves": [{"entity": "ENEMY_SCUTTLER", "count": 3, "dist": 12}, {"entity": "ENEMY_SCUTTLER", "count": 2, "dist": 14}],
                   "end_lines": ["DLG_TRAVELER_THANKS"], "reward": {"glimmer": 35, "items": [{"id": "cooling_salad", "count": 1}]}}},
    {"id": "elite_patrol", "name_key": "EVENT_ELITE_PATROL", "chance_per_hour": 0.14, "regions": ["valley", "highlands", "forest"],
     "distance": [70, 100], "spawn": "ENEMY_BULWARK", "escort": "ENEMY_THORNLING", "count": [2, 3], "alert": False, "period": "day"},
    {"id": "gilded_hop", "name_key": "EVENT_GILDED_HOP", "chance_per_hour": 0.3, "regions": ["valley", "lakeshore", "forest"],
     "distance": [40, 80], "rare": "ANIMAL_GILDED_HOP", "hours": [5.0, 7.5, 18.0, 20.0]},
    {"id": "wisp_lights", "name_key": "EVENT_WISP_LIGHTS", "chance_per_hour": 0.2, "regions": ["forest", "lakeshore", "veil"],
     "distance": [70, 130], "duration_hours": 2.0, "period": "night", "reward": {"items": [{"id": "wisp_filament", "count": [2, 3]}, {"id": "glowmoss", "count": [1, 2]}]}},
    {"id": "storm_glass", "name_key": "EVENT_STORM_GLASS", "chance_per_hour": 0.35, "regions": ["desert", "highlands", "coast"],
     "distance": [70, 140], "duration_hours": 2.0, "weather": ["storm", "sandstorm"], "reward": {"items": [{"id": "glass_shard", "count": [1, 2]}, {"id": "glimmer_shard", "count": [3, 6]}]}},
]

EVENT_LOC = {
    "EVENT_TRAVELER": L("A cry on the road", "Un grito en el camino", "Um grito na estrada", "Un cri sur la route", "Ein Schrei auf dem Weg", "道に悲鳴", "길 위의 비명", "路上的呼救"),
    "EVENT_NOMAD_RAID": L("Raiders in the dunes", "Asaltantes en las dunas", "Saqueadores nas dunas", "Pillards dans les dunes", "Räuber in den Dünen", "砂丘の襲撃", "모래언덕의 습격", "沙丘劫掠"),
    "EVENT_ELITE_PATROL": L("Something heavy walks nearby", "Algo pesado camina cerca", "Algo pesado anda por perto", "Quelque chose de lourd rôde", "Etwas Schweres geht umher", "重い足音が近くを行く", "무거운 무언가가 근처를 걷는다", "附近有沉重的脚步"),
    "EVENT_GILDED_HOP": L("A glint of gold in the grass", "Un destello dorado en la hierba", "Um brilho dourado na grama", "Un éclat doré dans l'herbe", "Ein Goldschimmer im Gras", "草むらに金の輝き", "풀숲에 황금빛", "草丛里一闪金光"),
    "EVENT_WISP_LIGHTS": L("Lights drift between the trees", "Luces flotan entre los árboles", "Luzes flutuam entre as árvores", "Des lueurs flottent entre les arbres", "Lichter treiben zwischen den Bäumen", "木々の間を灯りが漂う", "나무 사이로 빛이 떠돈다", "林间灯火飘荡"),
    "EVENT_STORM_GLASS": L("Lightning fused the ground", "Un rayo fundió el suelo", "Um raio fundiu o chão", "La foudre a fondu le sol", "Ein Blitz schmolz den Boden", "雷が地面を溶かした", "번개가 땅을 녹였다", "雷电熔化了地面"),
    "DLG_TRAVELER_THANKS": L("You came out of nowhere! Take this, please.", "¡Apareciste de la nada! Toma esto, por favor.", "Você surgiu do nada! Tome isto, por favor.", "Vous êtes sorti de nulle part ! Prenez ceci.", "Du kamst aus dem Nichts! Nimm das, bitte.", "どこからともなく！これを受け取って。", "어디서 나타난 거야! 이거 받아.", "你从天而降！请收下这个。"),
}

# --- Extra names ---------------------------------------------------------------------------------------------
EXTRA_LOC = {
    "NAME_VILLAGER": L("Pell, goatherd", "Pell, cabrero", "Pell, cabreiro", "Pell, chevrier", "Pell, Ziegenhirt", "山羊飼いペル", "염소치기 펠", "牧羊人佩尔"),
    "PROMPT_BEACON_LIT": L("A Warden beacon", "Una baliza del Guardián", "Um farol do Guardião", "Un fanal du Gardien", "Ein Hüterfeuer", "守り人の灯台", "지기의 봉화", "守风者烽火"),
    "TOAST_BEACON_LIT": L("The beacon burns. The wind stirs.", "La baliza arde. El viento se agita.", "O farol arde. O vento se agita.", "Le fanal brûle. Le vent s'éveille.", "Das Leuchtfeuer brennt. Der Wind regt sich.", "灯台が燃える。風が動き出す。", "봉화가 타오른다. 바람이 일렁인다.", "烽火燃起，风开始流动。"),
}


def color_check(all_entities, new_ids=None, limit=45.0):
    """Unique, clearly distinct solid colour per species (RGB distance).
    Only pairs involving new species are checked: existing placeholder
    colours are the user's and are never changed here."""
    def rgb(h):
        h = h.lstrip("#")
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    ents = [(e["id"], rgb(e["placeholder_color"])) for e in all_entities]
    bad = []
    for i in range(len(ents)):
        for j in range(i + 1, len(ents)):
            a, b = ents[i][1], ents[j][1]
            if new_ids is not None and ents[i][0] not in new_ids and ents[j][0] not in new_ids:
                continue
            d = sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5
            if d < limit:
                bad.append("%s %s %.0f" % (ents[i][0], ents[j][0], d))
    return bad

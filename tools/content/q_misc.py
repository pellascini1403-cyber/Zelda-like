"""Island-wide goals: Tamsin's survey, the cookbook, wind shrines, the
windstrider, wind chimes scattered everywhere and a flower that blooms
only at night."""
from qdsl import L, T, quest, stage, obj

QUESTS = []
Q = QUESTS.append

Q(quest("sq_tamsin_survey", "side", "exploration", "any", 2, "long",
    L("Tamsin's Survey", "El levantamiento de Tamsin", "O levantamento de Tamsin", "Le relevé de Tamsin", "Tamsins Vermessung", "タムシンの測量", "탐신의 측량", "塔姆辛的测绘"),
    L("Tamsin's map has holes. Stand in six far places so she can fill them in.", "El mapa de Tamsin tiene huecos. Visita seis lugares lejanos para que los complete.", "O mapa de Tamsin tem buracos. Visite seis lugares distantes para ela completar.", "La carte de Tamsin a des trous. Rendez-vous en six lieux lointains pour qu'elle les comble.", "Tamsins Karte hat Lücken. Besuche sechs ferne Orte, damit sie sie füllen kann.", "タムシンの地図は穴だらけ。遠い六か所に立って埋めてほしい。", "탐신의 지도엔 구멍이 있다. 먼 곳 여섯에 가서 채우게 해 줘.", "塔姆辛的地图有空白。去六个远处，让她补全。"),
    [stage(obj("discover", "needles", T("QO_T_FIND", "POI_NEEDLES")),
           obj("discover", "elder_tree", T("QO_T_FIND", "POI_ELDER_TREE")),
           obj("discover", "jade_bridge", T("QO_T_FIND", "POI_JADE_BRIDGE")),
           obj("discover", "broken_tower", T("QO_T_FIND", "POI_BROKEN_TOWER")),
           obj("discover", "dawn_wreck", T("QO_T_FIND", "POI_DAWN_WRECK")),
           obj("discover", "moss_crypt", T("QO_T_FIND", "POI_MOSS_CRYPT"))),
     stage(obj("talk", "NPC_CARTOGRAPHER", T("QO_T_RETURN", "NAME_CARTOGRAPHER")),
           talk=[L("Look at it now! Take a copy — the whole island, as far as we know it.", "¡Míralo ahora! Toma una copia: toda la isla, hasta donde sabemos.", "Olhe agora! Leve uma cópia: a ilha inteira, até onde sabemos.", "Regardez-la ! Prenez une copie : toute l'île, pour ce qu'on en sait.", "Sieh sie dir an! Nimm eine Abschrift — die ganze Insel, soweit wir sie kennen.", "見て！写しをあげる。分かる限りの島全部よ。", "이제 봐! 사본을 가져가, 우리가 아는 섬 전부야.", "你看！拿份副本去，我们所知的整座岛。")])],
    {"jade": 2, "glimmer": 60, "reveal": [{"pos": [0, 0], "radius": 20}]},
    start="talk:NPC_CARTOGRAPHER", requires=["mq_echoes"],
    offer_lines=[L("My map's full of blank patches. Six places — go stand in them and I'll do the rest.", "Mi mapa está lleno de huecos. Seis lugares: ve a pisarlos y yo hago el resto.", "Meu mapa está cheio de buracos. Seis lugares: vá até eles e eu faço o resto.", "Ma carte est pleine de blancs. Six lieux — allez-y, je fais le reste.", "Meine Karte hat weiße Flecken. Sechs Orte — geh hin, den Rest mache ich.", "地図が空白だらけ。六か所に行ってくれれば、あとは私が。", "지도에 빈칸투성이야. 여섯 곳, 가서 서 있어 주면 나머진 내가.", "我的地图全是空白。六个地方，你去站一站，剩下的交给我。")]))

Q(quest("sq_cookbook", "side", "crafting", "any", 2, "long",
    L("The Traveller's Cookbook", "El recetario del viajero", "O livro de receitas do viajante", "Le carnet de cuisine du voyageur", "Das Kochbuch des Reisenden", "旅人の料理帳", "여행자의 요리책", "旅人食谱"),
    L("Brask pays for proven recipes. Cook five different dishes and tell him how.", "Brask paga por recetas probadas. Cocina cinco platos distintos y cuéntale cómo.", "Brask paga por receitas testadas. Cozinhe cinco pratos diferentes e conte como.", "Brask paie les recettes éprouvées. Cuisinez cinq plats différents et expliquez-lui.", "Brask zahlt für erprobte Rezepte. Koche fünf verschiedene Gerichte und erzähl ihm wie.", "ブラスクは確かな料理法に金を払う。違う料理を五つ作って伝えよう。", "브라스크는 검증된 요리법에 돈을 낸다. 다른 요리 다섯을 만들어 알려 줘.", "布拉斯克收购可靠的食谱。做五道不同的菜，教给他。"),
    [stage(obj("cook", "hearty_stew", T("QO_T_COOK", "ITEM_HEARTY_STEW")),
           obj("cook", "vigor_broth", T("QO_T_COOK", "ITEM_VIGOR_BROTH")),
           obj("cook", "warming_curry", T("QO_T_COOK", "ITEM_WARMING_CURRY")),
           obj("cook", "cooling_salad", T("QO_T_COOK", "ITEM_COOLING_SALAD")),
           obj("cook", "fierce_skewer", T("QO_T_COOK", "ITEM_FIERCE_SKEWER"))),
     stage(obj("talk", "NPC_MERCHANT", T("QO_T_RETURN", "NAME_MERCHANT")),
           talk=[L("Five dishes! Here's the one recipe I never share: honey-pear tart.", "¡Cinco platos! Aquí va la receta que nunca comparto: tarta de miel y pera.", "Cinco pratos! Eis a receita que nunca divido: torta de mel e pera.", "Cinq plats ! Voici la recette que je ne partage jamais : la tarte miel-poire.", "Fünf Gerichte! Hier das Rezept, das ich nie teile: Honigbirnentarte.", "五品も！誰にも教えない秘伝をやる。蜂蜜梨のタルトだ。", "요리 다섯! 절대 안 알려 주는 비법이야. 꿀배 타르트.", "五道菜！我从不外传的方子给你：蜜梨挞。")])],
    {"recipes": [["honeycomb", "sunpear", "sunpear"]], "items": [{"id": "honey_pear_tart", "count": 1}], "jade": 2, "glimmer": 50},
    start="talk:NPC_MERCHANT", requires=["sq_mushroom_stew"],
    offer_lines=[L("I'll buy recipes that work. Five different dishes — cook them, then come tell me.", "Compro recetas que funcionan. Cinco platos distintos: cocínalos y ven a contármelo.", "Compro receitas que funcionam. Cinco pratos diferentes: cozinhe e venha contar.", "J'achète les recettes qui marchent. Cinq plats différents : cuisinez-les, puis racontez-moi.", "Ich kaufe Rezepte, die klappen. Fünf verschiedene Gerichte — koch sie, dann erzähl mir.", "使える料理法なら買う。違う料理を五つ作ったら教えに来てくれ。", "쓸 만한 요리법은 사지. 다른 요리 다섯, 만들고 와서 알려 줘.", "管用的菜谱我收。做五道不同的菜，再来讲给我听。")]))

Q(quest("sq_ribbons", "side", "exploration", "valley", 2, "medium", "QUEST_RIBBONS", "QUEST_RIBBONS_DESC",
    [stage(obj("discover", "wayside_shrine", "QO_SHRINE_WAYSIDE"),
           obj("discover", "heath_shrine", "QO_SHRINE_HEATH"),
           obj("discover", "jade_bridge", "QO_JADE_BRIDGE"))],
    {"items": [{"id": "stamina_bloom", "count": 1}], "glimmer": 25, "ability": "wind_sight"},
    start="event"))

Q(quest("sq_windstrider", "side", "traversal", "valley", 2, "short", "QUEST_WINDSTRIDER", "QUEST_WINDSTRIDER_DESC",
    [stage(obj("mount", "windstrider", "QO_TAME_STRIDER", marker=[260, 110]), hint_lines=["DLG_SQ_STRIDER_HINT"])],
    {"ability": "strider_call", "glimmer": 20},
    start="talk:NPC_CARTOGRAPHER", requires=["mq_vela"], offer_lines=["DLG_SQ_STRIDER_OFFER_1", "DLG_SQ_STRIDER_OFFER_2"]))

CHIMES = L("wind chimes", "campanillas de viento", "sinos de vento", "carillons à vent", "Windspiele", "風鈴", "풍경", "风铃")
Q(quest("dq_wind_chimes", "discovery", "exploration", "any", 3, "long",
    L("Chimes on the Wind", "Campanillas al viento", "Sinos ao vento", "Carillons dans le vent", "Windspiele im Wind", "風に鳴る鈴", "바람의 풍경", "风中铃"),
    L("Old Warden chimes hang in odd corners of the island. Ring every one and the wind will remember you.", "Viejas campanillas de los Guardianes cuelgan en rincones de la isla. Tócalas todas y el viento te recordará.", "Velhos sinos dos Guardiões pendem em cantos da ilha. Toque todos e o vento se lembrará de você.", "De vieux carillons des Gardiens pendent aux quatre coins de l'île. Faites-les tous sonner et le vent se souviendra de vous.", "Alte Hüterwindspiele hängen in Winkeln der Insel. Läute jedes, und der Wind wird sich an dich erinnern.", "島のあちこちに守り人の古い風鈴が。すべて鳴らせば風が覚えてくれる。", "섬 곳곳에 지기의 오래된 풍경이 걸려 있다. 모두 울리면 바람이 널 기억한다.", "岛上各处角落挂着守风者的旧风铃。全部敲响，风就会记住你。"),
    [stage(obj("interact", "group:chimes", T("QO_T_RING", CHIMES), count=8, hint="none"))],
    {"cosmetic": "ribbon_jade", "jade": 3, "glimmer": 50},
    start="event",
    spawns=[{"kind": "object", "id": "chime_%d" % i, "group": "chimes", "look": "chime", "pos": p, "when": "open", "prompt": "PROMPT_RING", "sound": "chime", "element": "wind", "hide_used": False,
             "reward": {"glimmer": 10}}
            for i, p in enumerate([[-40, 140], [180, 200], [230, 280], [440, 300], [-200, 20], [-60, -200], [320, -100], [-250, -200]])]))

BLOOM = L("the moon bloom", "la flor de luna", "a flor da lua", "la fleur de lune", "die Mondblüte", "月の花", "달꽃", "月华花")
Q(quest("dq_night_bloom", "discovery", "exploration", "highlands", 2, "short",
    L("Night Bloom", "Flor nocturna", "Flor noturna", "Fleur de nuit", "Nachtblüte", "夜の花", "밤꽃", "夜之花"),
    L("By the falls pool, a flower opens only under the moon. Its petals hold a little of the sky.", "Junto a la poza de la cascada, una flor se abre solo bajo la luna. Sus pétalos guardan un poco de cielo.", "Junto ao poço da cascata, uma flor só abre sob a lua. As pétalas guardam um pouco do céu.", "Près de la vasque des chutes, une fleur ne s'ouvre qu'à la lune. Ses pétales gardent un peu de ciel.", "Am Fallbecken öffnet sich eine Blume nur unterm Mond. Ihre Blätter halten ein Stück Himmel.", "滝壺のそば、月の下でだけ開く花。花びらに空が少し宿る。", "폭포 웅덩이 곁, 달 아래서만 피는 꽃. 꽃잎에 하늘이 조금 담겼다.", "瀑布潭边有朵只在月下开放的花，花瓣里盛着一点天空。"),
    [stage(obj("retrieve", "moon_bloom", T("QO_T_TAKE", BLOOM), hint="none"))],
    {"items": [{"id": "stamina_bloom", "count": 1}], "jade": 1},
    start="interact:moon_bloom",
    spawns=[{"kind": "object", "id": "moon_bloom", "look": "flower", "pos": [124, 64.4, -379], "when": "available", "conditions": {"period": "night"}, "prompt": "PROMPT_TAKE", "element": "jade", "range": 160}]))

"""Heath valley and hamlet: short, varied tales around home."""
from qdsl import L, T, quest, stage, obj

QUESTS = []
Q = QUESTS.append

KITE = L("Lio's kite", "la cometa de Lio", "a pipa do Lio", "le cerf-volant de Lio", "Lios Drachen", "リオの凧", "리오의 연", "小里奥的风筝")

Q(quest("sq_lost_kite", "side", "traversal", "valley", 1, "short",
    L("The Kite on the Lookout", "La cometa de la atalaya", "A pipa no mirante", "Le cerf-volant du guet", "Der Drachen auf der Warte", "物見台の凧", "망루의 연", "望楼上的风筝"),
    L("Lio's kite snagged on the lookout roof. Nobody else dares climb.", "La cometa de Lio se enganchó en el tejado de la atalaya. Nadie se atreve a subir.", "A pipa do Lio prendeu no telhado do mirante. Ninguém ousa subir.", "Le cerf-volant de Lio s'est pris au toit du guet. Personne n'ose grimper.", "Lios Drachen hängt am Dach der Warte. Keiner traut sich hinauf.", "リオの凧が物見台の屋根に引っかかった。誰も登れない。", "리오의 연이 망루 지붕에 걸렸다. 아무도 못 올라간다.", "小里奥的风筝挂在望楼顶上，没人敢爬。"),
    [stage(obj("retrieve", "lio_kite", T("QO_T_TAKE", KITE), marker=[-15, 210]),
           spawns=[{"kind": "object", "id": "lio_kite", "look": "kite", "poi": "hamlet_lookout", "pos": [0.9, 0.7], "snap": "top", "min_y": 28.0, "item": "lios_kite", "prompt": "PROMPT_TAKE", "range": 200}]),
     stage(obj("deliver", "NPC_CHILD", T("QO_T_GIVE", KITE, "NAME_CHILD"), item="lios_kite"),
           talk=[L("You flew it back?! Take my ribbons — they're lucky. I'll make more.", "¡¿La trajiste volando?! Toma mis cintas, dan suerte. Haré más.", "Você trouxe voando?! Fique com minhas fitas, dão sorte. Faço mais.", "Tu l'as rapporté en volant ?! Prends mes rubans, ils portent chance.", "Du hast ihn zurückgeflogen?! Nimm meine Bänder, die bringen Glück.", "飛んで持ってきたの！？リボンあげる、幸運のだよ。", "날아서 가져왔어?! 내 리본 줄게, 행운의 리본이야.", "你飞回来的？！我的彩带给你，会带来好运。")])],
    {"cosmetic": "ribbon_dawn", "glimmer": 15},
    start="talk:NPC_CHILD", requires=["mq_vela"],
    offer_lines=[L("My kite's stuck on the lookout! Can you get it? You've got the Vela!", "¡Mi cometa está atascada en la atalaya! ¿Puedes bajarla? ¡Tienes la Vela!", "Minha pipa prendeu no mirante! Pega pra mim? Você tem a Vela!", "Mon cerf-volant est coincé sur le guet ! Tu peux l'attraper ? Tu as la Vela !", "Mein Drachen hängt auf der Warte! Holst du ihn? Du hast doch die Vela!", "凧が物見台に！取ってくれる？ヴェラがあるでしょ！", "연이 망루에 걸렸어! 가져다줄래? 벨라 있잖아!", "我的风筝挂在望楼上！帮我拿下来？你有风帆呀！")]))

Q(quest("sq_mushroom_stew", "side", "gathering", "valley", 1, "short", "QUEST_MUSHROOM", "QUEST_MUSHROOM_DESC",
    [stage(obj("collect", "cap_mushroom", "QO_COLLECT_MUSHROOMS", count=5), hint_lines=["DLG_SQ_MUSH_HINT"]),
     stage(obj("talk", "NPC_MERCHANT", "QO_RETURN_MERCHANT"), talk_lines=["DLG_SQ_MUSH_DONE"])],
    {"glimmer": 40, "items": [{"id": "hearty_stew", "count": 2}]},
    start="talk:NPC_MERCHANT", requires=["mq_thorn_road"], offer_lines=["DLG_SQ_MUSH_OFFER_1", "DLG_SQ_MUSH_OFFER_2"]))

Q(quest("sq_thorn_cull", "side", "combat", "valley", 2, "short", "QUEST_THORN_CULL", "QUEST_THORN_CULL_DESC",
    [stage(obj("kill", "ENEMY_THORNLING", "QO_KILL_THORNLINGS", count=5, marker=[-150, 420], hint="area", area_radius=120.0), hint_lines=["DLG_SQ_THORN_HINT"]),
     stage(obj("talk", "NPC_VILLAGER", "QO_RETURN_VILLAGER"), talk_lines=["DLG_SQ_THORN_DONE"])],
    {"glimmer": 30, "items": [{"id": "fur_cap", "count": 1}, {"id": "whetstone", "count": 2}]},
    start="talk:NPC_VILLAGER", offer_lines=["DLG_SQ_THORN_OFFER_1", "DLG_SQ_THORN_OFFER_2"]))

Q(quest("sq_smith_ore", "side", "crafting", "valley", 2, "medium",
    L("Ore for the Forge", "Mineral para la forja", "Minério para a forja", "Du minerai pour la forge", "Erz für die Esse", "炉のための鉱石", "화로를 위한 광석", "炉中之矿"),
    L("Hadda's forge is cold. Iron from the old quarry, smelted at any campfire, would warm it.", "La forja de Hadda está fría. Hierro de la cantera vieja, fundido en cualquier hoguera, la calentaría.", "A forja de Hadda está fria. Ferro da pedreira velha, fundido em qualquer fogueira, a esquentaria.", "La forge de Hadda est froide. Du fer de la vieille carrière, fondu à un feu de camp, la réchaufferait.", "Haddas Esse ist kalt. Eisen aus dem alten Steinbruch, an einem Lagerfeuer geschmolzen, würde sie wärmen.", "ハッダの炉が冷えた。古い石切り場の鉄を焚き火で溶かせば温まる。", "하다의 화로가 식었다. 옛 채석장의 철을 모닥불에 녹이면 된다.", "哈达的炉子冷了。旧采石场的铁在营火上熔了就能生火。"),
    [stage(obj("gather", "iron_vein", T("QO_T_GATHER", L("iron veins", "vetas de hierro", "veios de ferro", "filons de fer", "Eisenadern", "鉄の鉱脈", "철광맥", "铁矿脉")), count=3, marker=[-330, -300], hint="area", area_radius=60.0)),
     stage(obj("craft", "iron_ingot", T("QO_T_CRAFT", "ITEM_IRON_INGOT"))),
     stage(obj("deliver", "NPC_SMITH", T("QO_T_GIVE", "ITEM_IRON_INGOT", "NAME_SMITH"), item="iron_ingot"),
           talk=[L("Good iron. Here — a blade from my last batch. And come back if you find a storm.", "Buen hierro. Toma, una hoja de mi última hornada. Y vuelve si encuentras una tormenta.", "Bom ferro. Tome, uma lâmina do último lote. E volte se achar uma tempestade.", "Bon fer. Tenez, une lame de ma dernière fournée. Revenez si vous trouvez un orage.", "Gutes Eisen. Hier, eine Klinge aus meiner letzten Charge. Komm wieder, wenn's stürmt.", "いい鉄だ。最後に打った刃をやる。嵐が来たらまた来な。", "좋은 철이야. 마지막으로 벼린 칼이다. 폭풍이 오면 다시 와.", "好铁。拿着，上一炉打的刀。遇到雷暴再来找我。")])],
    {"items": [{"id": "quarry_saber", "count": 1}], "glimmer": 30, "jade": 1},
    start="talk:NPC_SMITH", requires=["mq_thorn_road"],
    offer_lines=[L("Cold forge, cold smith. Iron from the old quarry would fix both.", "Forja fría, herrera fría. Hierro de la cantera vieja arreglaría ambas.", "Forja fria, ferreira fria. Ferro da pedreira velha resolveria as duas.", "Forge froide, forgeronne froide. Du fer de la carrière arrangerait tout.", "Kalte Esse, kalte Schmiedin. Eisen aus dem Steinbruch hilft beiden.", "冷えた炉に冷えた鍛冶屋。石切り場の鉄があればどっちも直る。", "식은 화로, 식은 대장장이. 채석장 철이면 둘 다 해결이지.", "炉冷，人也冷。旧采石场的铁能治好两样。")]))

Q(quest("sq_arsenal", "side", "crafting", "valley", 2, "medium",
    L("The Smith's Test", "La prueba de la herrera", "O teste da ferreira", "L'épreuve de la forgeronne", "Die Probe der Schmiedin", "鍛冶屋の試し", "대장장이의 시험", "铁匠的考验"),
    L("Hadda wants proof you can make your own tools before she teaches you more.", "Hadda quiere pruebas de que sabes fabricar tus herramientas antes de enseñarte más.", "Hadda quer provas de que você sabe fazer suas ferramentas antes de ensinar mais.", "Hadda veut la preuve que vous savez fabriquer vos outils avant d'aller plus loin.", "Hadda will sehen, dass du eigene Werkzeuge baust, bevor sie mehr lehrt.", "ハッダは教える前に、自分で道具を作れる証を見たい。", "하다는 더 가르치기 전에 네가 도구를 만들 줄 아는지 보고 싶어 한다.", "哈达要你先证明会自己做工具，才肯多教。"),
    [stage(obj("craft", "whetstone", T("QO_T_CRAFT", "ITEM_WHETSTONE")),
           obj("craft", "resin_bomb", T("QO_T_CRAFT", "ITEM_RESIN_BOMB")),
           obj("craft", "fur_cap", T("QO_T_CRAFT", "ITEM_FUR_CAP"))),
     stage(obj("talk", "NPC_SMITH", T("QO_T_RETURN", "NAME_SMITH")),
           talk=[L("Clumsy stitching, honest work. Take a forge stone — it fixes what whetstones can't.", "Costura torpe, trabajo honrado. Toma una piedra de forja: arregla lo que las piedras de afilar no.", "Costura torta, trabalho honesto. Tome uma pedra de forja: conserta o que a pedra de amolar não.", "Couture maladroite, travail honnête. Prenez une pierre de forge : elle répare ce que la queue ne peut.", "Krumme Naht, ehrliche Arbeit. Nimm einen Essenstein — er flickt, was Wetzsteine nicht schaffen.", "縫い目は下手だが正直な仕事だ。炉石をやる。砥石で直らんものも直る。", "바느질은 서툴지만 정직한 솜씨야. 대장돌을 가져가. 숫돌로 못 고치는 걸 고친다.", "针脚笨拙，但活儿实在。拿块锻石，磨刀石修不好的它能修。")])],
    {"items": [{"id": "forge_stone", "count": 1}], "jade": 1},
    start="talk:NPC_SMITH", requires=["sq_smith_ore"],
    offer_lines=[L("Make me a whetstone, a resin bomb and a fur cap. Then we'll talk.", "Hazme una piedra de afilar, una bomba de resina y un gorro de piel. Luego hablamos.", "Faça uma pedra de amolar, uma bomba de resina e um gorro de pele. Aí conversamos.", "Faites-moi une queue à aiguiser, une bombe de résine et un bonnet de fourrure. Ensuite on parle.", "Mach mir einen Wetzstein, eine Harzbombe und eine Pelzmütze. Dann reden wir.", "砥石と樹脂爆弾と毛皮帽を作ってみな。話はそれからだ。", "숫돌, 수지 폭탄, 털모자를 만들어 와. 그다음 얘기하자.", "给我做块磨刀石、一颗树脂炸弹、一顶毛皮帽，再来说话。")]))

Q(quest("sq_night_lanterns", "side", "puzzle", "valley", 1, "short",
    L("Lanterns for the Night Fair", "Faroles para la feria nocturna", "Lanternas para a feira noturna", "Lanternes pour la foire de nuit", "Laternen für den Nachtmarkt", "夜市の灯籠", "야시장의 등불", "夜市灯笼"),
    L("Pell wants the four hamlet braziers lit for the night fair. Only after dark, mind.", "Pell quiere encender los cuatro braseros de la aldea para la feria nocturna. Solo al anochecer.", "Pell quer os quatro braseiros da aldeia acesos para a feira noturna. Só depois de escurecer.", "Pell veut les quatre braseros du hameau allumés pour la foire de nuit. Une fois la nuit tombée.", "Pell will die vier Dorfbecken für den Nachtmarkt entzündet haben. Erst nach Einbruch der Dunkelheit.", "ペルは夜市のために村の四つの火鉢を灯してほしい。日が暮れてから。", "펠은 야시장을 위해 마을 화로 넷을 밝히고 싶어 한다. 해가 진 뒤에.", "佩尔想为夜市点亮村里四个火盆，要等天黑。"),
    [stage(obj("puzzle", "hamlet_lanterns", T("QO_T_NIGHT", L("Light the four fair braziers", "Enciende los cuatro braseros de la feria", "Acenda os quatro braseiros da feira", "Allumez les quatre braseros de la foire", "Entzünde die vier Marktbecken", "市の四つの火鉢を灯す", "장터 화로 넷을 밝히기", "点亮夜市四个火盆")), marker=[60, 150], hint="area", area_radius=40.0),
           spawns=[{"kind": "puzzle", "id": "hamlet_lanterns", "pos": [60, 150], "conditions": {"period": "night"},
                    "elements": [{"type": "brazier", "at": [26, 0]}, {"type": "brazier", "at": [-26, 4]}, {"type": "brazier", "at": [2, 27]}, {"type": "brazier", "at": [-2, -29]}]}]),
     stage(obj("talk", "NPC_VILLAGER", T("QO_T_RETURN", "NAME_VILLAGER")),
           talk=[L("Look at that glow! Here, a little flame of your own for that blade.", "¡Mira ese brillo! Toma, una llamita para tu arma.", "Olha esse brilho! Tome, uma chaminha para sua lâmina.", "Regardez cette lueur ! Tenez, une petite flamme pour votre lame.", "Sieh dir das Leuchten an! Hier, eine kleine Flamme für deine Klinge.", "いい灯りだ！お礼に、刃に小さな炎を。", "저 빛 좀 봐! 네 칼에 작은 불꽃을 줄게.", "瞧这光！送你一簇小火苗，配你的刀。")])],
    {"cosmetic": "trail_ember", "glimmer": 20},
    start="talk:NPC_VILLAGER", requires=["sq_thorn_cull"],
    offer_lines=[L("Night fair tonight, and nobody's lit the braziers. Flint or flame, either works.", "Esta noche hay feria y nadie encendió los braseros. Pedernal o llama, lo que sea.", "Feira hoje à noite e ninguém acendeu os braseiros. Pederneira ou chama, tanto faz.", "Foire ce soir et personne n'a allumé les braseros. Silex ou flamme, peu importe.", "Heute Nachtmarkt, und keiner hat die Becken entzündet. Feuerstein oder Flamme, egal.", "今夜は夜市なのに誰も火鉢を灯してない。火打ち石でも火でもいい。", "오늘 밤 야시장인데 아무도 화로를 안 켰어. 부싯돌이든 불이든.", "今晚有夜市，火盆却没人点。燧石或火都行。")]))

Q(quest("sq_strays", "side", "npc", "valley", 1, "medium",
    L("Strays", "Descarriadas", "Desgarradas", "Égarées", "Ausreißer", "迷い羊", "길 잃은 녀석들", "走失的羊"),
    L("Three of Pell's woolhorns bolted in the storm. Find them and calm them; they know the way home.", "Tres cabras lanudas de Pell huyeron con la tormenta. Encuéntralas y cálmalas: saben volver.", "Três cabras-lã de Pell fugiram na tempestade. Encontre e acalme; elas sabem voltar.", "Trois cornelaines de Pell ont fui pendant l'orage. Trouvez-les et calmez-les : elles connaissent le chemin.", "Drei von Pells Wollhörnern flohen im Sturm. Finde und beruhige sie; sie kennen den Heimweg.", "嵐でペルの毛角が三頭逃げた。見つけてなだめれば、自分で帰る。", "폭풍에 펠의 털뿔 셋이 달아났다. 찾아서 달래면 집으로 간다.", "佩尔的三头绒角兽在暴风雨中跑散了。找到它们、安抚好，它们认得路。"),
    [stage(obj("interact", "group:strays", T("QO_T_FIND", L("the strays", "las descarriadas", "as desgarradas", "les égarées", "die Ausreißer", "迷い羊", "길 잃은 녀석들", "走失的羊")), count=3, hint="area", area_radius=150.0, marker=[20, 230]),
           spawns=[{"kind": "actor", "entity": "ANIMAL_WOOLHORN", "pos": [-100, 160], "yaw": 40, "talk": {"id": "stray_a", "group": "strays", "prompt": "PROMPT_CALM", "then_path": [[-30, 165], [40, 170]]}},
                   {"kind": "actor", "entity": "ANIMAL_WOOLHORN", "pos": [-180, 235], "yaw": 120, "talk": {"id": "stray_b", "group": "strays", "prompt": "PROMPT_CALM", "then_path": [[-100, 200], [40, 170]]}},
                   {"kind": "actor", "entity": "ANIMAL_WOOLHORN", "pos": [170, 305], "yaw": 250, "talk": {"id": "stray_c", "group": "strays", "prompt": "PROMPT_CALM", "then_path": [[110, 240], [60, 175]]}}]),
     stage(obj("talk", "NPC_VILLAGER", T("QO_T_RETURN", "NAME_VILLAGER")),
           talk=[L("All three home and grumbling. Take this wrap — spun from their own wool.", "Las tres en casa y refunfuñando. Toma este abrigo, tejido con su lana.", "As três em casa, resmungando. Tome este agasalho, tecido com a lã delas.", "Les trois rentrées en grognant. Prenez ce châle, filé de leur laine.", "Alle drei daheim und am Murren. Nimm den Umhang — aus ihrer eigenen Wolle.", "三頭とも戻ってぶつぶつ言ってる。この外套を、あいつらの毛で編んだ。", "셋 다 돌아와 투덜대. 이 망토를 가져가, 걔들 털로 짰어.", "三头都回来了，还在嘟囔。拿着这件披风，用它们的毛织的。")])],
    {"items": [{"id": "woolen_wrap", "count": 1}], "glimmer": 25},
    start="talk:NPC_VILLAGER", requires=["sq_night_lanterns"],
    offer_lines=[L("Three of my woolhorns ran off in the storm. West fields, the river, the shrine road...", "Tres de mis cabras lanudas huyeron con la tormenta. Campos del oeste, el río, el camino del santuario...", "Três cabras-lã fugiram na tempestade. Campos a oeste, o rio, a estrada do santuário...", "Trois de mes cornelaines ont fui. Champs de l'ouest, la rivière, la route du sanctuaire...", "Drei Wollhörner sind im Sturm weg. Westfelder, der Fluss, der Schreinweg...", "嵐で毛角が三頭逃げた。西の畑、川、祠への道…", "폭풍에 털뿔 셋이 달아났어. 서쪽 밭, 강, 사당 길…", "三头绒角兽跑了。西边田里、河边、神祠路上……")]))

CLUE = L("Wayfarer's sign", "Señal del caminante", "Sinal do andarilho", "Signe du voyageur", "Wanderzeichen", "旅人の印", "나그네의 표식", "旅人记号")
Q(quest("dq_wayfarer_trail", "discovery", "exploration", "valley", 2, "medium",
    L("The Wayfarer's Trail", "El rastro del caminante", "A trilha do andarilho", "La piste du voyageur", "Die Spur des Wanderers", "旅人の足跡", "나그네의 흔적", "旅人的足迹"),
    L("Scratched signs lead from stone to stone. Someone hid something and wanted it found.", "Señales grabadas llevan de piedra en piedra. Alguien escondió algo y quería que se encontrara.", "Sinais riscados levam de pedra em pedra. Alguém escondeu algo e queria que fosse achado.", "Des signes gravés mènent de pierre en pierre. Quelqu'un a caché quelque chose, pour qu'on le trouve.", "Eingeritzte Zeichen führen von Stein zu Stein. Jemand versteckte etwas, um es finden zu lassen.", "刻まれた印が石から石へ。誰かが見つけてほしくて何かを隠した。", "새겨진 표식이 돌에서 돌로 이어진다. 누군가 찾아 주길 바라며 숨겼다.", "刻痕一石接一石。有人藏了东西，想让人找到。"),
    [stage(obj("interact", "wayfarer_1", T("QO_T_EXAMINE", CLUE))),
     stage(obj("interact", "wayfarer_2", L("Find the sign by the shrine road", "Encuentra la señal junto al camino del santuario", "Ache o sinal perto da estrada do santuário", "Trouvez le signe près de la route du sanctuaire", "Finde das Zeichen am Schreinweg", "祠への道のそばの印を探す", "사당 길 옆의 표식 찾기", "找神祠路旁的记号"), hint="area", area_radius=50.0, marker=[150, 290]),
           spawns=[{"kind": "object", "id": "wayfarer_2", "look": "clue", "pos": [152, 292], "prompt": "PROMPT_EXAMINE",
                    "lines": [L("\"Where echoes sleep, face the rising sun.\"", "\"Donde duermen los ecos, mira hacia el sol naciente.\"", "\"Onde os ecos dormem, encare o sol nascente.\"", "« Là où dorment les échos, fais face au soleil levant. »", "„Wo die Echos schlafen, blick zur aufgehenden Sonne.“", "「残響の眠る所で、朝日を向け」", "\"메아리가 잠든 곳에서 해 뜨는 쪽을 보라.\"", "“回声沉睡处，面朝初升之日。”")]}]),
     stage(obj("interact", "wayfarer_3", L("Find the sign east of the Echo Chamber", "Encuentra la señal al este de la Cámara del Eco", "Ache o sinal a leste da Câmara do Eco", "Trouvez le signe à l'est de la Chambre des Échos", "Finde das Zeichen östlich der Echokammer", "残響の間の東の印を探す", "메아리의 방 동쪽 표식 찾기", "找回音厅东边的记号"), hint="area", area_radius=45.0, marker=[262, 418]),
           spawns=[{"kind": "object", "id": "wayfarer_3", "look": "clue", "pos": [262, 418], "prompt": "PROMPT_EXAMINE",
                    "lines": [L("\"Follow the water into the trees. Dig where the red cap grows.\"", "\"Sigue el agua hacia los árboles. Cava donde crece la seta roja.\"", "\"Siga a água até as árvores. Cave onde cresce o chapéu vermelho.\"", "« Suis l'eau jusqu'aux arbres. Creuse où pousse le chapeau rouge. »", "„Folge dem Wasser in den Wald. Grab, wo der rote Hut wächst.“", "「水を追って森へ。赤い傘の生える所を掘れ」", "\"물을 따라 숲으로. 붉은 갓이 자라는 곳을 파라.\"", "“随水入林，在红菇生处挖。”")]}]),
     stage(obj("open_chest", "wayfarer_cache", L("Dig up the wayfarer's cache", "Desentierra el alijo del caminante", "Desenterre o esconderijo do andarilho", "Déterrez la cache du voyageur", "Grab das Versteck des Wanderers aus", "旅人の隠し物を掘り出す", "나그네의 은닉처 파내기", "挖出旅人的藏物"), hint="area", area_radius=40.0, marker=[330, 360]),
           spawns=[{"kind": "chest", "id": "wayfarer_cache", "pos": [331, 362], "table": "chest_hidden", "items": [{"id": "stamina_bloom", "count": 1}]},
                   {"kind": "object", "id": "cache_mushroom", "look": "flower", "pos": [333, 360], "once": False, "hide_used": False, "sparkle": False, "prompt": "PROMPT_EXAMINE",
                    "lines": [L("A red-capped mushroom. The earth beside it is loose.", "Una seta de sombrero rojo. La tierra de al lado está suelta.", "Um cogumelo de chapéu vermelho. A terra ao lado está solta.", "Un champignon à chapeau rouge. La terre à côté est meuble.", "Ein rothütiger Pilz. Die Erde daneben ist locker.", "赤い傘のキノコ。横の土が柔らかい。", "붉은 갓 버섯. 옆의 흙이 헐겁다.", "一朵红菇，旁边的土是松的。")]}])],
    {"jade": 2, "glimmer": 40},
    start="event",
    spawns=[{"kind": "object", "id": "wayfarer_1", "look": "clue", "pos": [100, 176], "prompt": "PROMPT_EXAMINE", "when": "open",
             "lines": [L("\"Three signs, one prize. Next: where the road meets the shrine.\"", "\"Tres señales, un premio. La siguiente: donde el camino se encuentra con el santuario.\"", "\"Três sinais, um prêmio. Próximo: onde a estrada encontra o santuário.\"", "« Trois signes, un trésor. Le suivant : où la route rejoint le sanctuaire. »", "„Drei Zeichen, ein Preis. Das nächste: wo der Weg den Schrein trifft.“", "「三つの印に一つの宝。次は道が祠に出会う所」", "\"표식 셋, 보물 하나. 다음은 길이 사당과 만나는 곳.\"", "“三记号，一宝藏。下一个：路与神祠相会处。”")]}]))

Q(quest("sq_fang_rescue", "side", "combat", "valley", 3, "medium",
    L("Caged at Fang Camp", "Enjaulado en el campamento Colmillo", "Engaiolado no acampamento Presa", "En cage au camp des Crocs", "Gefangen im Fanglager", "牙の野営地の虜", "송곳니 야영지의 포로", "獠牙营的俘虏"),
    L("A traveller Pip was guiding was dragged into Fang Camp. Quiet hands will get them out alive.", "Un viajero al que guiaba Pip fue arrastrado al campamento Colmillo. Unas manos sigilosas lo sacarán con vida.", "Um viajante guiado por Pip foi arrastado ao acampamento Presa. Mãos silenciosas o tirarão vivo.", "Un voyageur que guidait Pip a été traîné au camp des Crocs. Des mains discrètes le sortiront vivant.", "Ein Reisender, den Pip führte, wurde ins Fanglager geschleppt. Leise Hände holen ihn lebend raus.", "ピップが案内していた旅人が牙の野営地に連れ去られた。静かにやれば助かる。", "핍이 안내하던 나그네가 송곳니 야영지로 끌려갔다. 조용히 하면 살릴 수 있다.", "皮普带路的旅人被拖进了獠牙营。悄悄行动才能救他出来。"),
    [stage(obj("interact", "fang_captive", T("QO_T_FREE", "NAME_TRAVELER"), marker=[292, -29]),
           obj("sneak", "ENEMY_THORNLING", T("QO_T_SNEAK", "NAME_THORNLING"), count=2, optional=True),
           spawns=[{"kind": "actor", "entity": "NPC_TRAVELER", "pos": [292, -29], "tied": True, "hp": 100,
                    "talk": {"id": "fang_captive", "prompt": "PROMPT_FREE", "then_path": [[270, -10], [230, 30], [180, 70]],
                             "lines": [L("Bless you! I'll run for the hamlet — don't wait for me.", "¡Bendito seas! Corro a la aldea, no me esperes.", "Deus te abençoe! Vou correndo para a aldeia, não espere.", "Merci ! Je file au hameau, ne m'attendez pas.", "Segen dir! Ich renne ins Dorf, wart nicht auf mich.", "ありがとう！村まで走る、待たなくていい。", "고마워! 마을로 뛰어갈게, 기다리지 마.", "谢天谢地！我跑回村子，不用等我。")]}}]),
     stage(obj("talk", "NPC_COURIER", T("QO_T_RETURN", "NAME_COURIER")),
           talk=[L("They made it back! You're owed more than thanks.", "¡Llegó de vuelta! Te debo más que las gracias.", "Chegou de volta! Te devo mais que obrigado.", "Il est rentré ! Je vous dois plus qu'un merci.", "Er ist zurück! Ich schulde dir mehr als Dank.", "戻ってきた！礼だけじゃ足りないね。", "돌아왔어! 고맙다는 말로는 부족해.", "他回来了！光说谢谢可不够。")])],
    {"jade": 1, "glimmer": 40},
    bonus_rewards={"cosmetic": "echo_storm", "items": [{"id": "resin_bomb", "count": 3}]},
    start="talk:NPC_COURIER", requires=["mq_thorn_road"],
    offer_lines=[L("They took my traveller to Fang Camp! If you go in loud, they'll... please be quiet.", "¡Se llevaron a mi viajero al campamento Colmillo! Si entras a lo bruto... por favor, sé sigiloso.", "Levaram meu viajante ao acampamento Presa! Se entrar fazendo barulho... por favor, seja discreto.", "Ils ont emmené mon voyageur au camp des Crocs ! Si vous entrez bruyamment... soyez discret.", "Sie haben meinen Reisenden ins Fanglager gebracht! Wenn du laut reingehst... bitte sei leise.", "旅人が牙の野営地に！騒いだら…お願い、静かにね。", "내 나그네를 송곳니 야영지로 데려갔어! 시끄럽게 들어가면… 제발 조용히.", "他们把我的旅人抓进了獠牙营！要是硬闯……求你悄悄的。")]))

LETTER = "ITEM_PIPS_LETTER"
Q(quest("sq_courier_rounds", "side", "npc", "valley", 1, "medium",
    L("Pip's Rounds", "La ronda de Pip", "A ronda de Pip", "La tournée de Pip", "Pips Runde", "ピップの配達", "핍의 배달", "皮普的信差路"),
    L("Pip twisted an ankle. Three letters for three camps: the lake, the forest, the Needles.", "Pip se torció un tobillo. Tres cartas para tres campamentos: el lago, el bosque, las Agujas.", "Pip torceu o tornozelo. Três cartas para três acampamentos: o lago, a floresta, as Agulhas.", "Pip s'est tordu la cheville. Trois lettres pour trois camps : le lac, la forêt, les Aiguilles.", "Pip hat sich den Knöchel verdreht. Drei Briefe für drei Lager: See, Wald, Nadeln.", "ピップが足首をひねった。三つの野営地へ三通：湖、森、針岩。", "핍이 발목을 삐었다. 세 야영지에 편지 셋: 호수, 숲, 바늘바위.", "皮普扭了脚。三封信送三处营地：湖、林、针岩。"),
    [stage(obj("talk", "NPC_COURIER", T("QO_T_TALK", "NAME_COURIER")),
           talk=[L("Ilo at the lake, Varra in the forest, Kest under the Needles. Don't read them!", "Ilo en el lago, Varra en el bosque, Kest bajo las Agujas. ¡No las leas!", "Ilo no lago, Varra na floresta, Kest sob as Agulhas. Não leia!", "Ilo au lac, Varra en forêt, Kest sous les Aiguilles. Ne les lisez pas !", "Ilo am See, Varra im Wald, Kest unter den Nadeln. Nicht lesen!", "湖のイロ、森のヴァラ、針岩のケスト。読んじゃだめ！", "호수의 일로, 숲의 바라, 바늘바위의 케스트. 읽지 마!", "湖边伊洛、林中瓦拉、针岩下凯丝特。不许偷看！")],
           rewards={"items": [{"id": "pips_letter", "count": 3}]}),
     stage(obj("deliver", "NPC_FISHER", T("QO_T_GIVE", LETTER, "NAME_FISHER"), item="pips_letter"),
           obj("deliver", "NPC_HUNTER", T("QO_T_GIVE", LETTER, "NAME_HUNTER"), item="pips_letter"),
           obj("deliver", "NPC_CLIMBER", T("QO_T_GIVE", LETTER, "NAME_CLIMBER"), item="pips_letter"),
           talk=[L("A letter from Pip? Thank you, traveller.", "¿Una carta de Pip? Gracias, viajero.", "Uma carta de Pip? Obrigado, viajante.", "Une lettre de Pip ? Merci, voyageur.", "Ein Brief von Pip? Danke, Reisender.", "ピップから？ありがとう。", "핍의 편지? 고마워, 나그네.", "皮普的信？谢谢你，旅人。")])],
    {"glimmer": 50, "reveal": [{"pos": [-250, 100], "radius": 3}, {"pos": [370, 160], "radius": 3}, {"pos": [320, -160], "radius": 3}]},
    start="talk:NPC_COURIER", requires=["sq_fang_rescue"],
    offer_lines=[L("Ow, my ankle. Could you run my letters? Three camps, one fast pair of legs.", "Ay, mi tobillo. ¿Podrías llevar mis cartas? Tres campamentos, unas piernas rápidas.", "Ai, meu tornozelo. Pode levar minhas cartas? Três acampamentos, pernas rápidas.", "Aïe, ma cheville. Vous portez mes lettres ? Trois camps, des jambes rapides.", "Au, mein Knöchel. Trägst du meine Briefe aus? Drei Lager, schnelle Beine.", "いたた、足首が。手紙を運んで？三か所、速い足で。", "아야, 발목. 편지 좀 날라 줄래? 야영지 셋, 빠른 다리로.", "哎哟，脚踝。帮我送信吧？三处营地，就靠你的快腿。")]))

Q(quest("dq_gilded_hop", "discovery", "combat", "valley", 2, "short",
    L("The Gilded Hop", "El saltarín dorado", "O saltador dourado", "Le bondisseur doré", "Der Goldhüpfer", "金の跳ね兎", "황금 깡충이", "金跃兔"),
    L("At dawn and dusk a golden creature darts through the grass. Brask would pay a fortune for its fur.", "Al alba y al ocaso una criatura dorada corre entre la hierba. Brask pagaría una fortuna por su pelaje.", "Ao amanhecer e ao entardecer uma criatura dourada corre pela grama. Brask pagaria uma fortuna pelo pelo.", "À l'aube et au crépuscule, une créature dorée file dans l'herbe. Brask paierait une fortune sa fourrure.", "In Dämmerung huscht ein goldenes Tier durchs Gras. Brask zahlte ein Vermögen für sein Fell.", "明け方と夕暮れ、草むらを金色の獣が走る。ブラスクがその毛皮に大金を払う。", "새벽과 해질녘, 황금빛 짐승이 풀숲을 달린다. 브라스크가 그 털에 큰돈을 낸다.", "晨昏之时，金色小兽掠过草丛。布拉斯克愿为其毛皮出高价。"),
    [stage(obj("hunt", "ANIMAL_GILDED_HOP", T("QO_T_HUNT", "NAME_GILDED_HOP"))),
     stage(obj("deliver", "NPC_MERCHANT", T("QO_T_GIVE", "ITEM_GILDED_FUR", "NAME_MERCHANT"), item="gilded_fur"),
           talk=[L("Gilded fur! Nobody's brought me one in years. Name your price — no, I'll name it.", "¡Pelaje dorado! Hace años que nadie me trae uno. Pon tu precio... no, lo pongo yo.", "Pelo dourado! Ninguém me traz um há anos. Diga seu preço... não, eu digo.", "De la fourrure dorée ! Personne ne m'en a apporté depuis des années. Votre prix — non, le mien.", "Goldfell! Seit Jahren brachte mir keiner eins. Nenn deinen Preis — nein, ich nenne ihn.", "金の毛皮！何年ぶりだ。値段は…いや、俺が決める。", "황금 털가죽! 몇 년 만이야. 값을 불러… 아니, 내가 부르지.", "金毛皮！多少年没人给我带来了。你开价——不，我来开。")])],
    {"glimmer": 150, "jade": 2},
    start="event"))

Q(quest("dq_smoke_signal", "discovery", "combat", "valley", 2, "short",
    L("Smoke on the Horizon", "Humo en el horizonte", "Fumaça no horizonte", "Fumée à l'horizon", "Rauch am Horizont", "地平線の煙", "지평선의 연기", "天边的烟"),
    L("Dark smoke rises west of the heath. A farmstead is burning, and something is still prowling.", "Humo negro al oeste del brezal. Una granja arde y algo sigue rondando.", "Fumaça escura a oeste da charneca. Uma granja queima e algo ainda ronda.", "Une fumée noire à l'ouest de la lande. Une ferme brûle, et quelque chose rôde encore.", "Dunkler Rauch westlich der Heide. Ein Gehöft brennt, und noch schleicht etwas umher.", "荒野の西に黒煙。農家が燃え、まだ何かがうろついている。", "황야 서쪽에 검은 연기. 농가가 타고, 무언가 아직 서성인다.", "荒原西边黑烟滚滚。农舍在烧，还有东西在游荡。"),
    [stage(obj("reach", "", T("QO_T_REACH", L("the burning farmstead", "la granja en llamas", "a granja em chamas", "la ferme en feu", "das brennende Gehöft", "燃える農家", "불타는 농가", "燃烧的农舍")), pos=[-60, 330], radius=32.0)),
     stage(obj("protect", "farm_raid", T("QO_T_PROTECT", L("the farmer", "al granjero", "o fazendeiro", "le fermier", "den Bauern", "農夫", "농부", "农夫"))),
           spawns=[{"kind": "encounter", "id": "farm_raid", "mode": "protect", "pos": [-58, 334], "actor": "NPC_TRAVELER", "actor_hp": 110, "trigger_radius": 30, "element": "thorn", "shout_key": "SHOUT_HELP",
                    "waves": [{"entity": "ENEMY_THORNLING", "count": 3, "dist": 13}, {"entity": "ENEMY_THORNLING", "count": 2, "dist": 15, "delay": 3}, {"entity": "ENEMY_BULWARK", "count": 1, "dist": 16, "delay": 3}],
                    "end_lines": [L("They'd have had me too. The storehouse is yours to take from — it's all ash otherwise.", "Me habrían llevado también. Toma lo que quieras del almacén; si no, será ceniza.", "Teriam me levado também. Pegue o que quiser do depósito; senão vira cinza.", "Ils m'auraient eu aussi. Servez-vous dans la réserve, sinon tout finira en cendres.", "Mich hätten sie auch geholt. Nimm aus dem Speicher, was du willst — sonst wird es Asche.", "俺もやられるところだった。倉の物は持っていけ、灰になるだけだ。", "나도 당할 뻔했어. 창고 물건은 가져가, 어차피 재가 될 거야.", "差点连我也遭殃。仓里的东西你拿去吧，反正要烧成灰了。")]}])],
    {"jade": 1, "glimmer": 50, "items": [{"id": "hearty_stew", "count": 2}, {"id": "raw_meat", "count": 3}]},
    start="event",
    spawns=[{"kind": "cue", "cue": "smoke", "pos": [-60, 330], "when": "open", "range": 900},
            {"kind": "object", "id": "farm_cart", "look": "crate", "pos": [-64, 326], "when": "open", "once": False, "hide_used": False, "sparkle": False, "prompt": "PROMPT_EXAMINE",
             "lines": [L("Scorched crates. Claw marks on the door.", "Cajas chamuscadas. Marcas de garras en la puerta.", "Caixas chamuscadas. Marcas de garras na porta.", "Caisses roussies. Des traces de griffes sur la porte.", "Versengte Kisten. Krallenspuren an der Tür.", "焦げた木箱。扉に爪痕。", "그을린 상자. 문에 발톱 자국.", "烧焦的木箱，门上有爪痕。")]}]))

VANES = L("the three wind vanes", "las tres veletas", "os três cata-ventos", "les trois girouettes", "die drei Windfahnen", "三つの風見", "바람개비 셋", "三座风向标")
Q(quest("dq_sealed_sails", "discovery", "puzzle", "valley", 2, "short",
    L("Three Sails, One Breath", "Tres velas, un aliento", "Três velas, um fôlego", "Trois voiles, un souffle", "Drei Segel, ein Atem", "三つの帆、一つの息", "돛 셋, 숨 하나", "三帆一息"),
    L("A wind-sealed chest waits among three silent vanes. Wind, or fire beneath them, might wake them.", "Un cofre sellado por el viento espera entre tres veletas quietas. Viento, o fuego bajo ellas, podría despertarlas.", "Um baú selado pelo vento espera entre três cata-ventos parados. Vento, ou fogo embaixo, pode acordá-los.", "Un coffre scellé par le vent attend entre trois girouettes immobiles. Du vent, ou du feu dessous, les réveillerait.", "Eine windversiegelte Truhe wartet zwischen drei stillen Fahnen. Wind oder Feuer darunter weckt sie.", "三つの止まった風見の間に風封じの箱。風か、下の火が目覚めさせる。", "멈춘 바람개비 셋 사이에 바람으로 봉한 상자. 바람이나 아래의 불이 깨운다.", "三座静止的风向标间有个风封的箱子，风或下方的火能唤醒它们。"),
    [stage(obj("interact", "sails_tablet", T("QO_T_EXAMINE", L("the old tablet", "la vieja tablilla", "a velha tabuleta", "la vieille tablette", "die alte Tafel", "古い石板", "낡은 석판", "旧石碑")))),
     stage(obj("puzzle", "sealed_sails", T("QO_T_SOLVE", L("the sails", "las velas", "as velas", "les voiles", "die Segel", "帆", "돛", "三帆")), marker=[176, 312])),
     stage(obj("open_chest", "sealed_sails:chest", T("QO_T_OPEN", L("the wind-sealed chest", "el cofre sellado", "o baú selado", "le coffre scellé", "die versiegelte Truhe", "風封じの箱", "바람으로 봉한 상자", "风封之箱")), marker=[176, 312]))],
    {"jade": 2},
    start="interact:sails_tablet",
    spawns=[{"kind": "object", "id": "sails_tablet", "look": "board", "pos": [168, 318], "yaw": 30, "when": "open", "once": False, "hide_used": False, "prompt": "PROMPT_EXAMINE",
             "lines": [L("Carved: \"Three sails, one breath. Wake them all and the seal lets go.\"", "Grabado: \"Tres velas, un aliento. Despiértalas todas y el sello cede.\"", "Gravado: \"Três velas, um fôlego. Acorde todas e o selo cede.\"", "Gravé : « Trois voiles, un souffle. Éveille-les toutes et le sceau cède. »", "Eingraviert: „Drei Segel, ein Atem. Weck sie alle, dann weicht das Siegel.“", "刻字：「三つの帆に一つの息。すべて起こせば封は解ける」", "새김: \"돛 셋, 숨 하나. 모두 깨우면 봉인이 풀린다.\"", "刻着：“三帆一息，尽醒则封解。”")]},
            {"kind": "puzzle", "id": "sealed_sails", "pos": [176, 312], "when": "open",
             "elements": [{"type": "vane", "at": [-7, 0]}, {"type": "vane", "at": [5, -6]}, {"type": "vane", "at": [5, 6]}],
             "seal": {"at": [0, 0], "chest": {"id": "sealed_sails:chest", "table": "chest_hidden", "items": [{"id": "vital_seed", "count": 1}]}}}]))

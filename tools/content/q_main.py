"""The Warden's Road — the main line (16 quests).

Story in one breath: the Stillwake, a silence born in the Veil, is smothering
the wind. Oren, the last Wind Warden, went to stop it and has not returned.
His apprentice takes up his Vela and relights the Warden beacons of each land
— earning the wind's arts on the way — to face the Stillwake Warden.
Each quest leans on a different activity; talk is kept to a line or two."""
from qdsl import L, T, quest, stage, obj

QUESTS = []
Q = QUESTS.append

# --- Act I: the valley ------------------------------------------------------------------------------------

Q(quest("mq_vela", "main", "traversal", "valley", 1, "short",
    L("The Apprentice's Vela", "La Vela del aprendiz", "A Vela do aprendiz", "La Vela de l'apprenti", "Die Vela des Lehrlings", "見習いのヴェラ", "견습생의 벨라", "学徒的风帆"),
    L("Oren is gone and left you his Vela. Time to learn to fly.", "Oren se fue y te dejó su Vela. Hora de aprender a volar.", "Oren sumiu e deixou a Vela para você. Hora de aprender a voar.", "Oren est parti en vous laissant sa Vela. Il est temps d'apprendre à voler.", "Oren ist fort und hat dir seine Vela gelassen. Zeit, fliegen zu lernen.", "オレンは消え、ヴェラを残した。飛び方を覚える時だ。", "오렌은 떠나며 벨라를 남겼다. 나는 법을 배울 때다.", "奥伦走了，留下他的风帆。该学飞了。"),
    [stage(obj("talk", "NPC_CARTOGRAPHER", T("QO_T_TALK", "NAME_CARTOGRAPHER"), marker=[60, 156]),
           talk=[L("Oren left this for you. His Vela — a glider, apprentice.", "Oren te dejó esto. Su Vela: un planeador, aprendiz.", "Oren deixou isto para você. A Vela dele: um planador, aprendiz.", "Oren vous a laissé ceci. Sa Vela : un planeur, apprenti·e.", "Oren hat dir das dagelassen. Seine Vela — ein Gleiter, Lehrling.", "オレンがあんたに遺したよ。ヴェラ、つまり滑空翼さ。", "오렌이 네게 남긴 거야. 벨라, 활공 날개지.", "奥伦留给你的，他的风帆——一副滑翔翼。"),
                 L("Climb the lookout west of here and jump. Hold jump in the air to open it.", "Sube a la atalaya del oeste y salta. Mantén saltar en el aire para abrirla.", "Suba o mirante a oeste e pule. Segure pular no ar para abri-la.", "Grimpez au guet à l'ouest et sautez. Maintenez saut en l'air pour l'ouvrir.", "Kletter auf die Warte im Westen und spring. Halte Springen in der Luft, um sie zu öffnen.", "西の物見台に登って跳べ。空中でジャンプ長押しで開く。", "서쪽 망루에 올라 뛰어내려. 공중에서 점프를 누르면 펼쳐진다.", "爬上西边的望楼跳下去，空中按住跳跃就能展开。")]),
     stage(obj("climb", "hamlet_lookout", T("QO_T_CLIMB", "POI_HAMLET_LOOKOUT"), min_y=29.0, radius=9.0)),
     stage(obj("glide", "", L("Glide from the lookout", "Planea desde la atalaya", "Plane do mirante", "Planez depuis le guet", "Gleite von der Warte", "物見台から滑空する", "망루에서 활공하기", "从望楼滑翔"), count=15, metric="distance")),
     stage(obj("talk", "NPC_CARTOGRAPHER", T("QO_T_RETURN", "NAME_CARTOGRAPHER")),
           talk=[L("You flew! Badly, but you flew. Brask was asking for you.", "¡Volaste! Mal, pero volaste. Brask preguntaba por ti.", "Você voou! Mal, mas voou. Brask perguntou por você.", "Vous avez volé ! Mal, mais volé. Brask vous cherchait.", "Du bist geflogen! Schlecht, aber geflogen. Brask hat nach dir gefragt.", "飛んだね！下手だけど。ブラスクが呼んでたよ。", "날았네! 서툴지만. 브라스크가 널 찾더라.", "你飞起来了！虽然飞得难看。布拉斯克在找你。")])],
    {"jade": 2, "glimmer": 20, "reveal": {"pos": [60, 150], "radius": 6}},
    start="auto"))

Q(quest("mq_thorn_road", "main", "combat", "valley", 2, "short",
    L("Thorns on the Road", "Espinas en el camino", "Espinhos na estrada", "Des ronces sur la route", "Dornen auf dem Weg", "道のトゲ獣", "길 위의 가시", "路上荆棘"),
    L("Brask's hauler is stranded on the east road with thornlings closing in.", "El porteador de Brask está atrapado en el camino del este, rodeado de espinudos.", "O carregador de Brask está preso na estrada leste, cercado de espinhosos.", "Le porteur de Brask est coincé sur la route de l'est, cerné de ronceux.", "Brasks Träger sitzt auf der Oststraße fest, Dornlinge kreisen ihn ein.", "ブラスクの荷運びが東の道でトゲ獣に囲まれている。", "브라스크의 짐꾼이 동쪽 길에서 가시짐승에게 포위됐다.", "布拉斯克的脚夫困在东路上，棘兽正围上来。"),
    [stage(obj("protect", "cart_ambush", T("QO_T_PROTECT", "NAME_TRAVELER"), marker=[172, 78]),
           spawns=[{"kind": "encounter", "id": "cart_ambush", "mode": "protect", "pos": [172, 78], "actor": "NPC_TRAVELER", "actor_hp": 140,
                    "shout_key": "SHOUT_HELP", "trigger_radius": 24, "element": "thorn",
                    "waves": [{"entity": "ENEMY_THORNLING", "count": 2, "dist": 14}, {"entity": "ENEMY_THORNLING", "count": 3, "dist": 16, "delay": 3}],
                    "end_lines": [L("They came out of the ditch! The nest is just up the road.", "¡Salieron de la zanja! El nido está un poco más arriba.", "Saíram da vala! O ninho fica logo adiante.", "Ils sont sortis du fossé ! Le nid est juste plus haut.", "Sie kamen aus dem Graben! Das Nest liegt gleich weiter oben.", "溝から出てきた！巣はこの先だ。", "도랑에서 튀어나왔어! 둥지는 바로 저 위야.", "它们从沟里钻出来！巢就在前面。")]},
                   {"kind": "object", "id": "brask_cart", "look": "crate", "pos": [175, 81], "once": False, "hide_used": False,
                    "prompt": "PROMPT_EXAMINE", "lines": [L("Brask's cart. One wheel is deep in the mud.", "El carro de Brask. Una rueda está hundida en el barro.", "A carroça de Brask. Uma roda atolada na lama.", "La charrette de Brask. Une roue est embourbée.", "Brasks Karren. Ein Rad steckt tief im Schlamm.", "ブラスクの荷車。車輪が泥に埋まっている。", "브라스크의 수레. 바퀴 하나가 진흙에 박혔다.", "布拉斯克的货车，一个轮子陷在泥里。")]}]),
     stage(obj("destroy", "road_nest", T("QO_T_DESTROY", L("the thorn nest", "el nido de espinas", "o ninho de espinhos", "le nid de ronces", "das Dornennest", "トゲの巣", "가시 둥지", "荆棘巢")), marker=[196, 58]),
           spawns=[{"kind": "nest", "id": "road_nest", "nest": "thorn", "pos": [196, 58], "hp": 60, "melee": 0.3, "spawn": "ENEMY_THORNLING", "spawn_every": 12, "spawn_max": 2, "element": "thorn",
                    "drops": [{"id": "thorn_fang", "count": 2}]}],
           hint=[L("Blades won't do it. Fire will — or one of my resin bombs.", "Las hojas no bastan. El fuego sí, o una de mis bombas de resina.", "Lâminas não bastam. Fogo sim, ou uma bomba de resina.", "Les lames n'y suffiront pas. Le feu, si — ou une bombe de résine.", "Klingen reichen nicht. Feuer schon — oder eine Harzbombe.", "刃では無理だ。火か、樹脂爆弾だな。", "칼로는 안 돼. 불이나 수지 폭탄이면 되지.", "刀不管用，得用火，或者我的树脂炸弹。")]),
     stage(obj("talk", "NPC_MERCHANT", T("QO_T_RETURN", "NAME_MERCHANT")),
           talk=[L("Burned it out? Ha! The road's open again. Take these, you'll need them.", "¿Lo quemaste? ¡Ja! El camino vuelve a estar abierto. Toma, te harán falta.", "Queimou tudo? Ha! A estrada reabriu. Tome, vai precisar.", "Brûlé ? Ha ! La route est rouverte. Prenez ça, ça servira.", "Ausgebrannt? Ha! Die Straße ist frei. Nimm die, du wirst sie brauchen.", "焼き払ったか！道が開いた。これを持っていけ。", "태워버렸다고? 하! 길이 다시 열렸어. 이거 가져가.", "烧光了？哈！路通了。拿着，用得上。")])],
    {"items": [{"id": "resin_bomb", "count": 3}], "glimmer": 40, "jade": 1},
    start="talk:NPC_MERCHANT", requires=["mq_vela"],
    offer_lines=[L("My cart's stuck on the east road and thornlings are circling it. My hauler's still there!", "Mi carro se atascó en el camino del este y hay espinudos rondando. ¡Mi porteador sigue allí!", "Minha carroça atolou na estrada leste e há espinhosos rondando. Meu carregador está lá!", "Ma charrette est coincée sur la route de l'est, des ronceux rôdent. Mon porteur y est encore !", "Mein Karren steckt auf der Oststraße fest, Dornlinge kreisen. Mein Träger ist noch dort!", "荷車が東の道で動けない。トゲ獣が周りに！荷運びがまだいるんだ！", "수레가 동쪽 길에 박혔는데 가시짐승이 맴돌아. 짐꾼이 아직 거기 있어!", "我的货车陷在东路上，棘兽在打转，脚夫还在那儿！")]))

Q(quest("mq_echoes", "main", "puzzle", "valley", 2, "medium",
    L("Echoes in Stone", "Ecos en la piedra", "Ecos na pedra", "Échos dans la pierre", "Echos im Stein", "石の残響", "돌 속의 메아리", "石中回响"),
    L("Oren passed through the Echo Chamber. Its sealed heart may hold his trail.", "Oren pasó por la Cámara del Eco. Su corazón sellado quizá guarde su rastro.", "Oren passou pela Câmara do Eco. Seu coração selado pode guardar a pista dele.", "Oren est passé par la Chambre des Échos. Son cœur scellé garde peut-être sa trace.", "Oren kam durch die Echokammer. Ihr versiegeltes Herz birgt vielleicht seine Spur.", "オレンは残響の間を通った。封じられた奥に手がかりがあるかも。", "오렌은 메아리의 방을 지났다. 봉인된 중심에 흔적이 있을지도.", "奥伦去过回音厅，封印的中心或许留有他的踪迹。"),
    [stage(obj("discover", "echo_chamber", T("QO_T_FIND", "POI_ECHO_CHAMBER"))),
     stage(obj("puzzle", "echo_chamber", T("QO_T_SOLVE", "POI_ECHO_CHAMBER"), marker=[230, 420]),
           hint=[L("Three braziers in the far corners. Any flame will do: flint, a burning branch, the ember rod.", "Tres braseros en las esquinas. Cualquier llama sirve: pedernal, una rama ardiendo, la vara ígnea.", "Três braseiros nos cantos. Qualquer chama serve: pederneira, galho em chamas, bastão ígneo.", "Trois braseros aux coins. Toute flamme convient : silex, branche en feu, bâton de braise.", "Drei Feuerbecken in den Ecken. Jede Flamme taugt: Feuerstein, brennender Ast, Glutstab.", "奥の三つの火鉢。火打ち石でも燃える枝でも構わない。", "구석의 화로 세 개. 부싯돌이든 불붙은 가지든 상관없다.", "三个角落里的火盆，燧石、燃枝、烬杖都行。")]),
     stage(obj("retrieve", "oren_mark", T("QO_T_TAKE", "ITEM_OREN_LETTER"), marker=[233, 420]),
           spawns=[{"kind": "object", "id": "oren_mark", "look": "scroll", "poi": "echo_chamber", "pos": [3.2, 0.6], "item": "oren_letter", "prompt": "PROMPT_TAKE",
                    "lines": [L("\"Light the beacons, apprentice. The wind follows fire. — O.\"", "\"Enciende las balizas, aprendiz. El viento sigue al fuego. — O.\"", "\"Acenda os faróis, aprendiz. O vento segue o fogo. — O.\"", "« Allume les fanaux, apprenti·e. Le vent suit le feu. — O. »", "„Entzünde die Leuchtfeuer, Lehrling. Der Wind folgt dem Feuer. — O.“", "「灯台に火を。風は火を追う。——オ」", "\"봉화를 밝혀라, 견습생. 바람은 불을 따른다. — 오\"", "“点燃烽火，学徒。风随火走。——奥”")]}])],
    {"jade": 2, "glimmer": 30},
    start="auto", requires=["mq_thorn_road"]))

Q(quest("mq_cloud_temple", "main", "boss", "highlands", 3, "long",
    L("The Cloud Terrace", "La Terraza de las Nubes", "O Terraço das Nuvens", "La Terrasse des Nuées", "Die Wolkenterrasse", "雲の台", "구름 테라스", "云台"),
    L("The first beacon stands at the Wardens' temple on the mountain's shoulder. Something big guards it.", "La primera baliza está en el templo de los Guardianes, en el hombro de la montaña. Algo grande la guarda.", "O primeiro farol fica no templo dos Guardiões, no ombro da montanha. Algo grande o guarda.", "Le premier fanal se dresse au temple des Gardiens, sur l'épaule de la montagne. Une grosse bête le garde.", "Das erste Leuchtfeuer steht im Hütertempel an der Bergschulter. Etwas Großes bewacht es.", "最初の灯台は山の肩の守り人の寺に。何か大きなものが守っている。", "첫 봉화는 산 어깨의 지기 사원에 있다. 거대한 무언가가 지킨다.", "第一座烽火在山肩的守风者神殿，有巨物把守。"),
    [stage(obj("discover", "wind_overlook", T("QO_T_REACH", "POI_WIND_OVERLOOK"))),
     stage(obj("reach", "cloud_temple", T("QO_T_REACH", "POI_CLOUD_TEMPLE"), radius=26.0),
           obj("glide", "cloud_temple", L("Arrive by riding the overlook's updraft", "Llega aprovechando la corriente del mirador", "Chegue pela corrente do mirante", "Arrivez porté par le courant du belvédère", "Komm mit dem Aufwind der Aussicht", "展望台の上昇気流に乗って着く", "전망대 상승기류를 타고 도착", "借观景台的上升气流飞来"), radius=70.0, optional=True)),
     stage(obj("boss", "BOSS_THORNBACK", T("QO_T_DEFEAT", "NAME_THORNBACK"), marker=[0, -298])),
     stage(obj("flag", "beacon_valley", T("QO_T_LIGHT", L("the temple beacon", "la baliza del templo", "o farol do templo", "le fanal du temple", "das Tempelfeuer", "寺の灯台", "사원의 봉화", "神殿烽火")), marker=[-14, -315]))],
    {"ability": "gust_step", "max_stamina": 20, "jade": 3},
    start="auto", requires=["mq_echoes"],
    bonus_rewards={"cosmetic": "ribbon_cinnabar", "glimmer": 30}))

# --- Act II: three winds, then the sand ------------------------------------------------------------------------

Q(quest("mq_three_winds", "main", "story", "valley", 1, "short",
    L("Three Winds", "Tres vientos", "Três ventos", "Trois vents", "Drei Winde", "三つの風", "세 바람", "三股风"),
    L("One beacon burns. Oren's map marks three more: the lake, the salt coast and the Needles.", "Arde una baliza. El mapa de Oren marca tres más: el lago, la costa salada y las Agujas.", "Um farol arde. O mapa de Oren marca mais três: o lago, a costa salgada e as Agulhas.", "Un fanal brûle. La carte d'Oren en marque trois autres : le lac, la côte salée et les Aiguilles.", "Ein Feuer brennt. Orens Karte zeigt drei weitere: den See, die Salzküste und die Nadeln.", "灯台が一つ灯った。地図にはあと三つ：湖、潮の海岸、針岩。", "봉화 하나가 탄다. 지도엔 셋이 더: 호수, 소금 해안, 바늘바위.", "一座烽火燃起。地图上还有三处：湖、盐岸、针岩。"),
    [stage(obj("talk", "NPC_CARTOGRAPHER", T("QO_T_TALK", "NAME_CARTOGRAPHER")),
           talk=[L("A pillar of light over the temple! The map shows three more beacons. Any order you like.", "¡Un pilar de luz sobre el templo! El mapa muestra tres balizas más. En el orden que quieras.", "Um pilar de luz sobre o templo! O mapa mostra mais três faróis. Na ordem que quiser.", "Un pilier de lumière sur le temple ! Trois autres fanals, dans l'ordre qu'il vous plaira.", "Eine Lichtsäule über dem Tempel! Drei weitere Feuer, in beliebiger Reihenfolge.", "寺の上に光の柱！灯台はあと三つ。順番は好きに。", "사원 위에 빛기둥이! 봉화가 셋 더 있어. 순서는 마음대로.", "神殿上空一道光柱！还有三座烽火，顺序随你。"),
                 L("First, see Mother Ansel at the heath shrine. She knows what jade is for.", "Antes, ve a ver a Madre Ansel al santuario del brezal. Sabe para qué sirve el jade.", "Antes, veja Madre Ansel no santuário da charneca. Ela sabe para que serve o jade.", "D'abord, voyez Mère Ansel au sanctuaire de la lande. Elle sait à quoi sert le jade.", "Geh zuerst zu Mutter Ansel am Heideschrein. Sie weiß, wozu Jade gut ist.", "まず荒野の祠のアンセル婆に会って。翡翠の使い道を知ってる。", "먼저 황야 사당의 안셀 어머니를 만나 봐. 비취 쓰는 법을 알아.", "先去荒原神祠见安瑟嬷嬷，她知道翡翠的用处。")]),
     stage(obj("talk", "NPC_KEEPER", T("QO_T_TALK", "NAME_KEEPER")),
           talk=[L("Here, two stones of jade. Offer them at the altar and feel the wind answer.", "Toma, dos piedras de jade. Ofrécelas en el altar y siente cómo responde el viento.", "Tome, duas pedras de jade. Ofereça no altar e sinta o vento responder.", "Tenez, deux pierres de jade. Offrez-les à l'autel et sentez le vent répondre.", "Hier, zwei Jadesteine. Opfere sie am Altar und spür, wie der Wind antwortet.", "翡翠を二つあげよう。祭壇に捧げて、風の応えを感じなさい。", "비취 두 개다. 제단에 바치고 바람의 응답을 느껴라.", "给你两块翡翠。献于祭坛，感受风的回应。")],
           rewards={"jade": 2}),
     stage(obj("event", "upgrade_bought", T("QO_T_ALTAR", "POI_HEATH_SHRINE"), marker=[-120, 124]))],
    {"jade": 1, "reveal": [{"pos": [-400, 70], "radius": 5}, {"pos": [320, 760], "radius": 4}, {"pos": [390, -230], "radius": 4}]},
    start="auto", requires=["mq_cloud_temple"]))

Q(quest("mq_lake_beacon", "main", "puzzle", "lakeshore", 2, "medium",
    L("The Drowned Beacon", "La baliza ahogada", "O farol afogado", "Le fanal noyé", "Das ertrunkene Feuer", "沈んだ灯台", "잠긴 봉화", "溺水的烽火"),
    L("The lake beacon stands on Lily Isle, and fire does not cross water. Ilo the fisher knows a way.", "La baliza del lago está en la Isla de los Lirios, y el fuego no cruza el agua. Ilo, el pescador, sabe cómo.", "O farol do lago fica na Ilha dos Lírios, e o fogo não atravessa a água. Ilo, o pescador, sabe o jeito.", "Le fanal du lac est sur l'Île aux Lys, et le feu ne traverse pas l'eau. Ilo le pêcheur sait comment.", "Das Seefeuer steht auf der Lilieninsel, und Feuer quert kein Wasser. Ilo der Fischer weiß Rat.", "湖の灯台は睡蓮の小島。火は水を渡れない。漁師イロが方法を知っている。", "호수 봉화는 연꽃 섬에 있고, 불은 물을 건너지 못한다. 어부 일로가 방법을 안다.", "湖上烽火立于睡莲小岛，火过不了水。渔夫伊洛有办法。"),
    [stage(obj("talk", "NPC_FISHER", T("QO_T_TALK", "NAME_FISHER")),
           talk=[L("Light the three braziers on the shore and the isle wakes. Then swim — the lilies won't bite.", "Enciende los tres braseros de la orilla y la isla despertará. Luego nada: los lirios no muerden.", "Acenda os três braseiros da margem e a ilha desperta. Depois nade: os lírios não mordem.", "Allumez les trois braseros de la rive et l'île s'éveille. Puis nagez : les lys ne mordent pas.", "Entzünde die drei Feuerbecken am Ufer, dann erwacht die Insel. Dann schwimm — die Lilien beißen nicht.", "岸の三つの火鉢を灯せば島が目覚める。あとは泳げ。蓮は噛まない。", "물가의 화로 셋을 밝히면 섬이 깨어난다. 그다음 헤엄쳐. 연꽃은 안 문다.", "点亮岸边三个火盆，小岛就会苏醒。然后游过去，睡莲不咬人。")]),
     stage(obj("puzzle", "lake_braziers", T("QO_T_LIGHT", L("the three shore braziers", "los tres braseros de la orilla", "os três braseiros da margem", "les trois braseros de la rive", "die drei Uferbecken", "岸の三つの火鉢", "물가의 화로 셋", "岸边三个火盆")), hint="area", area_radius=170.0, marker=[-400, 70]),
           spawns=[{"kind": "puzzle", "id": "lake_braziers", "pos": [-400, 70], "range": 260,
                    "elements": [{"type": "brazier", "at": [150, -10]}, {"type": "brazier", "at": [-5, -155]}, {"type": "brazier", "at": [-150, 30]}]}]),
     stage(obj("reach", "lake_isle", L("Swim to Lily Isle", "Nada hasta la Isla de los Lirios", "Nade até a Ilha dos Lírios", "Nagez jusqu'à l'Île aux Lys", "Schwimm zur Lilieninsel", "睡蓮の小島まで泳ぐ", "연꽃 섬까지 헤엄치기", "游到睡莲小岛"), radius=11.0)),
     stage(obj("flag", "beacon_lake", T("QO_T_LIGHT", L("the lake beacon", "la baliza del lago", "o farol do lago", "le fanal du lac", "das Seefeuer", "湖の灯台", "호수의 봉화", "湖上烽火")), marker=[-440, 60]))],
    {"jade": 3, "items": [{"id": "frostmint", "count": 3}], "cosmetic": "trail_frost"},
    start="auto", requires=["mq_three_winds"]))

Q(quest("mq_coast_beacon", "main", "combat", "coast", 3, "medium",
    L("Salt and Spitters", "Sal y escupidores", "Sal e cuspidores", "Sel et cracheurs", "Salz und Speier", "潮風と吐き虫", "소금과 침뱉이", "盐与喷吐虫"),
    L("Spitters have nested on Gull Bluff, above the sea stack where the coast beacon waits.", "Los escupidores anidan en el Risco de las Gaviotas, sobre el farallón donde espera la baliza.", "Cuspidores fizeram ninhos no Penhasco das Gaivotas, sobre o rochedo do farol.", "Des cracheurs nichent sur la Falaise aux mouettes, au-dessus de l'aiguille du fanal.", "Speier nisten auf der Möwenklippe, über dem Felsen mit dem Küstenfeuer.", "鴎の崖に吐き虫が巣食った。下の岩塔に海岸の灯台がある。", "침뱉이들이 갈매기 절벽에 둥지를 틀었다. 아래 바위에 해안 봉화가 있다.", "喷吐虫在鸥崖筑巢，崖下岩柱上就是海岸烽火。"),
    [stage(obj("discover", "sea_bluff", T("QO_T_REACH", "POI_SEA_BLUFF"))),
     stage(obj("destroy", "group:bluff_nests", T("QO_T_DESTROY", L("the spitter nests", "los nidos de escupidores", "os ninhos de cuspidores", "les nids de cracheurs", "die Speiernester", "吐き虫の巣", "침뱉이 둥지", "喷吐虫巢")), count=3, hint="area", area_radius=45.0, marker=[300, 700]),
           spawns=[{"kind": "nest", "id": "bluff_nest_a", "group": "bluff_nests", "nest": "spitter", "poi": "sea_bluff", "pos": [24, 12], "hp": 70, "spawn": "ENEMY_SPITTER", "spawn_every": 14, "spawn_max": 1, "element": "fire"},
                   {"kind": "nest", "id": "bluff_nest_b", "group": "bluff_nests", "nest": "spitter", "poi": "sea_bluff", "pos": [-22, 22], "hp": 70, "spawn": "ENEMY_SPITTER", "spawn_every": 14, "spawn_max": 1, "element": "fire"},
                   {"kind": "nest", "id": "bluff_nest_c", "group": "bluff_nests", "nest": "spitter", "poi": "sea_bluff", "pos": [8, -26], "hp": 70, "spawn": "ENEMY_SPITTER", "spawn_every": 14, "spawn_max": 1, "element": "fire"}]),
     stage(obj("reach", "sea_stack", L("Glide down to the Salt Stack", "Planea hasta el Farallón de sal", "Plane até o Rochedo de sal", "Planez jusqu'à l'Aiguille de sel", "Gleite hinab zum Salzfels", "潮の岩塔まで滑空する", "소금 바위까지 활공", "滑翔到盐岩柱"), radius=9.0, min_y=9.0)),
     stage(obj("flag", "beacon_coast", T("QO_T_LIGHT", L("the coast beacon", "la baliza de la costa", "o farol da costa", "le fanal de la côte", "das Küstenfeuer", "海岸の灯台", "해안의 봉화", "海岸烽火")), marker=[330, 792]))],
    {"jade": 3, "glimmer": 60, "items": [{"id": "spitter_gland", "count": 3}]},
    start="auto", requires=["mq_three_winds"]))

Q(quest("mq_heights_beacon", "main", "boss", "valley", 3, "medium",
    L("The Needle's Eye", "El ojo de la aguja", "O olho da agulha", "Le chas de l'aiguille", "Das Nadelöhr", "針の目", "바늘귀", "针眼"),
    L("A harrier has claimed the Needles and the beacon on the tallest spire.", "Un azor se ha adueñado de las Agujas y de la baliza en la más alta.", "Um gavião tomou as Agulhas e o farol na mais alta.", "Un busard s'est approprié les Aiguilles et le fanal de la plus haute.", "Ein Weih hat die Nadeln besetzt, samt Feuer auf der höchsten.", "鷂が針岩と、一番高い岩の灯台を奪った。", "매 한 마리가 바늘바위와 가장 높은 곳의 봉화를 차지했다.", "一只崖鹞占据了针岩和最高处的烽火。"),
    [stage(obj("talk", "NPC_CLIMBER", T("QO_T_TALK", "NAME_CLIMBER")),
           talk=[L("Climb high, make noise. She'll come. Then pray your grip holds.", "Sube alto, haz ruido. Vendrá. Luego reza para que aguante tu agarre.", "Suba alto, faça barulho. Ela virá. Depois reze pela sua pegada.", "Montez haut, faites du bruit. Elle viendra. Priez pour votre prise.", "Kletter hoch, mach Lärm. Sie kommt. Dann bete, dass dein Griff hält.", "高く登って騒げ。来るぞ。あとは握力を祈れ。", "높이 올라가서 소란을 피워. 올 거야. 그다음 손아귀를 믿어.", "爬高点、弄出动静，她会来。然后祈祷你抓得牢。")]),
     stage(obj("climb", "needles", L("Climb one of the tall needles", "Escala una de las agujas altas", "Escale uma das agulhas altas", "Escaladez une des hautes aiguilles", "Erklimme eine der hohen Nadeln", "高い針岩のどれかに登る", "높은 바늘바위 하나에 오르기", "攀上一根高针岩"), radius=75.0, min_y=70.0, hint="area", area_radius=75.0),
           flag="harrier_roused"),
     stage(obj("boss", "BOSS_CRAG_HARRIER", T("QO_T_DEFEAT", "NAME_CRAG_HARRIER"), marker=[390, -205])),
     stage(obj("flag", "beacon_heights", T("QO_T_LIGHT", L("the Needles beacon", "la baliza de las Agujas", "o farol das Agulhas", "le fanal des Aiguilles", "das Nadelfeuer", "針岩の灯台", "바늘바위 봉화", "针岩烽火")), hint="area", area_radius=70.0, marker=[390, -230]))],
    {"jade": 3, "glimmer": 50, "items": [{"id": "stamina_bloom", "count": 1}]},
    start="auto", requires=["mq_three_winds"]))

Q(quest("mq_sand_road", "main", "exploration", "desert", 2, "medium",
    L("The Sand Road", "El camino de arena", "A estrada de areia", "La route de sable", "Die Sandstraße", "砂の道", "모래 길", "沙之路"),
    L("With four beacons lit, the east wind returns — smelling of sand. Oren went east.", "Con cuatro balizas encendidas vuelve el viento del este, con olor a arena. Oren fue al este.", "Com quatro faróis acesos, volta o vento leste, com cheiro de areia. Oren foi para o leste.", "Quatre fanals allumés : le vent d'est revient, sentant le sable. Oren est parti à l'est.", "Vier Feuer brennen, der Ostwind kehrt zurück — er riecht nach Sand. Oren ging nach Osten.", "四つの灯台が灯り、東風が戻った。砂の匂いがする。オレンは東へ。", "봉화 넷이 타자 동풍이 돌아왔다. 모래 냄새가 난다. 오렌은 동쪽으로 갔다.", "四座烽火燃起，东风带着沙味回来了。奥伦去了东边。"),
    [stage(obj("talk", "NPC_CARTOGRAPHER", T("QO_T_TALK", "NAME_CARTOGRAPHER")),
           talk=[L("Doran keeps the east road post. He'll know if Oren crossed.", "Doran guarda el puesto del camino del este. Sabrá si Oren cruzó.", "Doran guarda o posto da estrada leste. Ele saberá se Oren passou.", "Doran tient le poste de la route de l'est. Il saura si Oren est passé.", "Doran hält den Posten an der Oststraße. Er weiß, ob Oren durchkam.", "東街道の番所のドランなら、オレンが通ったか知ってる。", "동쪽 길 초소의 도란이 오렌이 지나갔는지 알 거야.", "东路哨所的多兰会知道奥伦有没有经过。")]),
     stage(obj("talk", "NPC_GUARD", T("QO_T_TALK", "NAME_GUARD")),
           talk=[L("He crossed. You'll cook in that coat — take this veil. Saffa's at the oasis.", "Cruzó. Te vas a cocer con ese abrigo: toma este velo. Saffa está en el oasis.", "Ele passou. Você vai cozinhar nesse casaco: tome este véu. Saffa está no oásis.", "Il est passé. Vous allez cuire dans ce manteau : prenez ce voile. Saffa est à l'oasis.", "Er kam durch. In dem Mantel kochst du — nimm den Schleier. Saffa ist an der Oase.", "通ったよ。その服じゃ茹だる。このヴェールを。サッファはオアシスだ。", "지나갔어. 그 옷이면 익어버려. 이 베일을 써. 사파는 오아시스에 있어.", "他过去了。穿这身会被烤熟的，拿着这面纱。萨法在绿洲。")],
           rewards={"items": [{"id": "nomad_veil", "count": 1}]}),
     stage(obj("region", "desert", T("QO_T_ENTER", "REGION_DESERT"), marker=[780, 260])),
     stage(obj("discover", "sunscar_oasis", T("QO_T_FIND", "POI_SUNSCAR_OASIS"))),
     stage(obj("talk", "NPC_NOMAD", T("QO_T_TALK", "NAME_NOMAD")),
           talk=[L("Oren? He asked about the Sun Vault. Help my people first, and I'll help you.", "¿Oren? Preguntó por la Cripta del Sol. Ayuda antes a mi gente y te ayudaré.", "Oren? Perguntou pela Cripta do Sol. Ajude meu povo e eu te ajudo.", "Oren ? Il cherchait la Crypte du Soleil. Aidez mon peuple d'abord, et je vous aiderai.", "Oren? Er fragte nach der Sonnengruft. Hilf erst meinen Leuten, dann helfe ich dir.", "オレン？日輪の墓所を尋ねていた。まず仲間を助けてくれ。", "오렌? 태양 묘소를 물었지. 우리 사람들을 먼저 도와주면 나도 돕지.", "奥伦？他打听过日轮墓。先帮我的人，我再帮你。")])],
    {"jade": 1, "items": [{"id": "cooling_salad", "count": 2}]},
    start="auto", requires=["mq_lake_beacon", "mq_coast_beacon", "mq_heights_beacon"]))

Q(quest("mq_caravan", "main", "combat", "desert", 3, "medium",
    L("The Last Caravan", "La última caravana", "A última caravana", "La dernière caravane", "Die letzte Karawane", "最後の隊商", "마지막 대상", "最后的商队"),
    L("Tobb's caravan must reach the Dune Ruins. Scuttlers hunt the route.", "La caravana de Tobb debe llegar a las Ruinas de las dunas. Los escarbadores acechan la ruta.", "A caravana de Tobb precisa chegar às Ruínas das dunas. Escavadores caçam a rota.", "La caravane de Tobb doit atteindre les Ruines des dunes. Des fouisseurs chassent sur la route.", "Tobbs Karawane muss die Dünenruinen erreichen. Scharrer jagen auf der Route.", "トッブの隊商を砂丘の遺跡へ。道には砂這いが潜む。", "톱의 대상을 모래언덕 유적까지. 길에는 모래기어가 숨어 있다.", "托布的商队必须抵达沙丘遗迹，沿途有掘沙虫出没。"),
    [stage(obj("escort", "tobb_caravan", T("QO_T_ESCORT", "NAME_CARAVAN"), marker=[1000, 322]),
           spawns=[{"kind": "encounter", "id": "tobb_caravan", "mode": "escort", "pos": [1000, 322], "actor": "NPC_CARAVAN", "actor_hp": 160, "element": "sand",
                    "path": [[985, 350], [968, 385], [950, 418], [928, 448], [908, 472]], "wait_distance": 22, "vanish": True,
                    "ambushes": [{"at": 2, "entity": "ENEMY_SCUTTLER", "count": 3, "dist": 12}, {"at": 4, "entity": "ENEMY_SCUTTLER", "count": 2, "dist": 12}],
                    "start_lines": [L("Stay close. If I stop, it's because something's in the sand.", "Quédate cerca. Si me paro, es que hay algo en la arena.", "Fique perto. Se eu parar, é porque há algo na areia.", "Restez près. Si je m'arrête, c'est qu'il y a quelque chose dans le sable.", "Bleib nah. Wenn ich stehe, ist was im Sand.", "離れるな。俺が止まったら、砂に何かいる。", "가까이 있어. 내가 멈추면 모래 속에 뭔가 있는 거야.", "跟紧。我停下，就是沙里有东西。")]}]),
     stage(obj("survive", "ruins_stand", T("QO_T_SURVIVE", "POI_DUNE_RUINS"), marker=[900, 480]),
           spawns=[{"kind": "encounter", "id": "ruins_stand", "mode": "survive", "pos": [900, 480], "radius": 20, "duration": 60, "interval": 7, "max_alive": 5, "trigger_radius": 18, "element": "sand",
                    "waves": [{"entity": "ENEMY_SCUTTLER", "count": 2, "dist": 16}, {"entity": "ENEMY_SPITTER", "count": 1, "dist": 18}, {"entity": "ENEMY_SCUTTLER", "count": 3, "dist": 16}]}],
           flag="tobb_arrived"),
     stage(obj("talk", "NPC_NOMAD", T("QO_T_RETURN", "NAME_NOMAD")),
           talk=[L("Tobb made it! The Sun Vault's door answers to fire. Go.", "¡Tobb lo logró! La puerta de la Cripta del Sol responde al fuego. Ve.", "Tobb conseguiu! A porta da Cripta do Sol responde ao fogo. Vá.", "Tobb est arrivé ! La porte de la Crypte du Soleil répond au feu. Allez.", "Tobb hat's geschafft! Die Tür der Sonnengruft antwortet auf Feuer. Geh.", "トッブが着いた！日輪の墓所の扉は火に応える。行け。", "톱이 해냈어! 태양 묘소의 문은 불에 응답해. 가.", "托布到了！日轮墓的门认火。去吧。")])],
    {"jade": 3, "glimmer": 80},
    start="auto", requires=["mq_sand_road"]))

Q(quest("mq_sun_vault", "main", "puzzle", "desert", 3, "medium",
    L("The Buried Wind", "El viento enterrado", "O vento enterrado", "Le vent enseveli", "Der begrabene Wind", "埋もれた風", "묻힌 바람", "埋藏之风"),
    L("Under the Sun Vault's seal lies a disc that remembers the wind.", "Bajo el sello de la Cripta del Sol hay un disco que recuerda el viento.", "Sob o selo da Cripta do Sol há um disco que lembra o vento.", "Sous le sceau de la Crypte du Soleil repose un disque qui se souvient du vent.", "Unter dem Siegel der Sonnengruft liegt eine Scheibe, die sich an den Wind erinnert.", "日輪の墓所の封印の下に、風を覚えた円盤がある。", "태양 묘소의 봉인 아래 바람을 기억하는 원반이 있다.", "日轮墓的封印下，藏着记得风的圆盘。"),
    [stage(obj("discover", "sun_vault", T("QO_T_FIND", "POI_SUN_VAULT"))),
     stage(obj("puzzle", "sun_vault", T("QO_T_SOLVE", "POI_SUN_VAULT"), marker=[1250, 380])),
     stage(obj("retrieve", "vault_disc", T("QO_T_TAKE", "ITEM_SUN_DISC"), marker=[1253, 380]),
           spawns=[{"kind": "object", "id": "vault_disc", "look": "relic", "poi": "sun_vault", "pos": [3.2, 0.6], "item": "sun_disc", "prompt": "PROMPT_TAKE", "element": "sand"}]),
     stage(obj("deliver", "NPC_NOMAD", T("QO_T_GIVE", "ITEM_SUN_DISC", "NAME_NOMAD"), item="sun_disc"),
           talk=[L("It's warm... Oren said the Matriarch guards the last desert beacon. Take care.", "Está tibio... Oren dijo que la Matriarca guarda la última baliza del desierto. Cuídate.", "Está morno... Oren disse que a Matriarca guarda o último farol do deserto. Cuidado.", "Il est tiède... Oren disait que la Matriarche garde le dernier fanal du désert. Prudence.", "Sie ist warm... Oren sagte, die Matriarchin bewacht das letzte Wüstenfeuer. Pass auf.", "温かい…オレンは女王が砂漠最後の灯台を守ると言っていた。気をつけて。", "따뜻해… 오렌이 여왕이 사막 마지막 봉화를 지킨다고 했어. 조심해.", "好暖……奥伦说女王守着沙漠最后的烽火。小心。")])],
    {"jade": 2, "items": [{"id": "cooling_salad", "count": 3}], "recipes": [["frostmint", "sunpear"]]},
    start="auto", requires=["mq_caravan"]))

Q(quest("mq_glass_matriarch", "main", "boss", "desert", 4, "medium",
    L("Glass and Fury", "Vidrio y furia", "Vidro e fúria", "Verre et fureur", "Glas und Zorn", "玻璃と怒り", "유리와 분노", "琉璃之怒"),
    L("The desert beacon stands at the Glass Arena, and its Matriarch does not share.", "La baliza del desierto está en la Arena de Vidrio, y su Matriarca no comparte.", "O farol do deserto fica na Arena de Vidro, e sua Matriarca não divide.", "Le fanal du désert est à l'Arène de verre, et sa Matriarche ne partage pas.", "Das Wüstenfeuer steht in der Glasarena, und ihre Matriarchin teilt nicht.", "砂漠の灯台は玻璃の闘技場に。女王は譲らない。", "사막 봉화는 유리 투기장에 있고, 여왕은 나누지 않는다.", "沙漠烽火在琉璃竞技场，女王不容他人染指。"),
    [stage(obj("discover", "glass_arena", T("QO_T_REACH", "POI_GLASS_ARENA"))),
     stage(obj("boss", "BOSS_GLASS_MATRIARCH", T("QO_T_DEFEAT", "NAME_MATRIARCH"), marker=[1300, 120])),
     stage(obj("flag", "beacon_desert", T("QO_T_LIGHT", L("the desert beacon", "la baliza del desierto", "o farol do deserto", "le fanal du désert", "das Wüstenfeuer", "砂漠の灯台", "사막의 봉화", "沙漠烽火")), marker=[1319, 139]))],
    {"ability": "jade_platform", "max_health": 20, "jade": 4},
    start="auto", requires=["mq_sun_vault"]))

# --- Act III: the Veil --------------------------------------------------------------------------------------------

Q(quest("mq_veil_edge", "main", "combat", "veil", 3, "medium",
    L("Into the Veil", "Hacia el Velo", "Rumo ao Véu", "Vers le Voile", "In den Schleier", "帳の中へ", "장막 속으로", "步入帷幕"),
    L("Five beacons burn. Only the Veil is left — where the stillness began.", "Arden cinco balizas. Solo queda el Velo, donde nació la quietud.", "Cinco faróis ardem. Só resta o Véu, onde a quietude nasceu.", "Cinq fanals brûlent. Reste le Voile, où le calme est né.", "Fünf Feuer brennen. Nur der Schleier bleibt — wo die Stille begann.", "灯台は五つ。残るは静寂の生まれた帳だけ。", "봉화 다섯이 탄다. 남은 건 고요가 시작된 장막뿐.", "五座烽火已燃。只剩寂静诞生的帷幕。"),
    [stage(obj("discover", "pilgrim_camp", T("QO_T_FIND", "POI_PILGRIM_CAMP"))),
     stage(obj("talk", "NPC_PILGRIM", T("QO_T_TALK", "NAME_PILGRIM")),
           talk=[L("Oren went in three days ago. At the Hushed Shrine the silence fights back. Stand fast.", "Oren entró hace tres días. En el Santuario silente el silencio se defiende. Resiste.", "Oren entrou há três dias. No Santuário silente o silêncio reage. Resista.", "Oren est entré il y a trois jours. Au Sanctuaire muet, le silence riposte. Tenez bon.", "Oren ging vor drei Tagen hinein. Am Stillen Schrein wehrt sich die Stille. Halte stand.", "オレンは三日前に入った。静寂の祠では沈黙が牙をむく。耐えて。", "오렌은 사흘 전에 들어갔어. 침묵의 사당에선 고요가 반격해. 버텨.", "奥伦三天前进去了。寂静神祠里，沉默会反扑。撑住。")]),
     stage(obj("survive", "hush_surge", T("QO_T_SURVIVE", "POI_VEIL_SHRINE"), marker=[700, -720]),
           spawns=[{"kind": "encounter", "id": "hush_surge", "mode": "survive", "pos": [700, -720], "radius": 16, "duration": 50, "interval": 8, "max_alive": 4, "trigger_radius": 14, "element": "still",
                    "waves": [{"entity": "ENEMY_SHADE", "count": 1, "dist": 14}, {"entity": "ENEMY_WISP", "count": 2, "dist": 14}, {"entity": "ENEMY_SHADE", "count": 2, "dist": 15}]}])],
    {"jade": 2, "items": [{"id": "mending_tea", "count": 2}]},
    start="auto", requires=["mq_glass_matriarch"]))

Q(quest("mq_anchors", "main", "combat", "veil", 4, "long",
    L("Three Anchors", "Tres anclas", "Três âncoras", "Trois ancres", "Drei Anker", "三つの錨", "세 개의 닻", "三座锚"),
    L("Three anchors pin the stillness to the Veil. Their guardians won't let go easily.", "Tres anclas sujetan la quietud al Velo. Sus guardianes no cederán fácilmente.", "Três âncoras prendem a quietude ao Véu. Seus guardiões não cederão fácil.", "Trois ancres clouent le calme au Voile. Leurs gardiens ne lâcheront pas facilement.", "Drei Anker halten die Stille im Schleier fest. Ihre Wächter lassen nicht leicht los.", "三つの錨が静寂を帳に縫い止めている。守護者は手放さない。", "세 개의 닻이 고요를 장막에 묶고 있다. 수호자들은 쉽게 놓지 않는다.", "三座锚把寂静钉在帷幕里，守卫不会轻易放手。"),
    [stage(obj("flag", "anchor_north", "QO_ANCHOR_NORTH", marker=[880, -1085]),
           obj("flag", "anchor_east", "QO_ANCHOR_EAST", marker=[1085, -880]),
           obj("flag", "anchor_west", "QO_ANCHOR_WEST", marker=[675, -880]))],
    {"jade": 3, "max_stamina": 20},
    start="auto", requires=["mq_veil_edge"]))

Q(quest("mq_drifting_isles", "main", "traversal", "veil", 4, "medium",
    L("Where the Wind Sleeps", "Donde duerme el viento", "Onde o vento dorme", "Là où dort le vent", "Wo der Wind schläft", "風の眠る場所", "바람이 잠든 곳", "风眠之处"),
    L("Freed from the anchors, the Drifting Isles rise. The Warden's Breath rests on the highest.", "Libres de las anclas, las Islas a la deriva se alzan. El Aliento del Guardián reposa en la más alta.", "Livres das âncoras, as Ilhas à deriva sobem. O Fôlego do Guardião repousa na mais alta.", "Libérées des ancres, les Îles dérivantes s'élèvent. Le Souffle du Gardien repose sur la plus haute.", "Von den Ankern befreit, steigen die Treibinseln. Der Hüteratem ruht auf der höchsten.", "錨が外れ、漂う島々が昇る。守り人の息吹は最も高い島に。", "닻에서 풀린 떠도는 섬들이 떠오른다. 지기의 숨결은 가장 높은 섬에.", "锚断之后，浮岛升起。守风者之息就在最高的那座。"),
    [stage(obj("discover", "drifting_isles", T("QO_T_FIND", "POI_DRIFTING_ISLES"))),
     stage(obj("reach", "drifting_isles", L("Climb the isles to the highest", "Asciende por las islas hasta la más alta", "Suba pelas ilhas até a mais alta", "Montez d'île en île jusqu'à la plus haute", "Steig von Insel zu Insel bis zur höchsten", "島々を伝って最も高い島へ", "섬들을 타고 가장 높은 섬으로", "逐岛攀上最高处"), radius=60.0, min_y=64.0, hint="area", area_radius=60.0)),
     stage(obj("retrieve", "warden_breath", T("QO_T_TAKE", "ITEM_WARDEN_BREATH")),
           spawns=[{"kind": "object", "id": "warden_breath", "look": "relic", "pos": [806.6, -972.0], "snap": "top", "min_y": 60.0, "item": "warden_breath", "prompt": "PROMPT_TAKE", "element": "wind", "range": 140,
                    "lines": [L("A feather that never settles. The air around it moves on its own.", "Una pluma que nunca se posa. El aire a su alrededor se mueve solo.", "Uma pena que nunca pousa. O ar em volta se move sozinho.", "Une plume qui ne se pose jamais. L'air autour bouge tout seul.", "Eine Feder, die nie ruht. Die Luft um sie bewegt sich von selbst.", "決して落ち着かない羽。周りの空気がひとりでに動く。", "결코 가라앉지 않는 깃털. 주변 공기가 저절로 움직인다.", "一根永不落定的羽毛，周围的空气自己在流动。")]}])],
    {"jade": 3, "glimmer": 60},
    start="auto", requires=["mq_anchors"]))

Q(quest("mq_stillwake", "main", "boss", "veil", 5, "long",
    L("The Stillwake Warden", "El Guardián de la Quietud", "O Guardião da Quietude", "Le Gardien du Calme", "Der Stillwacht-Hüter", "静寂の番人", "고요의 파수꾼", "寂静守望者"),
    L("With the Warden's Breath, the Still Heart can be entered. End the silence — and find Oren.", "Con el Aliento del Guardián se puede entrar al Corazón Quieto. Acaba con el silencio y encuentra a Oren.", "Com o Fôlego do Guardião, dá para entrar no Coração Quieto. Acabe com o silêncio e encontre Oren.", "Avec le Souffle du Gardien, on peut entrer dans le Cœur Immobile. Brisez le silence, retrouvez Oren.", "Mit dem Hüteratem lässt sich das Stille Herz betreten. Beende die Stille — und finde Oren.", "守り人の息吹があれば静寂の心に入れる。沈黙を終わらせ、オレンを見つけろ。", "지기의 숨결로 고요한 심장에 들어갈 수 있다. 침묵을 끝내고 오렌을 찾아라.", "有了守风者之息就能进入静寂之心。终结沉默，找到奥伦。"),
    [stage(obj("discover", "still_heart", T("QO_T_REACH", "POI_STILL_HEART"))),
     stage(obj("boss", "BOSS_STILLWAKE_WARDEN", T("QO_T_DEFEAT", "NAME_WARDEN"), marker=[880, -880])),
     stage(obj("interact", "oren_found", T("QO_T_TALK", "NAME_MENTOR"), marker=[884, -872]),
           spawns=[{"kind": "actor", "entity": "NPC_MENTOR", "pos": [884, -872], "yaw": 200,
                    "talk": {"id": "oren_found", "prompt": "PROMPT_TALK", "vanish": False,
                             "lines": [L("Apprentice... you lit them all? Then the wind is yours now.", "Aprendiz... ¿las encendiste todas? Entonces el viento es tuyo.", "Aprendiz... acendeu todos? Então o vento é seu agora.", "Apprenti·e... tu les as tous allumés ? Alors le vent est à toi.", "Lehrling... du hast sie alle entzündet? Dann gehört der Wind jetzt dir.", "弟子よ…全部灯したのか。ならば風はもうお前のものだ。", "견습생… 전부 밝혔느냐? 그럼 이제 바람은 네 것이다.", "徒儿……你全点亮了？那风就归你了。"),
                                       L("Come. There's a whole island still to see.", "Ven. Aún queda una isla entera por ver.", "Venha. Ainda há uma ilha inteira para ver.", "Viens. Il reste toute une île à voir.", "Komm. Da ist noch eine ganze Insel zu sehen.", "来い。まだ見るべき島がまるごとある。", "가자. 아직 볼 섬이 통째로 남았다.", "走吧，还有一整座岛等着你去看。")]}}],
           flag="ending_reached")],
    {"ability": "stillness", "glimmer": 300, "jade": 5, "cosmetic": "trail_gilt"},
    start="auto", requires=["mq_drifting_isles"]))

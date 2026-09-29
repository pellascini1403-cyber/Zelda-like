"""Lake, river and salt coast: swimming, night lanterns on the river, wreck
salvage, a bell on a broken tower and a smugglers' cove."""
from qdsl import L, T, quest, stage, obj

QUESTS = []
Q = QUESTS.append

NET = "ITEM_FISHING_NET"
Q(quest("sq_fisher_net", "side", "traversal", "lakeshore", 1, "short",
    L("The Drifting Net", "La red a la deriva", "A rede à deriva", "Le filet à la dérive", "Das treibende Netz", "流された網", "떠내려간 그물", "漂走的渔网"),
    L("Ilo's net broke loose and drifted across the lake. It's still floating — for now.", "La red de Ilo se soltó y cruzó el lago. Aún flota, por ahora.", "A rede de Ilo se soltou e atravessou o lago. Ainda flutua, por enquanto.", "Le filet d'Ilo s'est détaché et a traversé le lac. Il flotte encore — pour l'instant.", "Ilos Netz hat sich gelöst und trieb über den See. Noch schwimmt es — noch.", "イロの網がほどけて湖を流れた。まだ浮いている、今のところは。", "일로의 그물이 풀려 호수를 건너갔다. 아직은 떠 있다.", "伊洛的网脱了，漂过湖面，暂时还浮着。"),
    [stage(obj("retrieve", "lake_net", T("QO_T_TAKE", NET), hint="area", area_radius=60.0, marker=[-480, 40]),
           spawns=[{"kind": "object", "id": "lake_net", "look": "crate", "pos": [-482, 42], "float": True, "lift": -0.2, "item": "fishing_net", "prompt": "PROMPT_TAKE", "radius": 2.2}]),
     stage(obj("deliver", "NPC_FISHER", T("QO_T_GIVE", NET, "NAME_FISHER"), item="fishing_net"),
           talk=[L("You swam all that way? Here — frostmint from my garden, and a fish supper on me.", "¿Nadaste hasta allí? Toma, menta helada de mi huerto, y te invito a cenar pescado.", "Você nadou até lá? Tome, menta-gelada da minha horta, e o jantar de peixe é por minha conta.", "Vous avez nagé jusque-là ? Tenez, de la menthe-givre de mon potager, et le poisson est pour moi.", "Du bist so weit geschwommen? Hier, Frostminze aus meinem Garten, und das Fischessen geht auf mich.", "あんなところまで泳いだのか。庭の霜ミントと、魚の夕飯をおごるよ。", "거기까지 헤엄쳤어? 텃밭의 서리박하랑 생선 저녁은 내가 살게.", "游那么远？给你我园子里的霜薄荷，鱼饭我请。")])],
    {"items": [{"id": "frostmint", "count": 3}, {"id": "hearty_stew", "count": 1}], "glimmer": 25, "jade": 1},
    start="talk:NPC_FISHER",
    offer_lines=[L("My net! It's drifting to the far shore. I'm no swimmer — can you fetch it?", "¡Mi red! Se va a la otra orilla. No sé nadar, ¿puedes traerla?", "Minha rede! Está indo para a outra margem. Não sei nadar, pode buscar?", "Mon filet ! Il dérive vers l'autre rive. Je ne nage pas, vous pouvez le rapporter ?", "Mein Netz! Es treibt ans andere Ufer. Ich kann nicht schwimmen — holst du es?", "網が！向こう岸に流れていく。泳げないんだ、取ってきてくれ。", "내 그물! 건너편으로 떠내려가. 난 수영을 못 해, 가져다줄래?", "我的网！漂到对岸去了。我不会游泳，你能捞回来吗？")]))

LANTERN = L("a river lantern", "un farolillo de río", "uma lanterna de rio", "une lanterne de rivière", "eine Flusslaterne", "灯籠", "강 등불", "河灯")
Q(quest("sq_river_lanterns", "side", "exploration", "lakeshore", 2, "medium",
    L("Lanterns on the River", "Faroles en el río", "Lanternas no rio", "Lanternes sur la rivière", "Laternen auf dem Fluss", "川の灯籠", "강 위의 등불", "河上灯"),
    L("Ilo keeps an old custom: three paper lanterns set on the river at night, for those the water took.", "Ilo guarda una vieja costumbre: tres farolillos en el río de noche, por los que se llevó el agua.", "Ilo mantém um velho costume: três lanternas no rio à noite, pelos que a água levou.", "Ilo perpétue une vieille coutume : trois lanternes sur la rivière la nuit, pour ceux que l'eau a pris.", "Ilo pflegt einen alten Brauch: drei Papierlaternen nachts auf dem Fluss, für die, die das Wasser nahm.", "イロは古い習わしを守る。水に奪われた人のため、夜の川に三つの灯籠を。", "일로는 옛 풍습을 지킨다. 물에 잃은 이들을 위해 밤의 강에 등불 셋을.", "伊洛守着老规矩：夜里在河上放三盏纸灯，祭奠被水带走的人。"),
    [stage(obj("talk", "NPC_FISHER", T("QO_T_TALK", "NAME_FISHER")),
           talk=[L("Three lanterns: the upper bend, the falls pool, the river mouth. After dark only.", "Tres farolillos: la curva alta, la poza de la cascada, la desembocadura. Solo de noche.", "Três lanternas: a curva alta, o poço da cascata, a foz. Só à noite.", "Trois lanternes : le coude amont, la vasque des chutes, l'embouchure. La nuit seulement.", "Drei Laternen: die obere Biegung, das Fallbecken, die Mündung. Nur nach Einbruch der Nacht.", "三つ：上の曲がり、滝壺、河口。暗くなってからだ。", "셋: 위쪽 굽이, 폭포 웅덩이, 강어귀. 해가 진 뒤에만.", "三盏：上游河湾、瀑布潭、河口。只在天黑后。")],
           rewards={"items": [{"id": "river_lantern", "count": 3}]}),
     stage(obj("interact", "group:river_lights", T("QO_T_NIGHT", L("Set the lanterns on the river", "Pon los farolillos en el río", "Ponha as lanternas no rio", "Posez les lanternes sur la rivière", "Setz die Laternen auf den Fluss", "灯籠を川に浮かべる", "등불을 강에 띄우기", "把灯放到河上")), count=3, hint="area", area_radius=250.0, marker=[-300, 560]),
           spawns=[{"kind": "object", "id": "lantern_spot_%d" % i, "group": "river_lights", "look": "offering", "pos": p, "float": True, "lift": 0.1,
                    "needs_item": "river_lantern", "needs_count": 1, "conditions": {"period": "night"}, "hint_key": "HINT_WRONG_TIME", "prompt": "PROMPT_PLACE", "hide_used": False, "element": "fire", "sound": "ignite"}
                   for i, p in enumerate([[-332, 380], [-282, 590], [-248, 760]])])],
    {"jade": 2, "glimmer": 30, "items": [{"id": "stamina_bloom", "count": 1}]},
    start="talk:NPC_FISHER", requires=["sq_fisher_net"],
    offer_lines=[L("Would you set lanterns on the river with me tonight? My legs are bad for the banks.", "¿Pondrías farolillos en el río esta noche? Mis piernas no aguantan las orillas.", "Poria lanternas no rio hoje à noite? Minhas pernas não aguentam as margens.", "Vous poseriez des lanternes sur la rivière ce soir ? Mes jambes n'aiment pas les berges.", "Setzt du heute Nacht Laternen auf den Fluss? Meine Beine taugen nicht für die Ufer.", "今夜、川に灯籠を流してくれないか。足が岸辺にきつくてな。", "오늘 밤 강에 등불을 띄워 줄래? 다리가 강둑엔 힘들어서.", "今晚帮我在河上放灯好吗？我这腿走不了河岸。")]))

CRATES = L("floating cargo", "carga flotante", "carga flutuante", "cargaison flottante", "treibende Fracht", "漂う積み荷", "떠 있는 짐", "漂浮的货物")
Q(quest("dq_wreck_salvage", "discovery", "traversal", "coast", 2, "short",
    L("Salvage of the Dawn", "El rescate del Alba", "O resgate da Aurora", "Les épaves de l'Aube", "Bergung der Morgenröte", "暁号の引き揚げ", "새벽호의 인양", "拂晓号打捞"),
    L("Crates from the Dawn wreck bob in the surf. The spitters on the hull don't like visitors.", "Cajas del naufragio del Alba flotan en las olas. A los escupidores del casco no les gustan las visitas.", "Caixas do naufrágio da Aurora boiam nas ondas. Os cuspidores do casco não gostam de visitas.", "Des caisses de l'Aube flottent dans les vagues. Les cracheurs sur la coque n'aiment pas les visites.", "Kisten der Morgenröte treiben in der Brandung. Die Speier am Rumpf mögen keinen Besuch.", "暁号の木箱が波間に漂う。船体の吐き虫は客が嫌いだ。", "새벽호의 상자들이 파도에 떠다닌다. 선체의 침뱉이는 손님을 싫어한다.", "拂晓号的货箱在浪里起伏，船壳上的喷吐虫可不欢迎来客。"),
    [stage(obj("retrieve", "group:wreck_crates", T("QO_T_TAKE", CRATES), count=3, hint="area", area_radius=60.0, marker=[130, 828]),
           spawns=[{"kind": "object", "id": "wreck_crate_%d" % i, "group": "wreck_crates", "look": "crate", "pos": p, "float": True, "lift": -0.2, "prompt": "PROMPT_TAKE", "radius": 2.2,
                    "reward": {"glimmer": 25}}
                   for i, p in enumerate([[140, 832], [102, 842], [162, 818]])])],
    {"jade": 1, "items": [{"id": "iron_ingot", "count": 2}, {"id": "resin_bomb", "count": 2}]},
    start="poi:dawn_wreck"))

Q(quest("dq_tower_bell", "discovery", "exploration", "lakeshore", 1, "short",
    L("The Broken Tower's Bell", "La campana de la Torre Rota", "O sino da Torre Partida", "La cloche de la Tour brisée", "Die Glocke des Zerbrochenen Turms", "崩れ塔の鐘", "부서진 탑의 종", "断塔之钟"),
    L("A bronze bell still hangs in the Broken Tower. Wardens rang it to call the wind — and to see far.", "Una campana de bronce cuelga aún en la Torre Rota. Los Guardianes la tocaban para llamar al viento y ver lejos.", "Um sino de bronze ainda pende na Torre Partida. Os Guardiões o tocavam para chamar o vento e ver longe.", "Une cloche de bronze pend encore dans la Tour brisée. Les Gardiens la sonnaient pour appeler le vent — et voir loin.", "Im Zerbrochenen Turm hängt noch eine Bronzeglocke. Hüter läuteten sie, um den Wind zu rufen — und weit zu sehen.", "崩れ塔に青銅の鐘が残る。守り人は風を呼び、遠くを見るために鳴らした。", "부서진 탑에 청동 종이 아직 걸려 있다. 지기들은 바람을 부르고 멀리 보려 울렸다.", "断塔里还挂着一口铜钟。守风者敲它唤风，也借此远望。"),
    [stage(obj("interact", "tower_bell", T("QO_T_RING", L("the Warden bell", "la campana del Guardián", "o sino do Guardião", "la cloche du Gardien", "die Hüterglocke", "守り人の鐘", "지기의 종", "守风者之钟"))))],
    {"jade": 1, "reveal": [{"pos": [-400, 70], "radius": 6}, {"pos": [-330, 420], "radius": 5}]},
    start="interact:tower_bell",
    spawns=[{"kind": "object", "id": "tower_bell", "look": "bell", "poi": "broken_tower", "pos": [-1.2, -0.8], "snap": "top", "min_y": 9.0, "when": "always", "hide_used": False, "prompt": "PROMPT_RING", "sound": "discovery", "element": "wind", "range": 220,
             "lines": [L("The note rolls over the lake. For a moment the whole shore is clear to see.", "La nota rueda sobre el lago. Por un momento toda la orilla se ve clara.", "A nota rola sobre o lago. Por um momento toda a margem fica visível.", "La note roule sur le lac. Un instant, toute la rive est limpide.", "Der Ton rollt über den See. Einen Moment lang ist das ganze Ufer klar zu sehen.", "音が湖を渡る。一瞬、岸辺がすべて見渡せた。", "종소리가 호수 위로 굴러간다. 잠시 온 물가가 또렷이 보인다.", "钟声滚过湖面，一时间整片湖岸清晰可见。")]}]))

Q(quest("dq_smugglers_cove", "discovery", "combat", "coast", 2, "short",
    L("Smugglers' Cove", "La cala de los contrabandistas", "A enseada dos contrabandistas", "La crique des contrebandiers", "Die Schmugglerbucht", "密輸人の入り江", "밀수꾼의 만", "走私者洞湾"),
    L("Thornlings have moved into the smugglers' old grotto. The smugglers' hoard is still inside.", "Los espinudos ocuparon la vieja gruta de los contrabandistas. Su botín sigue dentro.", "Espinhosos ocuparam a velha gruta dos contrabandistas. O tesouro ainda está lá.", "Des ronceux ont envahi la vieille grotte des contrebandiers. Leur magot est toujours dedans.", "Dornlinge hausen in der alten Schmugglergrotte. Der Schatz liegt noch drin.", "密輸人の古い洞にトゲ獣が住み着いた。隠し財宝はまだ中に。", "밀수꾼의 옛 동굴에 가시짐승이 들어앉았다. 보물은 아직 안에 있다.", "棘兽占了走私者的旧洞，宝藏还在里面。"),
    [stage(obj("clear", "cove_squatters", T("QO_T_CLEAR", "NAME_THORNLING"), count=4, marker=[-600, 520]),
           spawns=[{"kind": "creature", "entity": "ENEMY_THORNLING", "group": "cove_squatters", "pos": [-600, 522], "count": 4, "spread": 5}]),
     stage(obj("open_chest", "smugglers_cove:hoard", T("QO_T_OPEN", L("the smugglers' hoard", "el botín", "o tesouro", "le magot", "den Schatz", "密輸人の財宝", "밀수꾼의 보물", "走私者的宝藏")), marker=[-600, 520]))],
    {"jade": 1, "glimmer": 30},
    start="poi:smugglers_cove"))

Q(quest("sq_sunken_hall", "discovery", "exploration", "lakeshore", 2, "short", "QUEST_SUNKEN", "QUEST_SUNKEN_DESC",
    [stage(obj("discover", "sunken_hall", "QO_FIND_SUNKEN")),
     stage(obj("open_chest", "sunken_hall:cache", "QO_SUNKEN_CACHE", marker=[-466, -165]))],
    {"glimmer": 35, "items": [{"id": "forge_stone", "count": 1}]},
    start="event"))

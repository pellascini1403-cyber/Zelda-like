"""Bounties (repeatable, offered by boards with daily rotation and
anti-repetition) and challenges (wind-ring courses with par times, a
combat trial). Quick 5-minute activities for mobile sessions."""
from qdsl import L, T, quest, stage, obj

QUESTS = []
Q = QUESTS.append


def bounty(qid, board, category, region, diff, title, desc, stages, rewards, **kw):
    return quest(qid, "bounty", category, region, diff, "short", title, desc, stages, rewards,
                 start="board", board=board, repeatable=True, cooldown_hours=20.0, **kw)


Q(bounty("bq_thorn_pack", "hamlet", "combat", "valley", 2,
    L("Bounty: Thorn Pack", "Encargo: manada espinuda", "Tarefa: matilha espinhosa", "Prime : meute de ronceux", "Kopfgeld: Dornenrudel", "賞金：トゲ獣の群れ", "현상금: 가시짐승 무리", "悬赏：棘兽群"),
    L("A thornling pack is harrying the east fields. Drive it off.", "Una manada espinuda acosa los campos del este. Ahuyéntala.", "Uma matilha espinhosa ataca os campos do leste. Afaste-a.", "Une meute de ronceux harcèle les champs de l'est. Chassez-la.", "Ein Dornenrudel plagt die Ostfelder. Vertreib es.", "トゲ獣の群れが東の畑を荒らす。追い払え。", "가시짐승 무리가 동쪽 밭을 괴롭힌다. 쫓아내라.", "一群棘兽在东田作乱，把它们赶走。"),
    [stage(obj("clear", "bq_thorns", T("QO_T_CLEAR", "NAME_THORNLING"), count=4, marker=[230, 60]),
           spawns=[{"kind": "creature", "entity": "ENEMY_THORNLING", "group": "bq_thorns", "pos": [230, 60], "count": 4, "spread": 6}])],
    {"glimmer": 40, "jade": 1}))

Q(bounty("bq_wisp_night", "hamlet", "combat", "valley", 2,
    L("Bounty: Night Wisps", "Encargo: fuegos fatuos nocturnos", "Tarefa: fogos-fátuos noturnos", "Prime : feux follets nocturnes", "Kopfgeld: Nachtirrlichter", "賞金：夜の鬼火", "현상금: 밤의 도깨비불", "悬赏：夜间鬼火"),
    L("Wisps sting the night herds. Their filament fetches a good price, too.", "Los fuegos fatuos pican a los rebaños de noche. Su filamento además se paga bien.", "Fogos-fátuos picam os rebanhos à noite. O filamento deles também vale bem.", "Les feux follets piquent les troupeaux la nuit. Leur filament se vend bien.", "Irrlichter stechen nachts die Herden. Ihr Faden bringt auch gutes Geld.", "鬼火が夜の家畜を刺す。糸もいい値で売れる。", "도깨비불이 밤에 가축을 쏜다. 실도 값이 좋다.", "鬼火夜里蜇伤牲口，它们的丝也值钱。"),
    [stage(obj("kill", "ENEMY_WISP", L("Defeat wisps (at night)", "Derrota fuegos fatuos (de noche)", "Derrote fogos-fátuos (à noite)", "Vaincre des feux follets (la nuit)", "Besiege Irrlichter (nachts)", "鬼火を倒す（夜に）", "도깨비불 처치 (밤에)", "击败鬼火（夜间）"), count=3, conditions={"period": "night"}, hint="none"))],
    {"glimmer": 45}))

SPITNESTS = L("the spitter nests", "los nidos de escupidores", "os ninhos de cuspidores", "les nids de cracheurs", "die Speiernester", "吐き虫の巣", "침뱉이 둥지", "喷吐虫巢")
Q(bounty("bq_spitter_nests", "lodge", "combat", "forest", 2,
    L("Bounty: Spitter Nests", "Encargo: nidos de escupidores", "Tarefa: ninhos de cuspidores", "Prime : nids de cracheurs", "Kopfgeld: Speiernester", "賞金：吐き虫の巣", "현상금: 침뱉이 둥지", "悬赏：喷吐虫巢"),
    L("Two spitter nests have sprouted by the lodge trail. Burn them out.", "Dos nidos de escupidores brotaron junto al sendero del refugio. Quémalos.", "Dois ninhos de cuspidores surgiram perto da trilha do abrigo. Queime-os.", "Deux nids de cracheurs ont poussé près du sentier de la loge. Brûlez-les.", "Zwei Speiernester am Hüttenpfad. Brenn sie aus.", "小屋の道沿いに吐き虫の巣が二つ。焼き払え。", "오두막 길가에 침뱉이 둥지 둘. 태워 버려라.", "小屋小路旁冒出两个喷吐虫巢，烧掉它们。"),
    [stage(obj("destroy", "group:bq_spit_nests", T("QO_T_DESTROY", SPITNESTS), count=2, marker=[470, 125], hint="area", area_radius=50.0),
           spawns=[{"kind": "nest", "id": "bq_spit_%d" % i, "group": "bq_spit_nests", "nest": "spitter", "pos": p, "hp": 60, "spawn": "ENEMY_SPITTER", "spawn_every": 15, "spawn_max": 1, "element": "fire"}
                   for i, p in enumerate([[462, 118], [492, 138]])])],
    {"glimmer": 50, "jade": 1}))

Q(bounty("bq_hunt_woolhorn", "lodge", "gathering", "forest", 1,
    L("Bounty: Meat for the Lodge", "Encargo: carne para el refugio", "Tarefa: carne para o abrigo", "Prime : viande pour la loge", "Kopfgeld: Fleisch für die Hütte", "賞金：小屋の肉", "현상금: 오두막의 고기", "悬赏：小屋的肉"),
    L("Varra's smokehouse is empty. Two cuts of meat, fresh.", "El ahumadero de Varra está vacío. Dos piezas de carne, frescas.", "O defumadouro de Varra está vazio. Duas peças de carne, frescas.", "Le fumoir de Varra est vide. Deux pièces de viande, fraîches.", "Varras Räucherkammer ist leer. Zwei frische Fleischstücke.", "ヴァラの燻製小屋が空だ。新鮮な肉を二切れ。", "바라의 훈제실이 비었다. 신선한 고기 두 덩이.", "瓦拉的熏房空了，要两块新鲜肉。"),
    [stage(obj("deliver", "NPC_HUNTER", T("QO_T_GIVE", "ITEM_RAW_MEAT", "NAME_HUNTER"), item="raw_meat", count=2),
           talk=[L("Good cuts. The smokehouse thanks you.", "Buenas piezas. El ahumadero te lo agradece.", "Boas peças. O defumadouro agradece.", "Beaux morceaux. Le fumoir vous remercie.", "Gute Stücke. Die Räucherkammer dankt.", "いい肉だ。燻製小屋が礼を言う。", "좋은 고기군. 훈제실이 고마워한다.", "好肉，熏房谢你了。")])],
    {"glimmer": 35, "items": [{"id": "fang_pepper", "count": 2}]}))

Q(bounty("bq_oasis_raid", "oasis", "combat", "desert", 3,
    L("Bounty: Raid on the Water", "Encargo: asalto al agua", "Tarefa: ataque à água", "Prime : raid sur l'eau", "Kopfgeld: Überfall am Wasser", "賞金：水場の襲撃", "현상금: 물가 습격", "悬赏：水源袭击"),
    L("Scuttlers are raiding the water carriers at the oasis edge. Keep the carrier alive.", "Los escarbadores asaltan a los aguadores en el borde del oasis. Mantén vivo al aguador.", "Escavadores atacam os carregadores de água na borda do oásis. Mantenha o carregador vivo.", "Des fouisseurs attaquent les porteurs d'eau au bord de l'oasis. Gardez le porteur en vie.", "Scharrer überfallen die Wasserträger am Oasenrand. Halte den Träger am Leben.", "オアシスの縁で水運びが砂這いに襲われる。守り抜け。", "오아시스 가장자리에서 물 나르는 이가 모래기어에 습격당한다. 지켜라.", "掘沙虫在绿洲边袭击挑水人，保护好他。"),
    [stage(obj("protect", "bq_water_raid", T("QO_T_PROTECT", "NAME_TRAVELER"), marker=[1050, 280]),
           spawns=[{"kind": "encounter", "id": "bq_water_raid", "mode": "protect", "pos": [1050, 280], "actor": "NPC_TRAVELER", "actor_hp": 120, "once": False, "trigger_radius": 22, "element": "sand",
                    "waves": [{"entity": "ENEMY_SCUTTLER", "count": 3, "dist": 13}, {"entity": "ENEMY_SCUTTLER", "count": 3, "dist": 15, "delay": 3}]}])],
    {"glimmer": 60, "jade": 1}))

Q(bounty("bq_scuttler_cull", "oasis", "combat", "desert", 2,
    L("Bounty: Scuttler Cull", "Encargo: exterminio de escarbadores", "Tarefa: abate de escavadores", "Prime : battue de fouisseurs", "Kopfgeld: Scharrerjagd", "賞金：砂這い狩り", "현상금: 모래기어 소탕", "悬赏：清剿掘沙虫"),
    L("Too many scuttlers near the trade routes. Thin them out.", "Demasiados escarbadores cerca de las rutas. Reduce su número.", "Escavadores demais nas rotas. Diminua o número.", "Trop de fouisseurs près des routes. Éclaircissez leurs rangs.", "Zu viele Scharrer an den Handelsrouten. Dünn sie aus.", "交易路に砂這いが多すぎる。数を減らせ。", "교역로에 모래기어가 너무 많다. 수를 줄여라.", "商路附近掘沙虫太多，削减它们。"),
    [stage(obj("kill", "ENEMY_SCUTTLER", T("QO_T_DEFEAT", "NAME_SCUTTLER"), count=5, hint="none"))],
    {"glimmer": 50, "items": [{"id": "cooling_salad", "count": 1}]}))

Q(bounty("bq_shade_hunt", "veil", "combat", "veil", 3,
    L("Bounty: Shade Hunt", "Encargo: caza de sombras", "Tarefa: caça às sombras", "Prime : chasse aux ombres", "Kopfgeld: Schattenjagd", "賞金：影狩り", "현상금: 그림자 사냥", "悬赏：猎影"),
    L("Every shade felled pushes the hush back a step.", "Cada sombra abatida hace retroceder el silencio un paso.", "Cada sombra abatida faz o silêncio recuar um passo.", "Chaque ombre abattue repousse le silence d'un pas.", "Jeder gefallene Schatten drängt die Stille einen Schritt zurück.", "影を一つ倒すたび、静寂が一歩退く。", "그림자 하나를 쓰러뜨릴 때마다 침묵이 한 걸음 물러난다.", "每倒下一道暗影，寂静便退一步。"),
    [stage(obj("kill", "ENEMY_SHADE", T("QO_T_DEFEAT", "NAME_SHADE"), count=3, hint="none"))],
    {"glimmer": 60, "jade": 1}))

Q(bounty("bq_hush_vigil", "veil", "combat", "veil", 3,
    L("Bounty: Vigil at the Shrine", "Encargo: vigilia en el santuario", "Tarefa: vigília no santuário", "Prime : veille au sanctuaire", "Kopfgeld: Wache am Schrein", "賞金：祠の夜番", "현상금: 사당의 불침번", "悬赏：神祠守夜"),
    L("The hush surges against the Hushed Shrine again. Hold it for the pilgrims.", "El silencio vuelve a embestir el Santuario silente. Resiste por los peregrinos.", "O silêncio avança de novo contra o Santuário silente. Resista pelos peregrinos.", "Le silence assaille de nouveau le Sanctuaire muet. Tenez bon pour les pèlerins.", "Die Stille brandet wieder gegen den Stillen Schrein. Halte ihn für die Pilger.", "静寂がまた静寂の祠に押し寄せる。巡礼者のために守れ。", "침묵이 다시 침묵의 사당으로 밀려든다. 순례자를 위해 버텨라.", "寂静再度冲击神祠，为朝圣者守住它。"),
    [stage(obj("survive", "bq_vigil", T("QO_T_SURVIVE", "POI_VEIL_SHRINE"), marker=[700, -720]),
           spawns=[{"kind": "encounter", "id": "bq_vigil", "mode": "survive", "pos": [700, -720], "radius": 16, "duration": 45, "interval": 8, "max_alive": 4, "trigger_radius": 14, "once": False, "element": "still",
                    "waves": [{"entity": "ENEMY_SHADE", "count": 1, "dist": 14}, {"entity": "ENEMY_WISP", "count": 2, "dist": 14}]}])],
    {"glimmer": 70, "jade": 1}))

# --- Challenges ------------------------------------------------------------------------------------------------


def course_challenge(qid, region, diff, title, desc, course, par, first, par_reward, course_name, **kw):
    cid = course["id"]
    return quest(qid, "challenge", "challenge", region, diff, "short", title, desc,
                 [stage(obj("course", cid, T("QO_T_COURSE", course_name))),
                  stage(obj("course", cid, T("QO_T_COURSE_PAR", course_name, str(par)), par=float(par)), rewards=par_reward)],
                 first, start="event", spawns=[dict(course, when="always", banner=course_name, par=float(par))], **kw)


RIDGE = L("the Overlook Dive", "el Descenso del Mirador", "o Mergulho do Mirante", "le Plongeon du Belvédère", "den Aussichtssturz", "展望台の急降下", "전망대 하강", "观景台俯冲")
Q(course_challenge("ch_overlook_dive", "highlands", 2,
    L("The Overlook Dive", "El Descenso del Mirador", "O Mergulho do Mirante", "Le Plongeon du Belvédère", "Der Aussichtssturz", "展望台の急降下", "전망대 하강", "观景台俯冲"),
    L("Wind rings trail down from the Wind Overlook. Ride the updraft, then dive through them.", "Anillos de viento bajan desde el Mirador del Viento. Sube con la corriente y lánzate a través.", "Anéis de vento descem do Mirante do Vento. Suba na corrente e mergulhe por eles.", "Des anneaux de vent descendent du Belvédère. Montez avec le courant, puis plongez au travers.", "Windringe führen von der Windaussicht hinab. Reite den Aufwind und stürz dich hindurch.", "風の展望台から風の輪が続く。上昇気流に乗り、くぐり抜けろ。", "바람 전망대에서 바람 고리가 이어진다. 상승기류를 타고 통과하라.", "风之环从观景台一路向下。乘上升气流，俯冲穿过。"),
    {"id": "overlook_dive", "kind": "course", "mode": "glide", "absolute": True, "ring_radius": 4.5, "range": 350,
     "rings": [[-130, -318, 80.0], [-130, -295, 74.5], [-128, -270, 69.0], [-124, -245, 63.5], [-118, -220, 58.0], [-110, -195, 52.5], [-100, -170, 47.0], [-90, -145, 41.5]]},
    22, {"jade": 1, "glimmer": 30}, {"jade": 2}, RIDGE))

BLUFF = L("the Gull Bluff Rings", "los Anillos del Risco", "os Anéis do Penhasco", "les Anneaux de la Falaise", "die Möwenklippenringe", "鴎の崖の輪", "갈매기 절벽 고리", "鸥崖风环")
Q(course_challenge("ch_bluff_rings", "coast", 2,
    L("Gull Bluff Rings", "Anillos del Risco de las gaviotas", "Anéis do Penhasco das gaivotas", "Anneaux de la Falaise aux mouettes", "Möwenklippenringe", "鴎の崖の輪", "갈매기 절벽 고리", "鸥崖风环"),
    L("From the bluff out over the sea: six rings, and the water waiting below.", "Del risco hacia el mar: seis anillos y el agua esperando abajo.", "Do penhasco para o mar: seis anéis e a água esperando abaixo.", "De la falaise vers la mer : six anneaux, et l'eau qui attend en bas.", "Von der Klippe aufs Meer: sechs Ringe, unten wartet das Wasser.", "崖から海へ。輪は六つ、下では水が待つ。", "절벽에서 바다로: 고리 여섯, 아래엔 물이 기다린다.", "从崖上飞向大海：六个风环，下面是海水。"),
    {"id": "bluff_rings", "kind": "course", "mode": "glide", "absolute": True, "ring_radius": 4.5, "range": 300,
     "rings": [[310, 712, 33.0], [325, 730, 27.5], [342, 748, 22.0], [360, 765, 16.5], [378, 782, 11.0], [396, 800, 5.5]]},
    16, {"jade": 1, "glimmer": 30}, {"jade": 2}, BLUFF, requires=["mq_coast_beacon"]))

ROAD = L("the Shrine Road Sprint", "la Carrera del Santuario", "a Corrida do Santuário", "le Sprint du Sanctuaire", "den Schreinweg-Sprint", "祠の道の疾走", "사당길 질주", "神祠路疾跑")
Q(course_challenge("ch_shrine_sprint", "valley", 1,
    L("Shrine Road Sprint", "Carrera del camino del santuario", "Corrida da estrada do santuário", "Sprint de la route du sanctuaire", "Schreinweg-Sprint", "祠の道の疾走", "사당길 질주", "神祠路疾跑"),
    L("Hamlet children race to the wayside shrine through these rings. Beat their record.", "Los niños de la aldea corren hasta el santuario por estos anillos. Supera su récord.", "As crianças da aldeia correm até o santuário por estes anéis. Bata o recorde delas.", "Les enfants du hameau courent au sanctuaire par ces anneaux. Battez leur record.", "Die Dorfkinder rennen durch diese Ringe zum Wegschrein. Schlag ihren Rekord.", "村の子らはこの輪をくぐって祠まで競走する。記録を破れ。", "마을 아이들은 이 고리를 지나 사당까지 달린다. 기록을 깨라.", "村里孩子穿过这些环跑到路边神祠，破他们的纪录。"),
    {"id": "shrine_sprint", "kind": "course", "mode": "run", "h": 1.8, "ring_radius": 3.5, "range": 250,
     "rings": [[70, 190], [95, 215], [120, 240], [135, 265], [150, 285]]},
    14, {"glimmer": 25, "jade": 1}, {"jade": 1, "items": [{"id": "swift_soup", "count": 2}]}, ROAD, requires=["mq_vela"]))

LAKE = L("the Lily Crossing", "la Travesía de los Lirios", "a Travessia dos Lírios", "la Traversée des Lys", "die Lilienquerung", "睡蓮渡り", "연꽃 건너기", "睡莲横渡")
Q(course_challenge("ch_lily_crossing", "lakeshore", 2,
    L("The Lily Crossing", "La travesía de los lirios", "A travessia dos lírios", "La traversée des lys", "Die Lilienquerung", "睡蓮渡り", "연꽃 건너기", "睡莲横渡"),
    L("Floating rings from Ilo's landing to Lily Isle. Swim fast; the lake is colder than it looks.", "Anillos flotantes del embarcadero de Ilo a la Isla de los Lirios. Nada rápido; el lago está más frío de lo que parece.", "Anéis flutuantes do cais de Ilo até a Ilha dos Lírios. Nade rápido; o lago é mais frio do que parece.", "Des anneaux flottants du ponton d'Ilo à l'Île aux Lys. Nagez vite ; le lac est plus froid qu'il n'y paraît.", "Schwimmende Ringe von Ilos Anlegestelle zur Lilieninsel. Schwimm schnell; der See ist kälter, als er aussieht.", "イロの船着き場から睡蓮の小島まで浮かぶ輪。速く泳げ、見た目より冷たい。", "일로의 나루에서 연꽃 섬까지 떠 있는 고리. 빨리 헤엄쳐, 보기보다 차갑다.", "从伊洛渡口到睡莲小岛的浮环。游快点，湖水比看起来冷。"),
    {"id": "lily_crossing", "kind": "course", "mode": "swim", "h": 0.8, "ring_radius": 3.8, "range": 260,
     "rings": [[-272, 96], [-318, 84], [-364, 72], [-422, 62]]},
    45, {"glimmer": 30, "jade": 1}, {"jade": 1, "items": [{"id": "vigor_broth", "count": 2}]}, LAKE, requires=["sq_fisher_net"]))

GALLOP = L("the Strider Circuit", "el Circuito del Zancudo", "o Circuito do Corredor", "le Circuit de l'Échassier", "den Schreiterkurs", "駆け獣の周回", "질주수 순회", "疾兽环道")
Q(course_challenge("ch_strider_circuit", "valley", 2,
    L("The Strider Circuit", "El circuito del zancudo", "O circuito do corredor", "Le circuit de l'échassier", "Der Schreiterkurs", "駆け獣の周回", "질주수 순회", "疾兽环道"),
    L("A mounted loop around the windstrider meadows. Only a rider can make the time.", "Un circuito a lomos alrededor de los prados de los zancudos. Solo un jinete logra el tiempo.", "Um circuito montado pelos prados dos corredores. Só um cavaleiro faz o tempo.", "Une boucle à monture autour des prés des échassiers. Seul un cavalier tient le temps.", "Eine Reitrunde um die Schreiterwiesen. Nur ein Reiter schafft die Zeit.", "駆け獣の草原を回る騎乗コース。乗り手だけがこの時間を出せる。", "질주수 초원을 도는 기승 코스. 기수만이 이 기록을 낸다.", "绕疾兽草场的骑乘环道，只有骑手能跑进时限。"),
    {"id": "strider_circuit", "kind": "course", "mode": "ride", "h": 2.0, "ring_radius": 4.2, "range": 260,
     "rings": [[280, 130], [320, 90], [300, 30], [240, 20], [200, 70], [232, 122]]},
    35, {"glimmer": 40, "jade": 1}, {"jade": 2}, GALLOP, requires_flags=["mount_windstrider"]))

GONG = L("the trial gong", "el gong de la prueba", "o gongo da prova", "le gong de l'épreuve", "den Prüfungsgong", "試練の銅鑼", "시련의 징", "试炼铜锣")
Q(quest("ch_terrace_trial", "challenge", "challenge", "highlands", 4, "short",
    L("Trial of the Terrace", "La prueba de la terraza", "A prova do terraço", "L'épreuve de la terrasse", "Die Prüfung der Terrasse", "台の試練", "테라스의 시련", "云台试炼"),
    L("With Thornback gone, the temple gong waits again. Strike it and hold the court for ninety breaths.", "Sin el Lomoespino, el gong del templo espera de nuevo. Tócalo y resiste en el patio noventa respiros.", "Sem o Dorso-espinho, o gongo do templo espera outra vez. Toque e resista no pátio por noventa fôlegos.", "Sans Dos-de-ronces, le gong du temple attend. Frappez-le et tenez la cour quatre-vingt-dix souffles.", "Ohne Dornrücken wartet der Tempelgong wieder. Schlag ihn und halte den Hof neunzig Atemzüge.", "トゲ背が去り、寺の銅鑼がまた待つ。打ち鳴らし、九十の息のあいだ庭を守れ。", "가시등이 사라지자 사원의 징이 다시 기다린다. 울리고 아흔 호흡 동안 뜰을 지켜라.", "刺背兽已除，神殿铜锣又在等人。敲响它，在庭中坚守九十息。"),
    [stage(obj("interact", "trial_gong", T("QO_T_RING", GONG))),
     stage(obj("survive", "terrace_trial", T("QO_T_SURVIVE", "POI_CLOUD_TEMPLE"), marker=[0, -300]),
           spawns=[{"kind": "encounter", "id": "terrace_trial", "mode": "survive", "pos": [0, -300], "radius": 18, "duration": 90, "interval": 7, "max_alive": 5, "trigger_radius": 30, "element": "thorn",
                    "banner": L("Trial of the Terrace", "Prueba de la terraza", "Prova do terraço", "Épreuve de la terrasse", "Terrassenprüfung", "台の試練", "테라스의 시련", "云台试炼"),
                    "waves": [{"entity": "ENEMY_THORNLING", "count": 3, "dist": 14}, {"entity": "ENEMY_SPITTER", "count": 1, "dist": 16}, {"entity": "ENEMY_BULWARK", "count": 1, "dist": 15}, {"entity": "ENEMY_THORNLING", "count": 2, "dist": 14}]}])],
    {"jade": 2, "glimmer": 80, "max_health": 20},
    start="interact:trial_gong", requires_flags=["boss_BOSS_THORNBACK"],
    spawns=[{"kind": "object", "id": "trial_gong", "look": "bell", "poi": "cloud_temple", "pos": [6, 4], "snap": "top", "min_y": 66.0, "when": "open", "once": False, "hide_used": False, "prompt": "PROMPT_RING", "sound": "discovery", "element": "wind", "range": 200}]))

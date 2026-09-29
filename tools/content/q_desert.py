"""Sunscar desert: water for the nomads, glass harvesting, burrows that only
explosives clear, obelisks that exist only in sandstorms, a relic only the
Wind Sight reveals, and a glass predator that hunts by moonlight."""
from qdsl import L, T, quest, stage, obj

QUESTS = []
Q = QUESTS.append

Q(quest("sq_nomad_water", "side", "gathering", "desert", 1, "short", "QUEST_NOMAD_WATER", "QUEST_NOMAD_WATER_DESC",
    [stage(obj("collect", "sunpear", "QO_COLLECT_SUNPEARS", count=4)),
     stage(obj("talk", "NPC_NOMAD", "QO_RETURN_NOMAD", marker=[1012, 304]), talk_lines=["DLG_SQ_NOMAD_DONE"])],
    {"items": [{"id": "cooling_salad", "count": 3}], "glimmer": 45},
    start="talk:NPC_NOMAD", requires=["mq_sand_road"], offer_lines=["DLG_SQ_NOMAD_OFFER_1", "DLG_SQ_NOMAD_OFFER_2"]))

Q(quest("sq_glass_harvest", "side", "gathering", "desert", 2, "medium",
    L("Glass Harvest", "Cosecha de vidrio", "Colheita de vidro", "Récolte de verre", "Glasernte", "玻璃の収穫", "유리 수확", "琉璃采收"),
    L("Tobb means to trade sun-glass on the coast. Lightning leaves it in the dunes, if you can stand the heat.", "Tobb quiere vender vidrio solar en la costa. Los rayos lo dejan en las dunas, si aguantas el calor.", "Tobb quer vender vidro-sol na costa. Os raios o deixam nas dunas, se você aguentar o calor.", "Tobb veut vendre du verre solaire sur la côte. La foudre en laisse dans les dunes, si vous tenez la chaleur.", "Tobb will Sonnenglas an der Küste handeln. Blitze hinterlassen es in den Dünen — wenn du die Hitze aushältst.", "トッブは日輪硝子を海岸で売りたい。雷が砂丘に残す。暑さに耐えられれば。", "톱은 해안에서 태양 유리를 팔려 한다. 번개가 모래언덕에 남긴다, 더위를 견디면.", "托布想把日琉璃卖到海边。雷电把它留在沙丘里，就看你扛不扛得住热。"),
    [stage(obj("gather", "glass_outcrop", T("QO_T_GATHER", L("glass outcrops", "afloramientos de vidrio", "afloramentos de vidro", "affleurements de verre", "Glasadern", "玻璃の露頭", "유리 노두", "琉璃矿脉")), count=3, hint="area", area_radius=250.0, marker=[1150, 300])),
     stage(obj("deliver", "NPC_CARAVAN", T("QO_T_GIVE", "ITEM_GLASS_SHARD", "NAME_CARAVAN"), item="glass_shard", count=2),
           talk=[L("Clear as water. The coast will pay double — and you'll get your share now.", "Claro como el agua. En la costa pagarán el doble, y tu parte te la doy ya.", "Claro como água. Na costa pagam o dobro, e sua parte você leva agora.", "Clair comme l'eau. La côte paiera double — et votre part, tout de suite.", "Klar wie Wasser. Die Küste zahlt das Doppelte — und deinen Anteil kriegst du jetzt.", "水のように澄んでる。海岸なら倍だ。お前の取り分は今やる。", "물처럼 맑군. 해안에선 두 배야. 네 몫은 지금 주지.", "清得像水。海边能卖双倍，你那份现在就给。")])],
    {"glimmer": 90, "jade": 1},
    start="talk:NPC_CARAVAN", requires=["mq_caravan"],
    offer_lines=[L("Sun-glass sells like water on the coast. Bring me two shards and I'll cut you in.", "El vidrio solar se vende como agua en la costa. Tráeme dos esquirlas y te doy tu parte.", "O vidro-sol vende como água na costa. Traga dois cacos e você entra na parte.", "Le verre solaire se vend comme l'eau sur la côte. Deux éclats, et vous êtes associé.", "Sonnenglas verkauft sich an der Küste wie Wasser. Zwei Splitter, dann bist du beteiligt.", "日輪硝子は海岸で飛ぶように売れる。二欠片持ってくれば分け前をやる。", "태양 유리는 해안에서 물처럼 팔려. 조각 둘 가져오면 한몫 주지.", "日琉璃在海边好卖得很。拿两片来，分你一份。")]))

BURROWS = L("the scuttler burrows", "las madrigueras de escarbadores", "as tocas de escavadores", "les terriers de fouisseurs", "die Scharrerbauten", "砂這いの巣穴", "모래기어 굴", "掘沙虫穴")
Q(quest("sq_scuttler_burrows", "side", "combat", "desert", 3, "medium",
    L("Burrows by the Road", "Madrigueras junto al camino", "Tocas perto da estrada", "Des terriers près de la route", "Bauten an der Straße", "道沿いの巣穴", "길가의 굴", "路边虫穴"),
    L("Scuttlers are breeding beside the sand road. Blades barely dent their burrows; bombs don't.", "Los escarbadores crían junto al camino de arena. Las hojas apenas mellan sus madrigueras; las bombas sí.", "Escavadores se reproduzem junto à estrada. Lâminas mal arranham as tocas; bombas não.", "Des fouisseurs se multiplient près de la route. Les lames entament à peine leurs terriers ; les bombes, si.", "Scharrer brüten an der Sandstraße. Klingen kratzen kaum an ihren Bauten, Bomben schon.", "砂の道の脇で砂這いが増えている。刃は巣穴に効かないが、爆弾は効く。", "모래 길 옆에서 모래기어가 번식한다. 칼은 굴에 흠집만 내지만 폭탄은 통한다.", "掘沙虫在沙路旁繁殖。刀砍不动虫穴，炸药可以。"),
    [stage(obj("destroy", "group:burrows", T("QO_T_DESTROY", BURROWS), count=3, hint="area", area_radius=70.0, marker=[880, 285]),
           spawns=[{"kind": "nest", "id": "burrow_%d" % i, "group": "burrows", "nest": "burrow", "pos": p, "hp": 50, "melee": 0.1, "weak": {"fire": 1.0, "explosion": 4.0},
                    "spawn": "ENEMY_SCUTTLER", "spawn_every": 11, "spawn_max": 2, "element": "sand", "hint_key": "HINT_RUBBLE", "drops": [{"id": "scuttler_chitin", "count": 2}]}
                   for i, p in enumerate([[860, 250], [880, 330], [902, 282]])]),
     stage(obj("talk", "NPC_GUARD", T("QO_T_RETURN", "NAME_GUARD")),
           talk=[L("Road's clear. Take these bombs — you clearly know what to do with them.", "Camino despejado. Toma estas bombas, está claro que sabes usarlas.", "Estrada livre. Tome estas bombas, você claramente sabe usá-las.", "Route dégagée. Prenez ces bombes, vous savez visiblement vous en servir.", "Straße frei. Nimm die Bomben — du weißt offensichtlich, was man damit macht.", "道が空いた。爆弾をやる、使い方は分かってるようだしな。", "길이 뚫렸군. 폭탄 가져가, 쓸 줄 아는 게 분명하니.", "路通了。炸弹给你，看得出你会用。")])],
    {"items": [{"id": "resin_bomb", "count": 4}], "jade": 2, "glimmer": 40},
    start="talk:NPC_GUARD", requires=["mq_sand_road"],
    offer_lines=[L("Three burrows by the road, scuttlers pouring out. My spear just bounces. Got bombs?", "Tres madrigueras junto al camino, salen escarbadores sin parar. Mi lanza rebota. ¿Tienes bombas?", "Três tocas na estrada, escavadores sem parar. Minha lança só quica. Tem bombas?", "Trois terriers au bord de la route, des fouisseurs à foison. Ma lance rebondit. Des bombes ?", "Drei Bauten an der Straße, Scharrer ohne Ende. Mein Speer prallt ab. Bomben dabei?", "道沿いに巣穴が三つ、砂這いがわんさか。槍が弾かれる。爆弾あるか？", "길가에 굴이 셋, 모래기어가 쏟아져. 내 창은 튕겨 나가. 폭탄 있나?", "路边三个虫穴，掘沙虫涌个不停，我的矛都弹开了。有炸药吗？")]))

OBELISK = L("the mirage obelisks", "los obeliscos del espejismo", "os obeliscos da miragem", "les obélisques du mirage", "die Trugbild-Obelisken", "蜃気楼の方尖塔", "신기루 오벨리스크", "蜃影方尖碑")
Q(quest("dq_mirage_obelisks", "discovery", "exploration", "desert", 3, "medium",
    L("Obelisks in the Storm", "Obeliscos en la tormenta", "Obeliscos na tempestade", "Obélisques dans la tempête", "Obelisken im Sturm", "嵐の中の方尖塔", "폭풍 속 오벨리스크", "风暴中的方尖碑"),
    L("During sandstorms, tall shapes stand in the dunes where nothing stands on clear days.", "Durante las tormentas de arena, figuras altas se alzan en las dunas donde en días claros no hay nada.", "Nas tempestades de areia, formas altas surgem nas dunas onde, em dias claros, não há nada.", "Pendant les tempêtes de sable, de hautes formes se dressent là où rien ne se tient par temps clair.", "In Sandstürmen stehen hohe Gestalten in den Dünen, wo an klaren Tagen nichts steht.", "砂嵐の日だけ、晴れた日には何もない砂丘に高い影が立つ。", "모래폭풍이 불 때만, 맑은 날엔 아무것도 없는 모래언덕에 높은 형체가 선다.", "沙暴天里，沙丘上会立起晴天里不存在的高影。"),
    [stage(obj("interact", "group:mirage", T("QO_T_EXAMINE", OBELISK), count=3, conditions={"weather": ["sandstorm"]}, hint="area", area_radius=220.0, marker=[1100, 270]))],
    {"jade": 3, "reveal": {"pos": [1170, 300], "radius": 9}},
    start="event",
    spawns=[{"kind": "object", "id": "mirage_%d" % i, "group": "mirage", "look": "obelisk", "pos": p, "when": "open", "conditions": {"weather": ["sandstorm"]}, "prompt": "PROMPT_EXAMINE", "element": "sand", "range": 300, "hide_used": False,
             "lines": [ln]}
            for i, (p, ln) in enumerate([
                ([980, 150], L("Warm to the touch. Sand pours from carvings of wind.", "Tibio al tacto. La arena brota de tallas de viento.", "Morno ao toque. Areia escorre de entalhes de vento.", "Tiède. Le sable coule de gravures de vent.", "Warm. Sand rinnt aus Windschnitzereien.", "温かい。風の彫刻から砂がこぼれる。", "따뜻하다. 바람 조각에서 모래가 흘러내린다.", "触手温热，风纹雕刻里沙粒流下。")),
                ([1102, 202], L("Carved eyes stare east, toward the Glass Arena.", "Ojos tallados miran al este, hacia la Arena de Vidrio.", "Olhos entalhados fitam o leste, para a Arena de Vidro.", "Des yeux gravés fixent l'est, vers l'Arène de verre.", "Gemeißelte Augen starren nach Osten, zur Glasarena.", "彫られた目が東、玻璃の闘技場を見つめる。", "새겨진 눈이 동쪽, 유리 투기장을 응시한다.", "雕刻的眼睛凝望东方的琉璃竞技场。")),
                ([1200, 450], L("A map of the desert, in stone. It glows, then fades with the storm.", "Un mapa del desierto, en piedra. Brilla y se apaga con la tormenta.", "Um mapa do deserto, em pedra. Brilha e some com a tempestade.", "Une carte du désert, dans la pierre. Elle luit, puis s'efface avec la tempête.", "Eine Wüstenkarte in Stein. Sie leuchtet und verblasst mit dem Sturm.", "石に刻まれた砂漠の地図。光り、嵐と共に消える。", "돌에 새긴 사막 지도. 빛나다가 폭풍과 함께 사라진다.", "石上刻着沙漠地图，发光后随风暴淡去。"))])]))

Q(quest("dq_buried_relic", "discovery", "exploration", "desert", 2, "short",
    L("Under the Dunes", "Bajo las dunas", "Sob as dunas", "Sous les dunes", "Unter den Dünen", "砂丘の下", "모래언덕 아래", "沙丘之下"),
    L("The Wind Sight shows a glint deep in the dunes. Something old lies just under the sand.", "La Vista del Viento muestra un destello en las dunas. Algo antiguo yace bajo la arena.", "A Visão do Vento mostra um brilho nas dunas. Algo antigo jaz sob a areia.", "La Vue du Vent révèle un éclat dans les dunes. Quelque chose d'ancien dort sous le sable.", "Die Windsicht zeigt ein Glitzern tief in den Dünen. Etwas Altes liegt unter dem Sand.", "風視が砂丘の奥のきらめきを映す。古い何かが砂のすぐ下に。", "바람의 눈이 모래언덕 깊은 곳의 반짝임을 비춘다. 오래된 무언가가 모래 바로 아래에.", "风之视界照出沙丘深处的一点闪光，有古物就埋在沙下。"),
    [stage(obj("ability_use", "wind_sight", T("QO_T_USE", "ABILITY_WIND_SIGHT"), conditions={"region": "desert"})),
     stage(obj("retrieve", "sand_relic", T("QO_T_TAKE", L("the buried relic", "la reliquia enterrada", "a relíquia enterrada", "la relique enfouie", "das vergrabene Relikt", "埋もれた遺物", "묻힌 유물", "埋藏的遗物")), marker=[1150, 330]),
           spawns=[{"kind": "object", "id": "sand_relic", "look": "relic", "pos": [1150, 330], "prompt": "PROMPT_TAKE", "element": "sand", "reward": {"items": [{"id": "glimmer_shard", "count": 12}]}},
                   {"kind": "cue", "cue": "pillar", "pos": [1150, 330], "range": 900}])],
    {"cosmetic": "echo_sand", "jade": 2},
    start="event", requires_abilities=["wind_sight"]))

Q(quest("sq_glass_stalker", "side", "boss", "desert", 4, "medium",
    L("The Glass Stalker", "El acechador de vidrio", "O espreitador de vidro", "Le traqueur de verre", "Der Glaspirscher", "玻璃の追跡者", "유리 추적자", "琉璃潜猎者"),
    L("Goats vanish from the oasis at night. Saffa found tracks that shine like shattered glass.", "De noche desaparecen cabras del oasis. Saffa halló huellas que brillan como vidrio roto.", "Cabras somem do oásis à noite. Saffa achou rastros que brilham como vidro quebrado.", "Des chèvres disparaissent de l'oasis la nuit. Saffa a trouvé des traces qui brillent comme du verre brisé.", "Nachts verschwinden Ziegen aus der Oase. Saffa fand Spuren, die wie Glassplitter glänzen.", "夜ごとオアシスの山羊が消える。サッファは割れ硝子のように光る足跡を見つけた。", "밤마다 오아시스의 염소가 사라진다. 사파는 깨진 유리처럼 빛나는 발자국을 찾았다.", "绿洲的山羊夜里失踪。萨法发现了像碎琉璃般发亮的足迹。"),
    [stage(obj("boss", "BOSS_GLASS_STALKER", L("Defeat the Glass Stalker (at night)", "Derrota al acechador de vidrio (de noche)", "Derrote o espreitador de vidro (à noite)", "Vaincre le traqueur de verre (la nuit)", "Besiege den Glaspirscher (nachts)", "玻璃の追跡者を倒す（夜に）", "유리 추적자 처치 (밤에)", "击败琉璃潜猎者（夜间）"), marker=[1180, 520])),
     stage(obj("talk", "NPC_NOMAD", T("QO_T_RETURN", "NAME_NOMAD")),
           talk=[L("The goats sleep easy. So will I. Take this, with the whole caravan's thanks.", "Las cabras duermen tranquilas. Yo también. Toma esto, con las gracias de toda la caravana.", "As cabras dormem tranquilas. Eu também. Tome, com a gratidão da caravana.", "Les chèvres dorment tranquilles. Moi aussi. Prenez ceci, avec les remerciements de la caravane.", "Die Ziegen schlafen ruhig. Ich auch. Nimm das, mit dem Dank der ganzen Karawane.", "山羊も俺も安心して眠れる。隊商みんなからの礼だ。", "염소들도 나도 편히 자겠군. 대상 모두의 감사를 담아.", "山羊睡得安稳了，我也是。拿着，全商队谢谢你。")])],
    {"jade": 2, "glimmer": 80, "items": [{"id": "dune_wrap", "count": 1}]},
    start="talk:NPC_NOMAD", requires=["mq_caravan"],
    offer_lines=[L("Something made of glass takes our goats at night. South dunes. Can you end it?", "Algo hecho de vidrio se lleva nuestras cabras de noche. Dunas del sur. ¿Puedes acabar con ello?", "Algo feito de vidro leva nossas cabras à noite. Dunas do sul. Pode acabar com isso?", "Une chose de verre prend nos chèvres la nuit. Dunes du sud. Vous pouvez y mettre fin ?", "Etwas aus Glas holt nachts unsere Ziegen. Süddünen. Kannst du es beenden?", "硝子の何かが夜に山羊をさらう。南の砂丘だ。終わらせてくれるか。", "유리로 된 무언가가 밤마다 염소를 채 가. 남쪽 모래언덕. 끝내 줄 수 있나?", "有个琉璃做的东西夜里叼走山羊，在南边沙丘。能除掉它吗？")]))

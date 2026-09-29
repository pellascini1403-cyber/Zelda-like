"""The eastern forest: hunting, hives, a grotto that glows at night, a lost
scholar, stones that whisper after dark and a chief that hunts by night."""
from qdsl import L, T, quest, stage, obj

QUESTS = []
Q = QUESTS.append

Q(quest("sq_hungry_hunter", "side", "gathering", "forest", 1, "medium",
    L("The Hungry Hunter", "La cazadora hambrienta", "A caçadora faminta", "La chasseuse affamée", "Die hungrige Jägerin", "腹ぺこの狩人", "배고픈 사냥꾼", "饥饿的猎人"),
    L("Varra has been tracking all day and forgot to eat. Hunt, cook, and bring her a hot meal.", "Varra lleva todo el día rastreando y olvidó comer. Caza, cocina y llévale algo caliente.", "Varra rastreou o dia todo e esqueceu de comer. Cace, cozinhe e leve algo quente.", "Varra a pisté toute la journée sans manger. Chassez, cuisinez, apportez-lui un plat chaud.", "Varra hat den ganzen Tag gefährtet und das Essen vergessen. Jage, koche, bring ihr etwas Warmes.", "ヴァラは一日中追跡して食べ忘れた。狩って、料理して、温かい食事を。", "바라는 종일 추적하다 끼니를 잊었다. 사냥하고 요리해서 따뜻한 한 끼를.", "瓦拉追了一整天忘了吃饭。去打猎、做饭，给她送顿热的。"),
    [stage(obj("hunt", "ANIMAL_WOOLHORN", T("QO_T_HUNT", "NAME_WOOLHORN"), count=2, hint="area", area_radius=150.0, marker=[300, 150])),
     stage(obj("cook", "hearty_stew", T("QO_T_COOK", "ITEM_HEARTY_STEW")),
           hint=[L("Meat in the pot, over any campfire. Simple food, done right.", "Carne a la olla, en cualquier hoguera. Comida sencilla, bien hecha.", "Carne na panela, em qualquer fogueira. Comida simples, bem feita.", "De la viande dans la marmite, sur n'importe quel feu. Simple et bien fait.", "Fleisch in den Topf, über jedes Lagerfeuer. Einfach, aber richtig.", "肉を鍋に入れて焚き火で。素朴な料理をきちんと。", "고기를 냄비에, 아무 모닥불이나. 소박하게, 제대로.", "肉下锅，随便哪堆营火。家常菜，做好就行。")]),
     stage(obj("deliver", "NPC_HUNTER", T("QO_T_GIVE", "ITEM_HEARTY_STEW", "NAME_HUNTER"), item="hearty_stew"),
           talk=[L("Mm. Hunters eat last and best. Here — my pepper skewer, the way my mother made it.", "Mm. Los cazadores comen los últimos y mejor. Toma, mi pincho picante, como lo hacía mi madre.", "Hum. Caçadores comem por último e melhor. Tome, meu espeto apimentado, do jeito da minha mãe.", "Mm. Les chasseurs mangent en dernier, et le mieux. Tenez, ma brochette pimentée, comme la faisait ma mère.", "Mm. Jäger essen zuletzt und am besten. Hier, mein Pfefferspieß nach Mutters Art.", "うまい。狩人は最後に一番いいものを食う。母の串焼きの作り方を教えよう。", "음. 사냥꾼은 마지막에, 제일 좋은 걸 먹지. 어머니식 고추 꼬치 비법이야.", "嗯，猎人最后吃，也吃最好的。我娘的辣串做法，教你。")])],
    {"recipes": [["fang_pepper", "raw_meat"]], "glimmer": 30, "jade": 1},
    start="talk:NPC_HUNTER",
    offer_lines=[L("Tracked a woolhorn herd all day, ate nothing. Hunt two, cook them, feed me?", "Rastreé una manada todo el día sin comer. ¿Cazas dos, los cocinas y me das de comer?", "Rastreei um rebanho o dia todo sem comer. Caça dois, cozinha e me alimenta?", "J'ai pisté un troupeau toute la journée sans manger. Chassez-en deux, cuisinez, nourrissez-moi ?", "Den ganzen Tag einer Herde nach, nichts gegessen. Zwei jagen, kochen, mich füttern?", "一日中群れを追って何も食べてない。二頭狩って料理してくれる？", "종일 무리를 쫓느라 굶었어. 둘 사냥해서 요리해 줄래?", "追了一天兽群，啥也没吃。打两头、做熟、喂我？")]))

HIVES = L("the amber hives", "las colmenas de ámbar", "as colmeias de âmbar", "les ruches d'ambre", "die Bernsteinstöcke", "琥珀の巣", "호박 벌집", "琥珀蜂巢")
Q(quest("dq_amber_hives", "discovery", "combat", "forest", 2, "short",
    L("The Amber Hives", "Las colmenas de ámbar", "As colmeias de âmbar", "Les ruches d'ambre", "Die Bernsteinstöcke", "琥珀の巣", "호박 벌집", "琥珀蜂巢"),
    L("Wisps have hollowed out amber hives at the elder tree's roots. Fire loosens them — and the honey.", "Los fuegos fatuos vaciaron colmenas de ámbar en las raíces del árbol anciano. El fuego las suelta, y la miel.", "Fogos-fátuos escavaram colmeias de âmbar nas raízes da árvore anciã. O fogo as solta, e o mel.", "Des feux follets ont creusé des ruches d'ambre aux racines de l'arbre ancien. Le feu les délogera, et le miel.", "Irrlichter haben Bernsteinstöcke an den Wurzeln des Altbaums ausgehöhlt. Feuer löst sie — und den Honig.", "長老樹の根に鬼火が琥珀の巣を作った。火で落とせば蜜も取れる。", "원로 나무 뿌리에 도깨비불이 호박 벌집을 팠다. 불로 떨구면 꿀도 얻는다.", "鬼火在古树根部掏出琥珀蜂巢。用火烧落，还有蜂蜜。"),
    [stage(obj("destroy", "group:amber_hives", T("QO_T_DESTROY", HIVES), count=2, hint="area", area_radius=60.0, marker=[520, 260]),
           spawns=[{"kind": "nest", "id": "hive_a", "group": "amber_hives", "nest": "hive", "pos": [545, 290], "hp": 55, "spawn": "ENEMY_WISP", "spawn_every": 13, "spawn_max": 2, "element": "electric",
                    "drops": [{"id": "honeycomb", "count": 2}, {"id": "amber_sap", "count": 2}]},
                   {"kind": "nest", "id": "hive_b", "group": "amber_hives", "nest": "hive", "pos": [500, 225], "hp": 55, "spawn": "ENEMY_WISP", "spawn_every": 13, "spawn_max": 2, "element": "electric",
                    "drops": [{"id": "honeycomb", "count": 2}, {"id": "amber_sap", "count": 2}]}])],
    {"jade": 1, "glimmer": 40},
    start="poi:elder_tree"))

Q(quest("sq_glowmoss", "side", "gathering", "forest", 2, "medium",
    L("Moss That Shines", "Musgo que brilla", "Musgo que brilha", "La mousse qui luit", "Moos, das leuchtet", "光る苔", "빛나는 이끼", "发光的苔"),
    L("Varra's old knee aches. Glowmoss eases it, but you can only find it shining at night.", "A Varra le duele su vieja rodilla. El musgo luciente la alivia, pero solo brilla de noche.", "O velho joelho de Varra dói. O musgo-luz alivia, mas só brilha à noite.", "Le vieux genou de Varra la fait souffrir. La mousse-lueur le soulage, mais ne luit que la nuit.", "Varras altes Knie schmerzt. Leuchtmoos hilft, doch es leuchtet nur nachts.", "ヴァラの古傷の膝が痛む。光苔が効くが、光るのは夜だけ。", "바라의 오랜 무릎이 쑤신다. 빛이끼가 듣는데, 밤에만 빛난다.", "瓦拉的老膝盖疼。萤苔能缓解，可它只在夜里发光。"),
    [stage(obj("gather", "glowmoss", L("Gather glowmoss (at night)", "Recoge musgo luciente (de noche)", "Colha musgo-luz (à noite)", "Récoltez de la mousse-lueur (la nuit)", "Sammle Leuchtmoos (nachts)", "光苔を採る（夜に）", "빛이끼 채집 (밤에)", "采集萤苔（夜间）"), count=3, conditions={"period": "night"}, hint="area", area_radius=40.0, marker=[600, 330])),
     stage(obj("deliver", "NPC_HUNTER", T("QO_T_GIVE", "ITEM_GLOWMOSS", "NAME_HUNTER"), item="glowmoss", count=3),
           talk=[L("Ahh. That's the stuff. A mending tea, for you — the recipe too.", "Ahh. Eso es. Un té reparador para ti, y la receta.", "Ahh. É isso. Um chá restaurador para você, e a receita.", "Ahh. C'est ça. Un thé réparateur pour vous — et la recette.", "Ahh. Genau das. Ein Heiltee für dich — samt Rezept.", "ああ、これだ。癒やしの茶をあげよう。作り方もね。", "아, 이거지. 회복 차 한 잔과 비법도 줄게.", "啊，就是这个。给你一壶疗愈茶，方子也教你。")])],
    {"items": [{"id": "mending_tea", "count": 2}], "recipes": [["glowmoss", "glowmoss"]], "jade": 1},
    start="talk:NPC_HUNTER", requires=["sq_hungry_hunter"],
    offer_lines=[L("There's a grotto east of here where the moss glows. At night, mind. Three handfuls.", "Hay una gruta al este donde el musgo brilla. De noche, ojo. Tres puñados.", "Há uma gruta a leste onde o musgo brilha. À noite, atenção. Três punhados.", "Il y a une grotte à l'est où la mousse luit. La nuit, attention. Trois poignées.", "Östlich liegt eine Grotte, wo das Moos leuchtet. Nachts, wohlgemerkt. Drei Handvoll.", "東の洞で苔が光る。夜だけだよ。三つかみ頼む。", "동쪽 동굴에 이끼가 빛나. 밤에만. 세 줌만.", "东边有个洞，苔会发光。记住是夜里。三把就好。")]))

RUBBLE = L("the rockfall", "el derrumbe", "o desmoronamento", "l'éboulis", "den Steinschlag", "落石", "낙석", "落石堆")
Q(quest("dq_sap_and_fire", "discovery", "crafting", "forest", 2, "medium",
    L("Sap and Fire", "Savia y fuego", "Seiva e fogo", "Sève et feu", "Harz und Feuer", "樹脂と火", "수액과 불", "树脂与火"),
    L("A smuggler's stash lies behind a rockfall. Their note says it plainly: bring fire-sap.", "Tras un derrumbe hay un alijo de contrabandista. Su nota lo dice claro: trae savia de fuego.", "Atrás de um desmoronamento há um esconderijo. O bilhete é claro: traga seiva de fogo.", "Une cache de contrebandier derrière un éboulis. Le mot est clair : apportez de la sève à feu.", "Hinter einem Steinschlag liegt ein Schmugglerversteck. Die Notiz sagt es klar: bring Feuerharz.", "落石の奥に密輸人の隠し物。書き付けにはっきりと：火の樹脂を持て。", "낙석 뒤에 밀수꾼의 은닉처. 쪽지엔 분명히: 불 수액을 가져와라.", "落石后面有走私者的藏货，纸条写得明白：带火树脂来。"),
    [stage(obj("interact", "rubble_note", T("QO_T_EXAMINE", L("the smuggler's note", "la nota del contrabandista", "o bilhete do contrabandista", "le mot du contrebandier", "die Schmugglernotiz", "密輸人の書き付け", "밀수꾼의 쪽지", "走私者的纸条")))),
     stage(obj("gather", "amber_tree", T("QO_T_GATHER", L("amber trees", "árboles de ámbar", "árvores de âmbar", "arbres à ambre", "Bernsteinbäume", "琥珀の木", "호박나무", "琥珀树")), count=2, hint="area", area_radius=200.0, marker=[470, 230]),
           obj("craft", "resin_bomb", T("QO_T_CRAFT", "ITEM_RESIN_BOMB"))),
     stage(obj("destroy", "cache_rubble", T("QO_T_DESTROY", RUBBLE), marker=[585, 400]),
           spawns=[{"kind": "nest", "id": "cache_rubble", "nest": "rubble", "pos": [585, 400], "hp": 40, "melee": 0.0, "weak": {"fire": 0.0, "explosion": 4.0}, "hint_key": "HINT_RUBBLE", "element": ""}]),
     stage(obj("open_chest", "rubble_stash", T("QO_T_OPEN", L("the smuggler's stash", "el alijo", "o esconderijo", "la cache", "das Versteck", "隠し物", "은닉처", "藏货")), marker=[588, 405]),
           spawns=[{"kind": "chest", "id": "rubble_stash", "pos": [588, 405], "table": "chest_camp", "items": [{"id": "lodestone_charm", "count": 1}]}])],
    {"jade": 1},
    start="interact:rubble_note",
    spawns=[{"kind": "object", "id": "rubble_note", "look": "scroll", "pos": [580, 396], "when": "open", "once": False, "hide_used": False, "prompt": "PROMPT_EXAMINE",
             "lines": [L("\"Stash is behind the fall. Bring fire-sap — a bomb, not a blade.\"", "\"El alijo está tras el derrumbe. Trae savia de fuego: una bomba, no una hoja.\"", "\"O esconderijo está atrás. Traga seiva de fogo: bomba, não lâmina.\"", "« La cache est derrière l'éboulis. Apportez de la sève à feu : une bombe, pas une lame. »", "„Versteck hinter dem Fall. Bring Feuerharz — eine Bombe, keine Klinge.“", "「隠し物は落石の奥。火の樹脂を――刃じゃなく爆弾だ」", "\"은닉처는 낙석 뒤. 불 수액을 — 칼 말고 폭탄.\"", "“货在落石后。带火树脂——要炸药，不要刀。”")]}]))

QUILL = "NAME_SCHOLAR"
Q(quest("sq_lost_scholar", "side", "npc", "forest", 3, "medium",
    L("The Lost Scholar", "El erudito perdido", "O estudioso perdido", "L'érudit égaré", "Der verirrte Gelehrte", "迷子の学者", "길 잃은 학자", "迷路的学者"),
    L("Quill went east to sketch ruins and walked into a spitter colony. Varra heard him shouting.", "Quill fue al este a dibujar ruinas y se metió en una colonia de escupidores. Varra lo oyó gritar.", "Quill foi ao leste desenhar ruínas e caiu numa colônia de cuspidores. Varra o ouviu gritar.", "Quill est allé dessiner des ruines à l'est et s'est jeté dans une colonie de cracheurs. Varra l'a entendu crier.", "Quill zog nach Osten, um Ruinen zu zeichnen, und geriet in eine Speierkolonie. Varra hörte ihn rufen.", "クイルは遺跡を描きに東へ行き、吐き虫の群れに踏み込んだ。ヴァラが叫び声を聞いた。", "퀼은 유적을 그리러 동쪽에 갔다가 침뱉이 무리에 빠졌다. 바라가 비명을 들었다.", "奎尔去东边画遗迹，闯进了喷吐虫窝。瓦拉听见他在喊。"),
    [stage(obj("clear", "quill_spitters", T("QO_T_CLEAR", "NAME_SPITTER"), count=3, marker=[660, 200]),
           spawns=[{"kind": "creature", "entity": "ENEMY_SPITTER", "group": "quill_spitters", "pos": [662, 204], "count": 3, "spread": 9}]),
     stage(obj("escort", "quill_escort", T("QO_T_ESCORT", QUILL), marker=[660, 200]))],
    {"jade": 2, "glimmer": 40},
    start="talk:NPC_HUNTER", requires=["sq_hungry_hunter"],
    spawns=[{"kind": "encounter", "id": "quill_escort", "mode": "escort", "pos": [660, 200], "actor": "NPC_SCHOLAR", "actor_hp": 120, "when": "active", "element": "thorn",
             "path": [[620, 195], [560, 186], [500, 180], [440, 170], [385, 163]], "wait_distance": 22, "vanish": True,
             "ambushes": [{"at": 2, "entity": "ENEMY_THORNLING", "count": 3, "dist": 12}],
             "start_lines": [L("You came! My sketches! My ankle! Lead on, I'll keep up. Mostly.", "¡Viniste! ¡Mis bocetos! ¡Mi tobillo! Guía, te seguiré. Casi siempre.", "Você veio! Meus esboços! Meu tornozelo! Vá na frente, eu acompanho. Quase.", "Vous êtes venu ! Mes croquis ! Ma cheville ! Passez devant, je suis. Presque.", "Du bist da! Meine Skizzen! Mein Knöchel! Geh vor, ich komme mit. Meistens.", "来てくれた！スケッチが！足首が！先に行って、ついてく。たぶん。", "와 줬구나! 내 스케치! 내 발목! 앞장서, 따라갈게. 아마도.", "你来了！我的画稿！我的脚踝！你带路，我尽量跟上。")],
             "end_lines": [L("Safe. Varra's lodge has room for a scholar, I'm told. I'll stay a while.", "A salvo. Me dicen que en el refugio de Varra cabe un erudito. Me quedaré un tiempo.", "A salvo. Dizem que o abrigo de Varra tem lugar para um estudioso. Vou ficar um tempo.", "Sauf. Il paraît que la loge de Varra a de la place pour un érudit. Je reste un peu.", "In Sicherheit. Varras Hütte hat Platz für einen Gelehrten. Ich bleibe eine Weile.", "助かった。ヴァラの小屋に学者の居場所があるらしい。しばらくいるよ。", "살았다. 바라의 오두막에 학자 자리가 있대. 한동안 머물게.", "得救了。听说瓦拉的小屋容得下学者，我住些日子。")]}],
    unlocks={"flags": ["quill_safe"]},
    offer_lines=[L("There's a scholar shouting in the east woods — spitters all around him. I've a bad knee...", "Hay un erudito gritando en el bosque del este, rodeado de escupidores. Tengo la rodilla mal...", "Tem um estudioso gritando na mata leste, cercado de cuspidores. Meu joelho está ruim...", "Un érudit crie dans les bois de l'est, des cracheurs tout autour. J'ai un mauvais genou...", "Im Ostwald schreit ein Gelehrter, rundherum Speier. Mein Knie ist schlecht...", "東の森で学者が叫んでる、吐き虫だらけだ。私は膝が悪くて…", "동쪽 숲에서 학자가 소리쳐, 침뱉이에 둘러싸여서. 난 무릎이 안 좋아서…", "东林里有个学者在喊，四周全是喷吐虫。我膝盖不好……")]))

STONES = L("the whispering stones", "las piedras que susurran", "as pedras que sussurram", "les pierres murmurantes", "die flüsternden Steine", "囁く石", "속삭이는 돌", "低语之石")
Q(quest("sq_whispering_stones", "side", "exploration", "forest", 2, "medium",
    L("Whispering Stones", "Piedras que susurran", "Pedras que sussurram", "Pierres murmurantes", "Flüsternde Steine", "囁く石", "속삭이는 돌", "低语之石"),
    L("Quill swears four old stones whisper after dark. He wants someone to listen.", "Quill jura que cuatro piedras viejas susurran al anochecer. Quiere que alguien escuche.", "Quill jura que quatro pedras antigas sussurram à noite. Quer que alguém escute.", "Quill jure que quatre vieilles pierres murmurent la nuit. Il veut qu'on les écoute.", "Quill schwört, vier alte Steine flüstern nachts. Jemand soll zuhören.", "クイルは四つの古い石が夜に囁くと言う。誰かに聞いてほしいらしい。", "퀼은 오래된 돌 넷이 밤에 속삭인다고 맹세한다. 누가 들어 주길 바란다.", "奎尔发誓有四块古石在夜里低语，他想找人去听。"),
    [stage(obj("interact", "group:whisper", T("QO_T_NIGHT", L("Listen to the whispering stones", "Escucha las piedras que susurran", "Ouça as pedras que sussurram", "Écoutez les pierres murmurantes", "Lausche den flüsternden Steinen", "囁く石に耳を澄ます", "속삭이는 돌에 귀 기울이기", "聆听低语之石")), count=4, hint="area", area_radius=220.0, marker=[430, 300]),
           spawns=[{"kind": "object", "id": "whisper_%d" % i, "group": "whisper", "look": "stone", "pos": p, "conditions": {"period": "night"}, "prompt": "PROMPT_EXAMINE", "hint_key": "HINT_WRONG_TIME", "element": "wind",
                    "lines": [ln]}
                   for i, (p, ln) in enumerate([
                       ([430, 330], L("\"...the wind was born here, between two breaths...\"", "\"...el viento nació aquí, entre dos alientos...\"", "\"...o vento nasceu aqui, entre dois fôlegos...\"", "« ...le vent est né ici, entre deux souffles... »", "„...hier wurde der Wind geboren, zwischen zwei Atemzügen...“", "「…風はここで生まれた、二つの息の間に…」", "\"…바람은 여기서 태어났다, 두 숨 사이에서…\"", "“……风生于此，两息之间……”")),
                       ([560, 180], L("\"...the Wardens kept it moving, fire to fire...\"", "\"...los Guardianes lo mantenían en marcha, de fuego en fuego...\"", "\"...os Guardiões o mantinham em movimento, de fogo em fogo...\"", "« ...les Gardiens le faisaient courir, de feu en feu... »", "„...die Hüter hielten ihn in Bewegung, von Feuer zu Feuer...“", "「…守り人は火から火へ風を運んだ…」", "\"…지기들은 불에서 불로 바람을 흐르게 했다…\"", "“……守风者以火传风，一处接一处……”")),
                       ([250, 250], L("\"...stillness is not peace. Stillness is hunger...\"", "\"...la quietud no es paz. La quietud es hambre...\"", "\"...quietude não é paz. Quietude é fome...\"", "« ...le calme n'est pas la paix. Le calme est une faim... »", "„...Stille ist kein Frieden. Stille ist Hunger...“", "「…静寂は安らぎではない。飢えだ…」", "\"…고요는 평화가 아니다. 굶주림이다…\"", "“……寂静不是安宁，是饥饿……”")),
                       ([480, 420], L("\"...when all the fires burn, the Heart can be woken...\"", "\"...cuando ardan todos los fuegos, el Corazón podrá despertar...\"", "\"...quando todos os fogos arderem, o Coração poderá despertar...\"", "« ...quand tous les feux brûleront, le Cœur pourra s'éveiller... »", "„...wenn alle Feuer brennen, kann das Herz erwachen...“", "「…すべての火が灯れば、心は目覚める…」", "\"…모든 불이 타오르면 심장이 깨어난다…\"", "“……火尽燃时，心可醒……”"))])]),
     stage(obj("talk", "NPC_SCHOLAR", T("QO_T_RETURN", QUILL)),
           talk=[L("They spoke to you?! Then my notes are right. Take this — it's yours more than mine.", "¡¿Te hablaron?! Entonces mis notas son correctas. Toma, es más tuyo que mío.", "Falaram com você?! Então minhas notas estão certas. Tome, é mais seu que meu.", "Elles vous ont parlé ?! Alors mes notes sont justes. Prenez, c'est plus à vous qu'à moi.", "Sie sprachen zu dir?! Dann stimmen meine Notizen. Nimm das, es gehört eher dir.", "話しかけてきた！？なら私の記録は正しい。これを、君のものだ。", "너한테 말했다고?! 그럼 내 기록이 맞아. 이거 받아, 네 거야.", "它们跟你说话了？！那我的笔记没错。拿着，这更该归你。")])],
    {"cosmetic": "trail_jade", "jade": 2, "items": [{"id": "vital_seed", "count": 1}]},
    start="talk:NPC_SCHOLAR", requires=["sq_lost_scholar"],
    offer_lines=[L("Four stones, four whispers, only at night. Listen to all four for me?", "Cuatro piedras, cuatro susurros, solo de noche. ¿Las escuchas por mí?", "Quatro pedras, quatro sussurros, só à noite. Ouve as quatro por mim?", "Quatre pierres, quatre murmures, la nuit seulement. Vous les écoutez pour moi ?", "Vier Steine, vier Flüstern, nur nachts. Hörst du sie dir für mich an?", "四つの石、四つの囁き、夜だけ。全部聞いてきてくれる？", "돌 넷, 속삭임 넷, 밤에만. 날 위해 다 들어 줄래?", "四块石头，四句低语，只在夜里。替我都听一遍？")]))

Q(quest("dq_thorn_chief", "discovery", "boss", "valley", 3, "short",
    L("The Thornling Chief", "El jefe espinudo", "O chefe espinhoso", "Le chef des ronceux", "Der Dornling-Häuptling", "トゲ獣の長", "가시짐승 우두머리", "棘兽首领"),
    L("Bones and broken spears litter the Thorn Den. Whatever leads the pack returns only at night.", "Huesos y lanzas rotas cubren la Guarida Espinosa. Lo que guía la manada solo vuelve de noche.", "Ossos e lanças quebradas cobrem a Toca Espinhosa. O líder da matilha só volta à noite.", "Os et lances brisées jonchent la Tanière des ronces. Ce qui mène la meute ne revient que la nuit.", "Knochen und zerbrochene Speere im Dornenbau. Wer das Rudel führt, kehrt nur nachts zurück.", "トゲの巣穴に骨と折れた槍。群れの長は夜にしか戻らない。", "가시 굴에 뼈와 부러진 창. 무리의 우두머리는 밤에만 돌아온다.", "荆棘巢穴里满是骨头和断矛。领头的只在夜里回来。"),
    [stage(obj("boss", "BOSS_THORN_CHIEF", L("Defeat the Thornling Chief (at night)", "Derrota al jefe espinudo (de noche)", "Derrote o chefe espinhoso (à noite)", "Vaincre le chef des ronceux (la nuit)", "Besiege den Dornling-Häuptling (nachts)", "トゲ獣の長を倒す（夜に）", "가시짐승 우두머리 처치 (밤에)", "击败棘兽首领（夜间）"), marker=[-150, 432]))],
    {"jade": 2, "glimmer": 60},
    start="poi:thorn_den"))

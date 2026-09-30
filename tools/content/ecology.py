"""Expansion content: ecosystems (enemy families, variants, fauna), region
spawn mixes, discoveries and their strings. Applied by tools/gen_content.py
(entities/visuals upserted, region spawn tables replaced, discoveries.json
owned by this module). See docs/EXPANSION_PLAN.md."""
from qdsl import L

# --- UI / system strings -----------------------------------------------------------------------------
STRINGS = {
    "JOURNAL_ATLAS": L("Atlas of wonders", "Atlas de maravillas", "Atlas de maravilhas", "Atlas des merveilles", "Atlas der Wunder", "驚異の地図帳", "경이의 지도첩", "奇景图志"),
    "ATLAS_FOUND": L("Wonder found", "Maravilla descubierta", "Maravilha descoberta", "Merveille découverte", "Wunder entdeckt", "驚異を発見", "경이 발견", "发现奇景"),
    "ATLAS_UNKNOWN": L("Something unfound", "Algo sin descubrir", "Algo não descoberto", "Quelque chose d'inconnu", "Etwas Unentdecktes", "まだ見ぬもの", "아직 찾지 못한 것", "尚未发现之物"),
    "ATLAS_NO_HINT": L("No one has spoken of it yet.", "Nadie ha hablado de ello todavía.", "Ninguém falou disso ainda.", "Personne n'en a encore parlé.", "Noch hat niemand davon erzählt.", "まだ誰もそれを語っていない。", "아직 누구도 그것을 말하지 않았다.", "还没有人提起过它。"),
    "TOAST_STOLEN": L("A thief snatched %d glimmer!", "¡Un ladrón te robó %d destellos!", "Um ladrão roubou %d brilhos!", "Un voleur a pris %d éclats !", "Ein Dieb hat %d Schimmer gestohlen!", "盗人に%dグリマーを奪われた！", "도둑이 반짝이 %d개를 훔쳤다!", "小偷抢走了%d微光！"),
    "TOAST_RECOVERED": L("Recovered %d glimmer", "Recuperaste %d destellos", "Recuperou %d brilhos", "%d éclats récupérés", "%d Schimmer zurückgeholt", "%dグリマーを取り戻した", "반짝이 %d개를 되찾았다", "夺回%d微光"),
}

FAUNA = {
    "FAUNA_GULLS": L("Gulls", "Gaviotas", "Gaivotas", "Mouettes", "Möwen", "カモメ", "갈매기", "海鸥"),
    "FAUNA_SPARROWS": L("Sparrows", "Gorriones", "Pardais", "Moineaux", "Spatzen", "スズメ", "참새", "麻雀"),
    "FAUNA_RAVENS": L("Ravens", "Cuervos", "Corvos", "Corbeaux", "Raben", "ワタリガラス", "까마귀", "渡鸦"),
    "FAUNA_BATS": L("Bats", "Murciélagos", "Morcegos", "Chauves-souris", "Fledermäuse", "コウモリ", "박쥐", "蝙蝠"),
    "FAUNA_FISH_LAKE": L("Lake minnows", "Pececillos del lago", "Peixinhos do lago", "Vairons du lac", "Seeelritzen", "湖の小魚", "호수 피라미", "湖中小鱼"),
    "FAUNA_FISH_SEA": L("Silverbacks", "Lomos de plata", "Dorsos-de-prata", "Dos-d'argent", "Silberrücken", "銀背魚", "은등고기", "银背鱼"),
    "FAUNA_REEFGLINTS": L("Reefglints", "Destellos del arrecife", "Lampejos do recife", "Éclats de récif", "Riffglitzer", "礁のきらめき", "산호 반짝이", "礁光鱼"),
    "FAUNA_FIREFLIES": L("Fireflies", "Luciérnagas", "Vaga-lumes", "Lucioles", "Glühwürmchen", "ホタル", "반딧불이", "萤火虫"),
    "FAUNA_BUTTERFLIES": L("Petalwings", "Alapétalos", "Asas-de-pétala", "Ailes-pétales", "Blütenflügler", "花びら蝶", "꽃잎나비", "瓣翼蝶"),
    "FAUNA_VEIL_MOTES": L("Veil motes", "Motas del Velo", "Partículas do Véu", "Poussières du Voile", "Schleierfunken", "帳の塵", "장막의 티끌", "帷幕微尘"),
    "FAUNA_SNOW_FINCHES": L("Snow finches", "Pinzones de nieve", "Tentilhões-da-neve", "Niverolles", "Schneefinken", "ユキスズメ", "눈되새", "雪雀"),
    "FAUNA_SAND_SKITTERS": L("Sand skitters", "Correarenas", "Corre-areias", "Trotte-sable", "Sandhuscher", "砂走り", "모래 종종이", "沙窜虫"),
    "FAUNA_TIDE_CRABS": L("Tide crabs", "Cangrejos de marea", "Caranguejos-da-maré", "Crabes des marées", "Gezeitenkrabben", "潮ガニ", "조수 게", "潮蟹"),
}

# Filled by phase 2+ (entities, visuals, spawn tables, discoveries).
ENTITIES = []      # [(entity dict, loc dict)]
VISUALS = []       # [visual profile dict]
REGION_SPAWNS = {} # region id -> {"enemy_spawns": [...], "animal_spawns": [...]}
DISCOVERIES = []   # [(discovery dict, loc dict)]
LOOT = {}

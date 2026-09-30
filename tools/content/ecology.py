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

# --- Phase 2: ecosystems ----------------------------------------------------------------------------
# Every family changes how you fight or move; none is a recolour with more HP.


def atk(aid, typ, **kw):
    d = {"id": aid, "type": typ}
    d.update(kw)
    return d


def enemy(eid, color, name, hp, collider, stats, attacks, ai, loot, visual, mult=None, locomotion=None, period=None, variant_of=None):
    key = "NAME_" + eid.split("_", 1)[1]
    d = {"id": eid, "kind": "ENEMY", "name_key": key, "placeholder_color": color, "placeholder_shape": "quadruped",
         "model": "", "collider": collider, "stats": dict({"max_health": hp}, **stats), "ai": ai, "attacks": attacks,
         "loot_table": loot}
    if variant_of:
        d = {"id": eid, "variant_of": variant_of, "name_key": key, "placeholder_color": color}
        if hp:
            d["stats"] = dict({"max_health": hp}, **stats)
        elif stats:
            d["stats"] = stats
        for k, v in (("collider", collider), ("ai", ai), ("attacks", attacks), ("loot_table", loot)):
            if v:
                d[k] = v
    if mult:
        d["element_mult"] = mult
    if locomotion:
        d["locomotion"] = locomotion
    if period:
        d["active_period"] = period
    vis = dict({"id": eid}, **visual) if visual is not None else None
    return d, {key: name}, vis


def animal(eid, color, name, hp, collider, stats, ai, loot, visual, locomotion=None, period=None):
    key = "NAME_" + eid.split("_", 1)[1]
    d = {"id": eid, "kind": "ANIMAL", "name_key": key, "placeholder_color": color, "placeholder_shape": "quadruped",
         "model": "", "collider": collider, "stats": dict({"max_health": hp}, **stats), "ai": ai, "loot_table": loot}
    if locomotion:
        d["locomotion"] = locomotion
    if period:
        d["active_period"] = period
    return d, {key: name}, dict({"id": eid, "family": "wildlife"}, **visual)


_E = [
    # Flyer that swoops: read its shadow, dodge the dive, punish it on the ground.
    enemy("ENEMY_GALE_KITE", "#add9d0", L("Gale Kite", "Milano del vendaval", "Milhafre do vendaval", "Milan des rafales", "Sturmmilan", "疾風トビ", "돌풍 솔개", "疾风鸢"), 45,
          {"radius": 0.55, "height": 0.9}, {"poise": 10, "walk_speed": 3.0, "run_speed": 7.5, "turn_speed": 6, "mass": 30},
          [atk("swoop", "module", windup=0.9, damage=14, knockback=9, charge_speed=22, poise_damage=18, element="wind"),
           atk("gust", "projectile", range_min=6, range_max=18, windup=0.7, recovery=0.8, cooldown=3.5, damage=7, element="wind", projectile_speed=18)],
          {"sight_range": 32, "fov": 360, "hearing": 1.2, "leash": 60, "wander_radius": 14, "respawn_hours": 48, "hover": 5.0,
           "behaviors": ["swoop"], "swoop_height": 9, "swoop_every": 5.5, "swoop_recover": 1.6},
          "drop_gale_kite", {"family": "enemy", "rank": "common", "species": "raptor", "features": ["crest", "talons"], "scale": 0.8},
          {"electric": 1.5}, locomotion="flying"),
    # Swimmer: untouchable deep, surfaces to strike; soaked, so shock hurts it double.
    enemy("ENEMY_MIRE_EEL", "#3f7644", L("Mire Eel", "Anguila del cieno", "Enguia do lodo", "Anguille des vases", "Schlammaal", "泥沼ウナギ", "진흙 뱀장어", "泥沼鳗"), 50,
          {"radius": 0.5, "height": 0.7}, {"poise": 12, "walk_speed": 2.2, "run_speed": 5.5, "turn_speed": 5, "mass": 50},
          [atk("snap", "lunge", range_min=0, range_max=4.5, windup=0.45, active=0.3, recovery=0.8, cooldown=1.6, damage=12, knockback=6, reach=1.6, arc=50, lunge_speed=11),
           atk("jet", "projectile", range_min=4, range_max=15, windup=0.6, recovery=0.8, cooldown=2.8, damage=8, element="water", projectile_speed=17)],
          {"sight_range": 22, "fov": 300, "hearing": 1.5, "leash": 40, "wander_radius": 10, "respawn_hours": 48,
           "behaviors": ["submerge"], "surface_range": 13, "surface_time": 4.5, "deep_depth": 2.6, "swim_depth": 0.6},
          "drop_mire_eel", {"family": "enemy", "rank": "common", "species": "serpent", "features": []},
          {"electric": 1.3, "fire": 0.5}, locomotion="aquatic"),
    # Climber: waits on walls, drops on you, hunts you while you climb.
    enemy("ENEMY_CRAG_WEAVER", "#644242", L("Crag Weaver", "Tejedora de riscos", "Tecelã dos penhascos", "Tisseuse des falaises", "Klippenweberin", "岩場の織り蜘蛛", "벼랑 거미", "崖织蛛"), 55,
          {"radius": 0.7, "height": 0.9}, {"poise": 14, "walk_speed": 2.4, "run_speed": 6.2, "turn_speed": 8, "mass": 45},
          [atk("bite", "melee", range_min=0, range_max=2.0, windup=0.4, recovery=0.6, cooldown=1.1, damage=10, knockback=3, reach=1.5, arc=55, weight=2),
           atk("web", "projectile", range_min=4, range_max=16, windup=0.6, recovery=0.8, cooldown=4.5, damage=3, element="web", projectile_speed=15),
           atk("drop", "module", windup=0.6, damage=16, radius=2.3)],
          {"sight_range": 22, "fov": 300, "hearing": 1.4, "leash": 45, "wander_radius": 10, "respawn_hours": 72,
           "behaviors": ["drop_from_above"], "drop_radius": 6},
          "drop_weaver", {"family": "enemy", "rank": "common", "species": "spider", "features": []},
          {"fire": 1.6}, locomotion="climber"),
    # Front armour: circle it, stagger it with slams/bombs, or parry its roll.
    enemy("ENEMY_BRAMBLE_CARAPACE", "#5e8422", L("Bramble Carapace", "Caparazón de zarza", "Carapaça de sarça", "Carapace des ronces", "Dornenpanzer", "茨甲虫", "가시 갑충", "荆甲虫"), 70,
          {"radius": 0.8, "height": 1.1}, {"defense": 1, "poise": 30, "walk_speed": 1.6, "run_speed": 4.2, "turn_speed": 3.2, "mass": 140},
          [atk("horn", "melee", range_min=0, range_max=2.4, windup=0.6, recovery=0.8, cooldown=1.4, damage=12, knockback=6, reach=2.0, arc=45, weight=2),
           atk("roll", "charge", range_min=5, range_max=16, windup=0.9, active=1.1, recovery=1.2, cooldown=5.0, damage=16, knockback=10, reach=16, charge_speed=13, poise_damage=25)],
          {"sight_range": 18, "fov": 150, "hearing": 1.0, "leash": 35, "wander_radius": 6, "respawn_hours": 72,
           "behaviors": ["front_armor"], "armor_arc": 70, "armor_mult": 0.1, "flipped_time": 3.2},
          "drop_carapace", {"family": "enemy", "rank": "common", "species": "beetle", "features": ["back_spikes"]},
          {"fire": 1.4}),
    # Sets grass alight where it runs; rain puts its flame out and leaves it soft.
    enemy("ENEMY_CINDER_IMP", "#ff7a00", L("Cinder Imp", "Diablillo de ceniza", "Diabrete de cinza", "Diablotin des cendres", "Aschekobold", "燃えさし小鬼", "잿불 도깨비", "余烬小鬼"), 28,
          {"radius": 0.35, "height": 1.0}, {"poise": 6, "walk_speed": 2.6, "run_speed": 7.0, "turn_speed": 10, "mass": 25},
          [atk("claw", "melee", range_min=0, range_max=1.8, windup=0.35, recovery=0.5, cooldown=0.9, damage=7, knockback=3, reach=1.3, arc=60, element="fire", weight=2),
           atk("ember", "projectile", range_min=4, range_max=14, windup=0.5, recovery=0.7, cooldown=2.6, damage=6, element="fire", projectile_speed=15)],
          {"sight_range": 22, "fov": 180, "hearing": 1.3, "leash": 40, "wander_radius": 10, "respawn_hours": 48,
           "behaviors": ["ignite"], "ignite_every": 3.5},
          "drop_imp", {"family": "enemy", "rank": "common", "species": "goblin", "features": ["head_flame"], "scale": 0.85},
          {"fire": 0.0, "water": 2.0, "ice": 2.0}),
    # Hunts by vibration under the sand: keep moving and it finds you; stand still.
    enemy("ENEMY_DUNE_BURROWER", "#f2c171", L("Dune Burrower", "Excavador de dunas", "Escavador das dunas", "Fouisseur des dunes", "Dünengräber", "砂潜り", "모래 굴착충", "沙丘掘虫"), 60,
          {"radius": 0.6, "height": 0.9}, {"defense": 1, "poise": 20, "walk_speed": 2.0, "run_speed": 6.5, "turn_speed": 6, "mass": 80},
          [atk("bite", "melee", range_min=0, range_max=2.4, windup=0.5, recovery=0.7, cooldown=1.3, damage=12, knockback=5, reach=2.0, arc=60),
           atk("erupt", "module", windup=0.8, damage=16, knockback=9, radius=2.4)],
          {"sight_range": 14, "fov": 360, "hearing": 2.0, "leash": 45, "wander_radius": 12, "respawn_hours": 48,
           "behaviors": ["burrow"], "hear_range": 26, "still_time": 1.5, "surface_time": 5.0},
          "drop_burrower", {"family": "enemy", "rank": "common", "species": "serpent", "features": []},
          {"ice": 1.6}, locomotion="burrower"),
    # Veil jelly: fades out of reach; fire pulls it back into the world.
    enemy("ENEMY_HUSH_DRIFTER", "#fdcdff", L("Hush Drifter", "Deriva del silencio", "Deriva do silêncio", "Dérive du silence", "Stilletreiber", "静寂の漂い", "침묵의 표류체", "寂静漂灵"), 48,
          {"radius": 0.7, "height": 1.6}, {"poise": 10, "walk_speed": 1.4, "run_speed": 3.2, "turn_speed": 4, "mass": 20},
          [atk("hush", "pulse", range_min=0, range_max=3.2, windup=0.9, recovery=1.0, cooldown=3.5, damage=12, radius=3.2, knockback=5, element="still", blockable=False),
           atk("mote", "projectile", range_min=4, range_max=16, windup=0.6, recovery=0.8, cooldown=2.4, damage=8, element="still", projectile_speed=11)],
          {"sight_range": 22, "fov": 360, "hearing": 1.0, "leash": 40, "wander_radius": 10, "respawn_hours": 48, "hover": 1.4,
           "behaviors": ["phase"], "phase_on": 4.0, "phase_off": 2.5},
          "drop_drifter", {"family": "enemy", "rank": "common", "species": "jelly", "features": []},
          {"fire": 1.8, "electric": 0.8}, locomotion="flying"),
    # Steals glimmer on a hit and runs: a chase you can win.
    enemy("ENEMY_GLINT_THIEF", "#bdc234", L("Glint Thief", "Ladrón de destellos", "Ladrão de brilhos", "Voleur d'éclats", "Glitzerdieb", "きらめき盗人", "반짝이 도둑", "闪光窃贼"), 26,
          {"radius": 0.35, "height": 1.0}, {"poise": 6, "walk_speed": 2.4, "run_speed": 7.6, "turn_speed": 10, "mass": 25},
          [atk("snatch", "melee", range_min=0, range_max=1.8, windup=0.3, recovery=0.4, cooldown=1.0, damage=4, knockback=2, reach=1.4, arc=70)],
          {"sight_range": 24, "fov": 200, "hearing": 1.5, "leash": 80, "wander_radius": 12, "respawn_hours": 96,
           "behaviors": ["steal"], "steal_amount": 15, "escape_distance": 60},
          "drop_thief", {"family": "enemy", "rank": "common", "species": "goblin", "features": ["sack"], "scale": 0.8}),
    # Night swarm: they wheel around you and dive one at a time; fire scatters them.
    enemy("ENEMY_DUSKWING", "#140a1e", L("Duskwing", "Alacrepúsculo", "Asa-crepúsculo", "Aile-crépuscule", "Dämmerflügler", "宵羽", "황혼날개", "暮翼"), 14,
          {"radius": 0.3, "height": 0.5}, {"poise": 3, "walk_speed": 3.5, "run_speed": 8.0, "turn_speed": 10, "mass": 6},
          [atk("nip", "lunge", range_min=0, range_max=4, windup=0.35, active=0.3, recovery=0.6, cooldown=1.6, damage=4, knockback=2, reach=1.2, arc=60, lunge_speed=12)],
          {"sight_range": 24, "fov": 360, "hearing": 2.0, "leash": 50, "wander_radius": 8, "respawn_hours": 24, "hover": 2.5,
           "behaviors": ["swarm", "fire_shy"], "fire_fear": 7},
          "drop_duskwing", {"family": "enemy", "rank": "common", "species": "bat", "features": [], "scale": 0.7},
          {"fire": 2.0}, locomotion="flying", period="night"),
    # Variants: same body, a different fight.
    enemy("ENEMY_RIME_THORNLING", "#d7fbe3", L("Rime Thornling", "Espinudo de escarcha", "Espinhoso da geada", "Ronceux du givre", "Reifdornling", "霧氷トゲ獣", "서리 가시짐승", "霜棘兽"), 38,
          None, {"run_speed": 6.2}, [atk("frost_bite", "melee", range_min=0, range_max=1.9, windup=0.4, active=0.1, recovery=0.5, cooldown=1.0, damage=9, knockback=3, reach=1.4, arc=55, element="cold", weight=2),
           atk("pounce", "lunge", range_min=3, range_max=7, windup=0.55, active=0.35, recovery=0.8, cooldown=3.5, damage=12, knockback=5, reach=1.4, arc=60, lunge_speed=13)],
          {"sleeps_at_night": False}, "drop_rime", {"features": ["snout", "ears", "mane_spikes", "tail", "claws"]},
          {"fire": 1.8}, variant_of="ENEMY_THORNLING"),
    enemy("ENEMY_STORM_BULWARK", "#6780bc", L("Stormcaller Bulwark", "Baluarte de tormenta", "Baluarte da tempestade", "Rempart d'orage", "Sturmbollwerk", "嵐呼びの巨兵", "폭풍 방벽", "唤雷巨卫"), 130,
          None, {}, None, {"behaviors": ["storm_charged"], "discharge_every": 6.0}, "drop_storm_bulwark",
          {"features": ["horns", "shoulder_spikes", "big_fists", "cracks", "halo"]}, {"electric": 0.2, "water": 1.0}, variant_of="ENEMY_BULWARK"),
    enemy("ENEMY_TIDE_SPITTER", "#20a0a0", L("Tidepool Spitter", "Escupidor de charcas", "Cuspidor das poças", "Cracheur des flaques", "Gezeitenspucker", "潮だまりの吐き屋", "조수웅덩이 침뱉이", "潮洼喷吐怪"), 0,
          None, {}, [atk("brine", "projectile", range_min=3, range_max=18, windup=0.6, active=0.1, recovery=0.8, cooldown=2.0, damage=9, element="water", projectile_speed=16)],
          {"behaviors": ["ambush"], "ambush_range": 7, "preferred_range": 9}, "drop_tide_spitter", {}, {"fire": 1.0, "electric": 1.6}, variant_of="ENEMY_SPITTER"),
    # Variants of the Crag Weaver: the dark and the unreal.
    enemy("ENEMY_CAVE_WEAVER", "#27306a", L("Cave Weaver", "Tejedora de cuevas", "Tecelã das cavernas", "Tisseuse des grottes", "Höhlenweberin", "洞窟の織り蜘蛛", "동굴 거미", "洞织蛛"), 45,
          None, {}, None, {"behaviors": ["ambush", "fire_shy"], "ambush_range": 5, "fire_fear": 5, "sight_range": 12}, "drop_weaver",
          {"features": ["back_plates"]}, {"fire": 2.0}, locomotion="ground", variant_of="ENEMY_CRAG_WEAVER"),
    enemy("ENEMY_VEIL_WEAVER", "#7e2cb0", L("Veil Weaver", "Tejedora del Velo", "Tecelã do Véu", "Tisseuse du Voile", "Schleierweberin", "帳の織り蜘蛛", "장막 거미", "帷织蛛"), 60,
          None, {}, None, {"behaviors": ["drop_from_above", "phase"], "phase_on": 5.0, "phase_off": 2.0}, "drop_veil_weaver",
          {"rank": "elite", "features": ["crystal_back"]}, {"fire": 1.4, "still": 0.0}, variant_of="ENEMY_CRAG_WEAVER"),
    enemy("ENEMY_SHELLBACK", "#d88a7a", L("Shellback", "Lomo de concha", "Dorso-de-concha", "Dos-de-coquille", "Schalenrücken", "殻背", "껍질등", "壳背虫"), 95,
          {"radius": 1.0, "height": 1.3}, {"defense": 2, "poise": 40, "mass": 190}, None, {"armor_mult": 0.05, "flipped_time": 4.0}, "drop_shellback",
          {"rank": "elite", "features": ["back_spikes"], "scale": 1.2}, {"fire": 1.0, "electric": 1.5}, variant_of="ENEMY_BRAMBLE_CARAPACE"),
]

_A = [
    animal("ANIMAL_CRAG_GOAT", "#a88570", L("Crag goat", "Cabra de riscos", "Cabra dos penhascos", "Chèvre des falaises", "Klippenziege", "岩山ヤギ", "벼랑 염소", "岩羊"), 22,
           {"radius": 0.45, "height": 1.1}, {"poise": 6, "walk_speed": 1.6, "run_speed": 7.0, "turn_speed": 8, "mass": 45},
           {"sight_range": 26, "fov": 300, "hearing": 1.5, "skittish": 0.25, "wander_radius": 12, "respawn_hours": 48}, "drop_goat",
           {"species": "grazer", "features": ["curled_horns", "beard"], "scale": 0.8}, locomotion="climber"),
    animal("ANIMAL_REED_HERON", "#8b6491", L("Reed heron", "Garza de juncos", "Garça-dos-juncos", "Héron des roseaux", "Schilfreiher", "葦のサギ", "갈대 왜가리", "芦苇鹭"), 10,
           {"radius": 0.3, "height": 1.3}, {"poise": 2, "walk_speed": 0.9, "run_speed": 6.0, "turn_speed": 6, "mass": 5},
           {"sight_range": 30, "fov": 330, "hearing": 2.2, "skittish": 0.02, "wander_radius": 6, "respawn_hours": 24}, "drop_heron",
           {"species": "wader", "features": []}),
    animal("ANIMAL_TIDE_CRAB", "#df5b51", L("Tide crab", "Cangrejo de marea", "Caranguejo-da-maré", "Crabe des marées", "Gezeitenkrabbe", "潮ガニ", "조수 게", "潮蟹"), 12,
           {"radius": 0.4, "height": 0.5}, {"poise": 4, "walk_speed": 1.2, "run_speed": 4.5, "turn_speed": 10, "mass": 8},
           {"sight_range": 14, "fov": 360, "hearing": 1.2, "skittish": 0.4, "wander_radius": 6, "respawn_hours": 24}, "drop_crab",
           {"species": "shellfolk", "features": []}),
    animal("ANIMAL_DUNE_FOX", "#ff875c", L("Dune fox", "Zorro de las dunas", "Raposa-das-dunas", "Fennec des dunes", "Dünenfuchs", "砂丘ギツネ", "모래언덕 여우", "沙丘狐"), 14,
           {"radius": 0.3, "height": 0.6}, {"poise": 3, "walk_speed": 2.0, "run_speed": 9.0, "turn_speed": 12, "mass": 8},
           {"sight_range": 24, "fov": 330, "hearing": 2.2, "skittish": 0.1, "wander_radius": 14, "respawn_hours": 24}, "drop_fox",
           {"species": "grazer", "features": ["big_ears", "tail"], "scale": 0.55}, period="night"),
    animal("ANIMAL_LUMEN_STAG", "#80ffd0", L("Lumen stag", "Ciervo lumen", "Cervo-lume", "Cerf lumen", "Lumenhirsch", "光角の鹿", "빛뿔 사슴", "明角鹿"), 30,
           {"radius": 0.55, "height": 1.8}, {"poise": 8, "walk_speed": 1.2, "run_speed": 8.5, "turn_speed": 6, "mass": 110},
           {"sight_range": 30, "fov": 300, "hearing": 1.6, "skittish": 0.1, "wander_radius": 16, "respawn_hours": 72}, "drop_lumen_stag",
           {"species": "grazer", "features": ["antlers", "shimmer", "veil", "long_neck"], "scale": 1.1}),
]

ENTITIES = [(d, l) for d, l, _v in _E + _A]
VISUALS = [v for _d, _l, v in _E + _A if v is not None]


def mat(iid, name, desc, icon, value, **kw):
    d = {"id": iid, "category": "material", "icon": "res://assets/icons/%s.svg" % icon, "value": value}
    d.update(kw)
    return d, {"ITEM_" + iid.upper(): name, "ITEM_" + iid.upper() + "_DESC": desc}


ITEMS = [
    mat("gale_feather", L("Gale feather", "Pluma de vendaval", "Pena de vendaval", "Plume de rafale", "Sturmfeder", "疾風の羽", "돌풍 깃털", "疾风羽"),
        L("Stiff and light. It still leans into the wind.", "Rígida y ligera. Aún se inclina hacia el viento.", "Rígida e leve. Ainda se inclina ao vento.", "Raide et légère. Elle penche encore vers le vent.", "Steif und leicht. Sie lehnt sich noch in den Wind.", "硬く軽い。今も風に身を傾ける。", "뻣뻣하고 가볍다. 아직도 바람 쪽으로 기운다.", "硬而轻，仍向着风倾斜。"), "mat_filament", 6),
    mat("eel_scale", L("Eel scale", "Escama de anguila", "Escama de enguia", "Écaille d'anguille", "Aalschuppe", "ウナギの鱗", "뱀장어 비늘", "鳗鳞"),
        L("Slick, green-black, never quite dry.", "Resbaladiza, verdinegra, nunca del todo seca.", "Escorregadia, verde-negra, nunca seca.", "Glissante, vert-noir, jamais tout à fait sèche.", "Glatt, grünschwarz, nie ganz trocken.", "ぬめる緑黒の鱗。乾ききらない。", "미끄럽고 검푸르며 마르지 않는다.", "滑腻墨绿，永远不干。"), "mat_plate", 6),
    mat("weaver_silk", L("Weaver silk", "Seda de tejedora", "Seda de tecelã", "Soie de tisseuse", "Weberseide", "織り蜘蛛の糸", "거미 비단", "织蛛丝"),
        L("Strong enough to hang a person from a cliff. Climbers pay well for it.", "Tan fuerte que sostiene a una persona en un risco. Los escaladores pagan bien.", "Forte o bastante para segurar alguém num penhasco. Escaladores pagam bem.", "Assez solide pour retenir quelqu'un à une falaise. Les grimpeurs paient bien.", "Stark genug, um jemanden an einer Klippe zu halten. Kletterer zahlen gut.", "崖で人を吊れるほど強い。登攀家が高く買う。", "사람을 절벽에 매달 만큼 질기다. 등반가들이 비싸게 산다.", "结实得能把人吊在崖上，攀岩者肯出高价。"), "mat_fiber", 8),
    mat("carapace_shard", L("Carapace shard", "Fragmento de caparazón", "Fragmento de carapaça", "Éclat de carapace", "Panzerscherbe", "甲殻の欠片", "갑각 조각", "甲壳碎片"),
        L("Curved and hard as fired clay. Smiths layer it into shields.", "Curvo y duro como arcilla cocida. Los herreros lo usan en escudos.", "Curvo e duro como barro cozido. Ferreiros o usam em escudos.", "Courbe et dur comme la terre cuite. Les forgerons en font des boucliers.", "Gewölbt und hart wie gebrannter Ton. Schmiede schichten ihn in Schilde.", "焼き物のように硬い。鍛冶屋が盾に重ねる。", "구운 흙처럼 단단하다. 대장장이가 방패에 덧댄다.", "弯而硬如陶，铁匠用它叠盾。"), "mat_plate", 7, tags=["armor"]),
    mat("cinder_ember", L("Cinder ember", "Brasa de ceniza", "Brasa de cinza", "Braise de cendre", "Aschenglut", "燃えさし", "잿불 씨", "余烬火种"),
        L("Warm in the hand for days. Keep it away from dry grass.", "Tibia en la mano durante días. Lejos de la hierba seca.", "Morna na mão por dias. Longe da grama seca.", "Tiède dans la main des jours durant. Loin de l'herbe sèche.", "Tagelang warm in der Hand. Fern von trockenem Gras halten.", "何日も手の中で温かい。枯れ草に近づけるな。", "며칠이고 손에서 따뜻하다. 마른 풀 근처엔 두지 마라.", "握在手里暖好几天，别靠近干草。"), "mat_sap", 7, tags=["flammable"]),
    mat("hush_gel", L("Hush gel", "Gel de silencio", "Gel do silêncio", "Gel de silence", "Stillegel", "静寂のゼリー", "침묵 젤", "寂静凝胶"),
        L("Cold, faintly violet. Sounds die when you hold it close.", "Frío, levemente violeta. Los sonidos mueren al acercarlo.", "Frio, levemente violeta. Os sons morrem perto dele.", "Froid, légèrement violet. Les sons meurent à son contact.", "Kalt, leicht violett. Geräusche ersterben in seiner Nähe.", "冷たく淡い紫。近づけると音が消える。", "차갑고 옅은 보랏빛. 가까이 대면 소리가 죽는다.", "冰冷微紫，靠近它声音就消失。"), "mat_gland", 16),
    mat("lumen_antler", L("Lumen antler", "Asta lumen", "Galhada-lume", "Bois lumen", "Lumengeweih", "光角", "빛뿔", "明角"),
        L("Shed, not taken. It glows a little in the dark.", "Mudada, no arrancada. Brilla un poco en la oscuridad.", "Caída, não arrancada. Brilha um pouco no escuro.", "Tombé, pas arraché. Il luit un peu dans le noir.", "Abgeworfen, nicht genommen. Leuchtet leicht im Dunkeln.", "奪ったのではなく落ちたもの。暗闇でかすかに光る。", "빼앗은 게 아니라 떨어진 것. 어둠 속에서 은은히 빛난다.", "是自然脱落的，不是夺来的。黑暗中微微发光。"), "mat_gem", 30, rarity=2),
    ({"id": "raw_fish", "category": "food", "icon": "res://assets/icons/food_meat.svg", "use_action": "eat", "value": 3, "effects": [{"type": "heal", "amount": 12}], "cook": {"heal": 1.5, "swift": 0.5}},
     {"ITEM_RAW_FISH": L("Raw fish", "Pescado crudo", "Peixe cru", "Poisson cru", "Roher Fisch", "生魚", "생선", "生鱼"),
      "ITEM_RAW_FISH_DESC": L("Better cooked. Ilo would say so, loudly.", "Mejor cocinado. Ilo lo diría, y alto.", "Melhor cozido. Ilo diria isso, bem alto.", "Meilleur cuit. Ilo le dirait, et fort.", "Gekocht besser. Ilo würde das laut sagen.", "焼いたほうがいい。イロなら大声でそう言う。", "익히는 게 낫다. 일로라면 크게 말할 것이다.", "还是煮熟好，伊洛一定会大声这么说。")}),
]


def drops(*entries):
    return [{"id": i, "chance": c, "count": n} for i, c, n in entries]


LOOT = {
    "drop_gale_kite": drops(("gale_feather", 0.9, [1, 2]), ("raw_meat", 0.3, [1, 1])),
    "drop_mire_eel": drops(("eel_scale", 0.9, [1, 2]), ("raw_fish", 0.6, [1, 2])),
    "drop_weaver": drops(("weaver_silk", 0.9, [1, 2]), ("fiber", 0.4, [1, 2])),
    "drop_veil_weaver": drops(("weaver_silk", 1.0, [2, 3]), ("shade_essence", 0.4, [1, 1])),
    "drop_carapace": drops(("carapace_shard", 0.9, [1, 2]), ("amber_sap", 0.4, [1, 2])),
    "drop_shellback": drops(("carapace_shard", 1.0, [2, 3]), ("eel_scale", 0.3, [1, 1]), ("glimmer_shard", 0.5, [1, 3])),
    "drop_imp": drops(("cinder_ember", 0.9, [1, 1]), ("emberroot", 0.3, [1, 1])),
    "drop_burrower": drops(("scuttler_chitin", 0.8, [1, 2]), ("glass_shard", 0.3, [1, 1])),
    "drop_drifter": drops(("hush_gel", 0.85, [1, 1])),
    "drop_thief": drops(("glimmer_shard", 1.0, [2, 4])),
    "drop_duskwing": drops(("beast_hide", 0.25, [1, 1])),
    "drop_rime": drops(("thorn_fang", 0.8, [1, 2]), ("frostmint", 0.4, [1, 1])),
    "drop_storm_bulwark": drops(("bulwark_plate", 1.0, [1, 2]), ("glimmer_shard", 0.6, [2, 4])),
    "drop_tide_spitter": drops(("spitter_gland", 0.8, [1, 1]), ("raw_fish", 0.4, [1, 1])),
    "drop_goat": drops(("raw_meat", 1.0, [1, 1]), ("beast_hide", 0.5, [1, 1])),
    "drop_heron": drops(("gale_feather", 0.5, [1, 1])),
    "drop_crab": drops(("raw_fish", 0.6, [1, 1])),
    "drop_fox": drops(("beast_hide", 0.7, [1, 1])),
    "drop_lumen_stag": drops(("lumen_antler", 0.6, [1, 1]), ("raw_meat", 0.5, [1, 1])),
    # Chests that tell you where you are.
    "chest_common@forest": drops(("glimmer_shard", 1.0, [2, 5]), ("amber_sap", 0.6, [2, 3]), ("cap_mushroom", 0.6, [2, 4]), ("glowmoss", 0.4, [1, 2]), ("weaver_silk", 0.2, [1, 1])),
    "chest_common@coast": drops(("glimmer_shard", 1.0, [3, 6]), ("raw_fish", 0.5, [1, 2]), ("eel_scale", 0.4, [1, 2]), ("resin_bomb", 0.3, [1, 1]), ("carapace_shard", 0.3, [1, 1])),
    "chest_common@lakeshore": drops(("glimmer_shard", 1.0, [2, 5]), ("raw_fish", 0.6, [1, 2]), ("fiber", 0.5, [2, 3]), ("eel_scale", 0.3, [1, 1])),
    "chest_common@highlands": drops(("glimmer_shard", 1.0, [2, 5]), ("iron_ore", 0.7, [1, 3]), ("frostmint", 0.5, [1, 2]), ("gale_feather", 0.3, [1, 2]), ("whetstone", 0.3, [1, 1])),
    "chest_common@desert": drops(("glimmer_shard", 1.0, [3, 6]), ("glass_shard", 0.5, [1, 2]), ("scuttler_chitin", 0.5, [1, 2]), ("cinder_ember", 0.3, [1, 1])),
    "chest_common@veil": drops(("glimmer_shard", 1.0, [4, 7]), ("hush_gel", 0.5, [1, 1]), ("shade_essence", 0.4, [1, 1]), ("wisp_filament", 0.4, [1, 1])),
}


def sp(entity, weight, group, **kw):
    d = {"entity": entity, "weight": weight, "group": group}
    d.update(kw)
    return d


DRY = ["clear", "cloudy", "windy"]
REGION_SPAWNS = {
    "valley": {
        "enemy_spawns": [sp("ENEMY_THORNLING", 3, [2, 3]), sp("ENEMY_SPITTER", 1, [1, 1]), sp("ENEMY_CINDER_IMP", 0.8, [1, 2], weather=DRY, period="day"),
                         sp("ENEMY_GLINT_THIEF", 0.5, [1, 1], period="day"), sp("ENEMY_STORM_BULWARK", 1.2, [1, 1], weather=["storm"]),
                         sp("ENEMY_WISP", 2, [1, 2], period="night"), sp("ENEMY_DUSKWING", 1.2, [3, 5], period="night"),
                         sp("ENEMY_GALE_KITE", 1, [1, 1], habitat="cliff")],
        "animal_spawns": [sp("ANIMAL_WOOLHORN", 3, [2, 4]), sp("ANIMAL_BURROWHOP", 2, [1, 3])],
    },
    "forest": {
        "enemy_spawns": [sp("ENEMY_BRAMBLE_CARAPACE", 2.5, [1, 2]), sp("ENEMY_SPITTER", 2, [1, 2]), sp("ENEMY_THORNLING", 1, [2, 3]),
                         sp("ENEMY_WISP", 1.5, [1, 2], period="night"), sp("ENEMY_DUSKWING", 2, [3, 5], period="night"),
                         sp("ENEMY_CRAG_WEAVER", 1, [1, 1], habitat="cliff")],
        "animal_spawns": [sp("ANIMAL_BURROWHOP", 2, [1, 3]), sp("ANIMAL_WOOLHORN", 1, [2, 3])],
    },
    "highlands": {
        "enemy_spawns": [sp("ENEMY_RIME_THORNLING", 3, [2, 3], weather=["snow", "cloudy", "windy"]), sp("ENEMY_THORNLING", 1.5, [2, 3], weather=["clear", "rain", "fog"]),
                         sp("ENEMY_BULWARK", 1, [1, 1]), sp("ENEMY_STORM_BULWARK", 2, [1, 1], weather=["storm"]), sp("ENEMY_GALE_KITE", 1.5, [1, 2]),
                         sp("ENEMY_WISP", 1, [1, 1], period="night"), sp("ENEMY_DUSKWING", 1, [3, 4], period="night"),
                         sp("ENEMY_CRAG_WEAVER", 3, [1, 2], habitat="cliff"), sp("ENEMY_GALE_KITE", 1, [1, 1], habitat="cliff")],
        "animal_spawns": [sp("ANIMAL_WOOLHORN", 1.5, [2, 3]), sp("ANIMAL_CRAG_GOAT", 1, [2, 3]), sp("ANIMAL_CRAG_GOAT", 3, [2, 4], habitat="cliff")],
    },
    "lakeshore": {
        "enemy_spawns": [sp("ENEMY_SPITTER", 2, [1, 2]), sp("ENEMY_GLINT_THIEF", 0.4, [1, 1], period="day"), sp("ENEMY_WISP", 2, [1, 2], period="night"),
                         sp("ENEMY_MIRE_EEL", 3, [1, 2], habitat="water")],
        "animal_spawns": [sp("ANIMAL_REED_HERON", 3, [1, 2]), sp("ANIMAL_BURROWHOP", 1.5, [1, 2]), sp("ANIMAL_WOOLHORN", 0.7, [2, 3])],
    },
    "coast": {
        "enemy_spawns": [sp("ENEMY_TIDE_SPITTER", 2.5, [1, 2]), sp("ENEMY_SHELLBACK", 1.2, [1, 1]), sp("ENEMY_GALE_KITE", 1, [1, 2]),
                         sp("ENEMY_GLINT_THIEF", 0.5, [1, 1], period="day"), sp("ENEMY_THORNLING", 0.7, [2, 2]),
                         sp("ENEMY_MIRE_EEL", 2, [1, 2], habitat="water"), sp("ENEMY_GALE_KITE", 1, [1, 1], habitat="cliff")],
        "animal_spawns": [sp("ANIMAL_TIDE_CRAB", 3, [2, 4]), sp("ANIMAL_BURROWHOP", 0.6, [1, 2])],
    },
    "desert": {
        "enemy_spawns": [sp("ENEMY_SCUTTLER", 3, [2, 4]), sp("ENEMY_DUNE_BURROWER", 2.5, [1, 1]), sp("ENEMY_CINDER_IMP", 1, [1, 2], period="day"),
                         sp("ENEMY_SPITTER", 0.5, [1, 1]), sp("ENEMY_WISP", 1, [1, 2], period="night")],
        "animal_spawns": [sp("ANIMAL_DUNE_FOX", 2, [1, 2], period="night"), sp("ANIMAL_BURROWHOP", 0.8, [1, 2])],
    },
    "veil": {
        "enemy_spawns": [sp("ENEMY_SHADE", 3, [1, 2]), sp("ENEMY_HUSH_DRIFTER", 2.5, [1, 2]), sp("ENEMY_VEIL_WEAVER", 1.5, [1, 1]),
                         sp("ENEMY_WISP", 1.5, [2, 3]), sp("ENEMY_VEIL_WEAVER", 2, [1, 1], habitat="cliff")],
        "animal_spawns": [sp("ANIMAL_LUMEN_STAG", 1, [1, 2])],
        "animal_density": 0.25,
    },
}

DISCOVERIES = []   # [(discovery dict, loc dict)]  — phase 3/4

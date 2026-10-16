#!/usr/bin/env python3
"""Generate CraftingForever's bundled data files.

Sources (not shipped with the addon, pass their paths on the command line):
  * pfQuest (https://github.com/shagu/pfQuest, MIT): spawn coordinates of gathering
    objects and creatures, in zone percent coordinates, plus zone dimensions.
  * CMaNGOS classic-db (https://github.com/cmangos/classic-db): the 1.12 world database,
    used for creature levels/ranks and skinning loot tables.

Usage:
  python3 tools/gen_data.py <pfQuest/db> <ClassicDB_*.sql or .sql.gz>

Writes Data/Zones.lua, Data/Nodes.lua, Data/Skinning.lua and Data/Locale.lua.
Data/Locale.lua also maps the item/NPC/place names used in Data/Guides.lua, so
re-run this after editing the guides.
"""
import gzip
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(__file__))
import pfdb  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# areaID: (mapFile, continent, minLevel, maxLevel, faction, uiMapID)
# faction: "A" alliance territory, "H" horde territory, "C" contested.
# uiMapID is the map ID of the modern client (WoW: Forever / Classic Era), from
# the UiMapAssignment table. The addon keys all its data by uiMapID.
ZONES = {
    1: ("DunMorogh", 2, 1, 10, "A", 1426),
    3: ("Badlands", 2, 35, 45, "C", 1418),
    4: ("BlastedLands", 2, 45, 55, "C", 1419),
    8: ("SwampOfSorrows", 2, 35, 45, "C", 1435),
    10: ("Duskwood", 2, 18, 30, "A", 1431),
    11: ("Wetlands", 2, 20, 30, "A", 1437),
    12: ("Elwynn", 2, 1, 10, "A", 1429),
    14: ("Durotar", 1, 1, 10, "H", 1411),
    15: ("Dustwallow", 1, 35, 45, "C", 1445),
    16: ("Aszhara", 1, 45, 55, "C", 1447),
    17: ("Barrens", 1, 10, 25, "H", 1413),
    28: ("WesternPlaguelands", 2, 51, 58, "C", 1422),
    33: ("Stranglethorn", 2, 30, 45, "C", 1434),
    36: ("Alterac", 2, 30, 40, "C", 1416),
    38: ("LochModan", 2, 10, 20, "A", 1432),
    40: ("Westfall", 2, 10, 20, "A", 1436),
    41: ("DeadwindPass", 2, 55, 60, "C", 1430),
    44: ("Redridge", 2, 15, 25, "A", 1433),
    45: ("Arathi", 2, 30, 40, "C", 1417),
    46: ("BurningSteppes", 2, 50, 58, "C", 1428),
    47: ("Hinterlands", 2, 40, 50, "C", 1425),
    51: ("SearingGorge", 2, 43, 50, "C", 1427),
    85: ("Tirisfal", 2, 1, 10, "H", 1420),
    130: ("Silverpine", 2, 10, 20, "H", 1421),
    139: ("EasternPlaguelands", 2, 53, 60, "C", 1423),
    141: ("Teldrassil", 1, 1, 10, "A", 1438),
    148: ("Darkshore", 1, 10, 20, "A", 1439),
    215: ("Mulgore", 1, 1, 10, "H", 1412),
    267: ("Hilsbrad", 2, 20, 30, "C", 1424),
    331: ("Ashenvale", 1, 18, 30, "C", 1440),
    357: ("Feralas", 1, 40, 50, "C", 1444),
    361: ("Felwood", 1, 48, 55, "C", 1448),
    400: ("ThousandNeedles", 1, 25, 35, "C", 1441),
    405: ("Desolace", 1, 30, 40, "C", 1443),
    406: ("StonetalonMountains", 1, 15, 27, "C", 1442),
    440: ("Tanaris", 1, 40, 50, "C", 1446),
    490: ("UngoroCrater", 1, 48, 55, "C", 1449),
    493: ("Moonglade", 1, 55, 60, "C", 1450),
    618: ("Winterspring", 1, 53, 60, "C", 1452),
    1377: ("Silithus", 1, 55, 60, "C", 1451),
}

# material key -> (profession, english item name or None, [gathering object names], skill)
# skill None = take it from pfQuest's mines/herbs meta data.
GATHER = {
    # Mining
    "copper": ("mining", "Copper Ore", ["Copper Vein"], None),
    "tin": ("mining", "Tin Ore", ["Tin Vein"], None),
    "incendicite": ("mining", "Incendicite Ore", ["Incendicite Mineral Vein"], None),
    "silver": ("mining", "Silver Ore", ["Silver Vein", "Ooze Covered Silver Vein"], None),
    "bloodstone": ("mining", "Lesser Bloodstone Ore", ["Lesser Bloodstone Deposit"], None),
    "iron": ("mining", "Iron Ore", ["Iron Deposit", "Ooze Covered Iron Deposit"], None),
    "gold": ("mining", "Gold Ore", ["Gold Vein", "Ooze Covered Gold Vein"], None),
    "mithril": ("mining", "Mithril Ore", ["Mithril Deposit", "Ooze Covered Mithril Deposit"], None),
    "truesilver": ("mining", "Truesilver Ore", ["Truesilver Deposit", "Ooze Covered Truesilver Deposit"], None),
    "darkiron": ("mining", "Dark Iron Ore", ["Dark Iron Deposit"], None),
    "thorium": ("mining", "Thorium Ore",
                ["Small Thorium Vein", "Ooze Covered Thorium Vein", "Hakkari Thorium Vein",
                 "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"], None),
    # Herbalism
    "peacebloom": ("herbalism", "Peacebloom", ["Peacebloom"], None),
    "silverleaf": ("herbalism", "Silverleaf", ["Silverleaf"], None),
    "earthroot": ("herbalism", "Earthroot", ["Earthroot"], None),
    "mageroyal": ("herbalism", "Mageroyal", ["Mageroyal"], None),
    "briarthorn": ("herbalism", "Briarthorn", ["Briarthorn"], None),
    "stranglekelp": ("herbalism", "Stranglekelp", ["Stranglekelp"], None),
    "bruiseweed": ("herbalism", "Bruiseweed", ["Bruiseweed"], None),
    "steelbloom": ("herbalism", "Wild Steelbloom", ["Wild Steelbloom"], None),
    "gravemoss": ("herbalism", "Grave Moss", ["Grave Moss"], None),
    "kingsblood": ("herbalism", "Kingsblood", ["Kingsblood"], None),
    "liferoot": ("herbalism", "Liferoot", ["Liferoot"], None),
    "fadeleaf": ("herbalism", "Fadeleaf", ["Fadeleaf"], None),
    "goldthorn": ("herbalism", "Goldthorn", ["Goldthorn"], None),
    "khadgar": ("herbalism", "Khadgar's Whisker", ["Khadgar's Whisker"], None),
    "wintersbite": ("herbalism", "Wintersbite", ["Wintersbite"], None),
    "firebloom": ("herbalism", "Firebloom", ["Firebloom"], None),
    "purplelotus": ("herbalism", "Purple Lotus", ["Purple Lotus"], None),
    "arthas": ("herbalism", "Arthas' Tears", ["Arthas' Tears"], None),
    "sungrass": ("herbalism", "Sungrass", ["Sungrass"], None),
    "blindweed": ("herbalism", "Blindweed", ["Blindweed"], None),
    "ghostmushroom": ("herbalism", "Ghost Mushroom", ["Ghost Mushroom"], None),
    "gromsblood": ("herbalism", "Gromsblood", ["Gromsblood"], None),
    "sansam": ("herbalism", "Golden Sansam", ["Golden Sansam"], None),
    "dreamfoil": ("herbalism", "Dreamfoil", ["Dreamfoil"], None),
    "silversage": ("herbalism", "Mountain Silversage", ["Mountain Silversage"], None),
    "plaguebloom": ("herbalism", "Plaguebloom", ["Plaguebloom"], None),
    "icecap": ("herbalism", "Icecap", ["Icecap"], None),
    "blacklotus": ("herbalism", "Black Lotus", ["Black Lotus"], None),
    # Fishing pools (skill = suggested fishing skill for the waters they appear in)
    "deviatefish": ("fishing", "Deviate Fish", ["School of Deviate Fish"], 25),
    "sagefish": ("fishing", "Raw Sagefish", ["Sagefish School"], 50),
    "blackmouth": ("fishing", "Oily Blackmouth", ["Oily Blackmouth School"], 100),
    "firefin": ("fishing", "Firefin Snapper", ["Firefin Snapper School"], 100),
    "wreckage": ("fishing", None, ["Floating Wreckage", "Floating Debris"], 100),
    "greatersagefish": ("fishing", "Raw Greater Sagefish", ["Greater Sagefish School"], 175),
    "stonescale": ("fishing", "Stonescale Eel", ["Stonescale Eel Swarm"], 250),
    "elementalwater": ("fishing", "Elemental Water", ["Patch of Elemental Water"], 250),
}

# fishing pools are not in the world database's spawn pools; about a third of a
# zone's pool spots hold a pool at any time
DEFAULT_FISH_AVAILABILITY = 0.33
DEFAULT_RESPAWN = 300

# material key -> (itemID, english name, minimum drop chance in % for a mob to count)
SKIN = {
    "ruinedscraps": (2934, "Ruined Leather Scraps", 10),
    "lightleather": (2318, "Light Leather", 10),
    "lighthide": (783, "Light Hide", 2),
    "mediumleather": (2319, "Medium Leather", 10),
    "mediumhide": (4232, "Medium Hide", 2),
    "heavyleather": (4234, "Heavy Leather", 10),
    "heavyhide": (4235, "Heavy Hide", 2),
    "thickleather": (4304, "Thick Leather", 10),
    "thickhide": (8169, "Thick Hide", 2),
    "ruggedleather": (8170, "Rugged Leather", 10),
    "ruggedhide": (8171, "Rugged Hide", 2),
    "scorpidscale": (8154, "Scorpid Scale", 5),
    "heavyscorpid": (15408, "Heavy Scorpid Scale", 5),
    "turtlescale": (8167, "Turtle Scale", 5),
    "wornscale": (8165, "Worn Dragonscale", 5),
    "devilsaur": (15417, "Devilsaur Leather", 5),
    "warbear": (15419, "Warbear Leather", 5),
    "chimera": (15423, "Chimera Leather", 5),
    "frostsaber": (15422, "Frostsaber Leather", 5),
    "greendragonscale": (15412, "Green Dragonscale", 3),
    "bluedragonscale": (15415, "Blue Dragonscale", 3),
    "blackdragonscale": (15416, "Black Dragonscale", 3),
    "reddragonscale": (15414, "Red Dragonscale", 3),
}

# profession skill line IDs (for localized skill names)
SKILLS = {
    "mining": 186, "herbalism": 182, "skinning": 393, "fishing": 356, "alchemy": 171,
    "blacksmithing": 164, "leatherworking": 165, "tailoring": 197, "engineering": 202,
    "enchanting": 333, "firstaid": 129, "cooking": 185,
}

LOCALES = ["deDE", "esES"]


def pack(x, y):
    """Pack zone percent coordinates (0-100, one decimal) into one integer."""
    return int(round(x * 10)) * 10000 + int(round(y * 10))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write(path, lines):
    with open(os.path.join(ROOT, path), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("wrote", path)


def dedupe(points, sizes, yards=6.0):
    """Drop spawn points closer than `yards` to an already kept one (same zone)."""
    w, h = sizes
    kept = []
    for x, y in sorted(points):
        for kx, ky in kept:
            dx, dy = (x - kx) * w / 100, (y - ky) * h / 100
            if dx * dx + dy * dy < yards * yards:
                break
        else:
            kept.append((x, y))
    return kept


def packed_list(points, per_line=12):
    vals = [str(pack(x, y)) for x, y in points]
    rows = [", ".join(vals[i:i + per_line]) for i in range(0, len(vals), per_line)]
    return rows


# ---------------------------------------------------------------- zones

def gen_zones(pf):
    names = pfdb.load_names(os.path.join(pf, "enUS", "zones.lua"))
    sizes = pfdb.load_minimap(os.path.join(pf, "minimap.lua"))
    out = [
        "-- Generated by tools/gen_data.py - do not edit by hand.",
        "-- [uiMapID] = { name, areaID, continent, minLevel, maxLevel, faction, widthYards, heightYards }",
        "CraftingForever_Zones = {",
    ]
    for aid in sorted(ZONES, key=lambda a: ZONES[a][5]):
        mf, cont, lo, hi, fac, ui = ZONES[aid]
        w, h = sizes[aid]
        out.append("  [%d] = { %s, %d, %d, %d, %d, %s, %.2f, %.2f }," % (
            ui, lua_str(names[aid]), aid, cont, lo, hi, lua_str(fac), w, h))
    out.append("}")
    write("Data/Zones.lua", out)
    return sizes


# ---------------------------------------------------------------- world database pools

def node_availability(sql):
    """{gameobject entry: average share of its spawn points holding a node}.

    Gathering nodes are spawned through pools that keep only `max_limit` of their
    members active, so most spawn points are empty at any moment.
    """
    spawns = {}
    by_entry = defaultdict(list)
    for r in sql_rows(sql, "gameobject"):
        guid, entry = int(r[0]), int(r[1])
        spawns[guid] = entry
        by_entry[entry].append(guid)
    limit = {int(r[0]): int(r[1]) for r in sql_rows(sql, "pool_template")}
    chances = defaultdict(list)   # pool -> member chances
    member = {}                    # guid -> (pool, chance)
    for r in sql_rows(sql, "pool_gameobject"):
        guid, pool, chance = int(r[0]), int(r[1]), float(r[2])
        member[guid] = (pool, chance)
        chances[pool].append(chance)
    for r in sql_rows(sql, "pool_gameobject_template"):
        entry, pool, chance = int(r[0]), int(r[1]), float(r[2])
        for guid in by_entry[entry]:
            if guid not in member:
                member[guid] = (pool, chance)
                chances[pool].append(chance)
    mother = {}
    for r in sql_rows(sql, "pool_pool"):
        pool, mom, chance = int(r[0]), int(r[1]), float(r[2])
        mother[pool] = (mom, chance)
        chances[mom].append(chance)

    def share(pool, chance):
        lim = limit.get(pool, 1)
        cs = chances[pool]
        explicit = sum(c for c in cs if c > 0)
        equal = sum(1 for c in cs if c == 0)
        if chance > 0:
            return min(1.0, lim * chance / 100)
        if not equal:
            return 0.0
        rest = max(0.0, 100 - explicit) / 100 if explicit else 1.0
        return min(1.0, lim * rest / equal)

    def active(pool, depth=0):
        if pool not in mother or depth > 5:
            return 1.0
        mom, chance = mother[pool]
        return share(mom, chance) * active(mom, depth + 1)

    out = {}
    for entry, guids in by_entry.items():
        vals = []
        for g in guids:
            if g in member:
                pool, chance = member[g]
                vals.append(share(pool, chance) * active(pool))
            else:
                vals.append(1.0)
        out[entry] = sum(vals) / len(vals)
    return out


# ---------------------------------------------------------------- gathering nodes

def gen_nodes(pf, sql, sizes, items_en):
    objects = pfdb.load_spawns(os.path.join(pf, "objects.lua"))
    onames = pfdb.load_names(os.path.join(pf, "enUS", "objects.lua"))
    skill = {}
    for key in ("mines", "herbs"):
        for oid, req in pfdb.load_meta(os.path.join(pf, "meta.lua"), key).items():
            skill[-oid] = int(req)
    fish = {-oid for oid in pfdb.load_meta(os.path.join(pf, "meta.lua"), "fish")}
    avail = node_availability(sql)

    by_name = defaultdict(list)
    for oid in set(skill) | fish:
        by_name[onames.get(oid)].append(oid)

    out = [
        "-- Generated by tools/gen_data.py - do not edit by hand.",
        "-- Spawn points derived from pfQuest (MIT, https://github.com/shagu/pfQuest);",
        "-- node availability from the CMaNGOS classic world database spawn pools.",
        "-- Coordinates are packed as floor(x*10)*10000 + floor(y*10) in zone percent.",
        "-- zones[uiMapID] = { a = share of spawn points holding a node, r = respawn seconds, points... }",
        "CraftingForever_GatherDB = {",
    ]
    used_objects = {}
    for key, (prof, iname, nodes, fixed_skill) in GATHER.items():
        req = None
        points = defaultdict(list)
        for nname in nodes:
            oids = by_name.get(nname)
            if not oids:
                # still listed under `nodes` so in-game gathering recognises it
                print("  note: no spawn data for %r" % nname)
                continue
            used_objects[nname] = oids
            for oid in oids:
                if oid in skill:
                    req = skill[oid] if req is None else min(req, skill[oid])
                for x, y, zone, respawn in objects.get(oid, {"coords": []})["coords"]:
                    if zone in ZONES:
                        points[zone].append((x, y, oid, respawn))
        if fixed_skill is not None:
            req = fixed_skill
        item = items_en[iname] if iname else 0
        out.append("  [%s] = {" % lua_str(key))
        out.append("    prof = %s, item = %d, name = %s, skill = %d," % (
            lua_str(prof), item, lua_str(iname or nodes[0]), max(req, 1)))
        out.append("    nodes = { %s }," % ", ".join(lua_str(n) for n in nodes))
        out.append("    zones = {")
        total = 0
        for zone in sorted(points):
            raw = points[zone]
            pts = dedupe([(x, y) for x, y, _, _ in raw], sizes[zone])
            total += len(pts)
            if prof == "fishing":
                a = DEFAULT_FISH_AVAILABILITY
            else:
                a = sum(avail.get(oid, 1.0) for _, _, oid, _ in raw) / len(raw)
            resp = sorted(r for _, _, _, r in raw if r > 0)
            r = resp[len(resp) // 2] if resp else DEFAULT_RESPAWN
            out.append("      [%d] = { a = %.3f, r = %d," % (ZONES[zone][5], a, r))
            out.extend("        %s," % row for row in packed_list(pts))
            out.append("      },")
        out.append("    },")
        out.append("  },")
        print("  %-15s skill %3d  %5d points in %d zones" % (key, max(req, 1), total, len(points)))
    out.append("}")
    write("Data/Nodes.lua", out)
    return used_objects


# ---------------------------------------------------------------- skinning

def sql_rows(sql_path, table):
    """Yield the tuples of every `INSERT INTO table VALUES (...),(...)` statement."""
    opener = gzip.open if sql_path.endswith(".gz") else open
    prefix = "INSERT INTO `%s` VALUES " % table
    with opener(sql_path, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith(prefix):
                yield from _parse_tuples(line[len(prefix):])


def _parse_tuples(s):
    i, n = 0, len(s)
    while i < n:
        if s[i] != "(":
            i += 1
            continue
        i += 1
        row, cur, quoted = [], [], False
        while i < n:
            c = s[i]
            if quoted:
                if c == "\\":
                    cur.append(s[i + 1])
                    i += 2
                    continue
                if c == "'":
                    quoted = False
                else:
                    cur.append(c)
            elif c == "'":
                quoted = True
            elif c == ",":
                row.append("".join(cur))
                cur = []
            elif c == ")":
                row.append("".join(cur))
                i += 1
                break
            else:
                cur.append(c)
            i += 1
        yield row


def table_columns(sql_path, table):
    opener = gzip.open if sql_path.endswith(".gz") else open
    cols, inside = [], False
    with opener(sql_path, "rt", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("CREATE TABLE `%s`" % table):
                inside = True
                continue
            if inside:
                line = line.strip()
                if line.startswith("`"):
                    cols.append(line.split("`")[1])
                else:
                    if cols and not line.startswith("`"):
                        if line.startswith("PRIMARY") or line.startswith(")"):
                            return cols
    return cols


def gen_skinning(pf, sql, sizes):
    cols = table_columns(sql, "creature_template")
    ix = {c: i for i, c in enumerate(cols)}
    creatures = {}
    for row in sql_rows(sql, "creature_template"):
        lootid = int(row[ix["SkinningLootId"]])
        rank = int(row[ix["Rank"]])
        # normal and elite mobs only: rares and bosses are not farmable
        if lootid and rank in (0, 1):
            creatures[int(row[ix["Entry"]])] = {
                "name": row[ix["Name"]], "lmin": int(row[ix["MinLevel"]]),
                "lmax": int(row[ix["MaxLevel"]]), "elite": rank == 1, "loot": lootid,
            }

    item_to_key = {item: key for key, (item, _, _) in SKIN.items()}
    loot = defaultdict(dict)  # lootid -> {key: chance}
    for entry, item, chance, *_ in sql_rows(sql, "skinning_loot_template"):
        key = item_to_key.get(int(item))
        if key:
            loot[int(entry)][key] = float(chance)

    units = pfdb.load_spawns(os.path.join(pf, "units.lua"))
    mobs, spawns = {}, defaultdict(dict)
    for cid, c in creatures.items():
        drops = {k: ch for k, ch in loot.get(c["loot"], {}).items() if ch >= SKIN[k][2]}
        if not drops:
            continue
        u = units.get(cid)
        if not u or "fac" in u:  # friendly NPCs carry a faction tag in pfQuest
            continue
        per_zone = defaultdict(list)
        for x, y, zone, _ in u["coords"]:
            if zone in ZONES:
                per_zone[zone].append((x, y))
        if not per_zone:
            continue
        resp = sorted(r for _, _, _, r in u["coords"] if r > 0)
        c["respawn"] = resp[len(resp) // 2] if resp else DEFAULT_RESPAWN
        mobs[cid] = (c, drops)
        for zone, pts in per_zone.items():
            spawns[zone][cid] = dedupe(pts, sizes[zone], 4.0)

    out = [
        "-- Generated by tools/gen_data.py - do not edit by hand.",
        "-- Creature spawns derived from pfQuest (MIT, https://github.com/shagu/pfQuest);",
        "-- levels and skinning loot from the CMaNGOS classic world database.",
        "CraftingForever_SkinDB = {",
        "  materials = {",
    ]
    for key, (item, name, _) in SKIN.items():
        out.append("    [%s] = { item = %d, name = %s }," % (lua_str(key), item, lua_str(name)))
    out.append("  },")
    out.append("  -- [creatureID] = { name, minLevel, maxLevel, elite, { [material] = drop% }, respawnSeconds }")
    out.append("  mobs = {")
    for cid in sorted(mobs):
        c, drops = mobs[cid]
        d = ", ".join("%s = %.1f" % (k, v) for k, v in sorted(drops.items()))
        out.append("    [%d] = { %s, %d, %d, %s, { %s }, %d }," % (
            cid, lua_str(c["name"]), c["lmin"], c["lmax"], "true" if c["elite"] else "false", d,
            c["respawn"]))
    out.append("  },")
    out.append("  -- [uiMapID] = { [creatureID] = { packed spawn points } }")
    out.append("  spawns = {")
    total = 0
    for zone in sorted(spawns):
        out.append("    [%d] = {" % ZONES[zone][5])
        for cid in sorted(spawns[zone]):
            pts = spawns[zone][cid]
            total += len(pts)
            out.append("      [%d] = { %s }," % (cid, ", ".join(str(pack(x, y)) for x, y in pts)))
        out.append("    },")
    out.append("  },")
    out.append("}")
    write("Data/Skinning.lua", out)
    print("  %d skinnable mobs, %d spawn points" % (len(mobs), total))
    return sorted(mobs)


# ---------------------------------------------------------------- localization

def guide_names():
    """English item, NPC and place names referenced by Data/Guides.lua."""
    with open(os.path.join(ROOT, "Data", "Guides.lua"), encoding="utf-8") as fh:
        text = "\n".join(l for l in fh if not l.lstrip().startswith("--"))
    items = set(re.findall(r'craft = "([^"]+)"', text))
    items |= set(re.findall(r'\{ "([^"]+)", \d+ \}', text))
    items |= set(re.findall(r"\{item:([^}]+)\}", text))
    npcs = set(re.findall(r"\{npc:([^}]+)\}", text))
    places = set(re.findall(r"\{place:([^}]+)\}", text))
    return items, npcs, places


def first_ids(names_by_id):
    out = {}
    for i in sorted(names_by_id):
        out.setdefault(names_by_id[i], i)
    return out


def gen_locale(pf, items_en, used_objects, mob_ids):
    zones_en = pfdb.load_names(os.path.join(pf, "enUS", "zones.lua"))
    units_en = pfdb.load_names(os.path.join(pf, "enUS", "units.lua"))
    item_names, npc_names, place_names = guide_names()

    guide_items = {}
    for name in sorted(item_names):
        if name in items_en:
            guide_items[name] = items_en[name]
        else:
            print("  note: %r is not an item (kept in english)" % name)
    unit_ids, zone_ids = first_ids(units_en), first_ids(zones_en)
    npcs = {n: unit_ids[n] for n in npc_names if n in unit_ids}
    places = {n: zone_ids[n] for n in place_names if n in zone_ids}
    for n in sorted((npc_names - set(npcs)) | (place_names - set(places))):
        print("  WARNING: unresolved guide name %r" % n)

    item_ids = set(guide_items.values())
    for _, iname, _, _ in GATHER.values():
        if iname:
            item_ids.add(items_en[iname])
    for item, _, _ in SKIN.values():
        item_ids.add(item)

    out = [
        "-- Generated by tools/gen_data.py - do not edit by hand.",
        "-- Localized names from pfQuest (MIT, https://github.com/shagu/pfQuest).",
        "",
        "-- english item names used by Data/Guides.lua -> itemID",
        "CraftingForever_ItemIDs = {",
    ]
    for name in sorted(guide_items):
        out.append("  [%s] = %d," % (lua_str(name), guide_items[name]))
    out.append("}")
    out.append("")
    out.append("CraftingForever_LocaleDB = {")
    for loc in LOCALES:
        def load(kind):
            return pfdb.load_names(os.path.join(pf, loc, kind + ".lua"))
        items, objects, zones = load("items"), load("objects"), load("zones")
        units, skills = load("units"), load("professions")
        out.append("  %s = {" % loc)
        out.append("    items = {")
        for i in sorted(item_ids):
            if i in items:
                out.append("      [%d] = %s," % (i, lua_str(items[i])))
        out.append("    },")
        out.append("    objects = {")
        for en in sorted(used_objects):
            for oid in used_objects[en]:
                if oid in objects and objects[oid] != en:
                    out.append("      [%s] = %s," % (lua_str(en), lua_str(objects[oid])))
                    break
        out.append("    },")
        out.append("    zones = {")
        for area in sorted(ZONES):
            if area in zones:
                out.append("      [%d] = %s," % (ZONES[area][5], lua_str(zones[area])))
        out.append("    },")
        out.append("    places = {")
        for en in sorted(places):
            if places[en] in zones:
                out.append("      [%s] = %s," % (lua_str(en), lua_str(zones[places[en]])))
        out.append("    },")
        out.append("    npcs = {")
        for en in sorted(npcs):
            if npcs[en] in units:
                out.append("      [%s] = %s," % (lua_str(en), lua_str(units[npcs[en]])))
        out.append("    },")
        out.append("    skills = {")
        for key in sorted(SKILLS):
            if SKILLS[key] in skills:
                out.append("      %s = %s," % (key, lua_str(skills[SKILLS[key]])))
        out.append("    },")
        out.append("    mobs = {")
        for cid in mob_ids:
            if cid in units:
                out.append("      [%d] = %s," % (cid, lua_str(units[cid])))
        out.append("    },")
        out.append("  },")
    out.append("}")
    write("Data/Locale.lua", out)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    pf, sql = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.join(ROOT, "Data"), exist_ok=True)
    items_en = first_ids(pfdb.load_names(os.path.join(pf, "enUS", "items.lua")))
    sizes = gen_zones(pf)
    used_objects = gen_nodes(pf, sql, sizes, items_en)
    mob_ids = gen_skinning(pf, sql, sizes)
    gen_locale(pf, items_en, used_objects, mob_ids)


if __name__ == "__main__":
    main()

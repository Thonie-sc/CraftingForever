#!/usr/bin/env python3
"""Generate CraftingForever's bundled data files.

Sources (not shipped with the addon, pass their paths on the command line):
  * pfQuest (https://github.com/shagu/pfQuest, MIT): spawn coordinates of gathering
    objects and creatures, in zone percent coordinates, plus zone dimensions.
  * CMaNGOS classic-db (https://github.com/cmangos/classic-db): the 1.12 world database,
    used for creature levels/ranks and skinning loot tables.

Usage:
  python3 tools/gen_data.py <pfQuest/db> <ClassicDB_*.sql or .sql.gz>

Writes Data/Zones.lua, Data/Nodes.lua and Data/Skinning.lua.
"""
import gzip
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(__file__))
import pfdb  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# areaID: (mapFile, continent, minLevel, maxLevel, faction)
# faction: "A" alliance territory, "H" horde territory, "C" contested.
# mapFile is the value 1.12's GetMapInfo() returns for that zone.
ZONES = {
    1: ("DunMorogh", 2, 1, 10, "A"),
    3: ("Badlands", 2, 35, 45, "C"),
    4: ("BlastedLands", 2, 45, 55, "C"),
    8: ("SwampOfSorrows", 2, 35, 45, "C"),
    10: ("Duskwood", 2, 18, 30, "A"),
    11: ("Wetlands", 2, 20, 30, "A"),
    12: ("Elwynn", 2, 1, 10, "A"),
    14: ("Durotar", 1, 1, 10, "H"),
    15: ("Dustwallow", 1, 35, 45, "C"),
    16: ("Aszhara", 1, 45, 55, "C"),
    17: ("Barrens", 1, 10, 25, "H"),
    28: ("WesternPlaguelands", 2, 51, 58, "C"),
    33: ("Stranglethorn", 2, 30, 45, "C"),
    36: ("Alterac", 2, 30, 40, "C"),
    38: ("LochModan", 2, 10, 20, "A"),
    40: ("Westfall", 2, 10, 20, "A"),
    41: ("DeadwindPass", 2, 55, 60, "C"),
    44: ("Redridge", 2, 15, 25, "A"),
    45: ("Arathi", 2, 30, 40, "C"),
    46: ("BurningSteppes", 2, 50, 58, "C"),
    47: ("Hinterlands", 2, 40, 50, "C"),
    51: ("SearingGorge", 2, 43, 50, "C"),
    85: ("Tirisfal", 2, 1, 10, "H"),
    130: ("Silverpine", 2, 10, 20, "H"),
    139: ("EasternPlaguelands", 2, 53, 60, "C"),
    141: ("Teldrassil", 1, 1, 10, "A"),
    148: ("Darkshore", 1, 10, 20, "A"),
    215: ("Mulgore", 1, 1, 10, "H"),
    267: ("Hilsbrad", 2, 20, 30, "C"),
    331: ("Ashenvale", 1, 18, 30, "C"),
    357: ("Feralas", 1, 40, 50, "C"),
    361: ("Felwood", 1, 48, 55, "C"),
    400: ("ThousandNeedles", 1, 25, 35, "C"),
    405: ("Desolace", 1, 30, 40, "C"),
    406: ("StonetalonMountains", 1, 15, 27, "C"),
    440: ("Tanaris", 1, 40, 50, "C"),
    490: ("UngoroCrater", 1, 48, 55, "C"),
    493: ("Moonglade", 1, 55, 60, "C"),
    618: ("Winterspring", 1, 53, 60, "C"),
    1377: ("Silithus", 1, 55, 60, "C"),
}

# material key -> (profession, itemID, english item name, [gathering object names])
GATHER = {
    # Mining
    "copper": ("mining", 2770, "Copper Ore", ["Copper Vein"]),
    "tin": ("mining", 2771, "Tin Ore", ["Tin Vein"]),
    "incendicite": ("mining", 3340, "Incendicite Ore", ["Incendicite Mineral Vein"]),
    "silver": ("mining", 2775, "Silver Ore", ["Silver Vein", "Ooze Covered Silver Vein"]),
    "bloodstone": ("mining", 4278, "Lesser Bloodstone Ore", ["Lesser Bloodstone Deposit"]),
    "iron": ("mining", 2772, "Iron Ore", ["Iron Deposit", "Ooze Covered Iron Deposit"]),
    "gold": ("mining", 2776, "Gold Ore", ["Gold Vein", "Ooze Covered Gold Vein"]),
    "mithril": ("mining", 3858, "Mithril Ore", ["Mithril Deposit", "Ooze Covered Mithril Deposit"]),
    "truesilver": ("mining", 7911, "Truesilver Ore",
                   ["Truesilver Deposit", "Ooze Covered Truesilver Deposit"]),
    "darkiron": ("mining", 11370, "Dark Iron Ore", ["Dark Iron Deposit"]),
    "thorium": ("mining", 10620, "Thorium Ore",
                ["Small Thorium Vein", "Ooze Covered Thorium Vein", "Hakkari Thorium Vein",
                 "Rich Thorium Vein", "Ooze Covered Rich Thorium Vein"]),
    # Herbalism
    "peacebloom": ("herbalism", 2447, "Peacebloom", ["Peacebloom"]),
    "silverleaf": ("herbalism", 765, "Silverleaf", ["Silverleaf"]),
    "earthroot": ("herbalism", 2449, "Earthroot", ["Earthroot"]),
    "mageroyal": ("herbalism", 785, "Mageroyal", ["Mageroyal"]),
    "briarthorn": ("herbalism", 2450, "Briarthorn", ["Briarthorn"]),
    "stranglekelp": ("herbalism", 3820, "Stranglekelp", ["Stranglekelp"]),
    "bruiseweed": ("herbalism", 2453, "Bruiseweed", ["Bruiseweed"]),
    "steelbloom": ("herbalism", 3355, "Wild Steelbloom", ["Wild Steelbloom"]),
    "gravemoss": ("herbalism", 3369, "Grave Moss", ["Grave Moss"]),
    "kingsblood": ("herbalism", 3356, "Kingsblood", ["Kingsblood"]),
    "liferoot": ("herbalism", 3357, "Liferoot", ["Liferoot"]),
    "fadeleaf": ("herbalism", 3818, "Fadeleaf", ["Fadeleaf"]),
    "goldthorn": ("herbalism", 3821, "Goldthorn", ["Goldthorn"]),
    "khadgar": ("herbalism", 3358, "Khadgar's Whisker", ["Khadgar's Whisker"]),
    "wintersbite": ("herbalism", 3819, "Wintersbite", ["Wintersbite"]),
    "firebloom": ("herbalism", 4625, "Firebloom", ["Firebloom"]),
    "purplelotus": ("herbalism", 8831, "Purple Lotus", ["Purple Lotus"]),
    "arthas": ("herbalism", 8836, "Arthas' Tears", ["Arthas' Tears"]),
    "sungrass": ("herbalism", 8838, "Sungrass", ["Sungrass"]),
    "blindweed": ("herbalism", 8839, "Blindweed", ["Blindweed"]),
    "ghostmushroom": ("herbalism", 8845, "Ghost Mushroom", ["Ghost Mushroom"]),
    "gromsblood": ("herbalism", 8846, "Gromsblood", ["Gromsblood"]),
    "sansam": ("herbalism", 13464, "Golden Sansam", ["Golden Sansam"]),
    "dreamfoil": ("herbalism", 13463, "Dreamfoil", ["Dreamfoil"]),
    "silversage": ("herbalism", 13465, "Mountain Silversage", ["Mountain Silversage"]),
    "plaguebloom": ("herbalism", 13466, "Plaguebloom", ["Plaguebloom"]),
    "icecap": ("herbalism", 13467, "Icecap", ["Icecap"]),
    "blacklotus": ("herbalism", 13468, "Black Lotus", ["Black Lotus"]),
}

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
        "-- [areaID] = { name, mapFile, continent, minLevel, maxLevel, faction, widthYards, heightYards }",
        "CraftingForever_Zones = {",
    ]
    for aid in sorted(ZONES):
        mf, cont, lo, hi, fac = ZONES[aid]
        w, h = sizes[aid]
        out.append("  [%d] = { %s, %s, %d, %d, %d, %s, %.2f, %.2f }," % (
            aid, lua_str(names[aid]), lua_str(mf), cont, lo, hi, lua_str(fac), w, h))
    out.append("}")
    write("Data/Zones.lua", out)
    return sizes


# ---------------------------------------------------------------- gathering nodes

def gen_nodes(pf, sizes):
    objects = pfdb.load_spawns(os.path.join(pf, "objects.lua"))
    onames = pfdb.load_names(os.path.join(pf, "enUS", "objects.lua"))
    skill = {}
    for key in ("mines", "herbs"):
        for oid, req in pfdb.load_meta(os.path.join(pf, "meta.lua"), key).items():
            skill[-oid] = int(req)

    by_name = defaultdict(list)
    for oid in skill:
        by_name[onames.get(oid)].append(oid)

    out = [
        "-- Generated by tools/gen_data.py - do not edit by hand.",
        "-- Spawn points derived from pfQuest (MIT, https://github.com/shagu/pfQuest).",
        "-- Coordinates are packed as floor(x*10)*10000 + floor(y*10) in zone percent.",
        "CraftingForever_GatherDB = {",
    ]
    for key, (prof, item, iname, nodes) in GATHER.items():
        req = None
        points = defaultdict(list)
        for nname in nodes:
            oids = by_name.get(nname)
            if not oids:
                # still listed under `nodes` so in-game gathering recognises it
                print("  note: no spawn data for %r" % nname)
                continue
            for oid in oids:
                req = skill[oid] if req is None else min(req, skill[oid])
                for x, y, zone, _ in objects.get(oid, {"coords": []})["coords"]:
                    if zone in ZONES:
                        points[zone].append((x, y))
        out.append("  [%s] = {" % lua_str(key))
        out.append("    prof = %s, item = %d, name = %s, skill = %d," % (
            lua_str(prof), item, lua_str(iname), max(req, 1)))
        out.append("    nodes = { %s }," % ", ".join(lua_str(n) for n in nodes))
        out.append("    zones = {")
        total = 0
        for zone in sorted(points):
            pts = dedupe(points[zone], sizes[zone])
            total += len(pts)
            out.append("      [%d] = {" % zone)
            out.extend("        %s," % row for row in packed_list(pts))
            out.append("      },")
        out.append("    },")
        out.append("  },")
        print("  %-14s skill %3d  %5d points in %d zones" % (key, max(req, 1), total, len(points)))
    out.append("}")
    write("Data/Nodes.lua", out)


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
    out.append("  -- [creatureID] = { name, minLevel, maxLevel, elite, { [material] = drop% } }")
    out.append("  mobs = {")
    for cid in sorted(mobs):
        c, drops = mobs[cid]
        d = ", ".join("%s = %.1f" % (k, v) for k, v in sorted(drops.items()))
        out.append("    [%d] = { %s, %d, %d, %s, { %s } }," % (
            cid, lua_str(c["name"]), c["lmin"], c["lmax"], "true" if c["elite"] else "false", d))
    out.append("  },")
    out.append("  -- [areaID] = { [creatureID] = { packed spawn points } }")
    out.append("  spawns = {")
    total = 0
    for zone in sorted(spawns):
        out.append("    [%d] = {" % zone)
        for cid in sorted(spawns[zone]):
            pts = spawns[zone][cid]
            total += len(pts)
            out.append("      [%d] = { %s }," % (cid, ", ".join(str(pack(x, y)) for x, y in pts)))
        out.append("    },")
    out.append("  },")
    out.append("}")
    write("Data/Skinning.lua", out)
    print("  %d skinnable mobs, %d spawn points" % (len(mobs), total))


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    pf, sql = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.join(ROOT, "Data"), exist_ok=True)
    sizes = gen_zones(pf)
    gen_nodes(pf, sizes)
    gen_skinning(pf, sql, sizes)


if __name__ == "__main__":
    main()

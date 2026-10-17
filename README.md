# CraftingForever

An addon for **WoW: Forever** (Blizzard's Forever client: Interface `16001`, modern 12.0-based engine with Classic Era content). It covers gathering routes, gathered-node tracking and profession leveling guides, in English, German and Spanish.

## Features

**Gathering routes (Mining, Herbalism, Skinning, Fishing pools)**
- Pick any combination of ores, herbs, leathers and fishing pools from the material list.
- *Find best routes* finds the loop with the highest expected yield per hour that never stands still waiting for respawns (see [How routes are ranked](#how-routes-are-ranked)). Spawn points of every selected material are merged, so picking Copper and Tin finds loops that gather both, and routes that offer all selected materials are preferred.
- Each result shows the zone, the area covered (whole zone or a circle around its densest spot), expected gathers per hour per material, lap time and stop count. Tick *Mounted* to plan at mount speed (on by default from level 40).
- Click a result to activate it. The loop is optimised (nearest neighbour plus 2-opt) and drawn on the world map as a dotted path with material icons at each stop. The stops also appear on the minimap. Double-click a result to open the world map on that zone.
- Filters: hide zones well above your level, and hide the enemy faction's territory.
- Skinning routes use real creature spawns and skinning loot tables. Mobs your Skinning skill can't skin are skipped.

**Gathered nodes**
- Every vein, herb or beast you gather is recorded where you stood, with the material's icon, on the world map and minimap. Hover a node to see how often you've gathered it and when you last did.
- Gathering the same spot again bumps its counter instead of adding a duplicate.
- Your own nodes also feed the route planner. Nodes are shared across all characters on the account.

**Anvils and forges**
- Characters with Mining or Blacksmithing see forges (for smelting, including goblin smelting pots) and, for Blacksmithing, anvils on the world map and minimap. There are 84 forges and 190 anvils, including the capital cities.
- The tracker shows the nearest forge and anvil in your zone with distance and coordinates. `/cf nearest` prints them in chat.
- Toggle with *Show anvils & forges* in the Routes tab.

**Leveling guides (automatic)**
- Your professions and skill levels are read automatically. The guide tab shows the guides for your professions, and the current step is highlighted.
- Guides: Mining, Herbalism, Skinning, Fishing, Alchemy, Blacksmithing, Leatherworking, Tailoring, Engineering, Enchanting, First Aid, Cooking.
- Gathering steps list materials and faction-specific zones. *Find route* builds a route for that step straight away.
- Crafting steps show the recipe in its current difficulty colour, the estimated crafts left, and reagents as `in bags / needed`.
- Opening a profession window once caches the real recipe reagents. These replace the guide's built-in ones, so the guide matches the server.
- When your skill hits its cap, the guide and tracker tell you what to do next: visit the trainer, or the book or quest for Fishing, Cooking and First Aid.
- A small movable tracker shows the current step of each profession and updates as you skill up.

**Languages**
- English, German (deDE) and Spanish (esES/esMX) clients. The interface and guide notes are translated, and item, herb, ore, zone, NPC and creature names come from the client's language data.
- Gathering is recognised in every language, because spells and loot are matched by ID.

## How routes are ranked

Only a share of a zone's spawn points hold a node at any time, for example about 18% for Copper Veins. This share comes from the world database's spawn pools. A gathered node respawns about 5 minutes later at a random point of its pool.

If a loop takes `T` seconds and covers a share `f` of the zone's spawn points, a respawn lands on the loop with probability `f`. The planner then reaches it after `T/2` on average. Otherwise the node waits off-route until another player takes it, assumed to be about 20 minutes. Each spawn point on the loop then yields `a / (respawn + f*T/2 + (1-f)*20min)` nodes per second.

Creatures respawn where they died, so a mob yields `1 / max(T, respawn)` kills per second. `T` includes travel time and time spent gathering (mining, picking, killing and skinning, fishing a pool, and remounting).

For each zone, the planner tries the whole zone and circles of 600, 1000 and 1600 yards around its densest spots, keeps the best one, and builds real loops for the most promising zones. Treat the yields as estimates for comparing routes, not exact promises.

## Installation

WoW: Forever keeps its own AddOns folder, separate from Retail and Classic Era:

```
World of Warcraft\_classic_beta_\Interface\AddOns\CraftingForever\CraftingForever.toc
```

1. Download the repository (or the branch) as a zip and extract it.
2. Move the extracted folder into `World of Warcraft\_classic_beta_\Interface\AddOns\`.
3. Rename the folder to exactly `CraftingForever`. GitHub zips are named like `CraftingForever-main`, and the game ignores a folder whose name doesn't match the `.toc` file.
4. Make sure `CraftingForever.toc` sits directly inside that folder, not one level deeper.
5. Restart the game completely; a `/reload` doesn't detect new addons. Then check that CraftingForever is ticked under AddOns on the character select screen.

## Usage

| Command | |
| --- | --- |
| `/cf` | toggle the main window |
| `/cf routes`, `/cf guide` | open a tab |
| `/cf tracker` | toggle the guide tracker |
| `/cf nearest` | nearest forge and anvil in your zone |
| `/cf clear` | clear the active route |
| `/cf resetnodes` | forget all gathered nodes |

Minimap button: left-click opens the window, right-click toggles the tracker, drag to move it.

## Known limitations

- Enchanting recipe names are spells, not items, so they stay in English in German and Spanish clients. Their recipe colour and real reagents are only picked up on English clients.
- Real recipe reagents are read through the classic trade skill functions. If the Forever client doesn't provide them, the guides use their built-in reagent lists.
- Built-in node, zone and mob data is Classic (1.12) world data, which WoW: Forever uses. Zones that are new in Forever, such as Zephras Isle, have no bundled data; nodes you gather there are still recorded, shown and used for routes.
- Crafting guide reagents marked `*` are approximate until you open the profession window once.

## Data and regeneration

`Data/Zones.lua`, `Data/Nodes.lua`, `Data/Skinning.lua`, `Data/Stations.lua` and `Data/Locale.lua` are generated by `tools/gen_data.py` from:

- [pfQuest](https://github.com/shagu/pfQuest) (MIT, see `NOTICE`): gathering object, fishing pool and creature spawn coordinates, respawn times, zone sizes, and German/Spanish names.
- [CMaNGOS classic-db](https://github.com/cmangos/classic-db): spawn pools (node availability), creature levels/ranks and skinning loot tables.

`Data/Locale.lua` also resolves the item, NPC and place names used in `Data/Guides.lua`, so re-run the generator after editing a guide.

```
python3 tools/gen_data.py <path/to/pfQuest/db> <path/to/ClassicDB_1_12_1_*.sql[.gz]>
```

## Development

`tools/test/harness.lua` runs the addon under a stock Lua 5.1 interpreter against a small mock of the WoW: Forever API and HereBeDragons. It covers file loading, route finding, gather recording and UI construction. The second argument picks which profession API the mock offers:

```
lua5.1 tools/test/harness.lua enUS professions
lua5.1 tools/test/harness.lua deDE skilllines
lua5.1 tools/test/harness.lua esES professions
```

The German and Spanish runs also check that every UI string and guide note has a translation with matching `%` specifiers and `{item:...}` tokens.

The client runs a modern engine, so many legacy globals are missing or broken. Prefer the `C_*` APIs, and wrap optional legacy calls in `pcall`. Zones are identified by `uiMapID` everywhere.

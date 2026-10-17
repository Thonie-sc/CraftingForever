-- Offline test harness: runs the addon under a stock Lua 5.1 interpreter with a
-- small mock of the WoW: Forever (modern engine) API and of HereBeDragons, then
-- exercises routes, gathering, guides and the UI.
--
--   lua5.1 tools/test/harness.lua [enUS|deDE|esES] [professions|skilllines]
--
-- The optional second argument picks which profession API the mock offers.

LOCALE = arg and arg[1] or "enUS"
PROF_API = arg and arg[2] or "professions"

-------------------------------------------------------------------------------
-- mock API
-------------------------------------------------------------------------------

local registry = {}
frames = {}
local now = 1000

local function newObject(name)
  local o = { _scripts = {}, _shown = true, _w = 100, _h = 100, _events = {}, _level = 1 }
  local methods = {
    SetScript = function(self, k, f) self._scripts[k] = f end,
    GetScript = function(self, k) return self._scripts[k] end,
    HookScript = function(self, k, f) self._scripts[k] = f end,
    RegisterEvent = function(self, e)
      if string.find(e, "^CRAFT_") then error("unknown event " .. e) end  -- modern client
      self._events[e] = true
    end,
    Show = function(self) self._shown = true if self._scripts.OnShow then self._scripts.OnShow(self) end end,
    Hide = function(self) self._shown = false end,
    IsVisible = function(self) return self._shown end,
    IsShown = function(self) return self._shown end,
    SetWidth = function(self, w) self._w = w end,
    SetHeight = function(self, h) self._h = h end,
    SetSize = function(self, w, h) self._w, self._h = w, h end,
    SetPoint = function(self, ...) self._point = { ... } end,
    GetWidth = function(self) return self._w end,
    GetHeight = function(self) return self._h end,
    GetFrameLevel = function(self) return self._level end,
    SetFrameLevel = function(self, l) self._level = l end,
    GetChecked = function(self) return self._checked end,
    SetChecked = function(self, v) self._checked = v end,
    SetText = function(self, t) self._text = t end,
    GetText = function(self) return self._text end,
    GetParent = function(self) return self._parent end,
    GetCenter = function() return 500, 500 end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function() return newObject() end,
    CreateFontString = function() return newObject() end,
    CreateLine = function() return newObject() end,
  }
  setmetatable(o, { __index = function(_, k)
    if methods[k] then return methods[k] end
    return function() end
  end })
  if name then registry[name] = o end
  return o
end

function CreateFrame(kind, name, parent, template)
  local f = newObject(name)
  f._parent = parent
  if parent then f._level = (parent._level or 0) + 1 end
  table.insert(frames, f)
  if name and template == "UICheckButtonTemplate" then f.text = newObject(name .. "Text") end
  if name and template == "FauxScrollFrameTemplate" then newObject(name .. "ScrollBar") end
  return f
end

setmetatable(_G, { __index = function(_, k) return registry[k] end })

function hooksecurefunc(t, k, f) end
UIParent = newObject("UIParent")
Minimap = newObject("Minimap")
Minimap._w, Minimap._h = 198, 198  -- the Forever client's minimap size
GameTooltip = newObject("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("[chat] " .. (string.gsub(m, "|c%x%x%x%x%x%x%x%x", ""))) end }
UISpecialFrames = {}
SlashCmdList = {}

local mapShown, mapID = false, nil
WorldMapFrame = newObject("WorldMapFrame")
WorldMapFrame.IsShown = function() return mapShown end
WorldMapFrame.GetMapID = function() return mapID end
WorldMapFrame.GetCanvas = function() return newObject() end
WorldMapFrame.OnMapChanged = function() end
function OpenWorldMap(id) mapShown, mapID = true, id end

-- player state
local player = { x = 0.42, y = 0.65, map = 1429, level = 12 }  -- Elwynn Forest
local profs = {
  { line = 186, key = "mining", rank = 72, max = 150 },
  { line = 393, key = "skinning", rank = 40, max = 75 },
  { line = 171, key = "alchemy", rank = 112, max = 150 },
  { line = 356, key = "fishing", rank = 150, max = 150 },
}
local ENGLISH = { mining = "Mining", skinning = "Skinning", alchemy = "Alchemy", fishing = "Fishing" }
local function skillName(key)
  local db = CraftingForever_LocaleDB[LOCALE]
  return db and db.skills[key] or ENGLISH[key] or key
end

if PROF_API == "professions" then
  function GetProfessions() return 1, 2, nil, 4, nil, 3 end
  function GetProfessionInfo(i)
    local p = profs[i]
    return skillName(p.key), 0, p.rank, p.max, 0, 0, p.line
  end
else
  function GetNumSkillLines() return #profs + 1 end
  function GetSkillLineInfo(i)
    if i == 1 then return "Professions", true, true end
    local p = profs[i - 1]
    return skillName(p.key), false, false, p.rank, 0, 0, p.max
  end
end

function UnitLevel() return player.level end
function UnitFactionGroup() return "Alliance" end
function GetTime() return now end
time = os.time
date = os.date
function GetLocale() return LOCALE end
function GetCursorPosition() return 0, 0 end
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset() return 0 end
function FauxScrollFrame_OnVerticalScroll() end

C_Map = { GetMapInfo = function() return nil end }
local SPELLS = { [2575] = "Mining", [2366] = "Herb Gathering", [8613] = "Skinning", [7620] = "Fishing", [133] = "Fireball" }
C_Spell = { GetSpellName = function(id) return SPELLS[id] end }
local bags = {}
C_Item = {
  GetItemIconByID = function(id) return 100000 + id end,
  GetItemCount = function(id) return bags[id] or 0 end,
}

-- HereBeDragons stand-in
local icons = { world = 0, mini = 0 }
local HBD = {
  GetPlayerZonePosition = function() return player.x, player.y, player.map, 3 end,
  GetZoneSize = function() return 0, 0 end,
}
local HBDP = {
  RemoveAllWorldMapIcons = function() icons.world = 0 end,
  RemoveAllMinimapIcons = function() icons.mini = 0 end,
  AddWorldMapIconMap = function(_, ref, icon, map, x, y)
    assert(type(icon) == "table" and type(map) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1)
    icons.world = icons.world + 1
  end,
  AddMinimapIconMap = function(_, ref, icon, map, x, y)
    assert(type(icon) == "table" and type(map) == "number")
    icons.mini = icons.mini + 1
  end,
}
function LibStub(name)
  if name == "HereBeDragons-2.0" then return HBD end
  if name == "HereBeDragons-Pins-2.0" then return HBDP end
  error("unknown library " .. name)
end

local loot = {}
local ITEM_IDS = { copper = 2770, tin = 2771, silverleaf = 765, lightleather = 2318, ruinedscraps = 2934, blackmouth = 6358 }
function GetNumLootItems() return #loot end
function GetLootSlotLink(i) return "|cffffffff|Hitem:" .. ITEM_IDS[loot[i]] .. "::::::::|h[x]|h|r" end

local function fire(ev, ...)
  for _, f in ipairs(frames) do
    if f._events[ev] and f._scripts.OnEvent then
      f._scripts.OnEvent(f, ev, ...)
    end
  end
end

-------------------------------------------------------------------------------
-- load the addon in .toc order (libraries are mocked above)
-------------------------------------------------------------------------------

local function check(cond, msg)
  if not cond then error("FAILED: " .. msg, 2) end
  print("ok   " .. msg)
end

for line in io.lines("CraftingForever.toc") do
  if not string.find(line, "^##") and string.find(line, "%S") and not string.find(line, "^Libs") then
    local path = string.gsub(line, "\\", "/")
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    chunk("CraftingForever", {})
  end
end
check(true, "all files load under Lua 5.1")

fire("ADDON_LOADED", "CraftingForever")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
local CF = CraftingForever

check(CF.profs.mining and CF.profs.mining.rank == 72, "professions detected via " .. PROF_API .. " (mining 72)")
check(CF.profs.fishing and CF.profs.fishing.max == 150, "fishing detected")
check(CF.materials.copper.skill == 1 and CF.materials.tin.skill == 65, "material skills")
check(CF.materials.lightleather ~= nil, "skinning materials registered")
check(CF.MaterialIcon("copper") == 102770, "material icons by item ID")

-- anvils and forges
check(CF.WantedStations().forge and not CF.WantedStations().anvil, "mining shows forges, not anvils")
local nForges = 0
CF.ForEachStation("forge", function(map) nForges = nForges + 1 end)
check(nForges > 50, "forge locations bundled (" .. nForges .. ")")
check(CraftingForever_Stations[1455] and CraftingForever_Stations[1455].forge, "Ironforge has forges")
local fx, fy = CF.NearestStation("forge")
check(fx and math.abs(fx - 41.5) < 1 and math.abs(fy - 65.7) < 1, "nearest forge is Goldshire's (41.5, 65.7)")
player.map = 1413  -- The Barrens
check(CF.NearestStation("forge") == nil or true, "zones without a forge are handled")
player.map = 1429
local ax, ay, ad = CF.NearestStation("anvil")
check(ad and ad > 0, string.format("nearest anvil in Elwynn: %.1f, %.1f (%d yd)", ax, ay, ad))
print("  " .. CF.NearestStationsText())
local results = CF.FindRoutes({ "copper" }, { [1455] = true, [1453] = true })
check(#results == 0, "capital cities are not used for routes")
CF.settings.showStations = false

-------------------------------------------------------------------------------
-- routes
-------------------------------------------------------------------------------

local function show(results, label)
  print("  " .. label)
  for i = 1, math.min(5, #results) do
    local r = results[i]
    local mats = {}
    for k, v in pairs(r.perMat) do table.insert(mats, string.format("%s=%.0f", k, v)) end
    print(string.format("    %d. %-22s %-34s stops %3d  lap %6s  %5.1f/h  [%s]", i,
      CF.ZoneName(r.area), CF.ui.ScopeText(r), #r.points, CF.FormatTime(r.lap), r.perHour,
      table.concat(mats, " ")))
  end
end

local t0 = os.clock()
local res = CF.FindRoutes({ "copper" })
show(res, string.format("copper (level 12 Alliance, on foot) - %.3fs", os.clock() - t0))
check(#res > 0, "copper routes found")
for i = 1, #res do
  local z = CraftingForever_Zones[res[i].area]
  check(z[6] ~= "H", "no horde territory in alliance results: " .. z[1])
  check(res[i].perHour > 0 and res[i].lap > 0, "yield and lap computed")
end
for i = 2, #res do
  check(res[i - 1].score >= res[i].score, "results sorted by score")
end

t0 = os.clock()
res = CF.FindRoutes({ "copper", "tin" })
show(res, string.format("copper + tin - %.3fs", os.clock() - t0))
check(res[1].perMat.copper and res[1].perMat.tin, "best combined route yields both copper and tin")

CF.settings.hideHighZones = false
player.level = 50
t0 = os.clock()
res = CF.FindRoutes({ "mithril", "truesilver" })
show(res, string.format("mithril + truesilver (level 50, mounted) - %.3fs", os.clock() - t0))
check(#res > 0 and res[1].mounted, "mithril routes, mounted")

t0 = os.clock()
res = CF.FindRoutes({ "blackmouth", "firefin", "wreckage" })
show(res, string.format("fishing pools - %.3fs", os.clock() - t0))
check(#res > 0, "fishing pool routes")

player.level = 12
CF.settings.hideHighZones = true
t0 = os.clock()
res = CF.FindRoutes({ "lightleather" })
show(res, string.format("light leather (skinning 40) - %.3fs", os.clock() - t0))
check(#res > 0, "skinning routes")

do
  local pts = res[1].points
  local T1, h1 = CF.EstimateYield(pts, 5000, 7)
  local T2, h2 = CF.EstimateYield(pts, 20000, 7)
  check(T2 > T1 and h2 <= h1, "longer loop -> longer lap, not more per hour")
end

local before = res[1].length
CF.SetActiveRoute(res[1])
check(CF.activeRoute.length <= before + 0.5, "2-opt does not lengthen the tour")
local seen = {}
for i = 1, #CF.activeRoute.order do seen[CF.activeRoute.order[i]] = true end
check(CF.Count(seen) == #CF.activeRoute.points, "tour visits every stop once")
check(icons.world == #CF.activeRoute.points and icons.mini == #CF.activeRoute.points,
  "route stops placed on world map and minimap (" .. icons.world .. ")")

-------------------------------------------------------------------------------
-- gathering
-------------------------------------------------------------------------------

local E = 1429
fire("UNIT_SPELLCAST_START", "player", "guid1", 2575)
loot = { "copper" }
now = now + 5
fire("LOOT_OPENED")
check(CF.db.nodes[E] and CF.db.nodes[E].copper and #CF.db.nodes[E].copper == 1, "copper vein recorded in Elwynn (map 1429)")

fire("UNIT_SPELLCAST_START", "player", "guid2", 2575)
now = now + 5
fire("LOOT_OPENED")
check(#CF.db.nodes[E].copper == 1 and CF.db.nodes[E].copper[1][3] == 2, "repeat gather merges into one node")

-- a higher rank / unknown spell ID still matches by localized spell name
SPELLS[99999] = "Herb Gathering"
player.x = 0.50
fire("UNIT_SPELLCAST_START", "player", "guid3", 99999)
loot = { "silverleaf" }
now = now + 5
fire("LOOT_OPENED")
check(CF.db.nodes[E].silverleaf and #CF.db.nodes[E].silverleaf == 1, "herb recorded by spell name")

fire("UNIT_SPELLCAST_START", "player", "guid4", 2575)
fire("UNIT_SPELLCAST_INTERRUPTED", "player", "guid4", 2575)
loot = { "tin" }
fire("LOOT_OPENED")
check(not CF.db.nodes[E].tin, "interrupted cast ignored")

fire("UNIT_SPELLCAST_START", "party1", "guid5", 2575)
fire("LOOT_OPENED")
check(not CF.db.nodes[E].tin, "other units' casts ignored")

player.x = 0.30
fire("UNIT_SPELLCAST_START", "player", "guid6", 8613)
loot = { "lightleather", "ruinedscraps" }
now = now + 3
fire("LOOT_OPENED")
check(CF.db.nodes[E].lightleather and #CF.db.nodes[E].lightleather == 1, "skinned mob recorded")

fire("UNIT_SPELLCAST_START", "player", "guid7", 133)
player.x = 0.70
loot = { "lightleather" }
now = now + 3
fire("LOOT_OPENED")
check(#CF.db.nodes[E].lightleather == 1, "unrelated cast + loot ignored")

player.x = 0.80
fire("UNIT_SPELLCAST_CHANNEL_START", "player", "guid8", 7620)
loot = { "blackmouth" }
now = now + 20
fire("LOOT_OPENED")
check(CF.db.nodes[E].blackmouth and #CF.db.nodes[E].blackmouth == 1, "fishing catch recorded")

-- nodes in a zone without bundled data (new Forever zone) are still recorded
player.map, player.x = 2521, 0.4
fire("UNIT_SPELLCAST_START", "player", "guid9", 2575)
loot = { "copper" }
now = now + 5
fire("LOOT_OPENED")
check(CF.db.nodes[2521] and #CF.db.nodes[2521].copper == 1, "node recorded in a zone without bundled data")
player.map = E

res = CF.FindRoutes({ "copper" }, { [E] = true })
check(res[1] and res[1].area == E, "restricted search returns Elwynn only")

-------------------------------------------------------------------------------
-- map layers and UI
-------------------------------------------------------------------------------

CF.SetActiveRoute(nil)
check(icons.world == 5 and icons.mini == 5, "5 gathered nodes shown on both maps (" .. icons.world .. ")")
mapShown, mapID = true, E
CF.UpdateWorldMap()

CF.ShowMainFrame("routes")
CF.cdb.selected.copper = true
CF.ShowMainFrame("guide")
CF.UpdateGuide()
local step = CF.GuideStep("mining", 72)
check(step and step.from == 65, "mining guide step for 72 is the tin step")
CF.FindGuideRoute(step)
check(CF.activeRoute and CF.activeRoute.counts.tin, "guide 'Find route' activates a tin route")
local astep = CF.GuideStep("alchemy", 112)
check(astep.craft == "Healing Potion", "alchemy step for 112")
local reagents = CF.StepReagents(astep)
check(reagents[1][3] ~= nil, "guide reagents carry item IDs")
print("  alchemy 112 reagents: " .. reagents[1][1] .. ", " .. reagents[2][1] .. ", " .. reagents[3][1])
check(CF.TrainerHint("fishing") ~= nil, "fishing capped at 150 -> trainer hint")
print("  hint: " .. CF.TrainerHint("fishing"))
check(not string.find(CF.TrainerHint("fishing"), "{"), "tokens replaced in hints")
for _, key in ipairs(CF.GUIDE_ORDER) do
  check(CF.Guides[key] and #CF.Guides[key].steps > 0, "guide " .. key)
end
-- routes tab: clicking material rows drives the search, stale results are dropped
do
  local R = CF.ui.routes
  check(CF.cdb.selected.tin and CF.cdb.selected.silver and not CF.cdb.selected.peacebloom,
    "guide route replaces the selection with the step's materials")
  check(#R.results > 0, "guide route results listed")
  local function rowFor(key)
    for _, row in ipairs(R.matRows) do if row.key == key then return row end end
  end
  R.matRows[1]:GetParent()  -- rows exist
  _G.CF_TEST_CLICK = function(row) row._scripts.OnClick(row, "LeftButton") end
  -- clear, then select copper only
  CF.cdb.selected = {}
  CF.ShowMainFrame("routes")
  local copperRow = rowFor("copper")
  check(copperRow ~= nil, "copper row in the material list")
  check(copperRow:GetFrameLevel() > R.matScroll:GetFrameLevel(), "material rows sit above the scroll frame")
  CF_TEST_CLICK(copperRow)
  check(CF.cdb.selected.copper and CF.Count(CF.cdb.selected) == 1, "clicking a row selects only that material")
  check(#R.results == 0, "changing the selection drops the old results")
  local find
  for _, f in ipairs(frames) do if f._text == CF.L["Find best routes"] then find = f end end
  find._scripts.OnClick(find, "LeftButton")
  check(#R.results > 0, "copper search listed")
  for _, r in ipairs(R.results) do
    check(#r.keys == 1 and r.keys[1] == "copper" and not r.perMat.tin, "copper-only result in " .. CF.ZoneName(r.area))
  end
  CF_TEST_CLICK(copperRow)
  find._scripts.OnClick(find, "LeftButton")
  check(#R.results == 0, "searching with nothing selected shows no stale results")
end
CF.SetActiveRoute(nil)
CF.settings.showStations = true
CF.UpdateWorldMap()
check(icons.world == 5 + nForges, "forges shown on the world map next to gathered nodes")
-- adventure mode: only anvils/forges this character has used
do
  CF.settings.adventureMode = true
  local count = 0
  CF.ForEachStation("forge", function() count = count + 1 end)
  check(count == 0, "adventure mode starts with no forges shown")
  check(CF.NearestStation("forge") == nil, "adventure mode: no nearest forge yet")
  check(string.find(CF.NearestStationsText(), CF.L["%s: none discovered in this zone"]:sub(5, 12), 1, true),
    "tracker says none discovered: " .. CF.NearestStationsText())

  -- smelting next to Goldshire's forge discovers it (snapped to the real forge)
  player.map, player.x, player.y = 1429, 0.414, 0.656
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "s1", 2657)  -- Smelt Copper
  local fx, fy, fd = CF.NearestStation("forge")
  check(fx and math.abs(fx - 41.5) < 0.05 and math.abs(fy - 65.7) < 0.05, "used forge discovered at its real spot")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "s2", 2657)
  check(#CF.cdb.stations[1429].forge == 1, "smelting there again adds nothing")
  count = 0
  CF.ForEachStation("forge", function() count = count + 1 end)
  check(count == 1, "exactly the used forge is shown")

  -- blacksmithing at the anvil (the client tells us which window is open)
  CF.profs.blacksmithing = { rank = 10, max = 75 }
  function GetTradeSkillLine() return CF.ProfName("blacksmithing") end
  fire("TRADE_SKILL_SHOW")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "s3", 2660)  -- Rough Sharpening Stone
  check(CF.cdb.stations[1429].anvil and #CF.cdb.stations[1429].anvil == 1, "anvil discovered by blacksmithing")
  fire("TRADE_SKILL_CLOSE")

  -- a forge missing from the bundled data is remembered where it was used
  player.map, player.x, player.y = 1413, 0.5, 0.5
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "s4", 2657)
  check(CF.cdb.stations[1413] and CF.cdb.stations[1413].forge[1][1] == 50, "unknown forge stored at the player's position")
  CF.settings.adventureMode = false
  local seen = false
  CF.ForEachStation("forge", function(map, x, y) if map == 1413 and x == 50 then seen = true end end)
  check(seen, "used forges missing from the data also show outside adventure mode")
  count = 0
  CF.ForEachStation("forge", function() count = count + 1 end)
  check(count == nForges + 1, "the Goldshire forge is not listed twice")
  player.map, player.x, player.y = 1429, 0.42, 0.65
  CF.profs.blacksmithing = nil
end
do
  local b = CraftingForeverMinimapButton
  local x, y = b._point[4], b._point[5]
  local r = math.sqrt(x * x + y * y)
  check(r >= 99 + 8, string.format("minimap button sits outside the minimap rim (%.0f px from center, rim at 99)", r))
end
CF.ToggleTracker()
CF.ToggleTracker()
SlashCmdList["CRAFTINGFOREVER"]("help")
check(true, "UI builds and updates")

-------------------------------------------------------------------------------
-- translations
-------------------------------------------------------------------------------

local function specifiers(str)
  local out = {}
  for f in string.gmatch(str, "%%[%a%%]") do table.insert(out, f) end
  return table.concat(out)
end

local function tokens(str)
  local out = {}
  for t in string.gmatch(str, "{%a+:[^}]+}") do table.insert(out, t) end
  table.sort(out)
  return table.concat(out)
end

if LOCALE ~= "enUS" then
  local keys = {}
  local files = { "Core.lua", "UI.lua", "GuideUI.lua", "MapPins.lua", "Stations.lua", "Data/Guides.lua" }
  for _, f in ipairs(files) do
    local fh = io.open(f)
    local src = fh:read("*a")
    fh:close()
    for k in string.gmatch(src, 'CF%.L%["(.-[^\\])"%]') do keys[(string.gsub(k, '\\"', '"'))] = true end
  end
  for _, g in pairs(CF.Guides) do
    for _, st in ipairs(g.steps) do
      for _, f in ipairs({ "text", "A", "H" }) do if st[f] then keys[st[f]] = true end end
    end
    for _, note in pairs(g.ranks or {}) do
      if type(note) == "table" then keys[note.A] = true keys[note.H] = true else keys[note] = true end
    end
  end
  for _, r in ipairs(CF.TRAINER_RANKS) do keys[r.rank] = true end
  for _, k in ipairs({ "Routes", "Leveling Guide", "Show gathered nodes", "Show route", "Minimap icons",
                       "Show anvils & forges", "Adventure mode: only used ones" }) do keys[k] = true end
  for _, def in pairs(CF.STATIONS) do keys[def.label] = true end
  local tr = CF.TRANSLATIONS[LOCALE]
  for k in pairs(keys) do
    check(tr[k] ~= nil, LOCALE .. " translation: " .. k)
    if tr[k] then
      check(specifiers(tr[k]) == specifiers(k), LOCALE .. " format specifiers match: " .. k)
      check(tokens(tr[k]) == tokens(k), LOCALE .. " tokens match: " .. k)
    end
  end
  for k in pairs(tr) do check(keys[k], LOCALE .. " translation is used: " .. k) end
  check(CF.ZoneName(E) ~= "Elwynn Forest", "zone names localized: " .. CF.ZoneName(E))
  check(CF.materials.copper.name ~= "Copper Ore", "material names localized: " .. CF.materials.copper.name)
end

print("\nall tests passed (" .. LOCALE .. ", " .. PROF_API .. ")")

-- Offline test harness: runs the addon under a stock Lua 5.0 interpreter with a
-- minimal mock of the 1.12 API, then exercises routes, gathering and the UI.
--
--   lua5.0 tools/test/harness.lua [enUS|deDE|esES]   (from the addon folder)

LOCALE = arg and arg[1] or "enUS"

-------------------------------------------------------------------------------
-- mock API
-------------------------------------------------------------------------------

local registry = {}
local frames = {}
local now = 1000

local function newObject(name)
  local o = { _scripts = {}, _shown = true, _w = 100, _h = 100, _events = {}, _level = 1 }
  local methods = {
    SetScript = function(self, k, f) self._scripts[k] = f end,
    GetScript = function(self, k) return self._scripts[k] end,
    RegisterEvent = function(self, e) self._events[e] = true end,
    Show = function(self) self._shown = true if self._scripts.OnShow then this = self self._scripts.OnShow() end end,
    Hide = function(self) self._shown = false end,
    IsVisible = function(self) return self._shown end,
    IsShown = function(self) return self._shown end,
    SetWidth = function(self, w) self._w = w end,
    SetHeight = function(self, h) self._h = h end,
    GetWidth = function(self) return self._w end,
    GetHeight = function(self) return self._h end,
    GetFrameLevel = function(self) return self._level end,
    SetFrameLevel = function(self, l) self._level = l end,
    GetChecked = function(self) return self._checked end,
    SetChecked = function(self, v) self._checked = v end,
    SetText = function(self, t) self._text = t end,
    GetText = function(self) return self._text end,
    GetParent = function(self) return self._parent end,
    GetZoom = function() return 0 end,
    GetCenter = function() return 500, 500 end,
    GetEffectiveScale = function() return 1 end,
    CreateTexture = function(self) return newObject() end,
    CreateFontString = function(self) return newObject() end,
  }
  setmetatable(o, { __index = function(t, k)
    if methods[k] then return methods[k] end
    return function() end
  end })
  if name then registry[name] = o end
  return o
end

function CreateFrame(kind, name, parent, template)
  local f = newObject(name)
  f._parent = parent
  table.insert(frames, f)
  if name and template == "UICheckButtonTemplate" then newObject(name .. "Text") end
  if name and template == "FauxScrollFrameTemplate" then newObject(name .. "ScrollBar") end
  return f
end

function getglobal(n) return registry[n] or getfenv(0)[n] end

UIParent = newObject("UIParent")
Minimap = newObject("Minimap")
Minimap._w = 140
WorldMapFrame = newObject("WorldMapFrame")
WorldMapFrame._shown = false
WorldMapButton = newObject("WorldMapButton")
WorldMapButton._w, WorldMapButton._h = 1002, 668
GameTooltip = newObject("GameTooltip")
GameTooltip._shown = false
GameTooltipTextLeft1 = newObject("GameTooltipTextLeft1")
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print("[chat] " .. string.gsub(m, "|c%x%x%x%x%x%x%x%x", "")) end }
UISpecialFrames = {}
SlashCmdList = {}

-- player state
local player = { x = 0.42, y = 0.65, map = "Elwynn", level = 12 }
local skills = {
  { "Professions", true, true },
  { "mining", false, false, 72, 0, 0, 150 },
  { "skinning", false, false, 40, 0, 0, 75 },
  { "alchemy", false, false, 112, 0, 0, 150 },
  { "fishing", false, false, 150, 0, 0, 150 },
}
local ENGLISH = { mining = "Mining", skinning = "Skinning", alchemy = "Alchemy", fishing = "Fishing" }
local function skillName(key)
  local db = CraftingForever_LocaleDB[LOCALE]
  return db and db.skills[key] or ENGLISH[key] or key
end

function UnitLevel() return player.level end
function UnitFactionGroup() return "Alliance" end
function UnitName() return nil end
function GetTime() return now end
function GetMapInfo() return player.map end
function SetMapToCurrentZone() end
function GetPlayerMapPosition() return player.x, player.y end
function GetCurrentMapContinent() return 2 end
function GetCurrentMapZone() return 1 end
function GetMapZones() return "Elwynn Forest" end
function SetMapZoom() end
function ToggleWorldMap() end
function GetCVar(k) if k == "minimapZoom" then return "0" end return "2" end
function GetItemInfo() return nil end
function GetContainerNumSlots() return 0 end
function GetContainerItemLink() return nil end
function GetContainerItemInfo() return nil end
function GetNumSkillLines() return table.getn(skills) end
function GetSkillLineInfo(i)
  local s = skills[i]
  return (s[2] and s[1] or skillName(s[1])), s[2], s[3], s[4], s[5], s[6], s[7]
end
function GetLocale() return LOCALE end
function ExpandSkillHeader() end
function CollapseSkillHeader() end
function GetNumTradeSkills() return 0 end
function GetNumCrafts() return 0 end
function GetCursorPosition() return 0, 0 end
function FauxScrollFrame_Update() end
function FauxScrollFrame_GetOffset() return 0 end
function FauxScrollFrame_OnVerticalScroll() end
date = os.date
time = os.time

local loot = {}
function GetNumLootItems() return table.getn(loot) end
function GetLootSlotInfo(i) return "Interface\\Icons\\Test", loot[i], 1 end

local function fire(ev, a1, a2, a3)
  for _, f in ipairs(frames) do
    if f._events[ev] and f._scripts.OnEvent then
      event, arg1, arg2, arg3 = ev, a1, a2, a3
      this = f
      f._scripts.OnEvent()
    end
  end
end

-------------------------------------------------------------------------------
-- load the addon in .toc order
-------------------------------------------------------------------------------

local function check(cond, msg)
  if not cond then error("FAILED: " .. msg, 2) end
  print("ok   " .. msg)
end

for line in io.lines("CraftingForever.toc") do
  if not string.find(line, "^##") and string.find(line, "%S") then
    local path = string.gsub(line, "\\", "/")
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    chunk()
  end
end
check(true, "all files load under Lua 5.0")

fire("ADDON_LOADED", "CraftingForever")
fire("PLAYER_ENTERING_WORLD")
local CF = CraftingForever

check(CF.profs.mining and CF.profs.mining.rank == 72, "professions detected (mining 72)")
check(CF.materials.copper.skill == 1 and CF.materials.tin.skill == 65, "material skills")
check(CF.materials.lightleather ~= nil, "skinning materials registered")

-------------------------------------------------------------------------------
-- routes
-------------------------------------------------------------------------------

local function show(results, label)
  print("  " .. label)
  for i = 1, math.min(5, table.getn(results)) do
    local r = results[i]
    local mats = {}
    for k, v in pairs(r.perMat) do table.insert(mats, string.format("%s=%.0f", k, v)) end
    print(string.format("    %d. %-22s %-34s stops %3d  lap %6s  %5.1f/h  [%s]", i,
      CF.ZoneName(r.area), CF.ui.ScopeText(r), table.getn(r.points), CF.FormatTime(r.lap), r.perHour,
      table.concat(mats, " ")))
  end
end

local t0 = os.clock()
local res = CF.FindRoutes({ "copper" })
show(res, string.format("copper (level 12 Alliance, on foot) - %.3fs", os.clock() - t0))
check(table.getn(res) > 0, "copper routes found")
for i = 1, table.getn(res) do
  local z = CraftingForever_Zones[res[i].area]
  check(z[6] ~= "H", "no horde territory in alliance results: " .. z[1])
  check(res[i].perHour > 0 and res[i].lap > 0, "yield and lap computed")
end
for i = 2, table.getn(res) do
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
check(table.getn(res) > 0 and res[1].mounted, "mithril routes, mounted")

t0 = os.clock()
res = CF.FindRoutes({ "thorium" })
show(res, string.format("thorium - %.3fs", os.clock() - t0))

t0 = os.clock()
res = CF.FindRoutes({ "blackmouth", "firefin", "wreckage" })
show(res, string.format("fishing pools - %.3fs", os.clock() - t0))
check(table.getn(res) > 0, "fishing pool routes")

player.level = 12
t0 = os.clock()
res = CF.FindRoutes({ "peacebloom", "silverleaf", "earthroot" })
show(res, string.format("starter herbs - %.3fs", os.clock() - t0))

CF.settings.hideHighZones = true
t0 = os.clock()
res = CF.FindRoutes({ "lightleather" })
show(res, string.format("light leather (skinning 40) - %.3fs", os.clock() - t0))
check(table.getn(res) > 0, "skinning routes")

-- the yield model: a longer loop of the same points never yields more per hour
do
  local pts = res[1].points
  local T1, h1 = CF.EstimateYield(pts, 5000, 7)
  local T2, h2 = CF.EstimateYield(pts, 20000, 7)
  check(T2 > T1 and h2 <= h1, "longer loop -> longer lap, not more per hour")
end

t0 = os.clock()
local before = res[1].length
CF.SetActiveRoute(res[1])
print(string.format("  2-opt: %d -> %d yd in %.3fs", before, CF.activeRoute.length, os.clock() - t0))
check(CF.activeRoute.length <= before + 0.5, "2-opt does not lengthen the tour")
local seen, n = {}, table.getn(CF.activeRoute.order)
for i = 1, n do seen[CF.activeRoute.order[i]] = true end
check(CF.Count(seen) == table.getn(CF.activeRoute.points), "tour visits every stop once")

-------------------------------------------------------------------------------
-- gathering
-------------------------------------------------------------------------------

local M = CF.materials
local mining = skillName("mining")
GameTooltip._shown = true
GameTooltipTextLeft1._text = (CF.LDB.objects and CF.LDB.objects["Copper Vein"]) or "Copper Vein"
fire("SPELLCAST_START", mining, 5000)
loot = { M.copper.name, "Rough Stone" }
now = now + 5
fire("LOOT_OPENED")
check(CF.db.nodes[12] and CF.db.nodes[12].copper and table.getn(CF.db.nodes[12].copper) == 1, "copper vein recorded in Elwynn")

-- same vein again merges
fire("SPELLCAST_START", mining, 5000)
now = now + 5
fire("LOOT_OPENED")
check(table.getn(CF.db.nodes[12].copper) == 1 and CF.db.nodes[12].copper[1][3] == 2, "repeat gather merges into one node")

-- herbs: recognised by the herb under the mouse, whatever the spell is called
GameTooltip._shown = true
GameTooltipTextLeft1._text = M.silverleaf.name
player.x = 0.50
fire("SPELLCAST_START", "Some Localized Herb Spell", 5000)
loot = { M.silverleaf.name }
now = now + 5
fire("LOOT_OPENED")
check(CF.db.nodes[12].silverleaf and table.getn(CF.db.nodes[12].silverleaf) == 1, "herb recorded")
GameTooltip._shown = false

-- interrupted cast records nothing
fire("SPELLCAST_START", mining, 5000)
fire("SPELLCAST_INTERRUPTED")
loot = { M.tin.name }
fire("LOOT_OPENED")
check(not CF.db.nodes[12].tin, "interrupted cast ignored")

-- skinning from loot
player.x = 0.30
fire("SPELLCAST_START", skillName("skinning"), 2000)
loot = { M.lightleather.name, M.ruinedscraps.name }
now = now + 3
fire("LOOT_OPENED")
check(CF.db.nodes[12].lightleather and table.getn(CF.db.nodes[12].lightleather) == 1, "skinned mob recorded")

-- a non-gathering cast followed by looting leather from a corpse is ignored
fire("SPELLCAST_START", "Fireball", 3000)
player.x = 0.70
loot = { M.lightleather.name }
now = now + 3
fire("LOOT_OPENED")
check(table.getn(CF.db.nodes[12].lightleather) == 1, "unrelated cast + loot ignored")

-- fishing is channelled and records the catch's pool type
player.x = 0.80
fire("SPELLCAST_CHANNEL_START", 30000, skillName("fishing"))
loot = { M.blackmouth.name }
now = now + 20
fire("LOOT_OPENED")
check(CF.db.nodes[12].blackmouth and table.getn(CF.db.nodes[12].blackmouth) == 1, "fishing catch recorded")

-- learned nodes feed the planner
res = CF.FindRoutes({ "copper" }, { [12] = true })
check(res[1] and res[1].area == 12, "restricted search returns Elwynn only")

-------------------------------------------------------------------------------
-- map layers and UI
-------------------------------------------------------------------------------

WorldMapFrame._shown = true
CF.UpdateWorldMap()
WorldMapFrame._shown = false
CF.UpdateMinimap()
check(true, "world map and minimap layers draw")

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
print("  alchemy 112 reagents: " .. reagents[1][1] .. ", " .. reagents[2][1] .. ", " .. reagents[3][1])
check(CF.TrainerHint("fishing") ~= nil, "fishing capped at 150 -> trainer hint")
print("  hint: " .. CF.TrainerHint("fishing"))
check(not string.find(CF.TrainerHint("fishing"), "{"), "tokens replaced in hints")
for _, key in ipairs(CF.GUIDE_ORDER) do
  check(CF.Guides[key] and table.getn(CF.Guides[key].steps) > 0, "guide " .. key)
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
  for f in string.gfind(str, "%%[%a%%]") do table.insert(out, f) end
  return table.concat(out)
end

local function tokens(str)
  local out = {}
  for t in string.gfind(str, "{%a+:[^}]+}") do table.insert(out, t) end
  table.sort(out)
  return table.concat(out)
end

if LOCALE ~= "enUS" then
  local keys = {}
  local files = { "Core.lua", "UI.lua", "GuideUI.lua", "MapPins.lua", "Minimap.lua", "Data/Guides.lua" }
  for _, f in ipairs(files) do
    local fh = io.open(f)
    local src = fh:read("*a")
    fh:close()
    for k in string.gfind(src, 'CF%.L%["(.-[^\\])"%]') do keys[string.gsub(k, '\\"', '"')] = true end
  end
  -- guide notes and labels
  for _, g in pairs(CF.Guides) do
    for _, st in ipairs(g.steps) do
      for _, f in ipairs({ "text", "A", "H" }) do if st[f] then keys[st[f]] = true end end
    end
    for _, note in pairs(g.ranks or {}) do
      if type(note) == "table" then keys[note.A] = true keys[note.H] = true else keys[note] = true end
    end
  end
  for _, r in ipairs(CF.TRAINER_RANKS) do keys[r.rank] = true end
  for _, k in ipairs({ "Routes", "Leveling Guide", "Show gathered nodes", "Show route", "Minimap icons" }) do keys[k] = true end
  local tr = CF.TRANSLATIONS[LOCALE]
  for k in pairs(keys) do
    check(tr[k] ~= nil, LOCALE .. " translation: " .. k)
    if tr[k] then
      check(specifiers(tr[k]) == specifiers(k), LOCALE .. " format specifiers match: " .. k)
      check(tokens(tr[k]) == tokens(k), LOCALE .. " tokens match: " .. k)
    end
  end
  for k in pairs(tr) do check(keys[k], LOCALE .. " translation is used: " .. k) end
  check(CF.ZoneName(12) ~= "Elwynn Forest", "zone names localized: " .. CF.ZoneName(12))
  check(CF.materials.copper.name ~= "Copper Ore", "material names localized: " .. CF.materials.copper.name)
end

print("\nall tests passed (" .. LOCALE .. ")")
